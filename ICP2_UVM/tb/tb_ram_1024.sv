`timescale 1ns / 1ps
`include "conv_defines_pkg.sv"

module tb_ram_1024;

  logic clk;
  logic write_en, read_en;
  logic [`ADDR_WIDTH-1:0] addr;
  logic [`DATA_WIDTH-1:0] ram_data_in;
  logic [`DATA_WIDTH-1:0] ram_data_out;
  logic ry;

  // Instantiate DUT
  ram_wrapper_1024 uut (
    .clk(clk),
    .write_en(write_en),
    .read_en(read_en),
    .addr(addr),
    .ram_data_in(ram_data_in),
    .ram_data_out(ram_data_out),
    .ry(ry)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Initialization
  initial begin
    clk         = 0;
    write_en    = 0;
    read_en     = 0;
    addr        = 0;
    ram_data_in = 0;

    // Wait for reset-like delay
    repeat (5) @(posedge clk);

    $display("===== SINGLE-CYCLE WRITES =====");

    // Write 5 values with exact 1-cycle enable
    for (int i = 0; i < 5; i++) begin
      @(posedge clk);
      write_en    = 1;
      read_en     = 0;
      addr        = i;
      ram_data_in = i + 100;

      @(posedge clk);  // Deassert after 1 cycle
      write_en = 0;
      ram_data_in = 8'hXX;
      addr = 'X;
 
      // Wait a few idle cycles
      repeat (2) @(posedge clk);
    end

    // Allow write to settle
    repeat (2) @(posedge clk);

    $display("===== READBACK =====");

    // Read back values
    for (int i = 0; i < 5; i++) begin
      @(posedge clk);
      write_en = 0;
      read_en  = 1;
      addr     = i;

      @(posedge clk);  // Wait 1 cycle for RAM to output valid data
      $display("RAM[%0d] = %0d", i, ram_data_out);

      read_en = 0;
      addr = 'X;
      repeat (1) @(posedge clk);
    end

    $display("===== DONE =====");
    $stop;
  end

endmodule
