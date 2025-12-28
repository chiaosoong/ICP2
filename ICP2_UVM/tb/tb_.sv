`include "conv_defines_pkg.sv"
// ======================================================
// Testbench for Patch Reader (Line Buffer Mode)
// ======================================================
`timescale 1ns/1ps

module tb_patch_reader;

  // Parameters
  parameter IFM_WIDTH  = 30;
  parameter IFM_HEIGHT = 30;
  parameter EXPECTED_PATCHES = 28 * 28;

  // DUT Signals
  logic         clk;
  logic         rst_n;
  logic         col_rd_en;
  logic [4:0]   row_idx;
  logic [4:0]   col_idx;
  logic         valid_patch;

  int patch_count = 0;
  int error_count = 0;

  // Instantiate DUT
  patch_reader #(
    .IFM_WIDTH (IFM_WIDTH),
    .IFM_HEIGHT(IFM_HEIGHT)
  ) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .col_rd_en   (col_rd_en),
    .col_idx     (col_idx),
    .row_idx     (row_idx),
    .valid_patch (valid_patch)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;  // 10ns clock

  // Test procedure
  initial begin
    $display("\n[TB] Starting Patch Reader Full Scan Test...\n");

    // Reset
    rst_n      = 0;
    col_rd_en  = 0;
    #20;
    rst_n      = 1;
    col_rd_en  = 1;

    // Run until all 784 valid patches are counted
    forever begin
      @(posedge clk);

      if (valid_patch) begin
        patch_count++;

        if (row_idx > 28) begin
          $display("[ERROR] Invalid patch at row=%0d, col=%0d", row_idx, col_idx);
          error_count++;
        end
      end

      if (patch_count == EXPECTED_PATCHES) begin
        $display("\n[TB] All %0d patches scanned successfully.", patch_count);
        if (error_count == 0)
          $display("[PASS] No errors detected.");
        else
          $display("[FAIL] %0d errors detected.", error_count);
        $stop;
      end
    end
  end

endmodule
