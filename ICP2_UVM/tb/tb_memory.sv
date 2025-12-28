`timescale 1ns/1ps
`include "conv_defines_pkg.sv"

module tb_memory;

  // ======================================================
  // Clock
  // ======================================================
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n;

  // ======================================================
  // DUT Signals
  // ======================================================

  // Addressing
  logic [2:0] ram_index_b3;
  logic [9:0] local_addr_b3;

  // Bank control
  logic [3:0] we_bank;
  logic [3:0] re_bank;

  // Data I/O
  logic [7:0] bank_din     [3:0];
  logic [7:0] bank0_outputs[2:0];
  logic [7:0] bank1_outputs[2:0];
  logic [7:0] bank2_outputs[2:0];
  logic [7:0] bank3_out;

  // MU Read state IFM indices (not used in this test)
  logic [2:0] ram_index_top, ram_index_mid, ram_index_bot;
  logic [9:0] rd_addr_top,   rd_addr_mid,   rd_addr_bot;

  int j;
  
  // ======================================================
  // DUT
  // ======================================================
  memory_module dut (
    .clk            (clk),
    .rst_n          (rst_n),

    .ram_index_b3   (ram_index_b3),
    .local_addr_b3  (local_addr_b3),

    .we_bank        (we_bank),
    .re_bank        (re_bank),

    .bank_din       (bank_din),

    .ram_index_top  (ram_index_top),
    .ram_index_mid  (ram_index_mid),
    .ram_index_bot  (ram_index_bot),

    .rd_addr_top    (rd_addr_top),
    .rd_addr_mid    (rd_addr_mid),
    .rd_addr_bot    (rd_addr_bot),

    .bank0_outputs  (bank0_outputs),
    .bank1_outputs  (bank1_outputs),
    .bank2_outputs  (bank2_outputs),
    .bank3_out      (bank3_out)
  );

  // ======================================================
  // Read task
  // ======================================================

    task automatic read_bank_parallel (
        input  int bank_num,
        input  [2:0] top_idx, mid_idx, bot_idx,
        input  [9:0] addr_top, addr_mid, addr_bot
    );
        begin
          // Activate read bank
          re_bank[bank_num] = 1;

          // Set all read indices and addresses in one cycle
          ram_index_top = top_idx;   rd_addr_top = addr_top;
          ram_index_mid = mid_idx;   rd_addr_mid = addr_mid;
          ram_index_bot = bot_idx;   rd_addr_bot = addr_bot;

          // Wait one clock cycle for RAM output
          @(posedge clk);

          // Deassert read signals
          re_bank[bank_num] = 0;
         // ram_index_top = 3'd0; rd_addr_top = 'x;
         // ram_index_mid = 3'd0; rd_addr_mid = 'x;
        //  ram_index_bot = 3'd0; rd_addr_bot = 'x;
        end
    endtask

  // ======================================================
  // Write task
  // ======================================================
    task automatic write_to_ram(
          input int          bank_sel,    // 0–3
          input logic [2:0]  ram_idx,
          input logic [9:0]  addr,
          input logic [7:0]  value
      );
          begin

            @(posedge clk);
            bank_din[bank_sel] = value;
            we_bank[bank_sel]  = 1;

            if (bank_sel == 3) begin
              // Bank3 path
              ram_index_b3  = ram_idx;
              local_addr_b3 = addr;
            end else begin
              // Banks 0–2 path: use TOP selector/addr for writes
              ram_index_top = ram_idx;
              rd_addr_top   = addr;
            end
            
            @(posedge clk);
            we_bank[bank_sel]  = 0;
            local_addr_b3         = 'x;
          end
      endtask

  // ======================================================
  // Test
  // ======================================================

  initial begin
    // Init
    // Init
    rst_n = 0;
    we_bank = 0;
    re_bank = 0;
    ram_index_b3  = 3'd7;  // safe default
    local_addr_b3 = 0;
    bank_din = '{default:0};

    ram_index_top = 3'd0;
    ram_index_mid = 3'd0;
    ram_index_bot = 3'd0;

    rd_addr_top   = '0;
    rd_addr_mid   = '0;
    rd_addr_bot   = '0;

    repeat (3) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);


    // bank, indx, add, value
    write_to_ram(0, 3'd0, 10'd0, 8'd10);
    write_to_ram(0, 3'd1, 10'd1, 8'd20);
    write_to_ram(0, 3'd2, 10'd2, 8'd30);

    write_to_ram(2, 3'd3, 10'd0, 8'd40);
    write_to_ram(2, 3'd4, 10'd1, 8'd50);
    write_to_ram(2, 3'd5, 10'd2, 8'd60);

    // Read : bank, top/mid/bot ind, top/mid/bot addr
    @(posedge clk);  
    read_bank_parallel(0, 3'd0, 3'd1, 3'd2, 10'd0, 10'd1, 10'd2);

    @(posedge clk); 
    read_bank_parallel(2, 3'd3, 3'd4, 3'd5, 10'd0, 10'd1, 10'd2);


    // ======================================================
    // Fill BANK 1 manually (6 RAMs × 150 values)
    // ======================================================
    for (int ram_idx = 2; ram_idx < 5; ram_idx++) begin
      for (int addr = 0; addr < 150; addr++) begin
        write_to_ram(1, ram_idx[2:0], addr[9:0], (ram_idx * 150 + addr) % 256);
      end
    end


    // Read 50 values from RAMs 2, 3, 4 in Bank 1
    for (j = 0; j < 50; j++) begin
        read_bank_parallel(
            1,             // Bank 1
            3'd2,          // top_idx → RAM 2
            3'd3,          // mid_idx → RAM 3
            3'd4,          // bot_idx → RAM 4
            j, j, j        // addr_top, addr_mid, addr_bot → all j
        );
    end

    local_addr_b3 = 'x;
    repeat (10) @(posedge clk); 
    $display("=== READBACK DONE ===");
    $stop;

  end

endmodule
