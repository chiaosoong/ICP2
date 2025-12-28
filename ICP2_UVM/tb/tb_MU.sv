`timescale 1ns/1ps
`include "conv_defines_pkg.sv"

// ============================================================================
// Testbench for MU_unit (combinational, array inputs + MU_en)
/*1⋅2+2⋅2+3⋅2+4⋅2+5⋅2+6⋅2+7⋅2+8⋅2+9⋅2 =90
1⋅2+3⋅4+5⋅6+7⋅8+9⋅10+11⋅12+13⋅14+15⋅16+17⋅18=1050
1⋅1+1⋅2+1⋅3+1⋅4+1⋅5+1⋅6+1⋅7+1⋅8+1⋅9= 45
255⋅255=65025*/	

// ============================================================================
module tb_MU;

  // ---------------- DUT I/O ----------------
  logic                   MU_en;
  logic [7:0]             patch_array  [0:8];
  logic [7:0]             kernel_array [0:8];
  logic [7:0]             MU_ofm_single;

  // ---------------- Expected model ----------------
  int unsigned            sum_u;     // wide accumulator for expected sum
  byte unsigned           exp_trunc; // low 8 bits (truncation)

  // ---------------- DUT ----------------
  MU_unit dut (
    .MU_en       (MU_en),
    .patch_array (patch_array),
    .kernel_array(kernel_array),
    .MU_ofm_single(MU_ofm_single)
  );

  // ---------------- Helpers ----------------
  task automatic clear_arrays();
    for (int i = 0; i < 9; i++) begin
      patch_array[i]  = '0;
      kernel_array[i] = '0;
    end
  endtask

  task automatic compute_expected_trunc();
    sum_u = 0;
    for (int i = 0; i < 9; i++) begin
      sum_u += patch_array[i] * kernel_array[i];
    end
    exp_trunc = sum_u[7:0]; // truncation to 8 bits (matches current RTL)
  endtask

  task automatic check(string tag);
    if (MU_ofm_single !== exp_trunc) begin
      $display("[ERROR] %s  got=%0d  exp=%0d  (sum=%0d)", tag, MU_ofm_single, exp_trunc, sum_u);
    end else begin
      $display("[PASS ] %s  val=%0d  (sum=%0d)", tag, MU_ofm_single, sum_u);
    end
  endtask

  // ---------------- Test sequence ----------------
  initial begin
    // Reset model state
    MU_en = 1'b0;
    clear_arrays();
    #1;

    // Test 0: MU_en=0 forces output to 0 regardless of inputs
    patch_array[0] = 8'd10; kernel_array[0] = 8'd20;
    compute_expected_trunc();   // exp_trunc is low 8 bits of 200, but MU_en=0 should force 0
    #1;
    if (MU_ofm_single !== 8'd0)
      $display("[ERROR] MU_en=0 gating failed: got=%0d exp=0", MU_ofm_single);
    else
      $display("[PASS ] MU_en=0 gating OK");

    // Test 1: Normal case (sum < 256 → truncation equals true sum)
    MU_en = 1'b1;
    clear_arrays();
    // small numbers to keep sum < 256
    // patch = {1..9}, kernel = all 2's → sum = 2*(1+...+9) = 90
    for (int i = 0; i < 9; i++) begin
      patch_array[i]  = i+1;
      kernel_array[i] = 8'd2;
    end
    compute_expected_trunc(); // exp_trunc should be 90
    #1; check("Test1 small (no wrap)");

    // Test 2: Large case (sum ≥ 256 → truncation)
    // patch = {1,3,5,...,17}, kernel = {2,4,6,...,18}
    clear_arrays();
    patch_array[0]=8'd1;  kernel_array[0]=8'd2;
    patch_array[1]=8'd3;  kernel_array[1]=8'd4;
    patch_array[2]=8'd5;  kernel_array[2]=8'd6;
    patch_array[3]=8'd7;  kernel_array[3]=8'd8;
    patch_array[4]=8'd9;  kernel_array[4]=8'd10;
    patch_array[5]=8'd11; kernel_array[5]=8'd12;
    patch_array[6]=8'd13; kernel_array[6]=8'd14;
    patch_array[7]=8'd15; kernel_array[7]=8'd16;
    patch_array[8]=8'd17; kernel_array[8]=8'd18;
    compute_expected_trunc(); // big sum; TB expects low 8 bits only
    #1; check("Test2 large (wrap/trunc)");




        // ========================================================
    // TEST 3: Simple known sum (no wrap) -> 45
    // patch = all 1's, kernel = 1..9
    // sum = 1*(1+2+...+9) = 45 -> exp_trunc = 45
    // ========================================================
    $display("\n====== TEST 3: Simple known sum (45) ======");
    clear_arrays();
    for (int i = 0; i < 9; i++) begin
      patch_array[i]  = 8'd1;
      kernel_array[i] = i+1;       // 1..9
    end
    MU_en = 1'b1;
    compute_expected_trunc();      // should be 45
    #1; check("Test3 simple sum");

    // ========================================================
    // TEST 4: Max inputs (wrap/truncation) -> expect low 8 bits
    // patch = all 255, kernel = all 255
    // each product = 65025, sum = 9*65025 = 585225
    // 585225 % 256 = 9 -> exp_trunc = 9
    // ========================================================
    $display("\n====== TEST 4: Max inputs (wrap/trunc) ======");
    clear_arrays();
    for (int i = 0; i < 9; i++) begin
      patch_array[i]  = 8'd255;
      kernel_array[i] = 8'd255;
    end
    MU_en = 1'b1;
    compute_expected_trunc();      // should compute to 9 via truncation
    #1; check("Test4 max inputs wrap");

    $display("==================================================");
    $display("TB finished.");
    $display("==================================================");




    #5 $stop;
  end

endmodule
