
`include "conv_defines_pkg.sv"

// ======================================================
// MU_summer_wrapper:
// - Instantiates 3× MU_sum_single_channel (no per-channel saturation)
// - Sums channels and SATURATES ONLY the final OFM to 8-bit
// ======================================================
module MU_summer_wrapper
(
    input  logic [`DATA_WIDTH-1:0] prod_sat [0:2][0:8], // [channel][tap], 3×9×8-bit
    output logic [`DATA_WIDTH-1:0] ofm                  // final saturated OFM (8-bit)
);
    // Per-channel max: 9×255 = 2295 -> 12 bits
    localparam int SUM_PER_CH_W = `DATA_WIDTH + 4;      // 12 when DATA_WIDTH=8
    // Total max: 3×2295 = 6885 -> needs 13 bits; use 14 for margin
    localparam int SUM_TOTAL_W  = SUM_PER_CH_W + 2;     // 14 when DATA_WIDTH=8

    // Internal per-channel sums
    logic [SUM_PER_CH_W-1:0] ch_sum    [0:2];
    logic [SUM_TOTAL_W-1:0]  total_sum;

    // 3 single-channel summers
    genvar ch;
    generate
        for (ch = 0; ch < 3; ch = ch + 1) begin : G_SUM_CH
            MU_sum_single_channel u_sum_single (
                .prod_sat (prod_sat[ch]),
                .ch_sum   (ch_sum[ch])
            );
        end
    endgenerate

    // ====================================
    // Final sum across channels + final 8-bit saturation
    // ====================================
    // 
    always_comb begin
        total_sum = ch_sum[0] + ch_sum[1] + ch_sum[2];         // 0..6885
        if (|total_sum[SUM_TOTAL_W-1:`DATA_WIDTH])             // any bits above 7 set?
            ofm = {`DATA_WIDTH{1'b1}};                         // clamp to 255
        else
            ofm = total_sum[`DATA_WIDTH-1:0];                  // exact if ≤255
    end

endmodule
