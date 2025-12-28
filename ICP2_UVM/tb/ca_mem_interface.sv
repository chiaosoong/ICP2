`include "conv_defines_pkg.sv"

`ifndef CA_MEM_IF_SV
  `define CA_MEM_IF_SV

  interface ca_mem_interface #(
    parameter int ADDR_W = 10,
    parameter int DATA_W = 8
  );

    // -------- IFM read / kernel control --------
    logic rd_ifm_rq;    // CA -> RAMC
    logic rd_ifm_hs;    // RAMC -> CA
    logic rd_knl_rq;    // CA -> RAMC
    logic rd_knl_hs;    // RAMC -> CA

    // -------- OFM write channel --------
    logic wr_rq;        // CA -> RAMC
    logic wr_hs;        // RAMC -> CA

    logic valid_patch;  // RAMC -> CA
    logic all_patches_done;   // RAMC -> CA


  // ---------------- Modports ----------------
  modport CA (
    // CA drives:
    output rd_ifm_rq,
    output rd_knl_rq,
    output wr_rq,
    // CA receives:
    input  rd_ifm_hs,
    input  rd_knl_hs,
    input  wr_hs,
    input  valid_patch,        // NEW
    input  all_patches_done    // NEW
  );

  modport RAMC (
    // RAMC receives:
    input  rd_ifm_rq,
    input  rd_knl_rq,
    input  wr_rq,
    // RAMC drives:
    output rd_ifm_hs,
    output rd_knl_hs,
    output wr_hs,
    output valid_patch,        // NEW
    output all_patches_done    // NEW
  );

  // Optional monitor view
  modport MON (
    input rd_ifm_rq,
    input rd_ifm_hs,
    input rd_knl_rq,
    input rd_knl_hs,
    input wr_rq,
    input wr_hs,
    input valid_patch,         // NEW
    input all_patches_done     // NEW
  );

endinterface
`endif
