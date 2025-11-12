// =================================================================================
/* Address Converter for Padded IFM Layout (30x30 across 6 RAMs)
 - No / or % operators (uses constant multiplies/shifts)

Purpose:
        input: 0-899
        output: 0-149 
                ram_index

        Designed for 6 rams 160 words each
        5 full rows of 30 inputs per ram*/
// =================================================================================

`include "conv_defines_pkg.sv"

module addr_conv_padded (
    input  logic [9:0] global_addr_padded,  // 0–899
    output logic [2:0] ram_index,           // 0–5
    output logic [7:0] local_addr           // 0–149
);

    // -------- intermediates --------
    logic [9:0] ga;                  // 0..899
    logic [5:0] row;                 // 0..29
    logic [4:0] col;                 // 0..29
    logic [3:0] row_div3;            // 0..9  (floor(row/3))
    logic [1:0] row_mod3;            // 0..2  (row % 3)
    logic [2:0] row_slot;            // 0..4  (per-half slot)
    logic [8:0] local_addr_raw;      // up to 149

    // Magic constants (exact over our domains):
    // floor(n/30) = (n * 2185) >> 16     for n in 0..1023
    // floor(n/3)  = (n * 43)   >> 7      for n in 0..63
    localparam int unsigned DIV30_M = 2185;  // 16-bit shift
    localparam int unsigned DIV30_S = 16;
    localparam int unsigned DIV3_M  = 43;    //  7-bit shift
    localparam int unsigned DIV3_S  = 7;

    always_comb begin
        // ---- defaults ----
        ga             = '0;        
        row            = '0;       
        col            = '0;        
        row_div3       = '0;        
        row_mod3       = '0;        
        row_slot       = '0;        
        local_addr_raw = '0;        
        ram_index      = 3'd0;      
        local_addr     = 8'd0;      

        // cast once
        ga = global_addr_padded; // no change

        // -------- row/col from 30x30 linear address --------
        row = ( (ga * DIV30_M) >> DIV30_S );                       // floor(ga/30), 0..29
        // col = ga - row*30;  30 = 32 - 2
        col = ga - ( (row << 5) - (row << 1) );                    // 0..29

        // -------- row % 3 and row / 3 --------
        row_div3 = ( (row * DIV3_M) >> DIV3_S );                   // floor(row/3), 0..9
        row_mod3 = row - (row_div3 * 3);                           // row % 3,   0..2

        // -------- bank select (two halves of 15 rows) --------
        if (row < 6'd15) begin
            ram_index = {1'b0, row_mod3};                          // 0..2
            row_slot  = row_div3;                                   // 0..4
        end else begin
            ram_index = 3 + {1'b0, row_mod3};                      // 3..5
            row_slot  = row_div3 - 3'd5;                           // 0..4
        end

        // -------- local address: row_slot*30 + col (no multiply) --------
        // 30 = 32 - 2
        local_addr_raw = ( (row_slot << 5) - (row_slot << 1) ) + col; // 0..149
        local_addr     = local_addr_raw[7:0];                         // 8-bit 0..149
    end

endmodule

