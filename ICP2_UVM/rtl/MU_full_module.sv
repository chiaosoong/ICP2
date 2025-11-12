

`include "conv_defines_pkg.sv"
// ======================================================
// the_MU_unit
// Reads IFM patch, uses patch shifters and kernel shifters
// Triggers MU when patch is valid
// ======================================================

module MU_full_module #(
)( 
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   MU_clear,
    input  logic                   MU_start,
    input  logic                   valid_patch_MU_i,
    
    // IFM data from RAM controller (latched on handshake)
    input  logic [`DATA_WIDTH-1:0] in_data_ch0 [2:0],  // top, mid, bot
    input  logic [`DATA_WIDTH-1:0] in_data_ch1 [2:0],
    input  logic [`DATA_WIDTH-1:0] in_data_ch2 [2:0],

    // Kernel shifter outputs
    input  logic [`DATA_WIDTH-1:0] kn_data_ch0 [0:8],
    input  logic [`DATA_WIDTH-1:0] kn_data_ch1 [0:8],
    input  logic [`DATA_WIDTH-1:0] kn_data_ch2 [0:8],

    // Final OFM output
    output logic                   MU_wr_rq_o,
    output logic [`DATA_WIDTH-1:0] ofm_final
);

    logic MU_en; 

    logic                   ifm_shift_en;

    logic [`DATA_WIDTH-1:0] data0_into_patch [2:0];
    logic [`DATA_WIDTH-1:0] data1_into_patch [2:0];
    logic [`DATA_WIDTH-1:0] data2_into_patch [2:0];

    // --- Wires from patch shifter (3×9) ---
    logic [`DATA_WIDTH-1:0] data_patch_out0 [0:8];
    logic [`DATA_WIDTH-1:0] data_patch_out1 [0:8];
    logic [`DATA_WIDTH-1:0] data_patch_out2 [0:8];

    typedef logic [`DATA_WIDTH-1:0] mu_array_t [0:`NUM_MU_ACTIVE-1][0:8];
    mu_array_t patch_2d;
    mu_array_t kernel_2d;

    logic [`DATA_WIDTH-1:0] prod_sat_c [0:2][0:8]; 

    logic                   valid_patch_MU_d;       // 1-cycle delayed valid
    logic                   valid_p1_r;             // stage-1 valid
    logic [`DATA_WIDTH-1:0] prod_sat_p1 [0:2][0:8]; // 27 pipelined products

    integer c, t;

    logic [`DATA_WIDTH-1:0] ofm_final_c; 
    logic [`DATA_WIDTH-1:0] ofm_final_reg, next_ofm_final;
    logic                   MU_wr_rq_reg,  next_MU_wr_rq;
// ===================================================================================
// Patch shifter stage
// ===================================================================================


    always_comb begin

        ifm_shift_en     = 1'b0; 
        /*data0_into_patch = '0;             
            ...
        Wrong default assignment: a packed bus to an unpacked array*/
        data0_into_patch   = '{default:'0};
        data1_into_patch   = '{default:'0};
        data2_into_patch   = '{default:'0};

        if (MU_start) begin
            ifm_shift_en = 1'b1; // start shifting
            //these are the 9 values that arrive from ram

            //start shifting in values into patch shifter
            data0_into_patch = in_data_ch0; //3 values
            data1_into_patch = in_data_ch1; //3 values    
            data2_into_patch = in_data_ch2; //3 values
        end
    end
    //----------------------------------
    patch_shifter_wrapper patch_shifter_wrap (
        .clk       (clk),
        .rst_n     (rst_n),
        .ifm_sh_en (ifm_shift_en),
        .ifm0_in   (data0_into_patch),
        .ifm1_in   (data1_into_patch),
        .ifm2_in   (data2_into_patch),
        .patch_out0(data_patch_out0),  // 9 elems
        .patch_out1(data_patch_out1),  // 9 elems
        .patch_out2(data_patch_out2)   // 9 elems
    );
    //----------------------------------


    genvar i;
    generate
        for (i = 0; i < 9; i++) begin : PACK_2D
            // patch: channel 0/1/2 for position i
            assign patch_2d[0][i] = data_patch_out0[i];
            assign patch_2d[1][i] = data_patch_out1[i];
            assign patch_2d[2][i] = data_patch_out2[i];

            // kernel: channel 0/1/2 for position i
            assign kernel_2d[0][i]  = kn_data_ch0[i];
            assign kernel_2d[1][i]  = kn_data_ch1[i];
            assign kernel_2d[2][i]  = kn_data_ch2[i];

        /*assign kernel_2d[i][0] = 8'd1;
            //TODO:Remember order of indices*/
        end
    endgenerate


// ===================================================================================
// Multiply stage
// ===================================================================================



    MU_multi_wrapper u_MU_multi (
        .MU_en          (MU_en),
        .patch_array    (patch_2d),
        .kernel_array   (kernel_2d),
        .prod_sat       (prod_sat_c)
   ); 


// ===================================================================================
// Pipeline register stage
// ===================================================================================


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            valid_patch_MU_d <= 1'b0;
            valid_p1_r       <= 1'b0;

            for (c = 0; c < 3; c = c + 1)
                for (t = 0; t < 9; t = t + 1)
                    prod_sat_p1[c][t] <= '0;

        //--------------------------------            
        end else if (MU_clear) begin

            valid_patch_MU_d <= 1'b0;
            valid_p1_r       <= 1'b0;

            for (c = 0; c < 3; c = c + 1)
                for (t = 0; t < 9; t = t + 1)
                    prod_sat_p1[c][t] <= '0;

        //--------------------------------
        end else begin
            // clk0→clk1 valid alignment
            valid_patch_MU_d <= valid_patch_MU_i;

            // capture 27 comb products at clk1
            if (valid_patch_MU_d) begin
                for (c = 0; c < 3; c = c + 1)
                    for (t = 0; t < 9; t = t + 1)
                        prod_sat_p1[c][t] <= prod_sat_c[c][t];
                valid_p1_r <= 1'b1;
                //------------------
            end else begin
                valid_p1_r <= 1'b0;
            end
        //--------------------------------
        end
    end

// ===================================================================================
// Summer stage after pipline
// ===================================================================================


    MU_summer_wrapper u_MU_summer (
        .prod_sat       (prod_sat_p1),
        .ofm            (ofm_final_c)
   );

// ===================================================================================
// Output stage
// ===================================================================================


    always_comb begin
        next_ofm_final = ofm_final_reg;     // hold by default
        next_MU_wr_rq  = 1'b0;

        if (valid_p1_r) begin               // 2nd stage fires when stage-1 valid
            next_ofm_final = ofm_final_c;
            next_MU_wr_rq  = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            ofm_final_reg <= '0;
            MU_wr_rq_reg  <= 1'b0;
        //------------------------
        end else if (MU_clear) begin
            ofm_final_reg <= '0;
            MU_wr_rq_reg  <= 1'b0;
        //------------------------
        end else begin
            ofm_final_reg <= next_ofm_final;
            MU_wr_rq_reg  <= next_MU_wr_rq;
        end
    end

    assign ofm_final = ofm_final_reg;
    assign MU_wr_rq_o = MU_wr_rq_reg;

    always_comb begin
        
        MU_en             = 1'b0;

        /*Valid is already delayed once to match ram output latency but it has to be delyed once again here since we are now pushing data into new registers on the clock not combinationally*/
        //------------------------------
        if (valid_patch_MU_d) begin
            /*if valid patch goes up due to bug like after CA is finished we 
              will make bogus wr_rq here*/
            MU_en = 1'b1; 
        end
        //------------------------------
    end
endmodule

/*Shift in the 3 new values evey cycle as they arrive

once valid patch is asserted we have a full window --> enable MU

MU will:
        - compute all 9 multiplications in one cycle 
        - for all 3 channels
        - and add them up producing an ofm pixel

Then:
        - Send read request 
          together with data


The MU unit will combinationally calculate the patch and try to write to the RAM. At the same time.

This is OK because we are writing to a different RAM. As long as the calculations are done by the end of the clock cycles. 

when outputs arrive they first have to go to patch shifter to create a full patch
then when valid patch is asserted by pointer patch will be connected to MU and MU enabled

the patch unit has 27 outputs which will connect to MU units
kernels are not shared among channels  there is also 27 kernel values

9 values are read from the ram each cycle (3 from each bank for the 3 channels)


//TODO: new
/*
.patch_in_MU[0](patch_in_MU[0])  // wrong
And expected:
A port literally named patch_in_MU[0] (which is not valid)
Or a complete array port called patch_in_MU, not indexed



Current pipeline:
Registers inside the shifters,

One big combo block for 27 multiplies + add + saturation,
    (this needs to break up)

One output register.   

we break it into this:
Shifter outputs (8-bit) + kernel taps (8-bit)
   │
   ├─► 27 multipliers (8×8 → 16 bits)
   │
   └─► 27 saturators (truncate/saturate to 8 bits)
                │
                └─► [REGISTER 27 products, 8 bits each]   <-- pipeline cut
                           │
                           └─► 3 summers (each adds 9x8-bit)
                                      │
                                      └─► 3→1 add (10–12 bits wide) + saturate
                                                 │
                                                 └─► [REGISTER final OFM + wr_rq]


*/