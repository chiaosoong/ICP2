`timescale 1ns / 1ps

`include "conv_defines_pkg.sv"
`include "read_from_file.sv"
`include "ca_mem_interface.sv"

// Inside tb_APB

    // ======================================================
    // Passive CA<->RAMC Monitor
    // ======================================================
    /*
    Monitors the signals going in and out of the interface without driving them
    requires a monintor to be written in the interface.
    We can just bind monitor to existing interface instance in TB
    */
    module ca_monitor (ca_mem_interface.MON mon_if);
        always @(posedge mon_if.rd_ifm_rq)
            $display("[%0t] [MON] CA requested IFM read", $time);

        always @(posedge mon_if.rd_knl_rq)
            $display("[%0t] [MON] CA requested KERNEL read", $time);

        always @(posedge mon_if.wr_rq)
            $display("[%0t] [MON] CA requested OFM write", $time);

        always @(posedge mon_if.valid_patch)
            $display("[%0t] [MON] RAMC delivered VALID PATCH", $time);

        always @(posedge mon_if.all_patches_done)
            $display("[%0t] [MON] RAMC signalled ALL PATCHES DONE", $time);
        endmodule


    module tb_APB;

    // ======================================================
    // APB Bus Interface Signals
    // ======================================================
    logic HCLK;
    logic HRESETn;
    logic PSEL;
    logic PENABLE;
    logic PWRITE;
    logic [11:0]  PADDR;
    logic [31:0]  PWDATA;
    logic [31:0]  PRDATA;
    logic         PREADY;
    logic         PSLVERR;

    // DUT Instance
    apb_convolution dut (
        .HCLK    (HCLK),
        .HRESETn (HRESETn),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PADDR   (PADDR),
        .PWDATA  (PWDATA),
        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR)
    );

    // Bind to the existing ca_mem_interface instance inside top_file_convolution
bind tb_APB.dut.u_top ca_monitor mon0 ( .mon_if(ca_bus) );



    // Clock Generation
    initial HCLK = 0;
    always #5 HCLK = ~HCLK;

    // ------------------------
    // Input Arrays
    // ------------------------
    int ifm_data0[0:2351];
    int ifm_data1[0:2351];
    int ifm_data2[0:2351];

    int kernel_data0[0:26];
    int kernel_data1[0:26];
    int kernel_data2[0:26];

    int expected_output0[0:783];
    int expected_output1[0:783];
    int expected_output2[0:783];

    int status;
    int total_mismatches = 0;
    int mismatches;
    bit all_passed;

//======================================================================================
// APB emulation

    // ======================================================
    //TODO register map
    // ======================================================
    /*
    Function	    PADDR[11:2]	Actual PADDR (12-bit)
    Data Write	    10'h000	    12'h000
    Read Addr Reg	10'h001	    12'h010
    Input Mode	    10'h002	    12'h008 ← correct one
    Kernel Mode	    10'h003	    12'h00C
    Read Mode	    10'h004	    12'h010
    Read Data Out	10'h005	    12'h014
    CA Finished Flag10'h006	    12'h018 */

    // ======================================================
    //TODO APB Write Transaction
    // - clk 0: Asserts PSEL, PADDR, PWDATA, and PWRITE
    // - clk 1: Asserts PENABLE to start write transfer
    // - clk 2: Deasserts all control signals to complete transaction
    // ======================================================
    task automatic apb_write(input [11:0] addr, input [31:0] data);
        @(posedge HCLK);
        PSEL    = 1;         // Select APB peripheral
        PENABLE = 0;         // Setup phase
        PWRITE  = 1;         // Indicate write
        PADDR   = addr;      // Set address
        PWDATA  = data;      // Set data to write

        @(posedge HCLK);
        PENABLE = 1;         // Enable phase

        @(posedge HCLK);
        PSEL    = 0;         // Complete transaction
        PENABLE = 0;
    endtask

    // ====================================================== 
    // Write All IFM Values
    // - Sets input_mode by writing '1' to address 0x008
    // - Writes 2352 values from ifm_data[] to address 0x000
    //   (One APB write per clock cycle using apb_write task)
    // ======================================================
    task write_ifm_generic(input int data_array[0:2351]);

        apb_write(12'h008, 1);

        for (int i = 0; i < 2352; i++)
            apb_write(12'h000, data_array[i]);

    endtask

    // ======================================================
    // Write All Kernel Values
    // - Sets kernel_mode by writing '1' to address 0x00C
    // - Writes 27 values from kernel_data[] to address 0x000
    //   (One APB write per clock cycle using apb_write task)
    // ======================================================
    task write_kernel_generic(input int ker_array[0:26]);

        apb_write(12'h00C, 1);

        for (int i = 0; i < 27; i++)
            apb_write(12'h000, ker_array[i]);

    endtask

    // ======================================================
    //TODO ABP Read Transaction
    // we arent actually using this
    // - clk 0: Asserts PSEL and PADDR
    // - clk 1: Asserts PENABLE 
    // - clk 2: writes PRDATA into "value" and deasserts control signals
    // ====================================================== 
    task automatic apb_read(input [11:0] addr, output int value);
        repeat (2) @(posedge HCLK);
        PSEL    = 1;          // Select APB peripheral
        PENABLE = 0;          // Setup phase
        PWRITE  = 0;          
        PADDR   = addr;       

        repeat (2) @(posedge HCLK);
        PENABLE = 1;          // Enable phase

        wait (PREADY == 1); // New: Wait until slave is ready
        
        @(posedge HCLK);
        value = PRDATA;       // Capture read data from slave

        @(posedge HCLK);
        PSEL    = 0;          // Complete transaction
        PENABLE = 0;
    endtask

    // ======================================================
    // Read all RAM 4 outputs
    // ======================================================
    //TODO:
    /*added argument to avoid hardcoding expected_output or repeating code*/
    task automatic read_bank4_results_burst(input int expected_array[0:783],
    output int mismatch_count);
        int value;
        int count = 0;
        mismatch_count = 0;     // <-- initialize the OUTPUT formal

        apb_write(12'h020, 1);   
        repeat (3) @(posedge HCLK);

        while (count < 784) begin
            apb_read(12'h014, value);  

            if (value[7:0] !== expected_array[count][7:0]) begin
                //$display("[ERROR] MISMATCH at bank4[%0d]: got %0d, expected %0d", count, value[7:0], expected_array[count][7:0]);
                //mismatches++;
                mismatch_count++;
            end else begin
                //$display("[OK   ] bank4[%0d] = %0d (OK)", count, value[7:0]);
            end
            count++;
        end

        if (mismatches == 0)
            $display("\n[PASS ] All %0d outputs matched expected results!\n", count);
        else
            $display("\n[FAIL ] %0d mismatches found out of %0d outputs\n", mismatches, count);
    endtask

    // ======================================================
    // APB & System Signal Initialization
    // - Resets clock and bus control signals before simulation
    // ======================================================
    initial begin

        HCLK    = 0;    
        HRESETn = 0;   

        PSEL    = 0;    
        PENABLE = 0;    
        PWRITE  = 0; 
        PADDR   = 0;    
        PWDATA  = 0;    

        //--------------------------------------
        // defined in read_from_file.sv 
        load_arrays(
            ifm_data0,         ifm_data1,         ifm_data2,
            kernel_data0,      kernel_data1,      kernel_data2,
            expected_output0,  expected_output1,  expected_output2
        );

        //--------------------------------------  
        repeat (5) @(posedge HCLK);
        HRESETn = 1; // release reset
        @(posedge HCLK);

        //--------------------------------------
        write_ifm_generic(ifm_data0);    // write inputs

        //--------------------------------------
        write_kernel_generic(kernel_data0); // write kernel

        //--------------------------------------
        do begin
            /* Poll CA_finished flag until asserted
            CA_finished exposed at 0x006*/
            apb_read(12'h018, status); 
        end while (status == 0);

        //--------------------------------------
        read_bank4_results_burst(expected_output0, mismatches);
        total_mismatches += mismatches; // trigger read

        //--------------------------------------
        repeat (5) @(posedge HCLK);

        // ==========================================================
        // Second Operation
        // ==========================================================
        write_ifm_generic(ifm_data1);
        write_kernel_generic(kernel_data1);
        do begin
            apb_read(12'h018, status); 
        end while (status == 0);
        read_bank4_results_burst(expected_output1, mismatches);
        total_mismatches += mismatches;
        repeat (5) @(posedge HCLK);

        // ==========================================================
        // Third Operation
        // ==========================================================
        write_ifm_generic(ifm_data2);
        write_kernel_generic(kernel_data2);

        do begin
            apb_read(12'h018, status);
        end while (status == 0);

        read_bank4_results_burst(expected_output2, mismatches);
        total_mismatches += mismatches;
        repeat (5) @(posedge HCLK);

        all_passed = (total_mismatches == 0);

        if (all_passed)
            $display("\n====================\nALL 3 OPERATIONS PASSED\n====================\n");
        else
            $display("\n====================\nTEST FAILED: %0d total mismatches\n====================\n", total_mismatches);
            

        $stop;
    end

endmodule