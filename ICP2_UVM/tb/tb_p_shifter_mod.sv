`timescale 1ns / 1ps
`include "conv_defines_pkg.sv"

module tb_p_shifter_mod;

    // ======================================================
    // Clock and Reset
    // ======================================================
    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;

    // ======================================================
    // DUT I/O Signals
    // ======================================================
    logic ifm_sh_en;

    logic [7:0] ifm0_in[2:0];     // top, mid, bot for channel 0
    logic [7:0] ifm1_in[2:0];     // channel 1
    logic [7:0] ifm2_in[2:0];     // channel 2

    logic [7:0] patch_out0[0:8];
    logic [7:0] patch_out1[0:8];
    logic [7:0] patch_out2[0:8];

    // ======================================================
    // DUT Instance
    // ======================================================
    patch_shifter_wrapper dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .ifm_sh_en  (ifm_sh_en),
        .ifm0_in    (ifm0_in),
        .ifm1_in    (ifm1_in),
        .ifm2_in    (ifm2_in),
        .patch_out0 (patch_out0),
        .patch_out1 (patch_out1),
        .patch_out2 (patch_out2)
    );

    // ======================================================
    // Simulation Sequence
    // ======================================================
    initial begin
        // ----------------------------------
        // Reset and Init
        // ----------------------------------
        rst_n = 0;
        ifm_sh_en = 0;

        for (int i = 0; i < 3; i++) begin
            ifm0_in[i] = 0;
            ifm1_in[i] = 0;
            ifm2_in[i] = 0;
        end

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ----------------------------------
        // Load 3 columns (warm-up)
        // ----------------------------------
        for (int col = 0; col < 3; col++) begin
            ifm0_in[0] = 10 + col;  ifm0_in[1] = 20 + col;  ifm0_in[2] = 30 + col;
            ifm1_in[0] = 40 + col;  ifm1_in[1] = 50 + col;  ifm1_in[2] = 60 + col;
            ifm2_in[0] = 70 + col;  ifm2_in[1] = 80 + col;  ifm2_in[2] = 90 + col;
            ifm_sh_en = 1;
            @(posedge clk);
        end

        ifm_sh_en = 0;
        @(posedge clk);

        $display("\n=== Patch After Warm-Up ===");
        $display("Channel 0: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out0[0], patch_out0[1], patch_out0[2],
                 patch_out0[3], patch_out0[4], patch_out0[5],
                 patch_out0[6], patch_out0[7], patch_out0[8]);

        $display("Channel 1: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out1[0], patch_out1[1], patch_out1[2],
                 patch_out1[3], patch_out1[4], patch_out1[5],
                 patch_out1[6], patch_out1[7], patch_out1[8]);

        $display("Channel 2: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out2[0], patch_out2[1], patch_out2[2],
                 patch_out2[3], patch_out2[4], patch_out2[5],
                 patch_out2[6], patch_out2[7], patch_out2[8]);

        // ----------------------------------
        // Shift New Column 4
        // ----------------------------------
        ifm0_in[0] = 13; ifm0_in[1] = 23; ifm0_in[2] = 33;
        ifm1_in[0] = 43; ifm1_in[1] = 53; ifm1_in[2] = 63;
        ifm2_in[0] = 73; ifm2_in[1] = 83; ifm2_in[2] = 93;

        ifm_sh_en = 1;
        @(posedge clk);
        ifm_sh_en = 0;
        @(posedge clk);

        $display("\n=== Patch After 1 Shift ===");
        $display("Channel 0: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out0[0], patch_out0[1], patch_out0[2],
                 patch_out0[3], patch_out0[4], patch_out0[5],
                 patch_out0[6], patch_out0[7], patch_out0[8]);

        $display("Channel 1: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out1[0], patch_out1[1], patch_out1[2],
                 patch_out1[3], patch_out1[4], patch_out1[5],
                 patch_out1[6], patch_out1[7], patch_out1[8]);

        $display("Channel 2: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out2[0], patch_out2[1], patch_out2[2],
                 patch_out2[3], patch_out2[4], patch_out2[5],
                 patch_out2[6], patch_out2[7], patch_out2[8]);

                // ----------------------------------
        // Shift Column 5
        // ----------------------------------
        ifm0_in[0] = 8'd14; ifm0_in[1] = 8'd24; ifm0_in[2] = 8'd34;
        ifm1_in[0] = 8'd44; ifm1_in[1] = 8'd54; ifm1_in[2] = 8'd64;
        ifm2_in[0] = 8'd74; ifm2_in[1] = 8'd84; ifm2_in[2] = 8'd94;

        ifm_sh_en = 1;
        @(posedge clk);
        ifm_sh_en = 0;
        @(posedge clk);

        $display("\n=== Patch After 2 Shifts ===");
        $display("Channel 0: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out0[0], patch_out0[1], patch_out0[2],
                 patch_out0[3], patch_out0[4], patch_out0[5],
                 patch_out0[6], patch_out0[7], patch_out0[8]);

        $display("Channel 1: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out1[0], patch_out1[1], patch_out1[2],
                 patch_out1[3], patch_out1[4], patch_out1[5],
                 patch_out1[6], patch_out1[7], patch_out1[8]);

        $display("Channel 2: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out2[0], patch_out2[1], patch_out2[2],
                 patch_out2[3], patch_out2[4], patch_out2[5],
                 patch_out2[6], patch_out2[7], patch_out2[8]);

        // ----------------------------------
        // Shift Column 6
        // ----------------------------------
        ifm0_in[0] = 8'd15; ifm0_in[1] = 8'd25; ifm0_in[2] = 8'd35;
        ifm1_in[0] = 8'd45; ifm1_in[1] = 8'd55; ifm1_in[2] = 8'd65;
        ifm2_in[0] = 8'd75; ifm2_in[1] = 8'd85; ifm2_in[2] = 8'd95;

        ifm_sh_en = 1;
        @(posedge clk);
        ifm_sh_en = 0;
        @(posedge clk);

        $display("\n=== Patch After 3 Shifts ===");
        $display("Channel 0: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out0[0], patch_out0[1], patch_out0[2],
                 patch_out0[3], patch_out0[4], patch_out0[5],
                 patch_out0[6], patch_out0[7], patch_out0[8]);

        $display("Channel 1: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out1[0], patch_out1[1], patch_out1[2],
                 patch_out1[3], patch_out1[4], patch_out1[5],
                 patch_out1[6], patch_out1[7], patch_out1[8]);

        $display("Channel 2: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out2[0], patch_out2[1], patch_out2[2],
                 patch_out2[3], patch_out2[4], patch_out2[5],
                 patch_out2[6], patch_out2[7], patch_out2[8]);

        // ----------------------------------
        // Shift Column 7
        // ----------------------------------
        ifm0_in[0] = 8'd16; ifm0_in[1] = 8'd26; ifm0_in[2] = 8'd36;
        ifm1_in[0] = 8'd46; ifm1_in[1] = 8'd56; ifm1_in[2] = 8'd66;
        ifm2_in[0] = 8'd76; ifm2_in[1] = 8'd86; ifm2_in[2] = 8'd96;

        ifm_sh_en = 1;
        @(posedge clk);
        ifm_sh_en = 0;
        @(posedge clk);

        $display("\n=== Patch After 4 Shifts ===");
        $display("Channel 0: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out0[0], patch_out0[1], patch_out0[2],
                 patch_out0[3], patch_out0[4], patch_out0[5],
                 patch_out0[6], patch_out0[7], patch_out0[8]);

        $display("Channel 1: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out1[0], patch_out1[1], patch_out1[2],
                 patch_out1[3], patch_out1[4], patch_out1[5],
                 patch_out1[6], patch_out1[7], patch_out1[8]);

        $display("Channel 2: [%0d %0d %0d] [%0d %0d %0d] [%0d %0d %0d]",
                 patch_out2[0], patch_out2[1], patch_out2[2],
                 patch_out2[3], patch_out2[4], patch_out2[5],
                 patch_out2[6], patch_out2[7], patch_out2[8]);

        $stop;

    end

endmodule
