`include "conv_defines_pkg.sv"

// ======================================================
// Shifter Array (3 Instances of kn_shifter)
// ======================================================

module kn_shifter_wrapper (
    input  logic         clk,
    input  logic         rst_n,

    input  logic [2:0]   shifter_write,         // One bit per channel
    input  logic [7:0]   shifter_in   [2:0],    // One input per shifter

    output logic [7:0]   shift_reg_out_ch0 [0:8], // Channel 0 outputs
    output logic [7:0]   shift_reg_out_ch1 [0:8], // Channel 1 outputs
    output logic [7:0]   shift_reg_out_ch2 [0:8]  // Channel 2 outputs
);

    // Channel 0
    kn_shifter_unit sh0 (
        .clk            (clk),
        .rst_n          (rst_n),
        .shifter_write  (shifter_write[0]),
        .shifter_in     (shifter_in[0]),
        .shift_reg_out  (shift_reg_out_ch0)
    );

    // Channel 1
    kn_shifter_unit sh1 (
        .clk            (clk),
        .rst_n          (rst_n),
        .shifter_write  (shifter_write[1]),
        .shifter_in     (shifter_in[1]),
        .shift_reg_out  (shift_reg_out_ch1)
    );

    // Channel 2
    kn_shifter_unit sh2 (
        .clk            (clk),
        .rst_n          (rst_n),
        .shifter_write  (shifter_write[2]),
        .shifter_in     (shifter_in[2]),
        .shift_reg_out  (shift_reg_out_ch2)
    );

endmodule
