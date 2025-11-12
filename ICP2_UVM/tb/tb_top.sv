`timescale 1ns / 1ps

`include "conv_defines_pkg.sv"
module tb_top;

    // ======================================================
    // Signal Declarations
    // ======================================================
    logic clk;
    logic rst_n;
    logic APB_wr_done;
    logic [1:0] channel_top;
    logic write_en_APB;
    logic valid_input_APB;
    logic [`ADDR_WIDTH-1:0] write_addr_APB;
    logic [`DATA_WIDTH-1:0] write_data_APB;
    logic ry_APB;
    logic [`DATA_WIDTH-1:0] top_output;
    logic CA_finished_tb;
    logic [`DATA_WIDTH-1:0] read_APB_data_top;
    logic read_cmd_APB_top;
    logic [`ADDR_WIDTH-1:0] read_apb_addr_top;

    // ======================================================
    // DUT Instantiation
    // ======================================================
    top_file_convolution dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .APB_wr_done        (APB_wr_done),
        .channel_top      (channel_top),
        .write_en_APB     (write_en_APB),
        .valid_input_APB  (valid_input_APB),
        .write_addr_APB   (write_addr_APB),
        .write_data_APB   (write_data_APB),
        .read_APB_data_top(read_APB_data_top),
        .read_cmd_APB_top (read_cmd_APB_top),
        .read_apb_addr_top(read_apb_addr_top),
        .CA_finished      (CA_finished_tb),
        .ry_APB           (ry_APB)
    );

    // ======================================================
    // Clock Generation: 100MHz
    // ======================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // ======================================================
    // Input Data Arrays (software-driven RAM initialization)
    // ======================================================
    int ifm_data    [0:2351];      // 28×28×3 IFM values
    int kernel_data [0:26];     // 3×3×3 kernel values

    // ======================================================
    // Load array from C-style .h file
    // - Supports lines like: uint8_t ifm[] = { 3, 2, ... };
    // - Ignores braces and semicolon
    // ======================================================
    task automatic load_arrays();
        int fd_ifm, fd_ker;
        int value;
        string line;
        int i;

        // -----------------------
        // Load IFM Data
        // -----------------------
        fd_ifm = $fopen("stimuli/ifm0.h", "r");
        if (!fd_ifm) $fatal("Failed to open ifm.h");

        i = 0;
        while (!$feof(fd_ifm) && i < 2352) begin
            void'($fgets(line, fd_ifm));
            if ($sscanf(line, "%d", value) == 1)
                ifm_data[i++] = value;
        end
        $fclose(fd_ifm);

        // -----------------------
        // Load Kernel Data
        // -----------------------
        fd_ker = $fopen("stimuli/w0.h", "r");
        if (!fd_ker) $fatal("Failed to open w.h");

        i = 0;
        while (!$feof(fd_ker) && i < 27) begin
            void'($fgets(line, fd_ker));
            if ($sscanf(line, "%d", value) == 1)
                kernel_data[i++] = value;
        end
        $fclose(fd_ker);
    endtask

    // ======================================================
    // Task: Write IFM values into RAMs 1–3
    // - Cycles through channels every 784 values
    // - Each value written 1 per clock cycle
    // ======================================================
    task automatic write_ifm_data();
        for (int ch = 0; ch < 3; ch++) begin
            channel_top     = ch;
            write_en_APB    = 1;
            @(posedge clk);
            for (int i = 0; i < 784; i++) begin
                //------------------------------
                valid_input_APB = 1;
                write_addr_APB  = i;
                write_data_APB  = ifm_data[ch * 784 + i];
                @(posedge clk);
                //------------------------------
            end
            write_en_APB     = 0;
            valid_input_APB  = 0;
            @(posedge clk); // optional gap between channel bursts
        end
    endtask

    // ======================================================
    // Task: Write kernel weights to RAMs 1–3
    // - RAM address range: 784 to 792 (9 values per channel)
    // - Channel changes every 9 values
    // ======================================================
    task automatic write_kernel_data();
        // Write 9 kernel values to each RAM channel
        for (int ch = 0; ch < 3; ch++) begin
            channel_top     = ch;
            write_en_APB    = 1;
            @(posedge clk);

            for (int i = 0; i < 9; i++) begin
                valid_input_APB = 1;
                write_addr_APB  = 784 + i;
                write_data_APB  = kernel_data[ch * 9 + i];
                @(posedge clk);
            end

            write_en_APB    = 0;
            valid_input_APB = 0;
            @(posedge clk);  // Small gap between channel writes
        end
    endtask
    
    // ======================================================
    // Task: Read results from RAM4 after CA finishes
    // ======================================================
    task automatic read_ram4_results();
        wait (CA_finished_tb == 1'b1);
        $display("=== Reading from RAM4 ===");
        for (int i = 0; i < 784; i++) begin
            read_apb_addr_top = i;
            read_cmd_APB_top  = 1'b1;
            @(posedge clk);
            read_cmd_APB_top  = 1'b0;
            @(posedge clk);
            $display("RAM4[%0d] = %0d", i, read_APB_data_top);
        end
    endtask

    // ======================================================
    // Main Simulation Sequence
    // ======================================================
    initial begin
        // Initial state
        clk = 0;
        rst_n = 0;
        APB_wr_done = 0;
        write_en_APB = 0;
        valid_input_APB = 0;
        channel_top = 0;
        write_addr_APB = 0;
        write_data_APB = 0;

        // Load IFM and kernel data from files
        load_arrays();
        /*load_array("ifm.h", ifm_data, 2352);
        load_array("w.h", kernel_data, 27);*/

        // Apply reset
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Write IFM into RAMs
        write_ifm_data();

        // Write kernel into RAMs
        write_kernel_data();

        // Trigger computation
        @(posedge clk);
        APB_wr_done = 1;
        @(posedge clk);
        APB_wr_done = 0;

        @(posedge clk);
        read_ram4_results();

       // repeat (20000) begin

        $stop;
    end

endmodule
