`timescale 1ns/1ps
`include "conv_defines_pkg.sv"

/*
wait (wr_rq) never detected in tb even though it was asserted from CA
the always block worked instead
*/


// ======================================================
// Testbench for CA_controller
// ======================================================
module tb_CA;

  // ======================================================
  // Clock and Reset
  // ======================================================
  logic clk = 0;
  logic rst_n;
  always #5 clk = ~clk;

  // ======================================================
  // I/O Signals
  // ======================================================
  logic start;
  logic wr_handshake_i;
  logic rd_handshake_i;

  logic [`DATA_WIDTH-1:0] ram1_output, ram2_output, ram3_output;

  logic CA_finished;
  logic wr_rq;
  logic [`ADDR_WIDTH:0] wr_addr;
  logic [`DATA_WIDTH-1:0] CA_output;
  logic rd_rq;
  logic [7:0] burst_size;

  int i;
  int pass_count = 0;
  int fail_count = 0;

  logic [9:0] expected_sum;
  logic [7:0] expected_pixel;

  logic kernel_done = 0; //TODO: signal used to make sure some always processes start later

  // ======================================================
  // Instantiate DUT
  // ======================================================
  CA_controller dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .start          (start),
    .CA_finished    (CA_finished),
    .wr_rq          (wr_rq),
    .wr_handshake_i (wr_handshake_i),
    .wr_addr        (wr_addr),
    .CA_output      (CA_output),
    .rd_rq          (rd_rq),
    .rd_handshake_i (rd_handshake_i),
    .burst_size     (burst_size),
    .ram1_output    (ram1_output),
    .ram2_output    (ram2_output),
    .ram3_output    (ram3_output)
  );


  // ======================================================
  // Kernel Values
  // ======================================================
  logic [`DATA_WIDTH-1:0] kernel_values_ch1 [0:8] = 
    '{8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9};
  logic [`DATA_WIDTH-1:0] kernel_values_ch2 [0:8] = 
    '{8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9};
  logic [`DATA_WIDTH-1:0] kernel_values_ch3 [0:8] = 
    '{8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9};

  logic [`DATA_WIDTH-1:0] patch_data = 8'd5;

  // ======================================================
  // Stimulus
  // ======================================================
  initial begin
    // Reset and init
    rst_n = 0;
    start = 0;
    wr_handshake_i = 0;
    rd_handshake_i = 0;
    ram1_output = 0;
    ram2_output = 0;
    ram3_output = 0;

    #20;
    rst_n = 1;
    #10;

    // Start CA
    start = 1;
    #10;
    start = 0;

    // -----------------------------------------------------
    // Feed kernel values (simulate RAM returning values)
    // -----------------------------------------------------
    wait (rd_rq);
    for (i = 0; i <= 8; i++) begin

      @(posedge clk);
      rd_handshake_i = 1;
      ram1_output = kernel_values_ch1[i];
      ram2_output = kernel_values_ch2[i];
      ram3_output = kernel_values_ch3[i];
    end

    @(posedge clk);
    rd_handshake_i = 1;
    @(posedge clk);
    rd_handshake_i = 0;
  
    wait (rd_rq);
    for (i = 0; i <= 8; i++) begin
      ram1_output <= patch_data;
      ram2_output <= patch_data;
      ram3_output <= patch_data;
      @(posedge clk);
      rd_handshake_i = 1;

    end


    wait (rd_rq);
    for (i = 0; i <= 8; i++) begin
      ram1_output <= patch_data;
      ram2_output <= patch_data;
      ram3_output <= patch_data;
      @(posedge clk);
      rd_handshake_i = 1;

    end

    wait (rd_rq);
    for (i = 0; i <= 8; i++) begin
      ram1_output <= patch_data;
      ram2_output <= patch_data;
      ram3_output <= patch_data;
      @(posedge clk);
      rd_handshake_i = 1;

    end

    wait (CA_finished);
    #20;

    $stop;
  end

  // ======================================================
  // Patch Feed (handled automatically during CA_MU)
  // ======================================================
  /*always @(posedge clk) begin
    if (rd_rq && kernel_done) begin
      rd_handshake_i <= 1;
      ram1_output <= patch_data;
      ram2_output <= patch_data;
      ram3_output <= patch_data;
    end else begin
      rd_handshake_i <= 0;
    end
  end */

  // ======================================================
  // Write Handshake
  // ======================================================
  always @(posedge clk) begin
    if (wr_rq) begin
      wr_handshake_i <= 1;
    end else begin
      wr_handshake_i <= 0;
    end
  end
endmodule
