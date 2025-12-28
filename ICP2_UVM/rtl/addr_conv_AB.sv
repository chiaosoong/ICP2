// ======================================================
// addr_collapse_mask_3x64
// ======================================================
// Collapse 6 virtual indices (0..5) into:
//   - idx_out      : 0..2 (physical bank index)
//   - mask_AB_out  : 64-bit active-low mask for RAM
// ======================================================
module addr_conv_AB (
    input  logic [2:0]  idx_top_in,
    input  logic [2:0]  idx_mid_in,
    input  logic [2:0]  idx_bot_in,

    output logic [1:0]  idx_top_out,
    output logic [1:0]  idx_mid_out,
    output logic [1:0]  idx_bot_out,

    input logic  [23:0] wr_data_i,
    output logic [63:0] wr_data_o,

    output logic        is_group_b_top,
    output logic        is_group_b_mid,
    output logic        is_group_b_bot,

    input  logic [63:0] mask_in,             // existing active-low mask
    output logic [63:0] mask_combined_out    // final active-low mask
);

    // Per-byte mask pattern (8 bits): 0=enable, 1=mask
    logic [7:0]  ab_bits;      // per-byte active-low: 0=enable, 1=mask
    logic [7:0]  b0,b1,b2,b3,b4,b5,b6,b7;
    logic [63:0] ab_mask_64;   // expanded A/B mask (active-low)
    logic [63:0] mask_channel; // base channel mask aligned to lanes

    // -----------------------------
    // Build collapsed index + 8-bit A/B mask pattern
    // -----------------------------
    // ---- collapse 0..5 -> 0..2 (TOP/MID/BOT) ----
    always_comb begin

        idx_top_out     = 2'd0;
        idx_mid_out     = 2'd0;
        idx_bot_out     = 2'd0;
        is_group_b_top  = 1'b0;
        is_group_b_mid  = 1'b0;
        is_group_b_bot  = 1'b0;

        // group flags
        is_group_b_top = (idx_top_in >= 3'd3);
        is_group_b_mid = (idx_mid_in >= 3'd3);
        is_group_b_bot = (idx_bot_in >= 3'd3);

        // TOP collapse
        unique case (idx_top_in)
            3'd0,3'd3: idx_top_out = 2'd0;
            3'd1,3'd4: idx_top_out = 2'd1;
            3'd2,3'd5: idx_top_out = 2'd2;
            default:   idx_top_out = 2'd0;
        endcase
        // MID collapse
        unique case (idx_mid_in)
            3'd0,3'd3: idx_mid_out = 2'd0;
            3'd1,3'd4: idx_mid_out = 2'd1;
            3'd2,3'd5: idx_mid_out = 2'd2;
            default:   idx_mid_out = 2'd0;
        endcase
        // BOT collapse
        unique case (idx_bot_in)
            3'd0,3'd3: idx_bot_out = 2'd0;
            3'd1,3'd4: idx_bot_out = 2'd1;
            3'd2,3'd5: idx_bot_out = 2'd2;
            default:   idx_bot_out = 2'd0;
        endcase
    end

    // -----------------------------
    // Write data lane alignment (use TOP group for write)
    // -----------------------------
    always_comb begin
        // default
        wr_data_o = 64'h0;

        if (is_group_b_top) begin
            // Group B → bytes 5..3 = data, 2..0 = 0
            wr_data_o = {16'h0000, wr_data_i, 24'h000000 };
        end else begin
            // Group A → bytes 2..0 = data, 5..3 = 0
            wr_data_o = { 40'h0000000000, wr_data_i };
        end
    end
    
    // -----------------------------
    // Build AB lane mask (from TOP)
    // -----------------------------

    // A/B pattern (active-low)
    always_comb begin
        // default: mask all bytes
        ab_bits = 8'hFF;

        ab_bits = is_group_b_top ? 8'b1100_0111   // enable bytes 3..5
                                 : 8'b1111_1000;  // enable bytes 0..2
    end

    // expand 8b -> 64b (tool-friendly)
    always_comb begin
        // defaults
        b0 = 8'hFF; b1 = 8'hFF; b2 = 8'hFF; b3 = 8'hFF;
        b4 = 8'hFF; b5 = 8'hFF; b6 = 8'hFF; b7 = 8'hFF;
        ab_mask_64 = 64'hFFFF_FFFF_FFFF_FFFF;

        b0 = {8{ab_bits[0]}};
        b1 = {8{ab_bits[1]}};
        b2 = {8{ab_bits[2]}};
        b3 = {8{ab_bits[3]}};
        b4 = {8{ab_bits[4]}};
        b5 = {8{ab_bits[5]}};
        b6 = {8{ab_bits[6]}};
        b7 = {8{ab_bits[7]}};
        ab_mask_64 = {b7,b6,b5,b4,b3,b2,b1,b0};
    end

    // orient base mask to match lanes (explicit bytes; no shifts needed)
    always_comb begin
        // default: mask-all
        mask_channel = 64'hFFFF_FFFF_FFFF_FFFF;

        if (is_group_b_top) begin
            // B: put mask_in[23:0] into bytes 5..3; others masked
            mask_channel = { 16'hFFFF,
                             mask_in[23:16],     // byte5 (ch2)
                             mask_in[15:8],      // byte4 (ch1)
                             mask_in[7:0],       // byte3 (ch0)
                             24'hFF_FF_FF };
        end else begin
            // A: assume mask_in already targets bytes 2..0 (others masked)
            mask_channel = mask_in;
        end
    end

    // -----------------------------
    // Final mask (active-low OR)
    // -----------------------------
    always_comb begin
        // default
        mask_combined_out = 64'hFFFF_FFFF_FFFF_FFFF;
        
        mask_combined_out = mask_channel | ab_mask_64;
    end

endmodule
