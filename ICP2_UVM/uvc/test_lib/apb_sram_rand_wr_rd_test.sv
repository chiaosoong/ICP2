class apb_sram_rand_wr_rd_test extends apb_base_test;
    `uvm_component_utils(apb_sram_rand_wr_rd_test)

    // constructor function
    function new(string name="apb_sram_rand_wr_rd_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction: new
    
    // build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction: build_phase
    
    // connect_phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction: connect_phase
    
    // run_phase
    virtual task run_phase(uvm_phase phase);
        int unsigned IFM_TOTAL = 3*784; // number of IFM writes
        int unsigned KER_TOTAL = 3*9;   // number of kernel writes

        super.run_phase(phase);
        phase.raise_objection(this);
        // Use base test helper `wr_data_2_mem` to perform random ifm and kernel writes
        // 1) Set Input Mode
        wr_data_2_mem(.addr(INPUT_MODE_ADDR), .data(1), .rand_addr(0), .rand_data(0));
        // 2) Write IFM
        for (int unsigned i = 0; i < IFM_TOTAL; i++) begin
            wr_data_2_mem(.addr(DATA_ADDR), .data('0), .rand_addr(0), .rand_data(1));
        end
        // 3) Set Kernel Mode
        wr_data_2_mem(.addr(KERNEL_MODE_ADDR), .data(1), .rand_addr(0), .rand_data(0));
        // 4) Write Kernel
        for (int unsigned k = 0; k < KER_TOTAL; k++) begin
            wr_data_2_mem(.addr(DATA_ADDR), .data('0), .rand_addr(0), .rand_data(1));
        end

        // Poll CA_finished to ensure CA has processed the data
        begin
            bit [31:0] read_val;
            apb_rd_sequence rd_seq;
            
            `uvm_info("TEST", "Waiting for CA to finish...", UVM_LOW)
            do begin
                rd_seq = apb_rd_sequence::type_id::create("rd_seq");
                rd_seq.addr = CA_FINISHED_ADDR;
                rd_seq.rand_addr = 0;
                rd_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
                read_val = rd_seq.item.DATA;
                if (read_val[0] == 0) #1us;
            end while (read_val[0] == 0);
            `uvm_info("TEST", "CA finished!", UVM_LOW)
        end
        
        // Trigger scoreboard comparison
        if (apb_env.apb_scb != null) begin
            apb_env.apb_scb.compare_saved_data();
        end

        phase.drop_objection(this);
    endtask: run_phase
    
endclass: apb_sram_rand_wr_rd_test