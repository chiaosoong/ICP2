
`include "conv_defines_pkg.sv"

// ======================================================
// patch_shifter_module: Instantiates 3 patch_shifter_conv for 3 IFM channels
// ======================================================

module patch_shifter_wrapper (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              ifm_sh_en,

    // Inputs per channel (top, mid, bot)
    input  logic [7:0]        ifm0_in[2:0],
    input  logic [7:0]        ifm1_in[2:0],
    input  logic [7:0]        ifm2_in[2:0],

    // Outputs per channel: patch_out[ch][0..8]
    output logic [7:0]        patch_out0[0:8],
    output logic [7:0]        patch_out1[0:8],
    output logic [7:0]        patch_out2[0:8]
);

    // Channel 0
    patch_shifter_unit u_patch_shifter_0 (
        .clk        (clk),
        .rst_n      (rst_n),
        .ifm_sh_en  (ifm_sh_en),
        .ifm_sh_in  (ifm0_in),
        .patch_out  (patch_out0)
    );

    // Channel 1
    patch_shifter_unit u_patch_shifter_1 (
        .clk        (clk),
        .rst_n      (rst_n),
        .ifm_sh_en  (ifm_sh_en),
        .ifm_sh_in  (ifm1_in),
        .patch_out  (patch_out1)
    );

    // Channel 2
    patch_shifter_unit u_patch_shifter_2 (
        .clk        (clk),
        .rst_n      (rst_n),
        .ifm_sh_en  (ifm_sh_en),
        .ifm_sh_in  (ifm2_in),
        .patch_out  (patch_out2)
    );


endmodule
