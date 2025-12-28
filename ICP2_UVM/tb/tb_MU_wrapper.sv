`timescale 1ns/1ps
`include "conv_defines_pkg.sv"

module tb_MU_wrapper;

  logic         clk;
  logic         rst_n;
  logic         MU_en;
  logic         wr_handshake_i;

  logic [7:0]   patch_array  [0:`NUM_MU_ACTIVE-1][0:8];
  logic [7:0]   kernel_array [0:`NUM_MU_ACTIVE-1][0:8];
  logic [7:0]   MU_ofm_all;

  MU_unit_wrapper dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .MU_en        (MU_en),
    .wr_handshake_i(wr_handshake_i),
    .patch_array  (patch_array),
    .kernel_array (kernel_array),
    .MU_ofm_all   (MU_ofm_all)
  );

  always #5 clk = ~clk;

  // Helpers for known patterns
  task automatic fill_small(input int c);
    for (int i=0; i<9; i++) begin
      patch_array[c][i]  = i+1;
      kernel_array[c][i] = 8'd2;
    end
  endtask

  task automatic fill_large(input int c);
    patch_array[c][0]=8'd1;  kernel_array[c][0]=8'd2;
    patch_array[c][1]=8'd3;  kernel_array[c][1]=8'd4;
    patch_array[c][2]=8'd5;  kernel_array[c][2]=8'd6;
    patch_array[c][3]=8'd7;  kernel_array[c][3]=8'd8;
    patch_array[c][4]=8'd9;  kernel_array[c][4]=8'd10;
    patch_array[c][5]=8'd11; kernel_array[c][5]=8'd12;
    patch_array[c][6]=8'd13; kernel_array[c][6]=8'd14;
    patch_array[c][7]=8'd15; kernel_array[c][7]=8'd16;
    patch_array[c][8]=8'd17; kernel_array[c][8]=8'd18;
  endtask

  task automatic fill_simple(input int c);
    for (int i=0; i<9; i++) begin
      patch_array[c][i]  = 8'd1;
      kernel_array[c][i] = i+1;
    end
  endtask

  task automatic fill_max(input int c);
    for (int i=0; i<9; i++) begin
      patch_array[c][i]  = 8'd255;
      kernel_array[c][i] = 8'd255;
    end
  endtask

initial begin
  clk=0; rst_n=1; MU_en=1;

  // Test1: all 1’s vs all 1’s -> each MU=9, total=27
  for (int c=0; c<3; c++) begin
    for (int i=0; i<9; i++) begin
      patch_array[c][i]  = 8'd1;
      kernel_array[c][i] = 8'd1;
    end
  end
  #1 $display("Test1 expect=27, got=%0d", MU_ofm_all);

  // Test2: MU0=81, MU1=54, MU2=18, total=153
  for (int i=0; i<9; i++) begin
    patch_array[0][i]=3; kernel_array[0][i]=3;
    patch_array[1][i]=2; kernel_array[1][i]=3;
    patch_array[2][i]=1; kernel_array[2][i]=2;
  end
  #1 $display("Test2 expect=153, got=%0d", MU_ofm_all);


  for (int i=0; i<9; i++) begin
    patch_array[0][i]=3; kernel_array[0][i]=3; 
    patch_array[1][i]=2; kernel_array[1][i]=2;
    patch_array[2][i]=1; kernel_array[2][i]=1;
  end
  #1 $display("Test3 expect=255, got=%0d", MU_ofm_all);

  for (int i=0; i<9; i++) begin
    patch_array[0][i]=i%4;
    kernel_array[0][i]=(i+1)%4;
    patch_array[1][i]=i%4;
    kernel_array[1][i]=(i+2)%4;
    patch_array[2][i]=i%4;
    kernel_array[2][i]=(i+3)%4;
  end
  #1 $display("Test4 expect≈120, got=%0d", MU_ofm_all);

  $stop;
end

endmodule
