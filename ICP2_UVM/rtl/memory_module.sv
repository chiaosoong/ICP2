
`include "conv_defines_pkg.sv"

module memory_module (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic [3:0]             we_bank, // each bit is one bank 
                                            // 0000 all off
                                            // 1111 all on
    input  logic [3:0]             re_bank,

    // used in write operations
    input  logic [2:0]             ram_index_b3,
    input  logic [`ADDR_WIDTH-1:0] local_addr_b3,
    input  logic [`DATA_WIDTH-1:0] bank_din [3:0],

    // used in read state during MU
    input  logic [2:0]             ram_index_top,
    input  logic [2:0]             ram_index_mid,
    input  logic [2:0]             ram_index_bot,

    input  logic [`ADDR_WIDTH-1:0] rd_addr_top, 
    input  logic [`ADDR_WIDTH-1:0] rd_addr_mid,
    input  logic [`ADDR_WIDTH-1:0] rd_addr_bot,

    // 9
    output logic [`DATA_WIDTH-1:0] chan0_A_out_top_mid_bot [2:0], 
    output logic [`DATA_WIDTH-1:0] chan1_A_out_top_mid_bot [2:0],
    output logic [`DATA_WIDTH-1:0] chan2_A_out_top_mid_bot [2:0],

    output logic [`DATA_WIDTH-1:0] bank3_out
);


// ================================================================
// Signals
// ================================================================
    logic [7:0]             addr_top_8bit;
    logic [7:0]             addr_mid_8bit;
    logic [7:0]             addr_bot_8bit;

    logic [2:0]             index_top_d;
    logic [2:0]             index_mid_d;
    logic [2:0]             index_bot_d;

    logic [1:0]             index_top_coll;
    logic [1:0]             index_mid_coll;
    logic [1:0]             index_bot_coll;

    logic [`DATA_WIDTH-1:0] bank0_outs_i   [0:`NUM_RAMS_PER_BANK-1];
    logic [`DATA_WIDTH-1:0] bank1_outs_i   [0:`NUM_RAMS_PER_BANK-1];
    logic [`DATA_WIDTH-1:0] bank2_outs_i   [0:`NUM_RAMS_PER_BANK-1];

    // Bank3 
    logic [`ADDR_WIDTH-3:0] loc_addr_8;         
    logic [`DATA_WIDTH-1:0] bank3_input;
    logic [`DATA_WIDTH-1:0] bank3_out_i[0:`NUM_RAMS_PER_BANK-2];
    logic [2:0]             ram_ind_d;
    logic [3:0]             re_bank_d;

    // Group-B flags from addr_conv_AB (+ delayed)
    logic is_group_b_top, is_group_b_mid, is_group_b_bot;
    logic is_group_b_top_d, is_group_b_mid_d, is_group_b_bot_d;

    // 64-bit RAM outputs per sub-RAM
    logic [63:0] shared_ifm_q64 [0:`NUM_RAMS_PER_BANK-1];

    // Write data to RAM: 24b in (packed ch2:ch1:ch0), 64b lane-oriented out
    logic [23:0] ifm24_din;
    logic [63:0] ifm64_din_shifted;

    // Base per-channel mask (bytes 2..0), combined/oriented mask to RAM
    logic [63:0] ifm_mask_channels;
    logic [63:0] ifm_mask_combined;




// ====================
// Addr bit correction - slicing 10 bit address to 8 bits
// ====================
    always_comb begin
        loc_addr_8          = local_addr_b3[7:0];         
        addr_top_8bit       = rd_addr_top[7:0];            
        addr_mid_8bit       = rd_addr_mid[7:0];            
        addr_bot_8bit       = rd_addr_bot[7:0];            
    end

// ====================
// Index delay
// ====================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_ind_d   <= 3'd0;
            index_top_d <= 3'd0;
            index_mid_d <= 3'd0;
            index_bot_d <= 3'd0;
            re_bank_d   <= 4'd0;
            is_group_b_top_d   <= 1'b0;
            is_group_b_mid_d   <= 1'b0;
            is_group_b_bot_d   <= 1'b0;
        end else begin
            ram_ind_d   <= ram_index_b3;
            index_top_d <= index_top_coll;
            index_mid_d <= index_mid_coll;
            index_bot_d <= index_bot_coll;
            re_bank_d   <= re_bank;
            is_group_b_top_d   <= is_group_b_top;
            is_group_b_mid_d   <= is_group_b_mid;
            is_group_b_bot_d   <= is_group_b_bot;
        end
    end

// ================================================================
/* IFM Shared-24 mode (single RAM for all 3 channels)

 - Byte lanes during read: 
    ch0 -> [7:0], 
    ch1 -> [15:8], 
    ch2 -> [23:16]

 - Bit-mask write: 
    M[0]=we_bank[0], 
    M[1]=we_bank[1], 
    M[2]=we_bank[2]

 - Read address top/mid/bot (shared like before)
 - Outputs are sliced to 3×8

 Needs:
   `define RAM_160_64bits_SHARED
   `define WRAPPER_DATA_WIDTH 24
   `define RAM_DATA_WIDTH 64*/
// ================================================================
`ifdef RAM_160_64bits_SHARED
        // Pack channel data; mask maps banks -> byte lanes
        assign ifm24_din  = { bank_din[2], bank_din[1], bank_din[0] };
        assign ifm_mask_channels = {
                            40'hFFFF_FFFF_FF,     // upper 5 bytes masked off ( all 1s)
                            {8{~we_bank[2]}},     // ch2 -> byte2  (we get 8x1 or 8x0 
                                                //depending on if mask is active or not)
                            {8{~we_bank[1]}},     // ch1 -> byte1
                            {8{~we_bank[0]}} };   // ch0 -> byte0
                        
// ==============================
// Output mux (uses delayed idx + delayed group flags)
// ==============================
always_comb begin
    chan0_A_out_top_mid_bot = '{default:'0};
    chan1_A_out_top_mid_bot = '{default:'0};
    chan2_A_out_top_mid_bot = '{default:'0};

    // ch0 : A→byte0, B→byte3
    if (re_bank_d[0]) begin
        if (index_top_d <= `FIVE)
            chan0_A_out_top_mid_bot[0] = is_group_b_top_d ? shared_ifm_q64[index_top_d][31:24]
                                                : shared_ifm_q64[index_top_d][7:0];
        if (index_mid_d <= `FIVE)
            chan0_A_out_top_mid_bot[1] = is_group_b_mid_d ? shared_ifm_q64[index_mid_d][31:24]
                                                : shared_ifm_q64[index_mid_d][7:0];
        if (index_bot_d <= `FIVE)
            chan0_A_out_top_mid_bot[2] = is_group_b_bot_d ? shared_ifm_q64[index_bot_d][31:24]
                                                : shared_ifm_q64[index_bot_d][7:0];
    end

    // ch1 : A→byte1, B→byte4
    if (re_bank_d[1]) begin
        if (index_top_d <= `FIVE)
            chan1_A_out_top_mid_bot[0] = is_group_b_top_d ? shared_ifm_q64[index_top_d][39:32]
                                                : shared_ifm_q64[index_top_d][15:8];
        if (index_mid_d <= `FIVE)
            chan1_A_out_top_mid_bot[1] = is_group_b_mid_d ? shared_ifm_q64[index_mid_d][39:32]
                                                : shared_ifm_q64[index_mid_d][15:8];
        if (index_bot_d <= `FIVE)
            chan1_A_out_top_mid_bot[2] = is_group_b_bot_d ? shared_ifm_q64[index_bot_d][39:32]
                                                : shared_ifm_q64[index_bot_d][15:8];
    end

    // ch2 : A→byte2, B→byte5
    if (re_bank_d[2]) begin
        if (index_top_d <= `FIVE)
            chan2_A_out_top_mid_bot[0] = is_group_b_top_d ? shared_ifm_q64[index_top_d][47:40]
                                                : shared_ifm_q64[index_top_d][23:16];
        if (index_mid_d <= `FIVE)
            chan2_A_out_top_mid_bot[1] = is_group_b_mid_d ? shared_ifm_q64[index_mid_d][47:40]
                                                : shared_ifm_q64[index_mid_d][23:16];
        if (index_bot_d <= `FIVE)
            chan2_A_out_top_mid_bot[2] = is_group_b_bot_d ? shared_ifm_q64[index_bot_d][47:40]
                                                : shared_ifm_q64[index_bot_d][23:16];
    end
end

    // ==============================
    // Shared IFM RAMs 
    // ==============================

    genvar is;
    generate
        for (is = 0; is < 3; is++) begin : SHARED_RAMS
            localparam logic [2:0] IDX = is[2:0];

            // helpers
            logic        we_any, re_any;                       // any IFM write/read
            logic        idx_top_eq, idx_mid_eq, idx_bot_eq;   // index matches
            logic [7:0]  addr_sel;                              // selected addr

            assign we_any     = (we_bank[0] | we_bank[1] | we_bank[2]);
            assign re_any     = (re_bank[0] | re_bank[1] | re_bank[2]);
            assign idx_top_eq = (index_top_coll == IDX[1:0]);
            assign idx_mid_eq = (index_mid_coll == IDX[1:0]);
            assign idx_bot_eq = (index_bot_coll == IDX[1:0]);

            assign addr_sel   = idx_top_eq ? addr_top_8bit :
                                idx_mid_eq ? addr_mid_8bit :
                                idx_bot_eq ? addr_bot_8bit : 8'd0;

            ram_wrapper_160 ram_shared (
            .clk         (clk),
            //----------------------------
            .write_en    ( we_any && idx_top_eq ),
            //----------------------------
            .read_en     ( re_any && (idx_top_eq || idx_mid_eq || idx_bot_eq) ),
            //----------------------------
            .addr        ( addr_sel ),
            //----------------------------
            .ram_data_in ( ifm64_din_shifted  ),              // 24-bit packed data
            .ram_data_out( shared_ifm_q64[is] ),  // 24-bit out
            .mask_in     (ifm_mask_combined ),             // 64-bit active-low mask
            .ry          ()
            );
        end
    endgenerate

`endif // RAM_IFM_SHARED24


// ============================================================================
// Bank 3: Output RAMs — shared by both modes (no masking)
// ============================================================================

    genvar i_b3;
    generate
        for (i_b3 = 0; i_b3 < `NUM_RAMS_PER_BANK-1; i_b3++) begin : BANK3
            logic [`WRAPPER_DATA_WIDTH-1:0] bank3_q;  // temp wide output

            ram_wrapper_160 bank3_inst (
            .clk          (clk),
            .write_en     (we_bank[3] && (ram_index_b3 == i_b3)),
            .read_en      (re_bank[3]  && (ram_index_b3 == i_b3)),
            .addr         (loc_addr_8),
            .ram_data_in  ( {{(`WRAPPER_DATA_WIDTH-8){1'b0}}, bank_din[3]} ),
            // zero-extend  to match data size depending on mode
            .ram_data_out ( bank3_q ),
            .mask_in      ('0),  // no masking
            .ry           ()
            );

            // take only the low byte for bank3_out_i
            assign bank3_out_i[i_b3] = bank3_q[7:0];
        end
    endgenerate
// ================
// Bank 3 output mux — both modes
// ================
    always_comb begin
        bank3_out = '0;
        if (re_bank_d[3] && (ram_ind_d <= `FOUR)) begin
            bank3_out = bank3_out_i[ram_ind_d];
        end
    end


    // ====================
    // Collapsing 6 rams into 3
    // ====================
    addr_conv_AB addr_coll (
        .idx_top_in        (ram_index_top),
        .idx_mid_in        (ram_index_mid),
        .idx_bot_in        (ram_index_bot),

        .idx_top_out       (index_top_coll),
        .idx_mid_out       (index_mid_coll),
        .idx_bot_out       (index_bot_coll),

        .wr_data_i         (ifm24_din),
        .wr_data_o         (ifm64_din_shifted),   // 64-bit, already lane-aligned

        .is_group_b_top    (is_group_b_top),
        .is_group_b_mid    (is_group_b_mid),
        .is_group_b_bot    (is_group_b_bot),

        .mask_in           (ifm_mask_channels),
        .mask_combined_out (ifm_mask_combined)
    );

endmodule

