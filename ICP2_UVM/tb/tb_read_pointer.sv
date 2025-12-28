`include "conv_defines_pkg.sv"

// ======================================================
// Testbench for Patch Reader (Line Buffer Mode)
// ======================================================
`timescale 1ns/1ps

module tb_read_pointer;

  // ======================================================
  // Clock
  // ======================================================
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n;

  // ======================================================
  //  Signals
  // ======================================================

    // Parameters
  parameter IFM_WIDTH  = 30;
  parameter IFM_HEIGHT = 30;
  parameter EXPECTED_PATCHES = 28 * 28;

  localparam int TOTAL_STEPS = IFM_WIDTH * (IFM_HEIGHT - 2); // 30*28 = 840

  // DUT Signals
  logic col_rd_en;
  logic valid_patch;
  logic [`ADDR_WIDTH-1:0] addr_top, addr_mid, addr_bot;

  int patch_count = 0;
  int error_count = 0;
  int steps = 0;
  // ======================================================
  // DUT
  // ======================================================
  read_pointer #(
    .IFM_WIDTH (IFM_WIDTH),
    .IFM_HEIGHT(IFM_HEIGHT)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .col_rd_en  (col_rd_en),
    .valid_patch(valid_patch),
    .addr_top   (addr_top),
    .addr_mid   (addr_mid),
    .addr_bot   (addr_bot)
  );


  // ======================================================
  // Test
  // ======================================================
  initial begin
    $display("\n[TB] Starting Patch Reader Full Scan Test...\n");

    // Reset
    rst_n     = 1'b0;
    col_rd_en = 1'b0;
    repeat (4) @(posedge clk);
    rst_n     = 1'b1;

    // pulse col_rd_en once per cycle for TOTAL_STEPS steps
    while (steps <= TOTAL_STEPS) begin

        @(posedge clk);
        col_rd_en <= 1'b1;

        steps++;
    end  

    $stop;
  end

endmodule
