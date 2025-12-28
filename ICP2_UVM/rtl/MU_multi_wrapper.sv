`include "conv_defines_pkg.sv"

// ======================================================
// MU_mul27_wrapper
// - Instantiates 3× MU_mul9_sat (one per channel)
// - Each produces 9 saturated products (8 bits)
// - Total output: 27 products grouped per channel
// - No pipelining or summing (done later)
// ======================================================
module MU_multi_wrapper
(
    input  logic                   MU_en,
    input  logic [`DATA_WIDTH-1:0] patch_array  [0:2][0:8],  // [channel][tap]
    input  logic [`DATA_WIDTH-1:0] kernel_array [0:2][0:8],  // [channel][tap]
    output logic [`DATA_WIDTH-1:0] prod_sat     [0:2][0:8]   // [channel][tap]
);

    genvar ch;
    generate
        for (ch = 0; ch < 3; ch++) begin : CHAN
            MU_multi_unit u_mul9 (
                .MU_en   (MU_en),
                .patch   (patch_array[ch]),
                .kernel  (kernel_array[ch]),
                .prod_sat(prod_sat[ch])
            );
        end
    endgenerate

endmodule


