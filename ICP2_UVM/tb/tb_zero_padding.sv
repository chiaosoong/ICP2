`timescale 1ns / 1ps

module tb_zero_padding;

  // Clock and reset
  logic clk;
  logic rst_n;
  logic start;

  // DUT outputs
  logic write_en;
  logic [2:0] ram_index;
  logic [9:0] ram_addr;
  logic [7:0] zero;
  logic  done;

  // Instantiate DUT
  z_pad_module dut (
    .clk(clk),
    .rst_n(rst_n),
    .start_zpad (start),
    .write_en(write_en),
    .ram_addr(ram_addr),
    .zero(zero),
    .padding_done(done)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Test sequence
  initial begin
    clk   = 0;
    rst_n = 0;
    start = 0;

    #20;
    rst_n = 1;
    #10;
    start = 1;
    #10;
    start = 0;

    // Let it run long enough
    #2000;
    $stop;
  end

endmodule
