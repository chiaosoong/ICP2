    // =================================================================================
    // apb_base_test
    // Purpose:
    //   Base UVM test that constructs the APB environment, retrieves the
    //   virtual APB interface from the `uvm_config_db`, and provides a set of
    //   convenience tasks used by derived tests to perform common operations
    //   (reads, writes, error injections and resets). This class does not
    //   implement stimulus itself; it offers reusable building blocks so tests
    //   can call `wr_data_2_mem`, `rd_data_4m_mem`, `rd_nd_compare_mem`, etc.
    // =================================================================================
    
class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)
    
    // instance of env and env_config
    apb_env_config      apb_env_cfg;
    apb_environment     apb_env;
    
    // constructor function
    function new(string name="apb_base_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction: new

    // build_phase
    virtual function void build_phase(uvm_phase phase);
    
        // build env and env_cfg
        apb_env_cfg = apb_env_config::type_id::create("apb_env_cfg");
        apb_env = apb_environment::type_id::create("apb_env", this);
        
        super.build_phase(phase);
        
        // get the interface from uvm_config_db
        if(!uvm_config_db#(virtual apb_interface)::get(this,"","APB_INTF", apb_env_cfg.apb_mstr_agnt_cfg.apb_intf)) begin
            `uvm_fatal("INTERFACE NOT FOUND ERROR", $sformatf("Could not retrieve apb_interface from uvm_config_db"))
        end
        
        // configure env_cfg: enable scoreboard and coverage and set agent mode
        apb_env_cfg.has_scoreboard = 1;
        apb_env_cfg.apb_mstr_agnt_cfg.has_functional_coverage = 1;
        apb_env_cfg.apb_mstr_agnt_cfg.is_active = UVM_ACTIVE;
        
        // publish environment configuration for the env and sub-components
        uvm_config_db#(apb_env_config)::set(null, "", "APB_ENV_CFG", apb_env_cfg);
        
    endfunction: build_phase
    
    // connect_phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction: connect_phase
    
    // run_phase
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask: run_phase

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // task: wr_rand_data_2_mem
    // input parameters:
    //                      addr: Memory address to write
    //                      data: Data to write
    //                      rand_addr: flag to enable random address selection
    //                      rand_data: flag to enable random data write
    // Description:         Write data to the specified address (supports
    //                      optional randomization of addr and data)
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    task wr_data_2_mem(input [`ADDR_WIDTH-1:0] addr, input [`DATA_WIDTH-1:0] data, input bit rand_addr, input bit rand_data);
        // declare the sequence
        apb_wr_sequence  wr_seq;
        
        // create the sequence
        wr_seq = apb_wr_sequence::type_id::create("wr_seq", this);
        
        // configure sequence
        wr_seq.addr = addr;
        // Mask data to ensure it complies with constraints if it's a directed write
        if (addr == DATA_ADDR) begin
            wr_seq.data = data & 32'h000000FF;
        end else if (addr == INPUT_MODE_ADDR || addr == KERNEL_MODE_ADDR || addr == READ_CTRL_ADDR) begin
            wr_seq.data = data & 32'h00000001;
        end else begin
            wr_seq.data = data;
        end
        
        wr_seq.rand_addr = rand_addr;
        wr_seq.rand_data = rand_data;
        
        // start the write sequence on the agent sequencer
        wr_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
    endtask: wr_data_2_mem
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // task: rd_nd_compare_mem
    // input parameters:
    //                      addr: Memory address to read
    //                      exp_data: expected data for comparing
    // Description:         Read data from the specified address and send the expected data to scoreboard.
    // Notes:
    //  - Creates an `apb_rd_sequence` instance and starts it on the APB
    //    master sequencer (the sequence performs the bus-level read).
    //  - After the sequence starts, this helper pushes the expected data
    //    into the scoreboard via `construct_nd_push_exp_pkt`. The scoreboard
    //    will later compare the expected value with the DUT's read result.
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    task rd_nd_compare_mem(input [`ADDR_WIDTH-1:0] addr, input [`DATA_WIDTH-1:0] exp_data);
        // declare the sequence
        apb_rd_sequence  rd_seq;
        
        // create the sequence
        rd_seq = apb_rd_sequence::type_id::create("rd_seq", this);
        
        // configure sequence
        rd_seq.addr = addr;
        
        // start the sequence on the agent's sequencer; this issues the
        // read to the driver which performs the APB transfer on the bus.
        rd_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
        
        // push expected value into scoreboard's expected list so it can
        // be compared when the monitor observes the DUT's read response.
        apb_env.apb_scb.construct_nd_push_exp_pkt(addr, exp_data);
    endtask

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // task: reset_dut
    // input parameters: None
    //                      
    // Description:          Reset the APB virtual interface by toggling the
    //                       PRESETn signal (implementation lives inside the
    //                       virtual interface method `reset_intf`). The task
    //                       then waits one clocking block tick to allow the
    //                       DUT to sample the reset completion.
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    task reset_dut();
        // 1. Assert Reset
        apb_env_cfg.apb_mstr_agnt_cfg.apb_intf.assert_reset();

        // Sample Reset State (0)
        apb_env.apb_mstr_agnt.apb_cov_mntr.reset_value = 0;
        apb_env.apb_mstr_agnt.apb_cov_mntr.reset_valid = 1;
        apb_env.apb_mstr_agnt.apb_cov_mntr.apb_state_cg.sample();

        // Wait for reset duration (2 clocks as per original reset_intf)
        repeat(2) @(apb_env_cfg.apb_mstr_agnt_cfg.apb_intf.cb);

        // 2. Deassert Reset
        apb_env_cfg.apb_mstr_agnt_cfg.apb_intf.deassert_reset();
        
        // Wait for stability
        @(apb_env_cfg.apb_mstr_agnt_cfg.apb_intf.cb);

        // Sample Run State (1)
        // Force state to IDLE after reset
        apb_env.apb_mstr_agnt.apb_cov_mntr.current_state = apb_coverage_monitor::IDLE;
        
        apb_env.apb_mstr_agnt.apb_cov_mntr.reset_value = 1;
        apb_env.apb_mstr_agnt.apb_cov_mntr.apb_state_cg.sample();
        // reset_valid remains 1 to capture Run state in subsequent transactions
    endtask: reset_dut
    
    /*
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // task: rd_data_4m_mem
    // input parameters:
    //                      addr: Memory address to read
    //                      rand_addr: flag to enable random address selection
    // Description:         Read data from the specified address
    // Notes:               Optionally supports randomized address selection
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    task rd_data_4m_mem(input [`ADDR_WIDTH-1:0] addr, input bit rand_addr);
        // declare the sequence
        apb_rd_sequence  rd_seq;
        
        // create the sequence
        rd_seq = apb_rd_sequence::type_id::create("rd_seq", this);
        
        // configure sequence
        rd_seq.addr = addr;
        rd_seq.rand_addr = rand_addr;
        
        // start the sequence on the agent sequencer
        rd_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
    endtask: rd_data_4m_mem
    
    /*
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // task: generate_mem_rd_err
    // input parameters:
    //                      addr: Memory address to read
    //                      rand_addr: flag to enable random address selection
    // Description:         Initiate read transfer with memory out of bound error
    // Notes:               Uses an error-injection read sequence which the
    //                      driver/monitor/scoreboard can treat as an error
    //                      scenario for verification of error handling.
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    task generate_mem_rd_err(input [`ADDR_WIDTH-1:0] addr, input bit rand_addr);
        // declare the sequence
        apb_err_rd_sequence  rd_seq;
        
        // create the sequence
        rd_seq = apb_err_rd_sequence::type_id::create("rd_seq", this);
        
        // configure sequence
        rd_seq.addr = addr;
        rd_seq.rand_addr = rand_addr;
        
        // start the error-inducing read sequence
        rd_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
    endtask: generate_mem_rd_err
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // task: generate_mem_wr_err
    // input parameters:
    //                      addr: Memory address to write
    //                      data: Data to write
    //                      rand_addr: flag to enable random address selection
    //                      rand_data: flag to enable random data write
    // Description:         Initiate write transfer with memory out of bound error
    // Notes:               Uses an error-injection write sequence to verify
    //                      DUT and testbench error reporting and recovery.
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    task generate_mem_wr_err(input [`ADDR_WIDTH-1:0] addr, input [`DATA_WIDTH-1:0] data, input bit rand_addr, input bit rand_data);
        // declare the sequence
        apb_err_wr_sequence  wr_seq;
        
        // create the sequence
        wr_seq = apb_err_wr_sequence::type_id::create("wr_seq", this);
        
        // configure sequence
        wr_seq.addr = addr;
        wr_seq.data = data;
        wr_seq.rand_addr = rand_addr;
        wr_seq.rand_data = rand_data;
        
        // start the error-inducing write sequence
        wr_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
    endtask: generate_mem_wr_err*/
endclass : apb_base_test