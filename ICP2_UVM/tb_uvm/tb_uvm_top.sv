// =================================================================================
// tb_uvm_top.sv
// Description:
//   UVM testbench top-level that instantiates APB interface, DUT (apb_convolution),
//   and a CA data monitor interface to observe kernel/IFM data without modifying
//   the original RTL code.
// =================================================================================

`include "../rtl/conv_defines_pkg.sv"
`include "apb_interface.sv"
`include "ca_monitor_interface.sv"
module tb_uvm_top;
    // ======================================================
    // Include and import uvm_pkg
    // ======================================================
    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import apb_test_pkg::*;

    // ======================================================
    // Clock Generation 100 MHz
    // ======================================================
    bit clk_100MHz;
    always #5 clk_100MHz = ~clk_100MHz;

    // ======================================================
    // Interface declarations
    // ======================================================
    apb_interface           apb_intf(clk_100MHz);
    ca_monitor_interface   ca_mon_intf(clk_100MHz, apb_intf.PRESETn);

    // ======================================================
    // DUT Instantiation
    // Note: apb_convolution internally instantiates top_file_convolution
    // ======================================================
    apb_convolution dut (
        .HRESETn(apb_intf.PRESETn),   // Active low Reset
        .HCLK(clk_100MHz),            // 100MHz clock
        .PSEL(apb_intf.PSEL),         // Select Signal
        .PENABLE(apb_intf.PENABLE),   // Enable Signal
        .PWRITE(apb_intf.PWRITE),     // Write Strobe
        .PADDR(apb_intf.PADDR),       // Addr
        .PWDATA(apb_intf.PWDATA),     // Write data
        .PRDATA(apb_intf.PRDATA),     // Read data
        .PREADY(apb_intf.PREADY),     // Slave Ready
        .PSLVERR(apb_intf.PSLVERR)    // Slave Error Response
    );

    // =================================================================================
    // CA Data Monitor Interface Connection (simulation-only)
    // - Use continuous assignment to snapshot DUT internals into the monitor
    // =================================================================================
    
    // Connect IFM data signals element-by-element
    assign ca_mon_intf.ifm0[0] = dut.u_top.ifm0[0];
    assign ca_mon_intf.ifm0[1] = dut.u_top.ifm0[1];
    assign ca_mon_intf.ifm0[2] = dut.u_top.ifm0[2];

    assign ca_mon_intf.ifm1[0] = dut.u_top.ifm1[0];
    assign ca_mon_intf.ifm1[1] = dut.u_top.ifm1[1];
    assign ca_mon_intf.ifm1[2] = dut.u_top.ifm1[2];

    assign ca_mon_intf.ifm2[0] = dut.u_top.ifm2[0];
    assign ca_mon_intf.ifm2[1] = dut.u_top.ifm2[1];
    assign ca_mon_intf.ifm2[2] = dut.u_top.ifm2[2];

    // Connect the IFM/kernel read handshake signals
    assign ca_mon_intf.rd_ifm_hs = dut.u_top.ca_bus.rd_ifm_hs;
    assign ca_mon_intf.rd_knl_hs = dut.u_top.ca_bus.rd_knl_hs;
    assign ca_mon_intf.valid_patch = dut.u_top.ca_bus.valid_patch;

    // =================================================================================
    // UVM Configuration DB Setup
    // =================================================================================
    initial begin
        // Set APB interface in config DB
        uvm_config_db#(virtual apb_interface)::set(
            null, "*", "APB_INTF", apb_intf
        );

        // Set CA data monitor interface in config DB
        // Pass the monitor modport type so monitors can get a virtual modport
        uvm_config_db#(virtual ca_monitor_interface.monitor)::set(
            null, "*", "CA_MON_INTF", ca_mon_intf
        );

        // Start the test
        run_test();
    end

endmodule