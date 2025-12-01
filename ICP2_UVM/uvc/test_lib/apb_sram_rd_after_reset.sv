class apb_sram_rd_after_reset extends apb_base_test;
    `uvm_component_utils(apb_sram_rd_after_reset)

    // constructor function
    function new(string name="apb_sram_rd_after_reset", uvm_component parent=null);
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
        super.run_phase(phase);       
        // Enable state coverage for this test
        if (apb_env.apb_mstr_agnt.apb_cov_mntr != null) begin
            apb_env.apb_mstr_agnt.apb_cov_mntr.state_valid = 1;
        end 
        phase.raise_objection(this);
        
        // 1. Reset in IDLE (Initial Reset)
        `uvm_info("TEST", ">>> Case 1: Reset in IDLE", UVM_LOW)
        reset_dut();
        if (apb_env.apb_scb != null) apb_env.apb_scb.flush();
        run_functional_check();

        // 2. Reset in WRITE_INIT
        `uvm_info("TEST", ">>> Case 2: Reset in WRITE_INIT", UVM_LOW)
        // Trigger WRITE_INIT state by writing to INPUT_MODE
        wr_data_2_mem(.addr(INPUT_MODE_ADDR), .data(1), .rand_addr(0), .rand_data(0));
        // Immediate Reset
        reset_dut();
        if (apb_env.apb_scb != null) apb_env.apb_scb.flush();
        run_functional_check();

        // 3. Reset in WRITE
        `uvm_info("TEST", ">>> Case 3: Reset in WRITE", UVM_LOW)
        // Trigger WRITE state
        wr_data_2_mem(.addr(INPUT_MODE_ADDR), .data(1), .rand_addr(0), .rand_data(0));
        // Write some data to enter WRITE state
        repeat(10) wr_data_2_mem(.addr(DATA_ADDR), .data($urandom), .rand_addr(0), .rand_data(0));
        // Reset
        reset_dut();
        if (apb_env.apb_scb != null) apb_env.apb_scb.flush();
        run_functional_check();

        // 4. Reset in APB_READ
        `uvm_info("TEST", ">>> Case 4: Reset in APB_READ", UVM_LOW)
        // We need to reach APB_READ state first, which requires a full calculation
        // Perform a full write and wait for CA finished
        run_full_write_and_wait();
        // Trigger APB_READ state
        wr_data_2_mem(.addr(READ_CTRL_ADDR), .data(1), .rand_addr(0), .rand_data(0));
        // Read a few items to be in the middle of reading
        repeat(10) begin
            apb_rd_sequence rd_seq;
            rd_seq = apb_rd_sequence::type_id::create("rd_seq");
            rd_seq.addr = OUTPUT_ADDR;
            rd_seq.rand_addr = 0;
            rd_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
        end
        // Reset
        reset_dut();
        if (apb_env.apb_scb != null) apb_env.apb_scb.flush();
        run_functional_check();

        phase.drop_objection(this);
    endtask: run_phase

    // Helper task: Run full functional check (Write IFM/Ker -> Wait -> Read -> Compare)
    task run_functional_check();
        `uvm_info("TEST", "Starting Functional Check...", UVM_LOW)
        
        // Perform full write and wait for CA finished
        run_full_write_and_wait();
        
        // Enable Burst Read
        wr_data_2_mem(.addr(READ_CTRL_ADDR), .data(1), .rand_addr(0), .rand_data(0));
        
        // Read Output
        // 用于后续scoreboard添加卷积结果时的对比
        for (int i = 0; i < 784; i++) begin
            apb_rd_sequence rd_out_seq;
            rd_out_seq = apb_rd_sequence::type_id::create($sformatf("rd_out_seq_%0d", i));
            rd_out_seq.addr = OUTPUT_ADDR;
            rd_out_seq.rand_addr = 0;
            rd_out_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
        end
        
        // Scoreboard Compare
        if (apb_env.apb_scb != null) begin
            apb_env.apb_scb.compare_saved_data();
        end
    endtask

    // Helper task: Write data and wait for CA (used to reach APB_READ state)
    task run_full_write_and_wait();
        int unsigned IFM_TOTAL = 3*784;
        int unsigned KER_TOTAL = 3*9;
        
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
        // Poll CA_finished
        run_wait_ca_finished();
    endtask

    // Helper task: Wait for CA finished
    task run_wait_ca_finished();
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
    endtask
    
endclass: apb_sram_rd_after_reset