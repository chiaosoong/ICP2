// ======================================================
// APB Wrapper 
// ======================================================

`include "conv_defines_pkg.sv"

module apb_convolution #(
    parameter RAM_SIZE   = 1024,
    parameter ADDR_WIDTH = $clog2(RAM_SIZE),
    parameter DATA_WIDTH = 8
)(
    input  logic                  HCLK,
    input  logic                  HRESETn,
    input  logic                  PSEL,
    input  logic                  PENABLE,
    input  logic                  PWRITE,
    input  logic [11:0]           PADDR,
    input  logic [31:0]           PWDATA,
    output logic [31:0]           PRDATA,
    output logic                  PREADY,
    output logic                  PSLVERR
);

    // ------------------------
    // Internal FSM Declaration
    // ------------------------
    typedef enum logic [2:0] {
        IDLE,
        WRITE_INIT,
        WRITE,
        APB_READ
    } apb_state_t;

    apb_state_t state, next_state;

    // TODO:
    /* Addr must be 12 bits from outside but we only use 10 bits PADDR [11:2]*/

    // ------------------------
    // Internal Register Declarations
    // ------------------------
    logic [DATA_WIDTH-1:0] wr_data_reg, next_wr_data;
    logic [ADDR_WIDTH-1:0] rd_burst_addr_reg, next_rd_burst_addr;


    logic [ADDR_WIDTH-1:0] read_counter, next_read_counter;
    logic enable_ram4, next_enable_ram4;

    logic [ADDR_WIDTH-1:0] rd_addr_to_ram;

    logic data_latched, next_data_latched;
    
    logic input_mode, next_input_mode;
    logic input_cmd, next_input_cmd;

    logic kernel_mode, next_kernel_mode;
    logic kernel_cmd, next_kernel_cmd;

    //logic read_mode, next_read_mode;
    logic read_cmd, next_read_cmd;
    
    logic burst_rd_cmd, next_burst_rd_cmd;

    logic [1:0] rd_en_counter, next_rd_en_counter;

    logic [11:0] wr_counter, next_wr_counter;
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [1:0] wr_channel;

    logic valid_input_APB;
    logic write_en_APB;
    logic APB_wr_done;

    logic [DATA_WIDTH-1:0] top_output;
    logic CA_finished;

    logic sw_wr_cmd; 
    assign sw_wr_cmd = (PSEL && PENABLE && PWRITE);

    logic ry_ram4;
    logic APB_ready_delayed, next_APB_ready_delayed;


    logic sw_rd_init; 
    assign sw_rd_init = (PSEL && PENABLE && !PWRITE);
    
    logic waiting_for_ram4, next_waiting_for_ram4;

    logic sw_read_done;
    assign sw_read_done = (PSEL && PENABLE && !PWRITE && PREADY);

    logic all_read_done, next_all_read_done;
    logic clear, next_clear;

    /* In APB, the master latches PRDATA only when PREADY = 1 during the access phase
    */

    logic data_write_pulse;
    assign data_write_pulse = (sw_wr_cmd && (PADDR[11:2] == 10'h000));

    // ======================================================
    // Sequential Process: Register Update ONLY
    // ======================================================
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            wr_data_reg     <= 0;
            wr_counter      <= 0;
            input_mode      <= 0;
            kernel_mode     <= 0;
            state           <= IDLE;
            data_latched    <= 0;
            read_counter    <= 0;
            enable_ram4      <= 0;
            burst_rd_cmd    <= 0;

            input_cmd       <= 0;
            kernel_cmd      <= 0;
            read_cmd        <= 0;
            waiting_for_ram4 <= 0;
            all_read_done    <= 0;
            clear     <=0;
            rd_en_counter    <=0;
            APB_ready_delayed <= 1'b0;

        end else begin
            wr_data_reg     <= next_wr_data;
            rd_burst_addr_reg<= next_rd_burst_addr;
            wr_counter      <= next_wr_counter;
            input_mode      <= next_input_mode;
            kernel_mode     <= next_kernel_mode;
            state           <= next_state;
            data_latched    <= next_data_latched;
            read_counter    <= next_read_counter;
            enable_ram4     <= next_enable_ram4;
            burst_rd_cmd    <= next_burst_rd_cmd;
            waiting_for_ram4 <= next_waiting_for_ram4;
            rd_en_counter   <= next_rd_en_counter;
            input_cmd       <= next_input_cmd;
            kernel_cmd      <= next_kernel_cmd;
            read_cmd        <= next_read_cmd;
            all_read_done   <= next_all_read_done;
            clear    <= next_clear;
            APB_ready_delayed <= next_APB_ready_delayed;
        end
    end

    // ======================================================
    // APB Writes
    // ======================================================
    always_comb begin
        next_wr_data     = wr_data_reg;
        
        next_input_mode   = input_mode;
        next_input_cmd = 0;

        next_kernel_mode   = kernel_mode ;
        next_kernel_cmd = 0;

        next_read_cmd = 0;

        next_burst_rd_cmd   = 0;

        /*software wrote somthing at one of the registers (pushed all 3 buttons).
        check address (cases) to see which register it was*/
        if (sw_wr_cmd) begin
            case (PADDR[11:2])
                //------------------------------------
                10'h000: begin // case: data reg
                    /*10'h000	0	0 × 4 = 0   → 0x000*/
                    next_wr_data     = PWDATA[7:0];

                end
                //------------------------------------
                10'h002: begin  // input_mode
                    /*10'h002	2	2 × 4 = 8   → 0x008*/
                    next_input_mode     = 1;
                    next_kernel_mode    = 0;
                    //next_read_mode      = 0;
                    next_input_cmd      = 1;
                end
                //------------------------------------
                10'h003: begin  // kernel_mode
                    /*10'h003	3	3 × 4 = 12  → 0x00C*/
                    next_input_mode     = 0;
                    next_kernel_mode    = 1;
                    //next_read_mode      = 0;
                    next_kernel_cmd     = 1;
                end
                //------------------------------------
                10'h008: begin 
                    /*10'h008	8	8 × 4 = 32  → 0x020*/
                    next_burst_rd_cmd = PWDATA[0];
                    next_input_mode     = 0;
                    next_kernel_mode    = 0;
                    //next_read_mode      = 0;
                end
                //------------------------------------
            endcase
        end
    end

    // ======================================================
    // APB Slave Output Logic
    // - PREADY asserted only when data is ready for read
    // - For write: slave doesn't stall, completes in 1 cycle
    // ======================================================
    always_comb begin
        PRDATA  = 32'd0;
        PREADY  = 1'b0;
        PSLVERR = 1'b0;

        // Read from controller RAM (RAM4)
        case (PADDR[11:2])

            // --------------------------------------------
            10'h005: begin // Output register
                if (APB_ready_delayed) begin
                    PRDATA = {24'd0, top_output};
                    PREADY = 1'b1; // valid regardless of sw_rd_init
                end
            end

            // --------------------------------------------
            10'h006: begin // CA finished
                if (sw_rd_init) begin
                    PRDATA = {31'd0, CA_finished};
                    PREADY = 1'b1;
                end
            end

            // --------------------------------------------
            10'h007: begin // all_read_done
                if (sw_rd_init) begin
                    PRDATA = {31'd0, all_read_done};
                    PREADY = 1'b1;
                end
            end

            // --------------------------------------------
            default: begin
                if (sw_rd_init) begin
                    PRDATA  = 32'd0;
                    PSLVERR = 1'b1;
                    PREADY  = 1'b1;
                end
            end
        endcase

        // ------------------------------
        if (sw_wr_cmd) begin
            PREADY = 1'b1; // all writes complete in 1 cycle
        end
    end
    // ======================================================
    // FSM Next State Logic
    // ======================================================
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if      (input_cmd || kernel_cmd)
                        next_state = WRITE_INIT;

                else if (burst_rd_cmd && CA_finished)
                        next_state = APB_READ;
                
            end
            //----------------------------------
            WRITE_INIT: begin
                next_state = WRITE; 
            end
            //----------------------------------
            WRITE: begin
                if ((input_mode && wr_counter == 12'd2352) ||
                    (kernel_mode && wr_counter == 12'd26 && data_latched)) begin
                    next_state = IDLE;
                end
            end
            //----------------------------------
            APB_READ: begin
                if (all_read_done)
                    next_state = IDLE;
            end
            //----------------------------------
            default: next_state = IDLE;
        endcase
    end

    // ======================================================
    // Address and Channel Generation
    // ======================================================
    always_comb begin
            
            wr_addr    = {ADDR_WIDTH{1'b0}}; // Default address

            if (input_mode == 1'b1) begin
                wr_addr = wr_counter % 784;

            end else if (kernel_mode == 1'b1) begin
                wr_addr = (wr_counter % 9) + 784; // Kernel address offset
            end
    end

    // ======================================================
    // Combinational Datapath Logic
    // ======================================================
    always_comb begin
        // Default values
        valid_input_APB     = 0;
        write_en_APB        = 0;
        APB_wr_done           = 0;
        next_wr_counter     = wr_counter;
        next_data_latched   = data_latched;
        next_rd_burst_addr  = rd_burst_addr_reg;
        next_read_counter   = read_counter;
        next_enable_ram4     = 0;
        wr_channel          = 2'd0;
        next_waiting_for_ram4 = waiting_for_ram4;
        next_all_read_done = all_read_done;
        next_clear  = 1'b0;
        next_APB_ready_delayed = APB_ready_delayed;
        next_rd_en_counter = rd_en_counter;

        
        // read address
        //rd_addr_to_ram = (state == APB_READ) ? rd_burst_addr_reg : rd_addr_single;
        rd_addr_to_ram = rd_burst_addr_reg;

        case (state)

            IDLE: begin 
                next_wr_counter    = 0;
                next_data_latched  = 0;
                next_read_counter  = 0;

                //TODO: if we want to reset CA before read
                /*if (burst_rd_cmd && CA_finished) begin
                    next_clear  = 1'b1;
                end*/

            end
            //-----------------------------
            WRITE_INIT: begin

                wr_channel   = 2'd0;
                write_en_APB = 1'b1; // assert write_en and channel only    
      
                next_all_read_done = 0;
            end
            //-----------------------------
            WRITE: begin
                        
                if (data_write_pulse && !data_latched) begin
                    next_data_latched = 1'b1;
                end

                if (data_latched) begin 

                        next_data_latched  = 0;
                        valid_input_APB = 1'b1;

                        next_wr_counter = wr_counter + 1;

                        if (input_mode == 1'b1) begin
                                //TODO:
                            /* we need to change channel on the last data of each channel not on the first data of new 
                            channel. Also change these to be scalable rn they are hardcoded*/
                                //------------------------------------
                                if (wr_counter == 12'd783) begin
                                    wr_channel      = 2'd1;
                                    write_en_APB    = 1'b1;
                                //------------------------------------
                                end else if (wr_counter == 12'd1567) begin
                                    wr_channel      = 2'd2;
                                    write_en_APB    = 1'b1;
                                end  
                        //------------------------------------                      
                        end else if (kernel_mode == 1'b1) begin
                                //------------------------------------
                                if (wr_counter == 12'd8) begin
                                    wr_channel      = 2'd1;
                                    write_en_APB    = 1'b1;
                                //------------------------------------
                                end else if (wr_counter == 12'd17) begin
                                    wr_channel      = 2'd2;
                                    write_en_APB    = 1'b1;
                                end 
                        //------------------------------------
                        if (wr_counter + 1 == 12'd27) begin
                            APB_wr_done = 1'b1;
                        end
                        end
                    end
                end
            
            //-----------------------------
            APB_READ: begin
                if (read_counter < 10'd784) begin
                        
                        if (rd_en_counter== 2) begin
                            next_APB_ready_delayed= 1;
                        end

                        if (waiting_for_ram4) begin
                            next_enable_ram4 = 1;   
                            next_rd_burst_addr = read_counter; 
                            next_rd_en_counter = rd_en_counter +1;

                        end else if (sw_rd_init) begin
                            next_waiting_for_ram4 = 1;
                            //next_enable_ram4 = 1; 
                        end                      

                        if (sw_read_done) begin
                                // set read addr
                                // incr addr and counter
                            next_read_counter = read_counter + 1; 
                            // assert read mode to ram controller
                            next_waiting_for_ram4 = 0;
                            next_APB_ready_delayed= 0;
                            next_rd_en_counter =0;
                        end

                end else begin
                    next_read_counter = 0;
                    next_all_read_done = 1'b1;
                    next_clear  = 1'b1;
                    
                end
            end
            //-----------------------------
            default: begin
                // Do nothing in IDLE
            end
        endcase
    end

    // ======================================================
    // Inst top_file_convolution
    // ======================================================
    top_file_convolution u_top (
        .clk                (HCLK),
        .rst_n              (HRESETn),
        .APB_wr_done        (APB_wr_done),
        .channel_top        (wr_channel),
        .write_en_APB       (write_en_APB),
        .valid_input_APB    (valid_input_APB),
        .write_addr_APB     (wr_addr),
        .write_data_APB     (wr_data_reg),
        .ry_APB             (ry_ram4),
        .read_APB_data_top  (top_output),
        .read_cmd_APB_top   (enable_ram4),
        .read_apb_addr_top  (rd_addr_to_ram),
        .CA_finished        (CA_finished),
        .top_clear       (clear)
    );

endmodule



