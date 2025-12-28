// ===================================================================================
/*  RAM Controller with Zero padding generator

4-bank memory.
Banks 0..2 hold IFM; Bank 3 holds OFM.

- APB write path:
 incoming writes (IFM + W) into banks 0..2,

- Zero padding:
 runs zero-padding after APB writes.

- CA read path:
serves 3-lane IFM reads for sliding 3×3 patches using read_pointer + address converters; asserts rd_ifm_hs_o for one cycle and valid_patch_o per patch until all_patches_done_o.

- Kernel read burst: 
provides 3-bank kernel reads with a 1-cycle rd_kn_hs_o.

- OFM write path:
accepts CA write requests to Bank 3; 

accepts APB reads from read Bank 3 only when CA is finished.*/  
// ===================================================================================

`include "conv_defines_pkg.sv"
`include "ca_mem_interface.sv"

module ram_controller_conv
(
    input  logic                    clk,
    input  logic                    rst_n,

    // Status/control
    input  logic                    CA_finished_i,
    input  logic                    ram_clear,

    // -------- APB side --------
    input  logic                    wr_en_APB_i,
    input  logic [`DATA_WIDTH-1:0]  wr_data_APB_i,
    input  logic [`ADDR_WIDTH-1:0]  wr_addr_APB_i,
    input  logic                    rd_rq_APB_i,
    input  logic [`ADDR_WIDTH-1:0]  rd_apb_addr_i,
    input  logic                    valid_input_APB_i,
    input  logic                    APB_wr_done,
    input  logic [1:0]              channel_ctrl,

    // -------- CA <-> RAMC interface (handshakes/flags) --------
    ca_mem_interface.RAMC           ca_if,   

    // -------- Data paths that are not in the interface --------
    input  logic [`DATA_WIDTH-1:0]  wr_data_ofm_i,
    input  logic [`ADDR_WIDTH-1:0]  wr_addr_ofm_i,

    output logic [`DATA_WIDTH-1:0]  ifm_data0_o [2:0], // top/mid/bot for bank0
    output logic [`DATA_WIDTH-1:0]  ifm_data1_o [2:0], // bank1
    output logic [`DATA_WIDTH-1:0]  ifm_data2_o [2:0], // bank2
    output logic [`DATA_WIDTH-1:0]  ofm_data_o
);
    

// ===================================================================================
//  Signal declerations
// ===================================================================================

    typedef enum logic [2:0] {
        IDLE           = 3'd0,
        WR_INPUT_st    = 3'd1,
        RD_KERNEL_st   = 3'd2,
        WR_ZERO_st     = 3'd3,
        RD_WR_CA_st    = 3'd4
        //WRITE_ofm_state    = 3'd5
    } state_t;

    state_t curr_state, next_state;

    // =====================
    // Handshaking and Delayed Signals
    // =====================
    logic                   rd_ifm_hs_o_d,        next_rd_ifm_hs_o;
    logic                   rd_kn_hs_o_d,         next_rd_kn_hs_o;
    logic                   valid_p_ram,          next_valid_p_ram;
    logic                   all_patches_done_d,   next_all_patches_done;
    logic [2:0]             done_cnt_ram_d,       next_done_cnt_ram;
    logic                   wr_hs_CA_o;
    logic                   pointer_done;
    // =================
    // CA <-> RAMC handshake and flags
    // =================

    // === Requests from CA ===
    wire rd_ifm_req  = ca_if.rd_ifm_rq;   // CA -> RAMC
    wire rd_knl_req  = ca_if.rd_knl_rq;   // CA -> RAMC
    wire wr_req      = ca_if.wr_rq;       // CA -> RAMC

    // === Drive responses/flags back to CA ===
    assign ca_if.rd_ifm_hs        = rd_ifm_hs_o_d;       // RAMC -> CA
    assign ca_if.rd_knl_hs        = rd_kn_hs_o_d;        // RAMC -> CA
    assign ca_if.wr_hs            = wr_hs_CA_o;          // RAMC -> CA
    assign ca_if.valid_patch      = valid_p_ram;         // RAMC -> CA
    assign ca_if.all_patches_done = all_patches_done_d;  // RAMC -> CA

    // =====================
    // Control & State Registers
    // =====================
    logic [7:0]             kn_cnt,               next_kn_cnt;
    logic [1:0]             channel,              next_channel;
    logic [`ADDR_WIDTH-1:0] kn_addr,              next_kn_addr;




    //assign all_patches_done_o = pointer_done;

    // =====================
    // RAM Interface Signals 
    // =====================
    logic [`DATA_WIDTH-1:0]   bank0_input,        bank1_input,       bank2_input;
    logic [`DATA_WIDTH-1:0]   bank3_input;
    logic [`DATA_WIDTH-1:0]   bank0_output_i [2:0];  // 3 outputs per bank
    logic [`DATA_WIDTH-1:0]   bank1_output_i [2:0];
    logic [`DATA_WIDTH-1:0]   bank2_output_i [2:0];
    logic [`DATA_WIDTH-1:0]   bank3_output_i;
    logic                     we_bank0,           we_bank1,          we_bank2,   we_bank3;
    logic                     re_bank0,           re_bank1,          re_bank2,   re_bank3;
    logic [`ADDR_WIDTH-1:0]   addr_bank0,         addr_bank1,        addr_bank2;
    logic [`ADDR_WIDTH-1:0]   addr_bank3;

    // =====================
    // Zero padding
    // =====================    
    logic [`ADDR_WIDTH-1:0]    z_addr_all_banks;
    logic [`ADDR_WIDTH-1:0]    z_addr_out;
    logic                      zp_done;
    logic                      start_zpad_i;
    logic                      zp_write_en;
    logic [`DATA_WIDTH-1:0]    zp_zero;

    // =====================
    // Address Converter
    // =====================
    logic [`RAM_IDX_WIDTH-1:0] ram_index_b3,     ram_index_top, ram_index_mid;
    logic [`RAM_IDX_WIDTH-1:0] ram_index_bot;
    logic [1:0]                addr_mode,        addr_mode_ofm;
    logic [`ADDR_WIDTH-1:0]    general_addr_top, general_addr_mid,  general_addr_bot;
    logic [`ADDR_WIDTH-1:0]    addr_rd_kernel,   shared_addr_to_top;

    logic [`ADDR_WIDTH-1:0]    local_addr_top,    local_addr_mid,   local_addr_bot;
    logic [`ADDR_WIDTH-1:0]    local_addr_b3;  

    // =====================
    // Read pointer
    // =====================
    logic                      valid_p_pointer;
    logic [`ADDR_WIDTH-1:0]    rp_top_addr,      rp_mid_addr,      rp_bot_addr;
    logic                      col_rp_en_d,      next_col_rp_en;
    logic [11:0]               cnt_valid_p,      next_cnt_valid_p;  
    logic [1:0]                cnt_hs_delay,     next_cnt_hs_delay;

// ===================================================================================
//  RAM outputs logic
// ===================================================================================
    always_comb begin

        ifm_data0_o    = bank0_output_i;  // unpacked array copy (3 lanes)
        ifm_data1_o    = bank1_output_i;
        ifm_data2_o    = bank2_output_i;
        ofm_data_o = bank3_output_i;  // scalar
    end

// ===================================================================================
//  Control Path
// ===================================================================================

    always_comb begin
    next_state = curr_state;

        case (curr_state)
            //-------------------------------------
            IDLE: begin
                if (wr_en_APB_i)
                    next_state = WR_INPUT_st;
                else if (rd_knl_req)
                    next_state = RD_KERNEL_st;
                else if (rd_ifm_req)
                    next_state = RD_WR_CA_st;
            end
            //-------------------------------------
            WR_INPUT_st: begin
                if (APB_wr_done)
                    next_state = WR_ZERO_st;
            end
            //-------------------------------------
            WR_ZERO_st: begin
                if (zp_done)
                    next_state = IDLE;
            end
            //-------------------------------------
            RD_KERNEL_st:
                if (!rd_knl_req) begin
                    // if we get into this state early its ok it'll go into idle
                    next_state = IDLE;
                end
            //-------------------------------------
            RD_WR_CA_st: begin
                //TODO:
                /*this state both reads and writes so we cant exit on finishing
                read. We also have to wait for write to finish.*/
                if ((cnt_valid_p == `ITERATION_COUNT) && (!wr_req) ) begin
                    next_state = IDLE;
                end
            end

        endcase
    end
// ===================================================================================
//  Datapath and Output Logic
// ===================================================================================

    always_comb begin
        addr_bank0 = '0; bank0_input = '0; we_bank0 = 1'b0; re_bank0 = 1'b0;
        addr_bank1 = '0; bank1_input = '0; we_bank1 = 1'b0; re_bank1 = 1'b0;
        addr_bank2 = '0; bank2_input = '0; we_bank2 = 1'b0; re_bank2 = 1'b0;
        addr_bank3 = '0; bank3_input = '0; we_bank3 = 1'b0; re_bank3 = 1'b0;


        // --------------------------
        // Counters / addresses
        // --------------------------
        //next_kn_cnt             = 1'b0;
        next_kn_cnt              = kn_cnt;                 //TODO: it was 0
        next_kn_addr             = kn_addr;
        next_channel             = channel;
        next_kn_addr             = kn_addr;
        next_cnt_valid_p         = cnt_valid_p;
        next_cnt_hs_delay        = cnt_hs_delay;

        // --------------------------
        // Control / handshakes
        // --------------------------
        next_rd_ifm_hs_o         = 1'b0;
        wr_hs_CA_o               = 1'b0;
        start_zpad_i             = 1'b0;
        next_valid_p_ram         = 1'b0;
        next_rd_kn_hs_o          = rd_kn_hs_o_d;
        next_col_rp_en           = 1'b0;
        next_done_cnt_ram        = done_cnt_ram_d;
        next_all_patches_done    = 1'b0;

        // General (global) address bridges from CA by default
        general_addr_top         = rp_top_addr;
        general_addr_mid         = rp_mid_addr;
        general_addr_bot         = rp_bot_addr;
        z_addr_all_banks         = '0;

        // ===============================================
        // bank3 APB access: 
        // Once CA operation is over bank3 is directly accessible to APB
        // ===============================================
        if (rd_rq_APB_i == 1'b1 && CA_finished_i == 1'b1) begin
            addr_bank3    = rd_apb_addr_i;       // Externally supplied address
            re_bank3      = 1'b1;                // Assert read enable to bank3
        end

        //=============================================================================
        case (curr_state)
            //-----------------------------------------
            IDLE: begin
                if (wr_en_APB_i) begin
                //TODO: 
                //channel and write_en have to be asserted together
                next_channel      = channel_ctrl;
                end
                //reset counter
                next_cnt_hs_delay  = 0;
                next_cnt_valid_p   = 0;
                next_done_cnt_ram  = 0;
                
            end

            //-----------------------------------------
            WR_INPUT_st: begin
                    //-------------------------
                    // channel choice and timing is taken care of by apb_wrapper
                    if (wr_en_APB_i) begin
                        next_channel = channel_ctrl;
                    end
                    //-------------------------
                    if (valid_input_APB_i) begin
                        //-------------------------
                            if (channel == `CHANNEL_1) begin
                                addr_bank0    = wr_addr_APB_i;
                                bank0_input   = wr_data_APB_i;
                                we_bank0      = 1'b1;
                            //-------------------------
                            end else if (channel == `CHANNEL_2) begin
                                addr_bank1    = wr_addr_APB_i;
                                bank1_input   = wr_data_APB_i;
                                we_bank1      = 1'b1;
                            //-------------------------
                            end else if (channel == `CHANNEL_3) begin
                                addr_bank2    = wr_addr_APB_i;
                                bank2_input   = wr_data_APB_i;
                                we_bank2      = 1'b1;
                            end
                    end
                end
            //-----------------------------------------
            WR_ZERO_st: begin
                //TODO: 
                /* z_addr_all_banks is shared among all banks 
                this is true of all addresses
                what selects bank is choice of index|re|we
                
                This state needs to start CA operation when zeros are padded*/
                start_zpad_i =1'b1;

                    if (zp_write_en) begin
                        // all banks selected
                        we_bank0     = 1'b1;
                        we_bank1     = 1'b1;
                        we_bank2     = 1'b1;

                        //all inputs 0
                        bank0_input  = zp_zero;
                        bank1_input  = zp_zero;
                        bank2_input  = zp_zero;

                        //all banks get this address
                        z_addr_all_banks  = z_addr_out; 
                    end  
            end
            //-----------------------------------------
            RD_KERNEL_st: begin
                    
                    if (rd_knl_req) begin
                        next_rd_kn_hs_o =1'b1;
                        // always gives handshake with one cycle latency regardless of read timing
                    end else begin
                        next_rd_kn_hs_o =1'b0;
                    end

                    //--------------------------
                    // perform read
                    if (rd_knl_req && (kn_cnt < `KERNEL_DEPTH)) begin
                        // read is immediately issued
                        next_kn_cnt  = kn_cnt + 1;
                        next_kn_addr = kn_addr + 1;

                        addr_rd_kernel = kn_addr; //shared
                        re_bank0      = 1'b1;
                        re_bank1      = 1'b1;
                        re_bank2      = 1'b1;
                    end 

                    //--------------------------
                    // once rd_rq is dropped reset these (we also exit state)
                    if (!rd_knl_req) begin
                        next_kn_cnt = 0;
                        next_kn_addr =`KERNEL_BASE_ADDR;
                    end
            end
            //-----------------------------------------
            RD_WR_CA_st: begin

                    // enable pointer
                    //next_col_rp_en =1'b1;
                    
                    // enable handshake delay counter
                    next_cnt_hs_delay = cnt_hs_delay +1;

                    //-------------------------
                    // One-cycle handshake
                    if (cnt_hs_delay == `HS_DELAY) begin
                        next_rd_ifm_hs_o = 1'b1;
                    end else if (cnt_hs_delay > 1) begin
                        // hold counter so it doesnt reset and fire hs again
                        next_cnt_hs_delay = cnt_hs_delay;
                    end 

                    //--------------------------
                    // repeat until all valid patches have been produced
                    if (valid_p_pointer) begin
                        next_cnt_valid_p   = cnt_valid_p +1;
                        next_valid_p_ram = 1'b1; //send delayed version
                    end 

                    //--------------------------
                    /* we disable column to give rams time to push out last output 
                    -2 gives exactly as many addr as we need but 
                    -1 shouldnt hurt it just produces one extra set of addresses*/
                    if (cnt_valid_p < `ITERATION_COUNT+1) begin
                        next_col_rp_en =1'b1;
                    end else begin
                        next_col_rp_en =1'b0;
                        //next_all_patches_done= 1'b1;
                    end

                    //--------------------------
                    if ((cnt_valid_p < `ITERATION_COUNT)&& col_rp_en_d) begin
                    /* enable reads all 3 banks
                       col_en will generate an addr as soon as up so 
                       re must only be asserted when col_en is asserted*/
                        re_bank0   = 1'b1;
                        re_bank1   = 1'b1;
                        re_bank2   = 1'b1;

                        // convert addresses coming from pointer
                        general_addr_top = rp_top_addr;   
                        general_addr_mid = rp_mid_addr;   
                        general_addr_bot = rp_bot_addr;   
  
                    end
                                 
                    // -------------------------
                    // Write to OFM (bank3) if write request active
                    if (wr_req) begin
                        addr_bank3       = wr_addr_ofm_i;
                        bank3_input      = wr_data_ofm_i;
                        we_bank3         = 1'b1;
                        wr_hs_CA_o       = 1'b1;
                    end        

                    if (pointer_done && (done_cnt_ram_d <2) ) begin

                        next_done_cnt_ram = done_cnt_ram_d +1;

                    end else if (done_cnt_ram_d==2) begin
                        next_all_patches_done= 1'b1;
                    end
            end
            //-----------------------------------------
        endcase
    end

// ===================================================================================
//  Sequential Process
// ===================================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // FSM
            curr_state           <= IDLE;
            kn_cnt               <= '0;
            kn_addr              <= `KERNEL_BASE_ADDR;
            rd_ifm_hs_o_d        <= 1'b0;
            rd_kn_hs_o_d         <= 1'b0;
            col_rp_en_d          <= 1'b0;
            valid_p_ram          <= 1'b0;
            channel              <= 2'd0;
            cnt_valid_p          <= '0;
            cnt_hs_delay         <= '0;
            all_patches_done_d   <= 1'b0;
            done_cnt_ram_d       <= 1'b0;   

        end else begin
            // FSM
            curr_state           <= next_state;
            // Kernel addressing
            kn_cnt               <= next_kn_cnt;
            kn_addr              <= next_kn_addr;
            // Handshakes / control
            rd_ifm_hs_o_d        <= next_rd_ifm_hs_o;
            rd_kn_hs_o_d         <= next_rd_kn_hs_o;
            col_rp_en_d          <= next_col_rp_en;
            valid_p_ram          <= next_valid_p_ram;
            // Counters / indices
            channel              <= next_channel;
            cnt_valid_p          <= next_cnt_valid_p;
            cnt_hs_delay         <= next_cnt_hs_delay;
            // Completion
            all_patches_done_d   <= next_all_patches_done;
            done_cnt_ram_d       <= next_done_cnt_ram;
        end
    end

// ===================================================================================
//  Address converter logic 
// ===================================================================================
    always_comb begin

        addr_mode_ofm = `OFM_MODE; //always same

        case (curr_state)

            WR_INPUT_st : addr_mode = `APB_WR_MODE;
            //--------------------          
            RD_KERNEL_st: addr_mode = `APB_WR_MODE;
            //--------------------
            RD_WR_CA_st : addr_mode = `FULL_IFM_MODE;
            //--------------------
            WR_ZERO_st  : addr_mode = `FULL_IFM_MODE;
            //--------------------
            default     : addr_mode = `APB_WR_MODE;
        endcase
    end

    //------------------------------------------
    always_comb begin

        /*this is a mux it assigns top addr normally except in the other mentioned states in the mux where it takes addr from apb instead*/
        shared_addr_to_top = general_addr_top; // normal MU path from CA

        //TODO
        // this was from when i used a single addr converter for all channels since they shared addresses
        case (curr_state)
            WR_INPUT_st: begin
                case (channel)
                    2'd0: shared_addr_to_top = addr_bank0;
                    2'd1: shared_addr_to_top = addr_bank1;
                    2'd2: shared_addr_to_top = addr_bank2;
                    default: ; // Do nothing
                endcase
            end

            RD_KERNEL_st: begin
                shared_addr_to_top = addr_rd_kernel; // Shared
            end

            WR_ZERO_st: begin
                shared_addr_to_top = z_addr_all_banks; // Shared
            end

        endcase
    end

// ===================================================================================
//  Component instantiations
// ===================================================================================

    // Address converters (top/mid/bot and reused in some states)
    addr_conv_wrapper addr_conv_top (
        .global_addr (shared_addr_to_top),
        .local_addr  (local_addr_top),
        .mode        (addr_mode),
        .ram_index   (ram_index_top)
    );

    addr_conv_wrapper addr_conv_mid (
        .global_addr (general_addr_mid),
        .local_addr  (local_addr_mid),
        .mode        (addr_mode),
        .ram_index   (ram_index_mid)
    );

    addr_conv_wrapper addr_conv_bot (
        .global_addr (general_addr_bot),
        .local_addr  (local_addr_bot),
        .mode        (addr_mode),
        .ram_index   (ram_index_bot)
    );

    addr_conv_wrapper addr_conv_ofm (
        .global_addr  (addr_bank3),
        .local_addr   (local_addr_b3),
        .mode         (addr_mode_ofm),
        .ram_index    (ram_index_b3)
    );
    //-------------------------------
    z_pad_module zero_pad_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .clear       (ram_clear),
        .start_zpad  (start_zpad_i ),
        .write_en    (zp_write_en),
        .ram_addr    (z_addr_out),
        .zero        (zp_zero),
        .padding_done(zp_done)
    );
    //-------------------------------
    // padded global addresses for top/mid/bot rows
    read_pointer read_ptr_inst (
        .clk              (clk),
        .rst_n            (rst_n),
        .clear            (ram_clear),
        .col_rd_en        (col_rp_en_d),
        .valid_p_pointer  (valid_p_pointer),
        .pointer_done (pointer_done),

        .addr_top   (rp_top_addr),
        .addr_mid   (rp_mid_addr),
        .addr_bot   (rp_bot_addr)
    );

    //-------------------------------
    memory_module mem_inst (
        .clk             (clk),
        .rst_n           (rst_n),

        .ram_index_b3    (ram_index_b3), 
        .local_addr_b3   (local_addr_b3),

        .ram_index_top   (ram_index_top),
        .ram_index_mid   (ram_index_mid),
        .ram_index_bot   (ram_index_bot),

        .rd_addr_top     (local_addr_top), 
        .rd_addr_mid     (local_addr_mid),
        .rd_addr_bot     (local_addr_bot),

        .we_bank         ({we_bank3, we_bank2, we_bank1, we_bank0}),
        .re_bank         ({re_bank3, re_bank2, re_bank1, re_bank0}),

        .bank_din        ({bank3_input, bank2_input, bank1_input, bank0_input}),

        .chan0_A_out_top_mid_bot   (bank0_output_i),  // 3 outputs
        .chan1_A_out_top_mid_bot   (bank1_output_i),
        .chan2_A_out_top_mid_bot   (bank2_output_i),
        .bank3_out       (bank3_output_i)
    );

endmodule
