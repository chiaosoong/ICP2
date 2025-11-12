
`timescale 1ns / 1ps
`include "conv_defines_pkg.sv"

module tb_patch_shifter_conv;

    // ----------------------------------
    // DUT Ports
    // ----------------------------------
    logic clk;
    logic rst_n;
    logic ifm_sh_en;
    logic [7:0] ifm_sh_in[2:0];         // Top, Mid, Bot
    logic [7:0] patch_out[0:8];         // Flattened 3x3 patch

    // ----------------------------------
    // Instantiate DUT
    // ----------------------------------
    patch_shifter dut (
        .clk(clk),
        .rst_n(rst_n),
        .ifm_sh_en(ifm_sh_en),
        .ifm_sh_in(ifm_sh_in),
        .patch_out(patch_out)
    );

    // ----------------------------------
    // Clock generation
    // ----------------------------------
    always #5 clk = ~clk;

    // ----------------------------------
    // Task to print patch window
    // ----------------------------------
    task print_patch;
        $display("Patch:");
        $display("[%0d %0d %0d]", patch_out[0], patch_out[1], patch_out[2]);
        $display("[%0d %0d %0d]", patch_out[3], patch_out[4], patch_out[5]);
        $display("[%0d %0d %0d]", patch_out[6], patch_out[7], patch_out[8]);
    endtask

    // ----------------------------------
    // Stimulus
    // ----------------------------------
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        ifm_sh_en = 0;
        ifm_sh_in[0] = 8'd0;
        ifm_sh_in[1] = 8'd0;
        ifm_sh_in[2] = 8'd0;

        // Reset pulse
        #12;
        rst_n = 1;

        // ----------------------------------
        // Warm-up: Load 3 columns (col0, col1, col2)
        // Each cycle inserts one column of 3 values
        // ----------------------------------

        repeat (6) @(posedge clk);  // gap after reset

        // Cycle 1 - Insert Column 0
        ifm_sh_en = 1;
        ifm_sh_in[0] = 8'd10;  // top
        ifm_sh_in[1] = 8'd20;  // mid
        ifm_sh_in[2] = 8'd30;  // bot
        @(posedge clk);

        // Cycle 2 - Insert Column 1
        ifm_sh_in[0] = 8'd11;
        ifm_sh_in[1] = 8'd21;
        ifm_sh_in[2] = 8'd31;
        @(posedge clk);

        // Cycle 3 - Insert Column 2
        ifm_sh_in[0] = 8'd12;
        ifm_sh_in[1] = 8'd22;
        ifm_sh_in[2] = 8'd32;
        @(posedge clk);

        // Print full patch
        ifm_sh_en = 0;
        @(posedge clk);
        $display("=== Patch after warm-up ===");
        print_patch();

        // Slide one patch to the right
        ifm_sh_en = 1;
        ifm_sh_in[0] = 8'd13;
        ifm_sh_in[1] = 8'd23;
        ifm_sh_in[2] = 8'd33;
        @(posedge clk);

        // Print shifted patch
        ifm_sh_en = 0;
        @(posedge clk);
        $display("=== Patch after one shift ===");
        print_patch();

        // One more shift
        ifm_sh_en = 1;
        ifm_sh_in[0] = 8'd14;
        ifm_sh_in[1] = 8'd24;
        ifm_sh_in[2] = 8'd34;
        @(posedge clk);

        ifm_sh_en = 0;
        @(posedge clk);
        $display("=== Patch after second shift ===");
        print_patch();

        // Done
        $stop;
    end

endmodule
