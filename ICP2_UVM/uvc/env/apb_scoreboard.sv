`include "uvm_macros.svh"
import uvm_pkg::*;

`uvm_analysis_imp_decl(_drv2scb)
`uvm_analysis_imp_decl(_mntr2scb)
`uvm_analysis_imp_decl(_ca2scb)

// =================================================================================
// Simple APB Scoreboard
// - Collects DATA writes observed by the driver/monitor (writes to DATA_ADDR)
// - Collects CA-observed IFM and kernel items (ca_ifm_kernel_seq_item)
// - Provides `compare_saved_data()` which compares stored driver DATA against
//   CA-observed values. This implementation is intentionally simple and
//   assumes the test writes IFM first then kernel in a fixed order.
// =================================================================================

class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    // ----- simple local constants (adjust if your design differs) -----
    localparam int IFM_TOTAL = 3*784; // 2352
    localparam int KER_TOTAL = 3*9;   // 27

    // ----- storage collected from analysis ports -----
    // flat list of DATA payloads observed on writes to DATA_ADDR
    bit [`DATA_WIDTH-1:0] drv_data[$];

    // CA-observed items
    ca_ifm_kernel_seq_item ca_ifm_items[$];   // items with is_kernel==0
    ca_ifm_kernel_seq_item ca_kernel_items[$]; // items with is_kernel==1

    // ----- analysis imports (these names match connections used in env) -----
    uvm_analysis_imp_drv2scb#(apb_seq_item, apb_scoreboard) ap_drv2scb;
    uvm_analysis_imp_mntr2scb#(apb_seq_item, apb_scoreboard) ap_mntr2scb;
    uvm_analysis_imp_ca2scb#(ca_ifm_kernel_seq_item, apb_scoreboard) ap_ca2scb;

    // constructor
    function new(string name = "apb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_drv2scb = new("ap_drv2scb", this);
        ap_mntr2scb = new("ap_mntr2scb", this);
        ap_ca2scb = new("ap_ca2scb", this);
    endfunction

    // build/connect stubs
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    // run_phase does not perform immediate comparisons; comparisons are
    // triggered on-demand by calling `compare_saved_data()` from a test.
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        // idle
        wait(0);
    endtask

    // -----------------------------------------------------------------
    // write_drv2scb: called when driver/monitor publishes an apb_seq_item
    // We only record write DATA payloads when they are writes to DATA_ADDR.
    // -----------------------------------------------------------------
    function void write_drv2scb(apb_seq_item item);
        if (item.op_type == WRITE && item.ADDR == DATA_ADDR) begin
            drv_data.push_back(item.DATA);
            // `uvm_info("SCB", $sformatf("Recorded driver DATA write: 0x%0h (total drv_data=%0d)", item.DATA, drv_data.size()), UVM_LOW)
        end
    endfunction

    // -----------------------------------------------------------------
    // write_ca2scb: called when CA monitor publishes a ca_ifm_kernel_seq_item
    // Store it in the appropriate list (IFM or kernel) for later comparison
    // -----------------------------------------------------------------
    function void write_ca2scb(ca_ifm_kernel_seq_item item);
        if (item.is_kernel) begin
            ca_kernel_items.push_back(item);
            // `uvm_info("SCB", $sformatf("Recorded CA KERNEL item (total ca_kernel_items=%0d)", ca_kernel_items.size()), UVM_LOW)
        end else begin
            ca_ifm_items.push_back(item);
            // `uvm_info("SCB", $sformatf("Recorded CA IFM item (total ca_ifm_items=%0d)", ca_ifm_items.size()), UVM_LOW)
        end
    endfunction

    // optional: keep monitor ap writes if needed (not required for this simple flow)
    function void write_mntr2scb(apb_seq_item item);
        // no-op or log if desired
        `uvm_info("SCB_MNTR", $sformatf("Monitor saw op=%0d ADDR=0x%0h DATA=0x%0h", item.op_type, item.ADDR, item.DATA), UVM_DEBUG);
    endfunction

    // -----------------------------------------------------------------
    // compare_saved_data: simple on-demand comparison
    // - splits drv_data into IFM and kernel using IFM_TOTAL/KER_TOTAL
    // - compares CA-observed arrays against driver arrays (by index)
    // - prints uvm_error on mismatches
    // -----------------------------------------------------------------
    function void compare_saved_data();
        int mismatches = 0;
        int unsigned ifm_per_ch = 784;
        int unsigned ker_per_ch = 9;
        int unsigned k_limit;

        // compare IFM: each CA IFM item corresponds to 3 driver entries (one from each channel block)
        `uvm_info("SCB_COMPARE", "Starting IFM Comparison...", UVM_LOW)
        for (int unsigned i = 0; i < ca_ifm_items.size(); i++) begin
            for (int lane = 0; lane < 3; lane++) begin
                // Calculate driver index based on block-wise storage
                // Lane 0 -> Ch0 (Offset 0)
                // Lane 1 -> Ch1 (Offset 784)
                // Lane 2 -> Ch2 (Offset 1568)
                int unsigned drv_idx = lane * ifm_per_ch + i;
                
                if (drv_idx >= drv_data.size()) begin
                    `uvm_error("SCB_COMPARE_IFM", $sformatf("Missing driver IFM data for CA item %0d lane %0d (idx=%0d)", i, lane, drv_idx));
                    mismatches++;
                    continue;
                end
                if (drv_data[drv_idx] !== ca_ifm_items[i].ifm_lane[lane]) begin
                    `uvm_error("SCB_COMPARE_IFM", $sformatf("IFM mismatch item %0d lane %0d: drv=0x%0h ca=0x%0h", i, lane, drv_data[drv_idx], ca_ifm_items[i].ifm_lane[lane]));
                    mismatches++;
                end else begin
                    // Print details for the first few and last few items to show the process
                    if (i < 3 || i >= ca_ifm_items.size() - 3) begin
                        `uvm_info("SCB_MATCH_IFM", $sformatf("IFM Match Item %0d Lane %0d: Drv_Idx[%0d]=0x%0h == CA_Lane[%0d]=0x%0h", i, lane, drv_idx, drv_data[drv_idx], lane, ca_ifm_items[i].ifm_lane[lane]), UVM_LOW)
                    end
                end
            end
        end

        // compare kernel: CA kernel items map similarly (block-wise after IFM)
        // Limit comparison to expected number of kernel items (9) to avoid issues with extra captures
        k_limit = (ca_kernel_items.size() > ker_per_ch) ? ker_per_ch : ca_kernel_items.size();
        
        `uvm_info("SCB_COMPARE", "Starting Kernel Comparison...", UVM_LOW)
        for (int unsigned i = 0; i < k_limit; i++) begin
            for (int lane = 0; lane < 3; lane++) begin
                // Calculate driver index: IFM offset + Lane offset + i
                // Lane 0 -> Ch0 (Offset 0)
                // Lane 1 -> Ch1 (Offset 9)
                // Lane 2 -> Ch2 (Offset 18)
                int unsigned drv_idx = IFM_TOTAL + (lane * ker_per_ch) + i;

                if (drv_idx >= drv_data.size()) begin
                    `uvm_error("SCB_COMPARE_KER", $sformatf("Missing driver KERNEL data for CA kernel item %0d lane %0d (idx=%0d)", i, lane, drv_idx));
                    mismatches++;
                    continue;
                end
                if (drv_data[drv_idx] !== ca_kernel_items[i].ifm_lane[lane]) begin
                    `uvm_error("SCB_COMPARE_KER", $sformatf("KERNEL mismatch item %0d lane %0d: drv=0x%0h ca=0x%0h", i, lane, drv_data[drv_idx], ca_kernel_items[i].ifm_lane[lane]));
                    mismatches++;
                end else begin
                    `uvm_info("SCB_MATCH_KER", $sformatf("KERNEL Match Item %0d Lane %0d: Drv_Idx[%0d]=0x%0h == CA_Lane[%0d]=0x%0h", i, lane, drv_idx, drv_data[drv_idx], lane, ca_kernel_items[i].ifm_lane[lane]), UVM_LOW)
                end
            end
        end

        if (mismatches == 0) begin
            `uvm_info("SCB_COMPARE", $sformatf("Comparison Successful!!"), UVM_LOW);
        end else begin
            `uvm_error("SCB_COMPARE", $sformatf("Comparison found %0d mismatches", mismatches));
        end
    endfunction

endclass: apb_scoreboard