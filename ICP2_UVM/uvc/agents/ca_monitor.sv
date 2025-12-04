// Simple UVM monitor that samples the `ca_monitor_intf` (or similar)
// and publishes a `ca_ifm_kernel_seq_item` on an analysis port.
class ca_monitor extends uvm_monitor;
    `uvm_component_utils(ca_monitor)

    // Virtual interface (monitor modport expected)
    virtual ca_monitor_interface.monitor mon_if;
    // Analysis port to send captured items to scoreboard/other components
    uvm_analysis_port#(ca_ifm_kernel_seq_item) ap;

    function new(string name = "ca_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    // Get interface from config DB
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ca_monitor_interface.monitor)::get(this, "", "CA_MON_INTF", mon_if)) begin
            `uvm_fatal("MON_IF_NOTFOUND", "ca_monitor: cannot find CA monitor interface in config DB (CA_MON_INTF)")
        end
    endfunction

    // Main sampling loop: capture both kernel loads and IFM patch reads
    virtual task run_phase(uvm_phase phase);
        ca_ifm_kernel_seq_item item;
        logic [7:0] prev_ifm0, prev_ifm1, prev_ifm2;

        forever begin
            // sample on the interface clocking block; mon_if.cb samples at posedge clk
            @(mon_if.cb);

            // Kernel load handshake: monitor provides a compact signal rd_knl_hs
            if (mon_if.cb.rd_knl_hs) begin
                item = ca_ifm_kernel_seq_item::type_id::create("item");
                item.is_kernel = 1;
                item.ifm_lane[0] = mon_if.cb.ifm0[0];
                item.ifm_lane[1] = mon_if.cb.ifm1[0];
                item.ifm_lane[2] = mon_if.cb.ifm2[0];
                item.time_stamp = $time;
                ap.write(item);
            end

            // IFM read handshake: CA requests IFM patches during CA_MU
            if (mon_if.cb.valid_patch) begin
                item = ca_ifm_kernel_seq_item::type_id::create("item");
                item.is_kernel = 0;
                // capture the 3 lanes making up the patch element
                // Use PREVIOUS cycle's data to capture the center pixel (p0) instead of right pixel (p1)
                // The valid_patch signal is delayed by 1 cycle relative to the center pixel read.
                item.ifm_lane[0] = prev_ifm0;
                item.ifm_lane[1] = prev_ifm1;
                item.ifm_lane[2] = prev_ifm2;
                item.time_stamp = $time;
                ap.write(item);
            end

            // Update history for next cycle
            // We sample index [1] (Mid Row) as that corresponds to the data row
            prev_ifm0 = mon_if.cb.ifm0[1];
            prev_ifm1 = mon_if.cb.ifm1[1];
            prev_ifm2 = mon_if.cb.ifm2[1];
        end
    endtask

endclass
