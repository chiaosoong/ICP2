
/*purpose:
        three type of addr conversions
            0-783 --> 0-899 from apb address to padded addresses
            0-899 --> 0-149 with special order for ram 160 word addr
            0-783 --> 0-159 for output ram read/write addresses

            APB can always both read and write to 0-783 addresses

            inside CA can work with 0-899 addresses

            ram controller will have its own local addresses which this module creates*/

`include "conv_defines_pkg.sv"

module addr_conv_wrapper 
(
    input  logic [`ADDR_WIDTH-1:0] global_addr,   // 0–783 for IFM
    output logic [`ADDR_WIDTH-1:0] local_addr,    // 0–149 per RAM
    input  logic [1:0]             mode,           
    // 0: APB_write, 1: FULL_IFM_ADDR 2: ofm/APB_read
    output logic [2:0]             ram_index    // 0–5
);


logic [7:0] local_addr_buffer;
logic [2:0] ram_index_buffer;

logic [`ADDR_WIDTH-1:0] local_addr_apb;
logic [2:0]             ram_index_apb;

logic [`ADDR_WIDTH-1:0] local_addr_ofm;
logic [2:0]             ram_index_ofm;

// ======================================================
// 0- 899 --> 0-149 addresses
// ======================================================
/*  input:  0-899
    output: 0-149
            with special order 
                        ram0 --> row0
                        ram1 --> row1
                        ram2 --> row2
            takes an 30x30 IFM addr and writes to 
            6 small rams in the row order above

            This order allows use to read 3 rows at the same time since each row is written to the next ram. This allows us to sweep a 3x3 window across a row without having to read values one at a time.

            Now we can read 3 values that we register.
            on the third clock cycle we have 9 values and MU unit can do the multiplication all at once.
            next clock cycle one colomn of patch is pushed out and a new column is pushed in this way. So each clock cycle we have a full patch. 
                
    */

addr_conv_padded padded_addr_inst (
    .global_addr_padded (global_addr),
    .ram_index          (ram_index_buffer),
    .local_addr         (local_addr_buffer)
);

// ======================================================
// APB writes: 783 --> 0-899
// ======================================================
        /*Used for writing inputs from APB
            0-783, to 0-149 with special order same as above.

            the difference here is that we skip addr that are reserved for 
            zero pads and write the 0-783 values to the addr they are meant to be
            in a 30x30 matrix*/

addr_conv_apb apb_map_i 
(
    .global_addr(global_addr),
    .local_addr (local_addr_apb),
    .ram_index  (ram_index_apb)
);

// ======================================================
// OFM_ADDR (0-783) → (0-159)
// ======================================================
    /* used for addressing ofm using small rams
         0-159   -->  0-159  ram index = 0 
         160-310 -->  0-159  ram index = 1 
         320–479 -->  0–159  ram index = 2 
         480–639 -->  0–159  ram index = 3 
         640–783 -->  0–143  ram index = 4 */

    always_comb begin
        // defaults
        local_addr_ofm = '0;            
        ram_index_ofm  = 3'd0;

        if (global_addr < 10'd160) begin
            ram_index_ofm  = 3'd0;       // bank 0
            local_addr_ofm = global_addr; // 0..159

        end else if (global_addr < 10'd320) begin
            ram_index_ofm  = 3'd1;       // bank 1
            local_addr_ofm = global_addr - 10'd160;

        end else if (global_addr < 10'd480) begin
            ram_index_ofm  = 3'd2;       // bank 2
            local_addr_ofm = global_addr - 10'd320;

        end else if (global_addr < 10'd640) begin
            ram_index_ofm  = 3'd3;       // bank 3
            local_addr_ofm = global_addr - 10'd480;
            
        end else begin
            // 640..783
            ram_index_ofm  = 3'd4;       // bank 4
            local_addr_ofm = global_addr - 10'd640; // 0..143
        end
    end
// ======================================================
// Output logic
// ======================================================

        always_comb begin
            case (mode)
                //---------------------
                `APB_WR_MODE: begin
                    local_addr = local_addr_apb;
                    ram_index  = ram_index_apb;
                end
                //---------------------
                `FULL_IFM_MODE: begin
                    local_addr = local_addr_buffer;
                    ram_index  = ram_index_buffer;
                end
                //---------------------
                `OFM_MODE: begin
                    local_addr = local_addr_ofm;
                    ram_index  = ram_index_ofm;
                end
                //---------------------
                default: begin
                    local_addr = '0;
                    ram_index  = `PAD_RAM_INDEX;
                end
            endcase
        end

endmodule
