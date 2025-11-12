`include "conv_defines_pkg.sv"

// ======================================================
// MU_sum_single_channel: sum 9×8-bit (NO saturation here)
// ======================================================
module MU_sum_single_channel
(
    input  logic [`DATA_WIDTH-1:0] prod_sat [0:8],  // 9 saturated products (8-bit)
    output logic [11:0]            ch_sum           // 0..2295 fits in 12 bits
);
    integer i;
    always_comb begin
        ch_sum = '0;
        for (i = 0; i < 9; i = i + 1) begin
            ch_sum += prod_sat[i];
        end
    end
endmodule
