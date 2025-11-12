`timescale 1ns / 1ps

`include "conv_defines_pkg.sv"

// ======================================================
// Testbench for patch_gen_conv
// Generates first 3 rows of patches (3 x 28 = 84 patches)
// ======================================================

module tb_patch;

    // -------------------------------------
    // DUT Interface Signals
    // -------------------------------------
    logic clk;
    logic rst_n;
    logic enable;

    logic [`ADDR_WIDTH-1:0] patch_addr;
    logic zero_pad;
    logic valid;
    logic done_1_patch;

    // -------------------------------------
    // Clock Generation
    // -------------------------------------
    always #5 clk = ~clk;

    // -------------------------------------
    // DUT Instantiation
    // -------------------------------------
    patch_gen_conv dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .patch_addr   (patch_addr),
        .zero_pad     (zero_pad),
        .valid        (valid),
        .done_1_patch (done_1_patch),
        .current_ram  (current_ram) //  Added to match updated module
    );

    // Stimulus
    initial begin
        clk = 0;
        rst_n = 0;
        enable = 0;

        #20;
        rst_n = 1;
        #10;
        enable = 1;

        // For full 28x28 IFM, 28x28 patches × 9 = 7056 cycles
        // 1 patch = 9 cycles, total 784 patches
        #70560;
        enable = 0;

        #20;
        $stop;
    end

    // -------------------------------------
    // Output Monitor
    // -------------------------------------
    always_ff @(posedge clk) begin
        if (valid) begin
            $display("Cycle %0t | Addr: %0d | zero_pad=%0b", 
                      $time, patch_addr, zero_pad);
        end
        if (done_1_patch) begin
            $display("Cycle %0t | >>> DONE patch", $time);
        end
    end

endmodule
