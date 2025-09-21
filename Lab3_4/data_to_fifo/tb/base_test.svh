//------------------------------------------------------------------------------
// Class base_test
// 
// Base class for all UVM test derived from uvm_test
// 
// This class contains the basic structure of UVM test class and provides some
// basic sequence and environment to make it easier for users to create
// test cases.
// 
// This class includes:
//  - base_test: Base class for all UVM test derived from uvm_test
//  - base_test::build_phase: Function to build the class within UVM build phase
//  - base_test::run_phase: Start UVM test in running phase
// 
// This class is a part of the test library.
// 
//------------------------------------------------------------------------------
class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    // Testbench top configuration object with all setup for the TB
    top_config  m_top_config;
    // Testbench environment
    tb_env  m_tb_env;

    //------------------------------------------------------------------------------
    // FUNCTION: new
    // Creates and constructs the sequence.
    //------------------------------------------------------------------------------
    function new (string name = "test",uvm_component parent = null);
        super.new(name,parent);
        // Get TB TOP configuration from UVM DB
        if ((uvm_config_db #(top_config)::get(null, "tb_top", "top_config", m_top_config))==0) begin
            `uvm_fatal(get_name(),"Cannot find <top_config> TB configuration!")
        end
    endfunction : new

    //------------------------------------------------------------------------------
    // FUNCTION: build_phase
    // Function to build the class within UVM build phase.
    //------------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Create TB verification environment
        m_tb_env = tb_env::type_id::create("m_tb_env",this);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // FUNCTION: run_phase
    // Start UVM test in running phase.
    //------------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        reset_seq reset;
        parallel_data_seq parallel_data;
        data_fifo_seq data_fifo;

        super.run_phase(phase);
        `uvm_info(get_name(),$sformatf("UVM TB Starts UVM test; '%s'",get_name()),UVM_NONE)
        // Raise objection if no UVM test is running
        phase.raise_objection(this);
        // Reset DUT before start
        reset = reset_seq::type_id::create("reset");
        if (!(reset.randomize() with {
            delay == 0;
            length == 2;
        })) `uvm_fatal(get_name(), "Failed to randomize reset")
        reset.start(m_tb_env.m_reset_agent.m_sequencer);

        // Fork two processes that running in parallel
        fork
            // Randomize input data and parity_error stimulus with different clock delay N times
            begin
                repeat (50) begin
                    parallel_data = parallel_data_seq::type_id::create("parallel_data");
                    if (!(parallel_data.randomize() with {
                        start_delay <= 4;
                    })) `uvm_fatal(get_name(), "Failed to randomize parallel data ")
                    parallel_data.start(m_tb_env.m_parallel_data_agent.m_sequencer);
                end
            end
            begin
                repeat (15) begin
                    data_fifo = data_fifo_seq::type_id::create("data_fifo");
                    if (!(data_fifo.randomize() with {
                        start_delay <= 10;
                        fifo_request== 1;
                    })) `uvm_fatal(get_name(), "Failed to randomize data_fifo")
                    data_fifo.start(m_tb_env.m_data_fifo_agent.m_sequencer);
                    data_fifo = data_fifo_seq::type_id::create("data_fifo");
                    if (!(data_fifo.randomize() with {
                        start_delay <= 5;
                        fifo_request== 0;
                    })) `uvm_fatal(get_name(), "Failed to randomize data_fifo")
                    data_fifo.start(m_tb_env.m_data_fifo_agent.m_sequencer);
                end
            end
        join
        // When both processes are done, wait 100ns
        #100ns;
        // Drop objection if no UVM test is running
        phase.drop_objection(this);
    endtask : run_phase

endclass : base_test
