`timescale 1ns/1ps
`include "conv_defines_pkg.sv"

// ======================================================
// Testbench for kn_shifter_wrapper (3 channels)
// ======================================================
module tb_kn_shifter;

  // ---------------- Clock / Reset ----------------
  logic clk = 0; always #5 clk = ~clk;
  logic rst_n;

  // ---------------- DUT I/O ----------------
  logic [2:0]   shifter_write;
  logic [7:0]   shifter_in [2:0];

  logic [7:0]   shift_reg_out_ch0 [0:`KERNEL_DEPTH-1];
  logic [7:0]   shift_reg_out_ch1 [0:`KERNEL_DEPTH-1];
  logic [7:0]   shift_reg_out_ch2 [0:`KERNEL_DEPTH-1];

  // ---------------- Model / Scoreboards ----------------
  logic [7:0]   expected_ch0 [0:`KERNEL_DEPTH-1];
  logic [7:0]   expected_ch1 [0:`KERNEL_DEPTH-1];
  logic [7:0]   expected_ch2 [0:`KERNEL_DEPTH-1];

  // ---------------- DUT ----------------
  kn_shifter_wrapper dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .shifter_write    (shifter_write),
    .shifter_in       (shifter_in),
    .shift_reg_out_ch0(shift_reg_out_ch0),
    .shift_reg_out_ch1(shift_reg_out_ch1),
    .shift_reg_out_ch2(shift_reg_out_ch2)
  );

  // ======================================================
  // Helpers
  // ======================================================
  int errors = 0;

  task automatic clear_expected();
    for (int i = 0; i < `KERNEL_DEPTH; i++) begin
      expected_ch0[i] = '0;
      expected_ch1[i] = '0;
      expected_ch2[i] = '0;
    end
  endtask

  // Shift-left model for a specific channel array
  task automatic model_shift_and_insert(input int ch, input logic [7:0] new_val);
    case (ch)
      0: begin
        for (int i = 0; i < `KERNEL_DEPTH-1; i++) expected_ch0[i] = expected_ch0[i+1];
        expected_ch0[`KERNEL_DEPTH-1] = new_val;
      end
      1: begin
        for (int i = 0; i < `KERNEL_DEPTH-1; i++) expected_ch1[i] = expected_ch1[i+1];
        expected_ch1[`KERNEL_DEPTH-1] = new_val;
      end
      2: begin
        for (int i = 0; i < `KERNEL_DEPTH-1; i++) expected_ch2[i] = expected_ch2[i+1];
        expected_ch2[`KERNEL_DEPTH-1] = new_val;
      end
      default: ;
    endcase
  endtask

  // Pulse a write for a given channel with a value
  task automatic pulse_write(input int ch, input logic [7:0] val);
    // default deassert
    shifter_write = 3'b000;
    shifter_in[0] = '0;
    shifter_in[1] = '0;
    shifter_in[2] = '0;

    shifter_in[ch] = val;
    shifter_write[ch] = 1'b1;
    @(negedge clk);
    shifter_write[ch] = 1'b0;
  endtask

  // Check all entries for one channel
  task automatic check_channel(input int ch, input string tag);
    for (int i = 0; i < `KERNEL_DEPTH; i++) begin
      logic [7:0] got;
      logic [7:0] exp;
      case (ch)
        0: begin got = shift_reg_out_ch0[i]; exp = expected_ch0[i]; end
        1: begin got = shift_reg_out_ch1[i]; exp = expected_ch1[i]; end
        2: begin got = shift_reg_out_ch2[i]; exp = expected_ch2[i]; end
        default: begin got = 'x; exp = 'x; end
      endcase

      if (got !== exp) begin
        $display("[ERROR] %s ch=%0d idx=%0d got=%0d exp=%0d", tag, ch, i, got, exp);
        errors++;
      end else begin
        $display("[PASS ] %s ch=%0d idx=%0d val=%0d", tag, ch, i, got);
      end
    end
  endtask

  // Check all channels
  task automatic check_all(input string tag);
    check_channel(0, {tag, " (ch0)"});
    check_channel(1, {tag, " (ch1)"});
    check_channel(2, {tag, " (ch2)"});
  endtask

  // ======================================================
  // Test
  // ======================================================
  initial begin
    // Init
    rst_n         = 1'b0;
    shifter_write = 3'b000;
    shifter_in[0] = '0;
    shifter_in[1] = '0;
    shifter_in[2] = '0;
    clear_expected();

    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // After reset: all zeros on all channels
    check_all("After reset");

    // -----------------------------------
    // Load 9 values per channel
    // ch0: 3,6,9,...,27
    // ch1: 5,10,15,...,45
    // ch2: 7,14,21,...,63
    // -----------------------------------
    for (int i = 0; i < `KERNEL_DEPTH; i++) begin
        pulse_write(0, (i+1)*3);  model_shift_and_insert(0, (i+1)*3);
        pulse_write(1, (i+1)*5);  model_shift_and_insert(1, (i+1)*5);
        pulse_write(2, (i+1)*7);  model_shift_and_insert(2, (i+1)*7);
    end


    check_all("After initial load of 9 values");

    // -----------------------------------
    // One extra insert per channel to test shift-left + tail-insert
    // -----------------------------------
    pulse_write(0, 8'd99);  model_shift_and_insert(0, 8'd99);
    pulse_write(1, 8'd55);  model_shift_and_insert(1, 8'd55);
    pulse_write(2, 8'd123); model_shift_and_insert(2, 8'd123);

    check_all("After extra insert (shift + tail)");

    // Summary
    $display("======================================");
    if (errors == 0)
      $display("TEST PASSED with no errors.");
    else
      $display("TEST FAILED with %0d error(s).", errors);
    $display("======================================");

    #10 $stop;
  end

endmodule
