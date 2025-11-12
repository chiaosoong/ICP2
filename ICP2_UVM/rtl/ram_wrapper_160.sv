// ======================================================
// Parameterized RAM Wrapper for 160xN SRAM (8/24/32)
// ======================================================
// ONE of these must be defined:

//   `define RAM_160_64bits_SHARED
//   `define RAM_160_32bits
//
// Also define:
//   `define WRAPPER_DATA_WIDTH 24
//   `define RAM_DATA_WIDTH 8/24/32 
// ======================================================
`include "conv_defines_pkg.sv"

module ram_wrapper_160
(
    input  logic                           clk,              
    input  logic                           write_en,         
    input  logic                           read_en,          
    input  logic        [7:0]              addr,             // 160 words -> 8-bit address
    input  logic [`WRAPPER_DATA_WIDTH-1:0] ram_data_in,   // data width (24)
    output logic [`WRAPPER_DATA_WIDTH-1:0] ram_data_out,  
    output logic                           ry,               
    input  logic        [63:0]             mask_in           // up to 4 mask bits;
);

// ===========================================================================
// 32-bit ram, 
// ===========================================================================
`ifdef RAM_160_32bits


// ===========================================================================
// 64-bit ram, 24-bit wrapper, bit-masking (3 channels)
// ===========================================================================
`elsif RAM_160_64bits_SHARED

    ST_SPHDL_160x64m8_bL u_sram (
        .CK      ( clk ),
        .CSN     ( ~(write_en | read_en) ),
        .A       ( addr ),
        .WEN     ( ~write_en ),
        .D       ( ram_data_in ),   
        .Q       ( ram_data_out ),
        .RY      ( ry ),
        .M       ( mask_in[63:0] ),   // 1 bit per byte
        .TBYPASS ( 1'b0 )
    );

`endif

endmodule


