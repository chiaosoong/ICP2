/*
  ================================================================
  Testbench Summary - APB Write to 4 RAMs via apb_convolution
  ================================================================

  - This test writes 10 values to each of 4 internal RAM blocks
    instantiated inside the apb_convolution module via APB interface.

  - For each RAM (ram = 0 to 3):
      * One write to channel selection register to activate the RAM
      * 10 writes to the RAM address register (values 0 to 9)
      * 10 writes to the RAM data register (values 1–10, 11–20, etc.)

  - The apb_write task:
      * Receives APB register address and data value as arguments
      * Performs a 3-cycle APB-compliant write sequence:
          1. Cycle 1: Assert PSEL, PWRITE, and set PADDR + PWDATA
          2. Cycle 2: Assert PENABLE
          3. Cycle 3: Deassert PSEL, PENABLE, and PWRITE
*/

`timescale 1ns/1ps

module tb_4_rams;

  // ======================================================
  // Parameter Definitions for DUT
  // ======================================================
  parameter RAM_SIZE   = 1024;
  parameter ADDR_WIDTH = $clog2(RAM_SIZE);
  parameter DATA_WIDTH = 8;

  // ======================================================
  // APB Bus Signal Declarations to mimic an APB master
  // ======================================================
  logic                  clk;
  logic                  rstn;
  logic                  PSEL;
  logic                  PENABLE;
  logic                  PWRITE;
  logic [11:0]           PADDR;
  logic [31:0]           PWDATA;
  logic [31:0]           PRDATA;
  logic                  PREADY;
  logic                  PSLVERR;

  // ======================================================
  // Clock Generation 100 MHz
  // ======================================================
  always #5 clk = ~clk;

  // ======================================================
  // DUT Instantiation
  // ======================================================
  apb_convolution #(
    .RAM_SIZE(RAM_SIZE),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .HCLK     (clk),
    .HRESETn  (rstn),
    .PSEL     (PSEL),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (PADDR),
    .PWDATA   (PWDATA),
    .PRDATA   (PRDATA),
    .PREADY   (PREADY),
    .PSLVERR  (PSLVERR)
  );

  // ======================================================
  /* APB Write Task: Performs a full APB-compliant write transaction:
        1. Assert PSEL + setup PADDR and PWDATA
        2. Wait one cycle, assert PENABLE (write phase)
        3. Wait one more cycle, deassert all control signals*/
  // ======================================================
  task automatic apb_write(input [11:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      PSEL    = 1;
      PENABLE = 0;
      PWRITE  = 1;
      PADDR   = addr;
      PWDATA  = data;
      @(posedge clk);
      PENABLE = 1;
      @(posedge clk);
      PSEL    = 0;
      PENABLE = 0;
      PWRITE  = 0;
    end
  endtask

  // ------------------------------------------------------
  // APB Read Task
  // ------------------------------------------------------
  task automatic apb_read(input [11:0] addr, output logic [31:0] data_out);
    begin
      @(posedge clk);
      PSEL    = 1;
      PENABLE = 0;
      PWRITE  = 0;
      PADDR   = addr;
      @(posedge clk);
      PENABLE = 1;
      @(posedge clk);
      data_out = PRDATA;
      PSEL     = 0;
      PENABLE  = 0;
    end
  endtask

  // ======================================================
  // Initial Test Logic
  // Resets the DUT, then writes 10 values into each of 4 RAMs:
  // RAM 0 gets 1–10, RAM 1 gets 11–20, etc.
  // Each RAM is selected before writing by setting the correct channel register
  // ======================================================
    logic [31:0] data_out;  // holds data read from APB
    int errors = 0;         // counts mismatches during read verification
    int expected;

  initial begin
    // Initialize signals
    clk   = 0;
    rstn  = 0;
    PSEL  = 0;
    PENABLE = 0;
    PWRITE  = 0;
    PADDR   = 0;
    PWDATA  = 0;


    // Hold reset for a few clock cycles
    repeat (3) @(posedge clk);
    rstn = 1;

    // -------------------------
    // Write Phase : Write 10 values to each RAM
    // -------------------------
      // --------------------------------------------------------------
      // Channel Selection - Fixed Addresses (Aligned to 32-bit words)
      // --------------------------------------------------------------
      /*
      Addresses are decoded using PADDR[11:2] in RTL.
      That means software must provide addresses that are multiples of 4.

      For example:
        - 12'h003 → binary 0000_0000_0011 → [11:2] = 0x00 → OK
        - 12'h004 → binary 0000_0000_0100 → [11:2] = 0x01 → WRONG (not what RTL expects)

      Working addresses based on RTL case labels:
        - 12'h00C → [11:2] = 0x003 → channel_1_reg
        - 12'h010 → [11:2] = 0x004 → channel_2_reg
        - 12'h014 → [11:2] = 0x005 → channel_3_reg
        - 12'h018 → [11:2] = 0x006 → read_channel_reg

      What worked:
        ✓ When PADDR[11:2] matches RTL cases (e.g., 12'h00C → 0x003)
      
      What didn’t:
        ✗ Using 12'h003, 12'h004, etc. which decode to [11:2] = 0x000, 0x001,
          and mismatched the RTL address space
      */

    $display("Starting Write phase ...");

    for (int ram = 0; ram < 4; ram++) begin
        $display("we are in the for loop now ...");
      // Select active RAM channel by writing to selection register
      apb_write(12'h00C, ram);  // 0x00C → (0x00C >> 2 = 0x003) → channel_0_reg

      // Write 10 sequential values into the selected RAM
      for (int i = 0; i < 10; i++) begin
        apb_write(12'h000, ram*10 + i + 1);    // data (unique per RAM)
        apb_write(12'h004, i);                 // address

      end
    end

         /* //TODO: these addresses were not word aligned hence connected to wrong register in the apb_conv module. To get correct address: 12'h003 × 4 = 12'h00C
        case (ram)
        0: apb_write(12'h003, 0);  // channel_1_reg
        1: apb_write(12'h004, 1);  // channel_2_reg
        2: apb_write(12'h005, 2);  // channel_3_reg
        3: apb_write(12'h006, 3);  // read_channel = output RAM (used here as write target)
      endcase
    */
    $display("Write phase complete. Starting readback...");


        /*
   both values are hex,
   Address	         PADDR[11:2] Register	Description
   decimal: 0   0x000	10'h000	wr_data_reg	Write data (1 byte)
   decimal: 4   0x004	10'h001	wr_addr_reg	Write address
   decimal: 8   0x008	10'h002	rd_addr_reg	Read address
   decimal: 12  0x00C	10'h003	wr_channel	Select RAM to write
   decimal: 16  0x010	10'h004	rd_channel	Select RAM to read
   decimal: 20  0x014	10'h005	rd_data_reg	Read data
   decimal: 24  0x018	10'h006	ram_ready	Read ready flag (1 = data valid)*/   
     
    // -------------------------
    // Read Phase + Self-Check
    // -------------------------

    for (int ram = 0; ram < 4; ram++) begin
      apb_write(12'h010, ram); // rd_channel = ram -- reg 16

      for (int i = 0; i < 10; i++) begin
        expected = ram*10 + i + 1;

        apb_write(12'h008, i);        // set read address -- reg 8
        repeat (3) @(posedge clk);    // wait for latency

        apb_read(12'h018, data_out);  // poll ram_ready flag -- reg 24

        while (data_out == 0)
          apb_read(12'h018, data_out);

        apb_read(12'h014, data_out);  // read data  -- reg 20

        if (data_out[7:0] !== expected[7:0]) begin
          $display("ERROR: RAM %0d, Addr %0d, Expected %0d, Got %0d",
                   ram, i, expected, data_out[7:0]);
          errors++;
        end else begin
          $display("PASS : RAM %0d, Addr %0d, Value %0d",
                   ram, i, data_out[7:0]);
        end
      end
    end

    $display("Test %s with %0d error(s).", (errors == 0) ? "PASSED" : "FAILED", errors);
    
    $stop;
  end

endmodule


   