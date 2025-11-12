// ======================================================
// Top-Level Integration: Controller (with 4 RAMs) + CA
// ======================================================

`include "conv_defines_pkg.sv"

module top_file_convolution 
(
    input  logic                   clk,
    input  logic                   rst_n,

    // Software/Stimulus Side
    input  logic                   APB_wr_done,
    input  logic [1:0]             channel_top,

    input  logic                   write_en_APB,
    input  logic                   valid_input_APB,
    input  logic [`ADDR_WIDTH-1:0] write_addr_APB,
    input  logic [`DATA_WIDTH-1:0] write_data_APB,

    output logic [`DATA_WIDTH-1:0] read_APB_data_top,
    input  logic                   read_cmd_APB_top,
    input  logic [`ADDR_WIDTH-1:0] read_apb_addr_top,
    output logic                   CA_finished,
    input  logic                   top_clear,

    output logic                   ry_APB
);
    // =========================
    // Interface instance (shared by CA & RAMC)
    // =========================
    ca_mem_interface #(
        .ADDR_W(`ADDR_WIDTH),
        .DATA_W(`DATA_WIDTH)
    ) ca_bus ();


    // =========================
    // Internal wiring
    // =========================

    // IFM data (3 lanes per bank)
    logic [`DATA_WIDTH-1:0] ifm0 [2:0];
    logic [`DATA_WIDTH-1:0] ifm1 [2:0];
    logic [`DATA_WIDTH-1:0] ifm2 [2:0];

    // OFM readback (APB reads bank3/OFM)
    logic [`DATA_WIDTH-1:0] ofm_data;

    // OFM write channel (CA -> RAMC)
    logic [`ADDR_WIDTH-1:0]  wr_addr_ofm;
    logic [`DATA_WIDTH-1:0]  wr_data_ofm;

    // APB read fanout (match RAMC *_i ports)
    logic                    rd_rq_APB_i;
    logic [`ADDR_WIDTH-1:0]  rd_apb_addr_i;

    // Channel mux: only relevant during APB writes
    logic [1:0] channel_mux;

    // CA finished fanout
    logic CA_finished_i;

    // =========================
    // Simple glue
    // =========================
    always_comb begin
        // steer channel only while writing
        channel_mux       = (write_en_APB) ? channel_top : 2'd0;

        // APB read data comes from RAMC OFM output
        read_APB_data_top = ofm_data;

        // expose CA finished
        CA_finished       = CA_finished_i;

        // pass-through APB read control
        rd_rq_APB_i       = read_cmd_APB_top;
        rd_apb_addr_i     = read_apb_addr_top;

        // not used in this revision
        ry_APB            = 1'b0;
    end

  // =========================
  // RAM Controller 
  // =========================
  /* intend to make a second version of ram controller with shared rams so depending
    on what macro is defined in define package one of the ram controllers will be instantiated*/
        
    `RAMC_NAME u_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),
        .APB_wr_done        (APB_wr_done),
        .channel_ctrl       (channel_mux),
        .CA_finished_i      (CA_finished_i),
        .ram_clear          (top_clear),

        // APB
        .wr_en_APB_i        (write_en_APB),
        .wr_data_APB_i      (write_data_APB),
        .wr_addr_APB_i      (write_addr_APB),
        .rd_rq_APB_i        (rd_rq_APB_i),
        .rd_apb_addr_i      (rd_apb_addr_i),
        .valid_input_APB_i  (valid_input_APB),

        // CA <-> RAMC interface (modport RAMC)
        .ca_if              (ca_bus),

        // OFM write datapath from CA
        .wr_data_ofm_i      (wr_data_ofm),
        .wr_addr_ofm_i      (wr_addr_ofm),

        // IFM data out to CA
        .ifm_data0_o        (ifm0),
        .ifm_data1_o        (ifm1),
        .ifm_data2_o        (ifm2),

        // OFM readback for APB
        .ofm_data_o         (ofm_data)
    );

    // =========================
    // Convolution Accelerator
    // =========================
    CA_buffer_mode u_ca (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_CA           (APB_wr_done), // sends CA to load kernel
        .CA_finished        (CA_finished_i),
        .CA_clear           (top_clear),

        // OFM write side (datapath)
        .wr_addr_ofm_o      (wr_addr_ofm),
        .wr_data_ofm_o      (wr_data_ofm),

        // IFM data from RAMC
        .ifm_data0_i        (ifm0),
        .ifm_data1_i        (ifm1),
        .ifm_data2_i        (ifm2),

        // CA <-> RAMC interface (modport CA)
        .ca_if              (ca_bus)
    );

    `undef RAMC_NAME

endmodule