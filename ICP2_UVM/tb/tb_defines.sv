`timescale 1ns/1ps

`include "conv_defines_pkg.sv"  // Now just macros, no package

module tb_conv_defines;

  initial begin
    $display("=== Testing conv_defines_pkg_yooo ===");

    // Display data widths and constants
    $display("DATA_WIDTH          = %0d", `DATA_WIDTH);
    $display("ADDR_WIDTH          = %0d", `ADDR_WIDTH);
    $display("IFM_WIDTH x HEIGHT  = %0d x %0d", `IFM_WIDTH, `IFM_HEIGHT);
    $display("KERNEL_BASE_ADDR    = %0d", `KERNEL_BASE_ADDR);
    $display("BURST_SIZE          = %0d", `BURST_SIZE);

    // RAM Mode Check
    `ifdef RAM_MODE_160
      $display("RAM MODE            = 160x32");
      $display("MU_COUNT            = %0d", `MU_COUNT);
      $display("SUM_COUNT           = %0d", `SUM_COUNT);
    `elsif RAM_MODE_1024
      $display("RAM MODE            = 1024x8");
      $display("MU_COUNT            = %0d", `MU_COUNT);
      $display("SUM_COUNT           = %0d", `SUM_COUNT);
    `else
      $display("RAM MODE            = UNKNOWN (no define set)");
    `endif

    $stop;
  end

endmodule
