`include "conv_defines_pkg.sv"

// ======================================================
// Patch Reader (counter-based, no div/mod)
// - valid_p_pointer: 1 when a full patch is ready (col >= 2) and not done
// - pointer_done: level-high once 784 patches have been generated
// - clear: synchronous 1-cycle pulse to clear counters for next run
// - Addresses: top = base_top_d, mid = base_top_d + IFM_WIDTH, bot = base_top_d + 2*IFM_WIDTH
// ======================================================
module read_pointer #(
    parameter int IFM_WIDTH  = 30,   // physical width incl. padded columns (30)
    parameter int IFM_HEIGHT = 30    // physical height incl. padded rows   (30)
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   col_rd_en,        // advance one column when 1
    input  logic                   clear,            // soft restart
    output logic                   valid_p_pointer,  // 1 when full patch is ready this cycle
    output logic                   pointer_done,     // high after 784 patches
    output logic [`ADDR_WIDTH-1:0] addr_top,
    output logic [`ADDR_WIDTH-1:0] addr_mid,
    output logic [`ADDR_WIDTH-1:0] addr_bot
);

    // ---------------- Derived constants ----------------
    localparam int ROWS_VALID     = IFM_HEIGHT - 2;              // 28
    localparam int VALID_PER_ROW  = IFM_WIDTH  - 2;              // 28

    `ifdef `DOUBLE_PIPLINE
        // Half-frame run: 15 rows × 28 cols = 420 valid patches
        localparam int TOTAL_PATCHES  = ((IFM_HEIGHT/2) - 2) * VALID_PER_ROW; 
    `else
        // Full-frame run: 28 rows × 28 cols = 784 valid patches
        localparam int TOTAL_PATCHES  = ROWS_VALID * VALID_PER_ROW;
    `endif


    // ---------------- Registers ----------------
    logic [5:0]               row_idx_d,      row_idx_next;        // 0..27
    logic [5:0]               col_idx_d,      col_idx_next;        // 0..29
    logic [`ADDR_WIDTH-1:0]   base_top_d,     base_top_next;       // row*W + col (running)
    logic [$clog2(TOTAL_PATCHES+1)-1:0] patch_cnt, patch_cnt_next; // 0..784

    // ---------------- Intermediates ----------------
    logic                     at_last_col;   // col == 29
    logic                     at_last_row;   // row == 27
    logic                     will_wrap;     // (row,col) -> (0,0) on next step
    logic                     patch_fire;    // one patch produced this cycle

    // =====================================================
    // Sequential: registers only
    // =====================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            row_idx_d   <= '0;
            col_idx_d   <= '0;
            base_top_d  <= '0;
            patch_cnt <= '0;
        end else if (clear == 1'b1) begin
            row_idx_d   <= '0;                 // restart scanning
            col_idx_d   <= '0;
            base_top_d  <= '0;                 // top starts at address 0
            patch_cnt <= '0;
        end else begin
            row_idx_d   <= row_idx_next;
            col_idx_d   <= col_idx_next;
            base_top_d  <= base_top_next;
            patch_cnt <= patch_cnt_next;
        end
    end

    // =====================================================
    // Combinational: next-state + outputs
    // =====================================================
    always_comb begin
        // -------- defaults (hold) --------
        row_idx_next     = row_idx_d;
        col_idx_next     = col_idx_d;
        base_top_next    = base_top_d;
        patch_cnt_next   = patch_cnt;

        valid_p_pointer  = 1'b0;
        pointer_done     = (patch_cnt == TOTAL_PATCHES);

        // -------- easy flags --------
        at_last_col      = (col_idx_d == (IFM_WIDTH  - 1));   // 29
        at_last_row      = (row_idx_d == (ROWS_VALID - 1));   // 27
        will_wrap        = (at_last_col == 1'b1) && (at_last_row == 1'b1);

        // -------- addresses (adds only; no multiply) --------
        addr_top = base_top_d;                                // row*W + col
        addr_mid = base_top_d + IFM_WIDTH;                    // (row+1)*W + col
        addr_bot = base_top_d + (2*IFM_WIDTH);                // (row+2)*W + col

        // -------- produce valid patch when col >= 2 and not done --------
        if (col_rd_en == 1'b1) begin
            if ((col_idx_d >= 6'd2) && (pointer_done == 1'b0)) begin
                valid_p_pointer = 1'b1;
            end else begin
                valid_p_pointer = 1'b0;
            end

            // ---- advance column/row ----
            if (at_last_col == 1'b1) begin
                col_idx_next = 6'd0;                       // wrap column
                if (at_last_row == 1'b1) begin
                    row_idx_next = 6'd0;                   // wrap row (end of 28 rows)
                end else begin
                    row_idx_next = row_idx_d + 6'd1;         // next row
                end
            end else begin
                col_idx_next = col_idx_d + 6'd1;             // next column
                row_idx_next = row_idx_d;                    // same row
            end

            // ---- advance base address (linear) ----
            if (will_wrap == 1'b1) begin
                base_top_next = '0;                        // wrap back to 0 with (0,0)
            end else begin
                base_top_next = base_top_d + {{(`ADDR_WIDTH-1){1'b0}}, 1'b1}; // +1 each step
            end
        end else begin
            // hold when not enabled
            valid_p_pointer = 1'b0;
        end

        // -------- count only actual valid patches; clamp at TOTAL_PATCHES --------
        patch_fire = (valid_p_pointer == 1'b1);
        if (clear == 1'b1) begin
            patch_cnt_next = '0;
        end else begin
            if (patch_fire == 1'b1) begin
                if (patch_cnt < TOTAL_PATCHES) begin
                    patch_cnt_next = patch_cnt + {{($bits(patch_cnt)-1){1'b0}}, 1'b1};
                end else begin
                    patch_cnt_next = patch_cnt;            // hold at 784
                end
            end else begin
                patch_cnt_next = patch_cnt;                // hold
            end
        end
    end

endmodule



/*Previous design used divide by row width which was at max 30 and according ot gpt takes to much hardware realstate

30 is not a power of two. So the synthesized hardware isn’t just a cheap bit-slice (like divide by 2 → shift right). Instead, the tool has to build:

A small divider for / 30, and
A modulo circuit for % 30.

This can result in:
A large-ish chunk of combinational logic (comparators + subtractors) inferred.
Longer delay on the row/col signals compared to just a counter.
More area/power than a simple counter.

In many designs that’s fine (30 is small), but if this module is on a critical path (e.g., feeding RAM addresses every cycle), it can become a bottleneck.*/