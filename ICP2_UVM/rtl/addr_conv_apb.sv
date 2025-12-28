// ====================================================================================
/* purpose:
        first step:
            0-783 --> 0-899 from apb address to padded addresses
        
        second step:
            0-899 --> 0-149
            with special arrangement
        
        Special arrangement:
            Also it changes the order in which data is written to ram
            Writes addresses in 3 row bundles. 
            Each of the 3 rows goes into a new ram so:
            ram0 --> row0
            ram1 --> row1
            ram2 --> row2
            and then repeat (6 rams needed for all values)
            this allows reading 3 rams at once for speed up of operations*/
// ====================================================================================

`include "conv_defines_pkg.sv"

module addr_conv_apb
(
    input  logic [`ADDR_WIDTH-1:0] global_addr,   // 0..783
    output logic [`ADDR_WIDTH-1:0] local_addr,    // 0..149
    output logic [2:0]             ram_index      // 0..5
);
    // ---- intermediates ----
    logic [9:0] ga;                 // widened for arithmetic
    logic [5:0] row;                // 0..27
    logic [5:0] col;                // 0..27
    logic [5:0] physical_row;       // 1..28
    logic [5:0] physical_col;       // 1..28
    logic [5:0] row_group;          // 0..9
    logic [1:0] mod3;               // 0..2
    logic [`ADDR_WIDTH-1:0] local_addr_raw;

    // Constants for magic division (exact over our ranges)
    // floor(n/28) = (n * 2341) >> 16   for n in 0..1023
    localparam int unsigned DIV28_M = 2341;
    localparam int unsigned DIV28_S = 16;

    // floor(n/3)  = (n * 43)   >> 7    for n in 0..63
    localparam int unsigned DIV3_M  = 43;
    localparam int unsigned DIV3_S  = 7;

    always_comb begin
        // Defaults

        physical_row   = '0;
        physical_col   = '0;
        row_group      = '0;
        mod3           = '0;
        local_addr_raw = '0;
        row            = '0;
        col            = '0;

        local_addr = '0;
        ram_index  = `PAD_RAM_INDEX;

        // Cast once
        ga = global_addr;

        // ---------- Kernel override: GA [KERNEL_BASE_ADDR .. +KERNEL_DEPTH-1] ----------
        if ((ga >= `KERNEL_BASE_ADDR) && (ga < (`KERNEL_BASE_ADDR + `KERNEL_DEPTH))) begin
            ram_index  = `KERNEL_RAM_IDX; // 5
            local_addr = `KERNEL_LOCAL_BASE + (ga - `KERNEL_BASE_ADDR);

            /* 
            Made exception for kernel addresses because addr 784-792 will be overwritten with zeros later due to old design addressing
            
            Ex: 150 + (784-784) = 150
                  150 + (785-784) = 151
                    ...
                  150 + (792-784)= 158  
                  */
        //-----------------------------------------------          
        end else begin
            // --------- Decode logical 28x28: row/col without div/mod ---------
            // row = floor(ga / 28)
            row = ( (ga * DIV28_M) >> DIV28_S );                 // 0..27

            // col = ga - row*28  (28 = 16 + 8 + 4)
            col = ga - ( (row << 4) + (row << 3) + (row << 2) ); // 0..27

            // Shift to physical 30x30 (skip border zeros)
            physical_row = row + 6'd1;   // 1..28
            physical_col = col + 6'd1;   // 1..28

            // --------- RAM select by row groups of 3 (no %/ div) ----------
            // row_group = floor(physical_row / 3)
            row_group = ( (physical_row * DIV3_M) >> DIV3_S );   // 0..9

            // mod3 = physical_row % 3 = physical_row - 3*row_group
            mod3 = physical_row - (row_group * 3);               // 0..2

            // First 15 physical rows (1..14) => banks 0..2, next 15 (15..28) => banks 3..5
            if (physical_row < 6'd15) begin
                ram_index = mod3[1:0];                           // 0..2
            end else begin
                ram_index = 3 + mod3[1:0];                       // 3..5
            end

            // --------- Local address within selected RAM (wrap @150) ----------
            // local_addr_raw = row_group*PHYS_WIDTH + physical_col
            // PHYS_WIDTH=30 => (row_group*32 - row_group*2) + physical_col
            local_addr_raw = ( (row_group << 5) - (row_group << 1) ) + physical_col; // up to ~298

            if (local_addr_raw >= 10'd150) begin
                local_addr = local_addr_raw - 10'd150;           // 0..149
            end else begin
                local_addr = local_addr_raw;                      // 0..149
            end
        end
    end
endmodule
