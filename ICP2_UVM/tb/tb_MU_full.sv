`include "conv_defines_pkg.sv"
`timescale 1ns/1ps

module tb_the_MU_unit;


  // ======================================================
  // Clock
  // ======================================================
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n;


  // ======================================================
  // DUT Signals
  // ======================================================
  localparam int ADDR_WIDTH = `ADDR_WIDTH;
  localparam int DW         = `DATA_WIDTH;
  localparam int MAX_WRITES = 32;

  // --- DUT I/O ---
  logic                      MU_start;

  logic [ADDR_WIDTH-1:0]     rd_addr_top_o, rd_addr_mid_o, rd_addr_bot_o;
  logic                      read_rq;   // from DUT
  logic                      rd_hs;     // our "RAM" handshake back to DUT
  assign rd_hs= 1'b1;

  logic [DW-1:0]             in_data_ch0 [2:0]; // top/mid/bot
  logic [DW-1:0]             in_data_ch1 [2:0];
  logic [DW-1:0]             in_data_ch2 [2:0];

  logic [DW-1:0]             kn_data_ch0 [0:8];
  logic [DW-1:0]             kn_data_ch1 [0:8];
  logic [DW-1:0]             kn_data_ch2 [0:8];

  logic                      MU_wr_rq_o;
  logic [ADDR_WIDTH-1:0]     MU_wr_addr_o;
  logic [DW-1:0]             ofm_final;

  // ======================================================
  // DUT
  // ======================================================
  the_MU_unit #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .MU_start      (MU_start),

    .rd_addr_top_o (rd_addr_top_o),
    .rd_addr_mid_o (rd_addr_mid_o),
    .rd_addr_bot_o (rd_addr_bot_o),
    .read_rq       (read_rq),
    .rd_hs         (rd_hs),

    .in_data_ch0   (in_data_ch0),
    .in_data_ch1   (in_data_ch1),
    .in_data_ch2   (in_data_ch2),

    .kn_data_ch0   (kn_data_ch0),
    .kn_data_ch1   (kn_data_ch1),
    .kn_data_ch2   (kn_data_ch2),

    .MU_wr_rq_o    (MU_wr_rq_o),
    .MU_wr_addr_o  (MU_wr_addr_o),
    .ofm_final       (ofm_final)
  );



   // ========= Test: one calculation, no fancy stuff =========
  initial begin
    int unsigned expected;
    logic [DW-1:0] expected_dw;

    rst_n    = 1'b0;
    MU_start = 1'b0;

    // kernels = 1 → MU sums the 27 IFM elements
    for (int i = 0; i < 9; i++) begin
      kn_data_ch0[i] = 'd1;
      kn_data_ch1[i] = 'd1;
      kn_data_ch2[i] = 'd1;
    end

    // reset
    repeat (4) @(posedge clk);
    rst_n    = 1'b1;
    @(posedge clk);

    // start the unit (drives internal read-pointer / shifter enable)
    MU_start = 1'b1;

    // feed THREE cycles of IFM triplets (columns 0,1,2) to build 3×3 windows
    // choose values 1..27 across channels/rows for easy expected sum = 378
    // ---- cycle 0 ----
    @(posedge clk);
    in_data_ch0[0] = 8'd1;  in_data_ch0[1] = 8'd2;  in_data_ch0[2] = 8'd3;   // ch0: top/mid/bot
    in_data_ch1[0] = 8'd4;  in_data_ch1[1] = 8'd5;  in_data_ch1[2] = 8'd6;   // ch1
    in_data_ch2[0] = 8'd7;  in_data_ch2[1] = 8'd8;  in_data_ch2[2] = 8'd9;   // ch2
    // ---- cycle 1 ----
    @(posedge clk);
    in_data_ch0[0] = 8'd10; in_data_ch0[1] = 8'd11; in_data_ch0[2] = 8'd12;
    in_data_ch1[0] = 8'd13; in_data_ch1[1] = 8'd14; in_data_ch1[2] = 8'd15;
    in_data_ch2[0] = 8'd16; in_data_ch2[1] = 8'd17; in_data_ch2[2] = 8'd18;
    // ---- cycle 2 ----
    @(posedge clk);
    in_data_ch0[0] = 8'd19; in_data_ch0[1] = 8'd20; in_data_ch0[2] = 8'd21;
    in_data_ch1[0] = 8'd22; in_data_ch1[1] = 8'd23; in_data_ch1[2] = 8'd24;
    in_data_ch2[0] = 8'd25; in_data_ch2[1] = 8'd26; in_data_ch2[2] = 8'd27;

    // after a couple of internal cycles (valid patch + 1-cycle delay),
    // the_MU_unit asserts MU_wr_rq_o with ofm_final latched.
    // just wait for the first pulse and print.
    wait (MU_wr_rq_o == 1'b1);
    expected    = (27*28)/2;         // 1..27 = 378
    expected_dw = expected[DW-1:0];  // masked to DATA_WIDTH
    $display("\n[TB] Expected OFM = %0d (masked=%0d)", expected, expected_dw);
    $display("[TB] DUT ofm_final  = %0d\n", ofm_final);

    repeat (200) @(posedge clk);
    
    $stop;
  end

endmodule


