class apb_coverage_monitor extends uvm_subscriber#(apb_seq_item);
    `uvm_component_utils(apb_coverage_monitor)
    
    // Local variables for coverage sampling (avoids object handle issues)
    // Use int unsigned to avoid coverpoint bin width warnings/overflows
    int unsigned cov_data;
    bit input_data_valid;
    bit state_valid;
    bit reset_value;
    bit reset_valid;
    
    // Mode tracking
    bit is_kernel_mode; // 0 = IFM, 1 = Kernel

    // State definition matching RTL for coverage
    typedef enum logic [2:0] {
        IDLE       = 3'd0,
        WRITE_INIT = 3'd1,
        WRITE      = 3'd2,
        APB_READ   = 3'd3
    } apb_state_e;

    apb_state_e current_state;

    // Covergroup for APB State
    covergroup apb_state_cg;
        STATE: coverpoint current_state iff (state_valid) {
            bins idle       = {IDLE};
            bins write_init = {WRITE_INIT};
            bins write      = {WRITE};
            bins apb_read   = {APB_READ};
        }
        RESET: coverpoint reset_value iff (reset_valid) {
            bins reset = {0};
            bins run   = {1};
        }
        STATE_CROSS: cross STATE, RESET;
    endgroup

    // IFM covergroup
    covergroup ifm_cg;
        DATA: coverpoint cov_data iff (input_data_valid) {
            wildcard bins bit0_passive = { 8'b???????0 };
            wildcard bins bit1_passive = { 8'b??????0? };
            wildcard bins bit2_passive = { 8'b?????0?? };
            wildcard bins bit3_passive = { 8'b????0??? };
            wildcard bins bit4_passive = { 8'b???0???? };
            wildcard bins bit5_passive = { 8'b??0????? };
            wildcard bins bit6_passive = { 8'b?0?????? };
            wildcard bins bit7_passive = { 8'b0??????? };
            wildcard bins bit0_active  = { 8'b???????1 };
            wildcard bins bit1_active  = { 8'b??????1? };
            wildcard bins bit2_active  = { 8'b?????1?? };
            wildcard bins bit3_active  = { 8'b????1??? };
            wildcard bins bit4_active  = { 8'b???1???? };
            wildcard bins bit5_active  = { 8'b??1????? };
            wildcard bins bit6_active  = { 8'b?1?????? };
            wildcard bins bit7_active  = { 8'b1??????? };
        }
    endgroup

    // Kernel covergroup
    covergroup kernel_cg;
        DATA: coverpoint cov_data iff (input_data_valid) {
            wildcard bins bit0_passive = { 8'b???????0 };
            wildcard bins bit1_passive = { 8'b??????0? };
            wildcard bins bit2_passive = { 8'b?????0?? };
            wildcard bins bit3_passive = { 8'b????0??? };
            wildcard bins bit4_passive = { 8'b???0???? };
            wildcard bins bit5_passive = { 8'b??0????? };
            wildcard bins bit6_passive = { 8'b?0?????? };
            wildcard bins bit7_passive = { 8'b0??????? };
            wildcard bins bit0_active  = { 8'b???????1 };
            wildcard bins bit1_active  = { 8'b??????1? };
            wildcard bins bit2_active  = { 8'b?????1?? };
            wildcard bins bit3_active  = { 8'b????1??? };
            wildcard bins bit4_active  = { 8'b???1???? };
            wildcard bins bit5_active  = { 8'b??1????? };
            wildcard bins bit6_active  = { 8'b?1?????? };
            wildcard bins bit7_active  = { 8'b1??????? };
        }
    endgroup
    
    // constructor function
    function new(string name="apb_coverage_monitor", uvm_component parent);
        super.new(name, parent);
        
        // create covergroups
        ifm_cg = new();
        kernel_cg = new();
        apb_state_cg = new();
        is_kernel_mode = 0; // Default to IFM mode
        cov_data = 0;
        input_data_valid = 0;
        state_valid = 0;
        reset_valid = 0;
        reset_value = 1;
        current_state = IDLE;
    endfunction: new

    // analysis port write function
    virtual function void write(apb_seq_item t);
        // Sample IDLE state before processing any transaction
        current_state = IDLE;
        apb_state_cg.sample();

        // State Coverage Sampling
        if (t.op_type == 1) begin // WRITE
            if (t.ADDR == INPUT_MODE_ADDR || t.ADDR == KERNEL_MODE_ADDR) begin
                current_state = WRITE_INIT;
                apb_state_cg.sample();
            end else if (t.ADDR == DATA_ADDR) begin
                current_state = WRITE;
                apb_state_cg.sample();
            end
        end else if (t.op_type == 0) begin // READ
             if (t.ADDR == OUTPUT_ADDR) begin
                 current_state = APB_READ;
                 apb_state_cg.sample();
             end
        end

        // Only process WRITE operations
        if (t.op_type == 1) begin // WRITE
            // Update Mode based on address
            if (t.ADDR == INPUT_MODE_ADDR) begin
                is_kernel_mode = 0;
                `uvm_info("COV_MON", "Switched to IFM Mode", UVM_LOW)
            end else if (t.ADDR == KERNEL_MODE_ADDR) begin
                is_kernel_mode = 1;
                `uvm_info("COV_MON", "Switched to KERNEL Mode", UVM_LOW)
            end 
            // Sample Data based on current mode
            else if (t.ADDR == DATA_ADDR) begin
                // Copy data to local variable for sampling
                cov_data = t.DATA;
                input_data_valid = 1;
                
                if (is_kernel_mode) begin
                    kernel_cg.sample();
                    // `uvm_info("COV_MON", $sformatf("Sampled KERNEL Data: 0x%0h", cov_data), UVM_HIGH)
                end else begin
                    ifm_cg.sample();
                    // `uvm_info("COV_MON", $sformatf("Sampled IFM Data: 0x%0h", cov_data), UVM_HIGH)
                end
                input_data_valid = 0;
            end
        end
    endfunction: write

endclass: apb_coverage_monitor