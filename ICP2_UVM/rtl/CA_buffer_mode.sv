

`include "conv_defines_pkg.sv"
// ======================================================
// CA_controller_buffer: Optimized for RAM_MODE_LINE_BUFFER
// ======================================================
`include "conv_defines_pkg.sv"
`include "ca_mem_interface.sv"

module CA_buffer_mode
(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start_CA,
    output logic                     CA_finished,
    input  logic                     CA_clear,

    // ===== Data paths (unchanged) =====
    output logic [`ADDR_WIDTH-1:0]   wr_addr_ofm_o,
    output logic [`DATA_WIDTH-1:0]   wr_data_ofm_o,
    input  logic [`DATA_WIDTH-1:0]   ifm_data0_i [2:0],
    input  logic [`DATA_WIDTH-1:0]   ifm_data1_i [2:0],
    input  logic [`DATA_WIDTH-1:0]   ifm_data2_i [2:0],

    // ===== CA <-> RAMC handshake/flags via interface =====
    ca_mem_interface.CA              ca_if
);

// ===================================================================================
//  Signal declerations
// ===================================================================================

    // FSM States
    typedef enum logic [2:0] {
        CA_IDLE,
        CA_LOAD_KERNEL,
        CA_MU,
        CA_DONE
    } ca_state_t;

    ca_state_t curr_state, next_state;

    // ====================
    // Counters / indices / base addresses
    // ====================
    logic [3:0]             kernel_counter,        next_kernel_counter;

    logic [4:0]             wr_counter,            next_wr_counter;
    logic [9:0]             iteration_count,       next_iteration_count;
    logic [`ADDR_WIDTH-1:0] write_base_addr,       next_write_base_addr;

    // ====================
    // MU read addressing / patch window control
    // ====================
    logic                   valid_patch_sig;
    logic                   MU_start_d,            next_MU_start;
    logic                   MU_start_comb;

    // ====================
    // Kernel data (shifter outputs)
    // ====================
    logic [`DATA_WIDTH-1:0] kn_data_ch0 [0:8];
    logic [`DATA_WIDTH-1:0] kn_data_ch1 [0:8];
    logic [`DATA_WIDTH-1:0] kn_data_ch2 [0:8];

    // ====================
    // Handshakes / requests / completion
    // ====================
    logic                   rd_ifm_rq_o_reg,       next_rd_ifm_rq_o;
    logic                   rd_kn_rq_d,            next_rd_kn_rq;
    logic                   CA_finished_d,         next_CA_finished_d;

    // ====================
    // OFM write path (addresses, data, request, result)
    // ====================
    logic [`DATA_WIDTH-1:0] wr_data_ofm_sig;
    logic [`ADDR_WIDTH-1:0] wr_addr_ofm_o_i;
    logic [`ADDR_WIDTH-1:0] wr_addr_ofm_o_MU;
    logic                   wr_rq_CA_o_MU;
    logic [`DATA_WIDTH-1:0] ofm_final;

    // ====================
    // Kernel and shifters
    // ====================
    logic [`ADDR_WIDTH-1:0] kernel_base_addr;
    logic [2:0]             shifter_write;
    logic [`DATA_WIDTH-1:0] shifter_in  [2:0]; // array of 3 elements each 8 bits
    logic [`DATA_WIDTH-1:0] shifter_out [2:0];

    // ======================================================
    // CA <-> RAMC Interface Mapping 
    // ======================================================

    // ---- From RAMC to CA (aliases keep your existing *_i names) ----
    wire rd_ifm_hs_i         = ca_if.rd_ifm_hs;        // RAMC -> CA
    wire rd_knl_hs_i         = ca_if.rd_knl_hs;        // RAMC -> CA
    wire wr_hs_CA_i          = ca_if.wr_hs;            // RAMC -> CA
    wire valid_patch_i       = ca_if.valid_patch;      // RAMC -> CA
    wire all_patches_done_i  = ca_if.all_patches_done; // RAMC -> CA

    // ---- From CA to RAMC (driven by your existing outputs/signals) ----
    assign ca_if.rd_ifm_rq   = rd_ifm_rq_o_reg;            // CA -> RAMC
    assign ca_if.rd_knl_rq   = rd_kn_rq_d;            // CA -> RAMC
    assign ca_if.wr_rq       = wr_rq_CA_o_MU;             // CA -> RAMC

// ===================================================================================
//  Output logic
// ===================================================================================
    
    assign wr_data_ofm_o                     = wr_data_ofm_sig;
    assign wr_addr_ofm_o                     = wr_addr_ofm_o_i;

    // Status / flags
    assign CA_finished                       = next_CA_finished_d;
    assign valid_patch_sig                   = valid_patch_i;


// ===================================================================================
//  Control Path
// ===================================================================================

    always_comb begin

        next_state = curr_state;

        case (curr_state)
            //============================================
            CA_IDLE:
                if (start_CA) begin
                    next_state = CA_LOAD_KERNEL;
                end
            //============================================
            CA_LOAD_KERNEL:
                if (kernel_counter == `KERNEL_DEPTH-1) begin
                    next_state = CA_MU;
                    /*10 cycles as we arent shifting anything on first
                    need to wait for rd_hanshake from ram_ctrl*/
                end
            //============================================
            CA_MU:
                if (all_patches_done_i)
                    next_state = CA_DONE;
            //============================================
            CA_DONE:
                if (CA_clear) begin
                    next_state = CA_IDLE;
                end else begin
                    next_state = CA_DONE;
                end

        endcase
    end
// ===================================================================================
//  Datapath
// ===================================================================================

    always_comb begin

        // ====Defaults========

        next_CA_finished_d      = 1'b0;
        next_rd_ifm_rq_o        = 1'b0; 
        next_MU_start           = MU_start_d; // must hold stable for entire CA operation
        MU_start_comb           = 1'b0;       //used for first cycle to avoid delay
        next_rd_kn_rq           = 1'b0;

        // Data / addresses
        wr_data_ofm_sig        = '0;
        wr_addr_ofm_o_i        = '0;
        next_write_base_addr   = write_base_addr;

        // Counters 
        next_kernel_counter     = kernel_counter;
        next_wr_counter         = wr_counter;
        next_iteration_count    = iteration_count;

        // Shifter control default
        shifter_write           = 3'b000; // all 3 default 0
        shifter_in[0] = '0; shifter_in[1] = '0; shifter_in[2] = '0;


        case (curr_state)
            //============================================
            CA_LOAD_KERNEL: begin
                //load 3 kernels
                
                next_rd_kn_rq =1'b1;
                /*this must remain high as until all values are read from ram
                dropping this early causes ram to exit kernel state*/

                if (rd_knl_hs_i) begin
                    //--------------------
                    if (kernel_counter < `KERNEL_DEPTH-1)
                        next_kernel_counter = kernel_counter + 1;
                    else
                        next_kernel_counter = kernel_counter; // hold at max
                    //--------------------
                end else begin
                    next_kernel_counter = kernel_counter;     // hold when no hs
                end

                //-------------------------------------------
                if (rd_knl_hs_i) begin

                    shifter_write = 3'b111;

                    //TODO:
                    /*which output connects here?*/
                    shifter_in[0] = ifm_data0_i[0]; // use top row
                    shifter_in[1] = ifm_data1_i[0];
                    shifter_in[2] = ifm_data2_i[0];

                end
            end

            //============================================
            CA_MU: begin
                //I dont remember why we needed to delay rd_ifm_rq_o but if we do that then we also need to delay start which will generate the addresses
                next_rd_ifm_rq_o = 1'b1;

                if (rd_ifm_hs_i)begin
                    // since we are already delaying the start handshake must come
                    // 1 clk earlier than output because once start is asserted
                    // patch shifter will try to capture data
                    next_MU_start = 1'b1;
                    MU_start_comb = 1'b1;
                end
                
                //-------------------------------------------
                if (wr_hs_CA_i) begin // combinational handshake, rq already sent by MU
                    next_iteration_count = iteration_count + 1;
                    wr_addr_ofm_o_i      = write_base_addr;
                    wr_data_ofm_sig      = ofm_final;
                    next_write_base_addr = write_base_addr + 1;
                end
            end 

            //============================================
            CA_DONE: begin
                next_CA_finished_d = 1'b1; //TODO: 
                //this is combinational, register it? or is it meant to be on only in this state
                next_write_base_addr    = '0;
                next_iteration_count    = '0;
                next_kernel_counter     = '0;
                next_wr_counter         = '0;
                wr_data_ofm_sig         = 8'd0;
                wr_addr_ofm_o_i         = '0;
                next_MU_start           = 1'b0;

            end
            //============================================

        endcase
    end

// ===================================================================================
//  Register Updates
// ===================================================================================
    always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // FSM state
        curr_state         <= CA_IDLE;
        // Counters and iteration
        kernel_counter     <= 0;
        wr_counter         <= 0;
        iteration_count    <= 0;
        // Address/channel tracking
        write_base_addr    <= 0;
        // Output sum
        rd_ifm_rq_o_reg    <= 1'b0;
        MU_start_d         <= 1'b0;
        rd_kn_rq_d         <= 1'b0;
        CA_finished_d      <= 1'b0;

    //-------------------------------------------------------------
    end else begin
        // FSM state
        curr_state         <= next_state;
        // Counters and iteration
        kernel_counter     <= next_kernel_counter;
        wr_counter         <= next_wr_counter;
        iteration_count    <= next_iteration_count;
        // Address/channel tracking
        write_base_addr    <= next_write_base_addr;
        // Output sum
        rd_ifm_rq_o_reg    <= next_rd_ifm_rq_o;
        MU_start_d         <= next_MU_start;
        rd_kn_rq_d         <= next_rd_kn_rq;
        CA_finished_d      <= next_CA_finished_d;
    end
end
  
// ===================================================================================
//  Instantiations
// ===================================================================================

    MU_full_module mu_module_inst (
        .clk            (clk),
        .rst_n          (rst_n),
        .MU_clear       (CA_clear),
        .MU_start       (MU_start_d || MU_start_comb),
        .valid_patch_MU_i (valid_patch_sig),

        .in_data_ch0    (ifm_data0_i),
        .in_data_ch1    (ifm_data1_i),
        .in_data_ch2    (ifm_data2_i),

        .kn_data_ch0    (kn_data_ch0),
        .kn_data_ch1    (kn_data_ch1),
        .kn_data_ch2    (kn_data_ch2),

        .MU_wr_rq_o     (wr_rq_CA_o_MU),
        .ofm_final      (ofm_final)
    );

    kn_shifter_wrapper kn_shifters (
        .clk              (clk),
        .rst_n            (rst_n),

        .shifter_write    (shifter_write),
        .shifter_in       (shifter_in),

        .shift_reg_out_ch0(kn_data_ch0), //9 elem
        .shift_reg_out_ch1(kn_data_ch1), //9 elem
        .shift_reg_out_ch2(kn_data_ch2)  //9 elem
    );

endmodule
