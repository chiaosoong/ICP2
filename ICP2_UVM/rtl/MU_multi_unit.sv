
`include "conv_defines_pkg.sv"

// ======================================================
// MU_mul9_sat: 9× (patch * kernel) with per-product saturation to 8 bits
// ======================================================
module MU_multi_unit
(
    input  logic                   MU_en,
    input  logic [`DATA_WIDTH-1:0] patch  [0:8],   // 9 patch values (8-bit)  // inputs
    input  logic [`DATA_WIDTH-1:0] kernel [0:8],   // 9 kernel values (8-bit) // inputs
    output logic [`DATA_WIDTH-1:0] prod_sat[0:8]   // 9 saturated products    // outputs
);

    localparam int PROD_W = 2*`DATA_WIDTH; // 16 for 8-bit
    logic [PROD_W-1:0] raw_prod [0:8];
    integer i;

    always_comb begin
        for (i = 0; i < 9; i = i + 1) begin
            if (MU_en) begin
                raw_prod[i] = patch[i] * kernel[i];                  // 8×8→16
                if (|raw_prod[i][PROD_W-1:`DATA_WIDTH])              // any upper bits set?
                    prod_sat[i] = {`DATA_WIDTH{1'b1}};               // 255
                else
                    prod_sat[i] = raw_prod[i][`DATA_WIDTH-1:0];      // exact (≤255)
            end else begin
                raw_prod[i] = '0;
                prod_sat[i] = '0;                                    // outputs forced to 0
            end
        end
    end

endmodule