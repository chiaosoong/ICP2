class apb_coverage_monitor extends uvm_subscriber#(apb_seq_item);
    `uvm_component_utils(apb_coverage_monitor)
    
    // Local variables for coverage sampling (avoids object handle issues)
    // Use int unsigned to avoid coverpoint bin width warnings/overflows
    int unsigned cov_data;
    
    // Mode tracking
    bit is_kernel_mode; // 0 = IFM, 1 = Kernel

    // IFM covergroup
    covergroup ifm_cg;
        DATA: coverpoint cov_data {
            bins low_val_data = {[0 : 63]};
            bins mid_val_data = {[64 : 127]};
            bins mid_high_val_data = {[128 : 191]};
            bins high_val_data = {[192 : 255]};
        }
    endgroup

    // Kernel covergroup
    covergroup kernel_cg;
        DATA: coverpoint cov_data {
            bins low_val_data = {[0 : 63]};
            bins mid_val_data = {[64 : 127]};
            bins mid_high_val_data = {[128 : 191]};
            bins high_val_data = {[192 : 255]};
        }
    endgroup
    
    // constructor function
    function new(string name="apb_coverage_monitor", uvm_component parent);
        super.new(name, parent);
        
        // create covergroups
        ifm_cg = new();
        kernel_cg = new();
        is_kernel_mode = 0; // Default to IFM mode
        cov_data = 0;
    endfunction: new

    // analysis port write function
    virtual function void write(apb_seq_item t);
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
                
                if (is_kernel_mode) begin
                    kernel_cg.sample();
                    // `uvm_info("COV_MON", $sformatf("Sampled KERNEL Data: 0x%0h", cov_data), UVM_HIGH)
                end else begin
                    ifm_cg.sample();
                    // `uvm_info("COV_MON", $sformatf("Sampled IFM Data: 0x%0h", cov_data), UVM_HIGH)
                end
            end
        end
    endfunction: write

endclass: apb_coverage_monitor