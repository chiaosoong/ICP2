`include "conv_defines_pkg.sv"


// ======================================================
// patch_shifter_conv: Single-channel 3x3 IFM Patch Shifter
// ======================================================

module patch_shifter_unit (
    input  logic           clk,
    input  logic           rst_n,
    input  logic           ifm_sh_en,          // Shift and insert new column
    input  logic [7:0]     ifm_sh_in[2:0],     // ifm_sh_in[0]=top, [1]=mid, [2]=bot

    output logic [7:0]     patch_out[0:8]      // 3x3 patch window: left-to-right, top-down
);

    // Internal 3x3 patch buffer: flat layout
    logic [7:0] shift_reg[0:8];  // [0]=TL, [1]=TM, [2]=TR, ..., [8]=BR
    logic [7:0] shift_next[0:8];

    // --------------------------------------------------
    // Combinational shift logic
    // --------------------------------------------------
    always_comb begin
        // Default: hold current values
        for (int i = 0; i < 9; i++) begin
            shift_next[i] = shift_reg[i];
        end

        if (ifm_sh_en) begin
            // Top row: [0 1 2]
            shift_next[0] = shift_reg[1];
            shift_next[1] = shift_reg[2];
            shift_next[2] = ifm_sh_in[0];

            // Mid row: [3 4 5]
            shift_next[3] = shift_reg[4];
            shift_next[4] = shift_reg[5];
            shift_next[5] = ifm_sh_in[1];

            // Bot row: [6 7 8]
            shift_next[6] = shift_reg[7];
            shift_next[7] = shift_reg[8];
            shift_next[8] = ifm_sh_in[2];
        end
    end

    // --------------------------------------------------
    // Sequential register update
    // --------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 9; i++) begin
                shift_reg[i] <= 8'd0;
            end
        end else begin
            for (int i = 0; i < 9; i++) begin
                shift_reg[i] <= shift_next[i];
            end
        end
    end

    // --------------------------------------------------
    // Output assignments
    // --------------------------------------------------
    always_comb begin
        for (int i = 0; i < 9; i++) begin
            patch_out[i] = shift_reg[i];
        end
    end

endmodule

/*
patch_out[0] = top-left
patch_out[1] = top-mid
patch_out[2] = top-right

patch_out[3] = mid-left
patch_out[4] = mid-mid
patch_out[5] = mid-right

patch_out[6] = bot-left
patch_out[7] = bot-mid
patch_out[8] = bot-right
*/
