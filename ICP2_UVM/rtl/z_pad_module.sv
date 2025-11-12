/*
Purpose:
        It produces border addresses (0–899) for the the padding
        border—top row, bottom row, then left and right columns—
        
        asserts write_en while each address is produced, 
        outputs a constant zero data value for those writes, 
        raises padding_done when finished.
*/


// ======================================================
// Zero Padding Generator Module (Serial Write Version)
// ======================================================
`include "conv_defines_pkg.sv"

module z_pad_module (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    clear,
    input  logic                    start_zpad,
    output logic                    write_en,
    output logic [`ADDR_WIDTH-1:0]  ram_addr,
    output logic [`DATA_WIDTH-1:0]  zero,
    output logic                    padding_done
);
    //TODO:
    // revert to using glocal 0-899 add here and pass it through addr conveter instead

    typedef enum logic [2:0] {
        IDLE     = 3'd0,
        TOP_BOT  = 3'd1,
        LEFT     = 3'd2,
        RIGHT    = 3'd3,
        DONE     = 3'd4
    } state_t;

    // =========================================================
    // Signal Declarations
    // =========================================================
    state_t curr_state, next_state;

    localparam int TOP_BOT_COUNTER = 6'd59;   // 30 + 30 - 1
    localparam int SIDE_COUNTER    = 6'd27;   // 28 - 1

    logic [5:0] counter, next_counter;
    logic [5:0] row;                   // 0..29
    logic [5:0] col;                   // 0..29
    logic [`ADDR_WIDTH-1:0] addr_calc;     // 0..899
    logic write_en_d;

    // =========================================================
    // Output Assignments
    // =========================================================
    assign zero         = '0;
    assign ram_addr     = addr_calc;
    assign write_en     = write_en_d;
     // flat address = row*30 + col (30 = 5'b11110)
    assign addr_calc = (row * 10'd30) + col; // 0..899
    assign padding_done = (curr_state == DONE);

    // =========================================================
    // Sequential FSM State Update
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            counter    <= '0;
        end else if (clear == 1'b1) begin
            curr_state <= IDLE;   // soft clear from top
            counter    <= '0;
        end else begin
            curr_state <= next_state;
            counter    <= next_counter;
        end
    end

    // =========================================================
    // Combinational Control Path
    // =========================================================
    always_comb begin
        next_state   = curr_state;

        case (curr_state)

            IDLE: begin
                if (start_zpad) begin
                    next_state   = TOP_BOT;

                end
            end
            //-------------------------
            TOP_BOT: begin
                
                if (counter == TOP_BOT_COUNTER) begin
                    next_state   = LEFT;

                end
            end
            //-------------------------
            LEFT: begin
                //27 since top and bot rows already done
                if (counter == SIDE_COUNTER) begin
                    next_state   = RIGHT;
                end
            end
            //-------------------------
            RIGHT: begin
                if (counter == SIDE_COUNTER)
                    next_state = DONE;
            end
            //-------------------------
            DONE: begin
                if (clear) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: begin
                next_state   = IDLE;
            end
        endcase
    end

    // =========================================================
    // Combinational Datapath and Output Logic
    // =========================================================

    //TODO:
    /*
    we can technically write to 6 rams at once this way:
    i, i+30, i+60, i+90, i+120,i+150 then increment i by 6 do this 5 times

    If top and bottom get serialized = 30
    sizes will be 28/6 = 5 each so 10
    total = 40 cycles

    currently:
            top+bot+sides= 30+30+28+28=118
    
    */
    always_comb begin

        row  = 6'd0;                     
        col  = 6'd0;
        write_en_d  = 1'b0;
        next_counter = counter;

        case (curr_state)

            TOP_BOT: begin

                next_counter = counter + 6'd1;
                write_en_d = 1'b1;

                if (counter == TOP_BOT_COUNTER) begin
                    // do one last addr before resetting (row 29, col 29)
                    row          = 6'd29;
                    col          = 6'd29;
                    next_counter = 6'd0;

                end else if (counter < 6'd30) begin
                    // keep row same increment column
                    row = 6'd0;           // row 0
                    col = counter;        

                end else begin
                    row = 6'd29;          // row 29
                    col = counter - 6'd30; 
                end                     
            end
            //-------------------------
            LEFT: begin

                next_counter = counter + 6'd1;
                write_en_d = 1'b1;
                //------------------
                if (counter == SIDE_COUNTER) begin
                    row = 6'd28;
                    col = 6'd0;
                    next_counter = 6'd0;
                end else begin
                    // keep column same increment row
                    row = counter + 6'd1;     // column 0
                    col = 6'd0; 
                end

            end
            //-------------------------
            RIGHT: begin

                next_counter = counter + 6'd1;
                write_en_d = 1'b1;
                //------------------
                if (counter == SIDE_COUNTER) begin
                    row = 6'd28;
                    col = 6'd29;
                    next_counter = 6'd0;
                end else begin
                    row = counter + 6'd1;     // column 29
                    col = 6'd29; 
                end                             
            end

        endcase


    end




endmodule