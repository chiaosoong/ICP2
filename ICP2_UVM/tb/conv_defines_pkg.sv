`ifndef CONV_CONFIG_SV
`define CONV_CONFIG_SV

  // ======================================================
  // RAM Mode Selection
  // ======================================================
  `define RAM_MODE_160
  // `define RAM_MODE_1024
  `define RAM_MODE_LINE_BUFFER
  `define UNIQUE_RAMS_PER_BANK
  //`define SHARE_RAMS_ALL_BANKS

    
 
// `define RAM_160_32bits
  `define RAM_160_64bits_SHARED

  `define DOUBLE_PIPLINE

  `ifdef RAM_160_32bits
    `define RAM_DATA_WIDTH 32
    `define WRAPPER_DATA_WIDTH 8

  
  `elsif RAM_160_64bits_SHARED
    `define RAM_DATA_WIDTH 64
    `define WRAPPER_DATA_WIDTH 64
    
  `endif
    // ======================================================
  // RAM Width Parameters
  // ======================================================


  // ---------- Select RAM controller flavor ----------
  `ifdef UNIQUE_RAMS_PER_BANK
    `define RAMC_NAME ram_controller_conv
  `elsif SHARE_RAMS_ALL_BANKS
    `define RAMC_NAME ram_controller_shared
  `else
    // Fallback (choose one as default)
    `define RAMC_NAME ram_controller
  `endif

  // ======================================================
  // MU
  // ======================================================
  `define NUM_MU_ACTIVE 3
  `define NUM_RAMS_PER_BANK 6 
  `define SUBRAMS_IFM 3
  //TODO:
  // some of these no longer represent what they are called
  `define MU_COUNT   3
  `define SUM_COUNT  1
  // ======================================================
  // Global Constants
  // ======================================================
  `define DATA_WIDTH       8
  `define RAM_SIZE         1024 
  `define ADDR_WIDTH       $clog2(`RAM_SIZE) // 10
  `define RAM_IDX_WIDTH    $clog2(`NUM_RAMS_PER_BANK) // 3

  `define APB_WR_MODE   2'd0
  `define FULL_IFM_MODE 2'd1
  `define OFM_MODE      2'd2

  // ======================================================
  // Shifter
  // ======================================================
  `define KERNEL_DEPTH       9             // 9 - 1
  `define SH_ADD_WIDTH    $clog2(`KERNEL_DEPTH)
  `define KERNEL_BASE_ADDR 10'd784 /* only true in APB mode
                                   these addresses will be mapped to zero
                                   padding in ifm mode*/
  `define KERNEL_LOCAL_BASE 9'd150
  `define KERNEL_RAM_IDX      9'd5
  `define IFM_HEIGHT       28
  `define IFM_WIDTH        28
  `define PHYS_WIDTH       30
  `define MAX_PATCH_ADDR (`IFM_WIDTH * `IFM_HEIGHT - 1)
  `define PAD_RAM_INDEX    0
  `define ROWS_PER_RAM    5
  // ======================================================
  // CA controller
  // ====================================================== 
  `define ITERATION_COUNT  784
  `define SAT_LIMIT        10'd255
  `define MAX_PIXEL        8'd255

  // ======================================================
  // RAM controller
  // ====================================================== 
  `define CA_WR_CYCLES     1
  //`define RA_RD_CYCLES     (`KERNEL_DEPTH + 2)
  `define CHANNEL_1 2'd0
  `define CHANNEL_2 2'd1
  `define CHANNEL_3 2'd2

  `define ZERO 3'd0
  `define ONE  3'd1
  `define TWO  3'd2
  `define THREE 3'd3
  `define FOUR  3'd4
  `define FIVE  3'd5

  `define HS_DELAY 1'd1

  // ======================================================
  // MU unit
  // ======================================================
  `define SUM_WIDTH        16
  `define OFM_WIDTH        10
  `define RESULT_LATENCY   29

`endif
