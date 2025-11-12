`timescale 1ns/1ps
`include "conv_defines_pkg.sv"

module tb_ram_controller;

  // ---------------- Clock / Reset ----------------
  logic clk = 0; always #5 clk = ~clk;
  logic rst_n;

  // ---------------- DUT I/O ----------------
  // APB-like write/read to IFM memories (banks 0..2) and OFM bank (bank3)
  logic                    APB_wr_done_ram;
  logic [1:0]              channel_ctrl;
  logic                    CA_finished_i;
  logic                    MU_done;

  logic                    wr_en_APB;
  logic                    valid_input_APB;
  logic [`DATA_WIDTH-1:0]  wr_data_APB;
  logic [`ADDR_WIDTH-1:0]  wr_addr_APB;
  logic                    rd_cmd_APB;
  logic [`ADDR_WIDTH-1:0]  rd_apb_addr;

  // CA side
  logic                    burst_rd_rq_i;
  logic                    rd_hs;
  logic                    rd_knl_rq_i;
  logic                    rd_kn_hs;

  logic [`ADDR_WIDTH-1:0]  rd_addr_CA_top;
  logic [`ADDR_WIDTH-1:0]  rd_addr_CA_mid;
  logic [`ADDR_WIDTH-1:0]  rd_addr_CA_bot;

  logic [`DATA_WIDTH-1:0]              bank0_out [2:0];
  logic [`DATA_WIDTH-1:0]              bank1_out [2:0];
  logic [`DATA_WIDTH-1:0]              bank2_out [2:0];
  logic [`DATA_WIDTH-1:0]  bank3_output;

  logic                    wr_rq_CA_i;
  logic                    wr_handshake;
  logic [`DATA_WIDTH-1:0]  wr_data_CA;
  logic [`ADDR_WIDTH-1:0]  wr_addr_CA;

  logic [`ADDR_WIDTH-1:0]  rd_addr_CA;
  logic                    use_kernel_addr;

  logic                    ry;

  localparam logic [1:0] CH0 = `CHANNEL_1;
  localparam logic [1:0] CH1 = `CHANNEL_2;
  localparam logic [1:0] CH2 = `CHANNEL_3;

  integer wr_count;

  // ---------------- DUT ----------------
  ram_controller_conv dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .APB_wr_done    (APB_wr_done_ram),
    .channel_ctrl   (channel_ctrl),
    .CA_finished_i  (CA_finished_i),

    .wr_en_APB      (wr_en_APB),
    .valid_input_APB(valid_input_APB),
    .wr_data_APB    (wr_data_APB),
    .wr_addr_APB    (wr_addr_APB),
    .rd_cmd_APB     (rd_cmd_APB),
    .rd_apb_addr    (rd_apb_addr),

    // ===== Interface to CA =====
    .rd_ifm_rq_i  (burst_rd_rq_i),
    .rd_ifm_hs_o          (rd_hs),
    .rd_knl_rq_i    (rd_knl_rq_i),
    .rd_kn_hs_o       (rd_kn_hs),

    .wr_rq_CA_i     (wr_rq_CA_i),
    .wr_hs_CA_o   (wr_handshake),
    .wr_data_ofm_i     (wr_data_CA),
    .wr_addr_ofm_i     (wr_addr_CA),

    .ifm_data0_o      (bank0_out),
    .ifm_data1_o      (bank1_out),
    .ifm_data2_o      (bank2_out),
    .ofm_data_o   (bank3_output)


  );


// -------------------------------
// 1.1
// -------------------------------
  task automatic apb_latch_channel(input logic [1:0] ch);
  begin
    // Latch channel this cycle, no write
    channel_ctrl     = ch;
    wr_en_APB        = 1'b1;
    valid_input_APB  = 1'b0;
    @(posedge clk);
    wr_en_APB        = 1'b0;
  end
  endtask
// -------------------------------
// 1.2
// -------------------------------
  task automatic apb_write_one(
    input int addr_i,
    input int data_i,
    input bit relatch_next,
    input logic [1:0] next_ch
  );
    begin
      // Present address/data and optionally re-latch next channel
      wr_addr_APB      = addr_i;
      wr_data_APB      = data_i % 256;
      valid_input_APB  = 1'b1;

      if (relatch_next) begin
        channel_ctrl   = next_ch;
        wr_en_APB      = 1'b1;   // latch next channel in SAME cycle as last write
      end else begin
        wr_en_APB      = 1'b0;
      end

      @(posedge clk);            // one write per clock
      valid_input_APB  = 1'b0;
      wr_en_APB        = 1'b0;
      wr_count++;
    end
  endtask

// -------------------------------
// 1.3
// -------------------------------
  localparam int NUM_OF_INPUTS = 784; // 0..783
  localparam int NUM_KERNEL    = 9;   // 784..792
  localparam int K_BASE        = NUM_OF_INPUTS;

  task automatic apb_write_burst_ifm(input logic [1:0] ch);
    int i;
    begin
        apb_latch_channel(ch); // pure latch, NO write; next cycle starts at addr 0

        for (i = 0; i < NUM_OF_INPUTS; i++) begin
          bit relatch = (i == NUM_OF_INPUTS-1) && (ch < 2); // re-latch next channel on last write
          apb_write_one(i, i, relatch, ch + 2'd1);
        end
    end
  endtask

  task automatic apb_write_burst_kernel(input logic [1:0] ch);
    int i;
    begin
        apb_latch_channel(ch); // pure latch before kernel burst

        for (i = K_BASE; i < K_BASE + NUM_KERNEL; i++) begin
          bit relatch = (i == K_BASE + NUM_KERNEL - 1) && (ch < 2);
          apb_write_one(i, i, relatch, ch + 2'd1);
        end
    end
  endtask

// -------------------------------
// Task 1 full
// -------------------------------
  task automatic task1_apb_writes;
    logic [1:0] ch;

    begin
      wr_count = 0;

      // IFM bursts: CH0 -> CH1 -> CH2
        for (ch = 2'd0; ch < 2'd3; ch++) begin
          apb_write_burst_ifm(ch);
        end

        // Kernel bursts: CH0 -> CH1 -> CH2
        for (ch = 2'd0; ch < 2'd3; ch++) begin
          apb_write_burst_kernel(ch);
        end

        // Signal done
        APB_wr_done_ram = 1'b1;
        @(posedge clk);
        APB_wr_done_ram = 1'b0;
    end
  endtask


// =============================================
//  2. TASK: wait for zero-pad until entering idle state (skip first idle state)
// =============================================


  task automatic task2_start_burst_read;
    int i;
    begin

        // Wait for zero-pad phase and return to IDLE
        wait (dut.curr_state == dut.WR_ZERO_st);
        wait (dut.curr_state == dut.IDLE);

        // Pulse read request for one cycle
        @(posedge clk);
        burst_rd_rq_i = 1'b1;
        @(posedge clk);
        burst_rd_rq_i = 1'b0;

        //-----------------------------
        wait (dut.curr_state == dut.RD_WR_CA_st);
        @(posedge clk);

        //-----------------------------
        for (i = 0; i < 784; i++) begin
            wr_rq_CA_i   = 1'b1;
            //----------------------
            if (wr_handshake) begin
                wr_addr_CA   = i[`ADDR_WIDTH-1:0];
                wr_data_CA   = i[7:0];
            end  
            @(posedge clk);      
        end

        //-----------------------------
        wr_rq_CA_i   = 1'b0;
        wr_addr_CA   = 'x;
        wr_data_CA   = 'x;

        // wait until all patches valid 
        wait (dut.cnt_valid_patch == 12'd784);

        @(posedge clk);
        wait (dut.curr_state == dut.IDLE);

    end
  endtask

  // =============================================
//  Read Bank3 via APB (controller-gated)
//  - start_addr: first APB (OFM) address to read (0..783)
//  - count     : number of reads
//  - do_check  : when 1, compare bank3_output with addr[7:0]
// =============================================
// =============================================
// Read Bank3 via APB, sequentially per sub-RAM
// Chunks: [0..159], [160..319], [320..479], [480..639], [640..783]
// =============================================
task automatic task_apb_read_bank3_by_ram(input bit check = 1'b0);
  int seg;
  logic [`ADDR_WIDTH-1:0] addr_n;
  byte expected;
begin
  // Gate controller path to Bank3
  CA_finished_i = 1'b1;
  rd_cmd_APB    = 1'b1;

  for (seg = 0; seg < 5; seg++) begin
    int start = seg * 160;
    int count = (seg < 4) ? 160 : 144; // last chunk is 640..783

    // Prime first address of this segment
    addr_n      = start;
    rd_apb_addr = addr_n;
    @(posedge clk); // 1-cycle latency

    // Pipeline: one result and one next address per cycle
    for (int k = 0; k < count; k++) begin
      // Check / print result for current addr
      expected = byte'(addr_n[7:0]);   // wrap to 8-bit
      if (check && bank3_output !== expected)
        $error("[%0t] B3 READ seg=%0d addr=%0d exp=%0h got=%0h",
               $time, seg, addr_n, expected, bank3_output);
      else
        $display("[%0t] B3 READ seg=%0d addr=%0d data=%0h",
                 $time, seg, addr_n, bank3_output);

      // Drive next address within this segment
      if (k+1 < count) begin
        addr_n      = start + (k+1);
        rd_apb_addr = addr_n;
        @(posedge clk);
      end
    end
  end

  // Tidy
  rd_cmd_APB    = 1'b0;
  CA_finished_i = 1'b0;
end
endtask



// =============================================
//  Test 
// =============================================
  initial begin
    // defaults
    rst_n            = 0;
    APB_wr_done_ram  = 0;
    channel_ctrl     = CH0;
    CA_finished_i    = 0;
    MU_done          = 0;

    wr_en_APB        = 0;
    valid_input_APB  = 0;
    wr_data_APB      = '0;
    wr_addr_APB      = '0;
    rd_cmd_APB       = 0;
    rd_apb_addr      = '0;

    burst_rd_rq_i    = 0;
    rd_knl_rq_i      = 0;

    rd_addr_CA_top   = '0;
    rd_addr_CA_mid   = '0;
    rd_addr_CA_bot   = '0;

    wr_rq_CA_i       = 0;
    wr_data_CA       = '0;
    wr_addr_CA       = '0;

    rd_addr_CA       = '0;
    use_kernel_addr  = 0;
    wr_count         = 0;

    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    // ---- Run tasks sequentially ----
    task1_apb_writes();
    task2_start_burst_read();
    task_apb_read_bank3_by_ram(/*check=*/1'b1);

    // wrap up
    repeat (10) @(posedge clk);
    $display("TB done.");
    $stop;
  end

endmodule
