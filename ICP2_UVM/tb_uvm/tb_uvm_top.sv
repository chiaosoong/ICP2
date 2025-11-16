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

    // ======================================================
    // Clock Generation 100 MHz
    // ======================================================
    logic clk_100MHz;
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
    // CA Data Monitor Interface Connection
    // =================================================================================
    initial begin
        // Use 'force' to connect the monitor interface to the DUT's internal signals.
        // Force IFM data signals
        force ca_mon_intf.ifm0 = tb_uvm_top.dut.u_top.ifm0;
        force ca_mon_intf.ifm1 = tb_uvm_top.dut.u_top.ifm1;
        force ca_mon_intf.ifm2 = tb_uvm_top.dut.u_top.ifm2;

        // Force the IFM read handshake signal (to indicate valid IFM data)
        force ca_mon_intf.rd_ifm_hs = tb_uvm_top.dut.u_top.ca_bus.rd_ifm_hs;
        force ca_mon_intf.rd_knl_hs = tb_uvm_top.dut.u_top.ca_bus.rd_knl_hs;
    end

    // =================================================================================
    // UVM Configuration DB Setup
    // =================================================================================
    initial begin
        // Set APB interface in config DB
        uvm_config_db#(virtual apb_interface)::set(
            null, "*", "APB_INTF", apb_intf
        );

        // Set CA data monitor interface in config DB
        // UVM monitors can retrieve this and use it to observe signals
        uvm_config_db#(virtual ca_monitor_interface)::set(
            null, "*", "CA_MON_INTF", ca_mon_intf
        );

        // Start the test
        run_test();
    end

endmodule