`include "../rtl/conv_defines_pkg.sv"
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
    // Interface declaration
    // ====================================================
    apb_interface   apb_intf(clk_100MHz);

    // ======================================================
    // DUT Instantiation
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

    // set interface in uvm config db 
    initial begin
        uvm_config_db#(virtual apb_interface)::set(null, "*", "APB_INTF", apb_intf);
        // start the test
        run_test();
    end
endmodule