`include "conv_defines_pkg.sv"

module kn_shifter_unit (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         shifter_write,        // Shift left and insert at tail
    input  logic [`DATA_WIDTH-1:0]       shifter_in,           // Value to load

    output logic [`DATA_WIDTH-1:0]       shift_reg_out [0:8]   // All 9 internal values exposed
);


    logic [`DATA_WIDTH-1:0] shift_reg      [0:`KERNEL_DEPTH-1];
    logic [`DATA_WIDTH-1:0] shift_reg_next [0:`KERNEL_DEPTH-1];

    // ===================================================================================
    //  register updates
    // ===================================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < `KERNEL_DEPTH; i++) begin
                shift_reg[i] <= '0;
            end
        end else if (shifter_write) begin
            for (int i = 0; i < `KERNEL_DEPTH; i++) begin
                shift_reg[i] <= shift_reg_next[i];
            end
        end
        // else: hold current values (no unnecessary toggling)
    end

    // ===================================================================================
    //  Write logic
    // ===================================================================================
    always_comb begin
        // Default: hold current state
        for (int i = 0; i < `KERNEL_DEPTH; i++) begin
            shift_reg_next[i] = shift_reg[i];
        end

        // Shift left, insert at tail
        if (shifter_write) begin
            shift_reg_next[0] = shift_reg[1];
            shift_reg_next[1] = shift_reg[2];
            shift_reg_next[2] = shift_reg[3];
            shift_reg_next[3] = shift_reg[4];
            shift_reg_next[4] = shift_reg[5];
            shift_reg_next[5] = shift_reg[6];
            shift_reg_next[6] = shift_reg[7];
            shift_reg_next[7] = shift_reg[8];
            shift_reg_next[8] = shifter_in;
        end
    end

    // ===================================================================================
    //  output logic - all 9 exposed
    // ===================================================================================
    always_comb begin
        for (int i = 0; i < `KERNEL_DEPTH; i++) begin
            shift_reg_out[i] = shift_reg[i];
        end
    end

endmodule

/*
The shifter is only used to preload 9 kernel values.
After loading (via rotation write), the values remain fixed throughout the CA's operation.
During compute, you need all 9 kernel values at once, not one at a time.
Their ordering is fixed, so indexed access (rd_addr) is redundant.*/