
`include "conv_defines_pkg.sv"

module memory_module (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic [3:0]             we_bank, 
    input  logic [3:0]             re_bank,
    /* each bit is one bank
       0000 all off
       1111 all on*/

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

    // [0]= TOP, [1]= MID, [2]=BOT
    output logic [`DATA_WIDTH-1:0] chan0_A_out_top_mid_bot [2:0], 
    output logic [`DATA_WIDTH-1:0] chan1_A_out_top_mid_bot [2:0],
    output logic [`DATA_WIDTH-1:0] chan2_A_out_top_mid_bot [2:0],

    output logic [`DATA_WIDTH-1:0] chan0_B_out_top_mid_bot [2:0], 
    output logic [`DATA_WIDTH-1:0] chan1_B_out_top_mid_bot [2:0],
    output logic [`DATA_WIDTH-1:0] chan2_B_out_top_mid_bot [2:0],

    output logic [`DATA_WIDTH-1:0] bank3_out
);


// ================================================================
// Signals
// ================================================================
    logic [7:0]             addr_top_8b;
    logic [7:0]             addr_mid_8b;
    logic [7:0]             addr_bot_8b;

    logic [1:0]             index_top_d;
    logic [1:0]             index_mid_d;
    logic [1:0]             index_bot_d;

    logic [1:0]             index_top_coll;
    logic [1:0]             index_mid_coll;
    logic [1:0]             index_bot_coll;

    // Bank3 
    logic [7:0]             addr_wr_8b;
    logic [`ADDR_WIDTH-3:0] loc_addr_8;         
    logic [`DATA_WIDTH-1:0] bank3_input;
    logic [`DATA_WIDTH-1:0] bank3_out_i[0:`NUM_RAMS_PER_BANK-2];
    logic [2:0]             ram_ind_d;
    logic [3:0]             re_bank_d;

    // Group-B flags from addr_conv_AB (+ delayed)
    logic is_group_b_top,   is_group_b_mid,   is_group_b_bot;
    logic is_group_b_top_d, is_group_b_mid_d, is_group_b_bot_d;

    // 64-bit RAM outputs per sub-RAM
    logic [63:0] shared_ifm_q64 [0:`SUBRAMS_IFM-1];

    // Write data
    logic [23:0] ifm24_din;
    logic [63:0] ifm64_din_shifted;
    logic [63:0] ifm_mask_channels;
    logic [63:0] ifm_mask_combined;


    logic [7:0] addr_rd_sel [0:`SUBRAMS_IFM-1];
    logic       we_any_ifm;
    logic       re_any_ifm;

`ifdef RAM_160_64bits_SHARED

// ====================
// Addr bit correction - slicing 10 bit to 8 
// ====================
    always_comb begin
        // Address slices
        addr_wr_8b  = local_addr_b3[7:0];
        addr_top_8b = rd_addr_top[7:0];
        addr_mid_8b = rd_addr_mid[7:0];
        addr_bot_8b = rd_addr_bot[7:0];
        loc_addr_8  = local_addr_b3[7:0];

        // Per-channel write data packing (ch2:ch1:ch0)
        ifm24_din = { bank_din[2], bank_din[1], bank_din[0] };

        // Base channel mask (active-low) targeting A-lane bytes 2..0
        //   ch2 → byte2, ch1 → byte1, ch0 → byte0
        ifm_mask_channels = {40'hFFFF_FFFF_FF,                 // bytes 7..3 default masked
                            {8{~we_bank[2]}},                 // byte2 enable when ch2 write_en=1
                            {8{~we_bank[1]}},                 // byte1 enable when ch1 write_en=1
                            {8{~we_bank[0]}} };               // byte0 enable when ch0 write_en=1
                                                

        // Reductions
        we_any_ifm = (we_bank[0] | we_bank[1] | we_bank[2]);
        re_any_ifm = (re_bank[0] | re_bank[1] | re_bank[2]);
    end


    // ==============================
    // Shared IFM RAMs 
    // ==============================

    genvar is;
    generate
        for (is = 0; is < `SUBRAMS_IFM; is++) begin : SHARED_RAMS
          // Match flags
            logic idx_top_eq;
            logic idx_mid_eq;
            logic idx_bot_eq;

            // Enables per instance
            logic write_en_ifm;
            logic read_en_ifm;

            // Address per instance
            logic [7:0] addr_ifm;

            // ---- continuous assigns (no always_comb) ----
            assign idx_top_eq = (index_top_coll == is[1:0]);
            assign idx_mid_eq = (index_mid_coll == is[1:0]);
            assign idx_bot_eq = (index_bot_coll == is[1:0]);

            // Write tied to the instance targeted by TOP (legacy policy)
            assign write_en_ifm = we_any_ifm & idx_top_eq;

            // Read when any of TOP/MID/BOT map to this instance
            assign read_en_ifm  = re_any_ifm & (idx_top_eq | idx_mid_eq | idx_bot_eq);

            // Address mux: write has priority (should not overlap in your FSM)
            assign addr_ifm     = write_en_ifm ? addr_wr_8b : addr_rd_sel[is];

            // 64-bit shared IFM RAM instance
            ram_wrapper_160 u_ifm_ram (
                .clk          (clk),
                .write_en     (write_en_ifm),
                .read_en      (read_en_ifm),
                .addr         (addr_ifm),
                .ram_data_in  (ifm64_din_shifted),   // 64b, A/B lane already oriented
                .ram_data_out (shared_ifm_q64[is]),  // 64b
                .mask_in      (ifm_mask_combined),   // 64b, active-low
                .ry           (/* unused */)
            );
        end
    endgenerate

// =====================================================================================
// Output mux
// =====================================================================================

// =====================================================================================
// READ address selection per sub-RAM instance (no generate, pure assigns)
// Intent:
//   - There are 3 single-port IFM sub-RAMs, indexed 0..2.
//   - This cycle, TOP/MID/BOT target indices index_top_coll/index_mid_coll/index_bot_coll.
//   - For instance i, select the address of the row that targets i; else 0.
// =====================================================================================
    assign addr_rd_sel[0] = (index_top_coll == 2'd0) ? addr_top_8b :
                            (index_mid_coll == 2'd0) ? addr_mid_8b :
                            (index_bot_coll == 2'd0) ? addr_bot_8b : 8'd0;

    assign addr_rd_sel[1] = (index_top_coll == 2'd1) ? addr_top_8b :
                            (index_mid_coll == 2'd1) ? addr_mid_8b :
                            (index_bot_coll == 2'd1) ? addr_bot_8b : 8'd0;

    assign addr_rd_sel[2] = (index_top_coll == 2'd2) ? addr_top_8b :
                            (index_mid_coll == 2'd2) ? addr_mid_8b :
                            (index_bot_coll == 2'd2) ? addr_bot_8b : 8'd0;

    // ======================================================
    // READ slicing: expose BOTH lanes for TOP/MID/BOT (per channel)
    // ======================================================
    always_comb begin
        // Defaults: zero all outputs
        chan0_A_out_top_mid_bot = '{default:'0};
        chan1_A_out_top_mid_bot = '{default:'0};
        chan2_A_out_top_mid_bot = '{default:'0};

        chan0_B_out_top_mid_bot = '{default:'0};
        chan1_B_out_top_mid_bot = '{default:'0};
        chan2_B_out_top_mid_bot = '{default:'0};

        // Channel 0 (ch0): A=[7:0],  B=[31:24]
        if (re_bank_d[0] == 1'b1) begin
            // TOP
            chan0_A_out_top_mid_bot[0] = shared_ifm_q64[index_top_d][7:0];
            chan0_B_out_top_mid_bot[0] = shared_ifm_q64[index_top_d][31:24];
            // MID
            chan0_A_out_top_mid_bot[1] = shared_ifm_q64[index_mid_d][7:0];
            chan0_B_out_top_mid_bot[1] = shared_ifm_q64[index_mid_d][31:24];
            // BOT
            chan0_A_out_top_mid_bot[2] = shared_ifm_q64[index_bot_d][7:0];
            chan0_B_out_top_mid_bot[2] = shared_ifm_q64[index_bot_d][31:24];
        end

        // Channel 1 (ch1): A=[15:8],  B=[39:32]
        if (re_bank_d[1] == 1'b1) begin
            chan1_A_out_top_mid_bot[0] = shared_ifm_q64[index_top_d][15:8];
            chan1_B_out_top_mid_bot[0] = shared_ifm_q64[index_top_d][39:32];

            chan1_A_out_top_mid_bot[1] = shared_ifm_q64[index_mid_d][15:8];
            chan1_B_out_top_mid_bot[1] = shared_ifm_q64[index_mid_d][39:32];

            chan1_A_out_top_mid_bot[2] = shared_ifm_q64[index_bot_d][15:8];
            chan1_B_out_top_mid_bot[2] = shared_ifm_q64[index_bot_d][39:32];
        end

        // Channel 2 (ch2): A=[23:16], B=[47:40]
        if (re_bank_d[2] == 1'b1) begin
            chan2_A_out_top_mid_bot[0] = shared_ifm_q64[index_top_d][23:16];
            chan2_B_out_top_mid_bot[0] = shared_ifm_q64[index_top_d][47:40];

            chan2_A_out_top_mid_bot[1] = shared_ifm_q64[index_mid_d][23:16];
            chan2_B_out_top_mid_bot[1] = shared_ifm_q64[index_mid_d][47:40];

            chan2_A_out_top_mid_bot[2] = shared_ifm_q64[index_bot_d][23:16];
            chan2_B_out_top_mid_bot[2] = shared_ifm_q64[index_bot_d][47:40];
        end
    end



`endif // RAM_IFM_SHARED24



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

