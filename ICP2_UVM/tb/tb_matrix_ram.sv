// ======================================================
// Testbench for sram_wrapper (SystemVerilog)
// ======================================================

`timescale 1ns / 1ps

module tb_sram_wrapper;

  // Clock and reset
  logic clk;
  logic cs_n;
  logic we_n;
  logic [7:0]  address;
  logic [31:0] write_data;
  logic [31:0] read_data;
  logic        ry;

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk; // 100 MHz clock

  // Instantiate the DUT
  ram_wrapper_160 dut (
    .clk        (clk),
    .cs_n       (cs_n),
    .we_n       (we_n),
    .address    (address),
    .ry         (ry),
    .write_data (write_data),
    .read_data  (read_data)
  );

  // Test sequence
  initial begin
    // Default signals
    cs_n = 1;
    we_n = 1;
    address = 0;
    write_data = 0;

    // Wait some time
    #20;

    // Write value to address 0x01
    @(posedge clk);
    cs_n = 0;
    we_n = 0;
    address = 8'h01;
    write_data = 32'hDEADBEEF;

    // Write value to address 0x02
    @(posedge clk);
    address = 8'h02;
    write_data = 32'hCAFEBABE;

    // End write
    @(posedge clk);
    we_n = 1;

    // Read back from address 0x01
    @(posedge clk);
    address = 8'h01;

    @(posedge clk);
    $display("Read [0x01] = 0x%08X (RY = %b)", read_data, ry);

    // Read back from address 0x02
    @(posedge clk);
    address = 8'h02;

    @(posedge clk);
    $display("Read [0x02] = 0x%08X (RY = %b)", read_data, ry);

    // Done
    @(posedge clk);
    cs_n = 1;

    #20;
    $stop;
  end

endmodule
