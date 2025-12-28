`timescale 1ns/1ps
`include "conv_defines_pkg.sv"

// ===============================================
// Combined TB: address_converter — sweep all modes
// - Simple iteration only (no checks, no random)
// - Uses tasks to sweep each mode's full range
// ===============================================
module tb_addr_conv_wrapper;

  // Clock (DUT is combinational; clock just paces the sweeps)
  logic clk = 0;
  always #5 clk = ~clk;

  // Reset (not used by DUT, included for TB form)
  logic rst_n = 0;

  // DUT I/O
  logic [`ADDR_WIDTH-1:0] global_addr;   // driven by TB
  logic [`ADDR_WIDTH-1:0] local_addr;    // observed
  logic [1:0]             mode;          // driven by TB
  logic [2:0]             ram_index;     // observed

  // DUT
  addr_conv_wrapper dut (
    .global_addr(global_addr),
    .local_addr (local_addr),
    .mode       (mode),
    .ram_index  (ram_index)
  );

  // -------------------------
  // Tasks: sweep per mode
  // -------------------------

  /* when testing three things matter:
      global address --->
                          -local address
                          -ram index
                          first ram index is 1 not 0 since it is 
                            reserved for first row zeroes*/
        
  task automatic sweep_apb; // 0..783 (28x28)
    begin
      mode = `APB_WR_MODE;
      for (int i = 0; i <= 783; i++) begin
        global_addr = i[`ADDR_WIDTH-1:0];
        @(posedge clk);
      end
    end
  endtask
  //---------------------------------------
  task automatic sweep_full_ifm; // 0..899 (30x30 padded)
    begin
      mode = `FULL_IFM_MODE;
      for (int i = 0; i <= 899; i++) begin
        global_addr = i[`ADDR_WIDTH-1:0];
        @(posedge clk);
      end
    end
  endtask
  //--------------------------------------- 
  task automatic sweep_ofm; // 0..783 (chunked by 160)
    begin
      mode = `OFM_MODE;
      for (int i = 0; i <= 783; i++) begin
        global_addr = i[`ADDR_WIDTH-1:0];
        @(posedge clk);
      end
    end
  endtask

  // -------------------------
  // Test sequence
  // -------------------------
  initial begin
    // simple reset pulse
    repeat (2) @(posedge clk);
    rst_n = 1'b1;

    // Run tasks sequentially (blocking calls)
    $display("[TB] Start APB sweep");
    sweep_apb();

    repeat (2) @(posedge clk); // spacer
    $display("[TB] Start FULL_IFM sweep");
    sweep_full_ifm();

    repeat (2) @(posedge clk); // spacer
    $display("[TB] Start OFM sweep");
  
    sweep_ofm();

    $display("[TB] Done1.");

    $stop;
  end

endmodule
