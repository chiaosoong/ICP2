//------------------------------------------------------------------------------
// parallel_data_driver class
//
// This class represents the driver for the parallel data interface.
// The driver handles the generation of parallel data transactions.
//
// The driver has the following functionality:
// - Get sequence item from the interface's sequencer
// - Perform the requested action and send response back.
// - Write data and set data valid signal
// - Wait one clock cycle with data valid 
//
//------------------------------------------------------------------------------
class parallel_data_driver extends uvm_driver #(parallel_data_seq_item);
    `uvm_component_param_utils(parallel_data_driver)

    // PARALLEL_DATA uVC configuration object.
    parallel_data_config  m_config;

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        if (!uvm_config_db #(parallel_data_config)::get(this,"","parallel_data_config", m_config)) begin
            `uvm_fatal(get_name(),"Cannot find the VC configuration!")
        end
    endfunction

    //------------------------------------------------------------------------------
    // FUNCTION: build
    // The build phase for the component.
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // FUNCTION: run_phase
    // The run phase for the component.
    // - Main loop
    // -  Wait for sequence item.
    // -  Perform the requested action
    // -  Send a response back.
    //------------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        parallel_data_seq_item seq_item;
        // Reset signals
        m_config.m_vif.data_valid <= 0;
        m_config.m_vif.data <= 0;
        
        // Loop forever
        forever begin
            // Wait for sequence item
            seq_item_port.get(seq_item);
            // Perform the requested action and send response back.
            `uvm_info(get_name(),$sformatf("Start parallel interface transaction. start clock delay=%0d  Parallel data=%0d", seq_item.start_delay, seq_item.data),UVM_HIGH)
            // Wait number of clocks
            repeat (seq_item.start_delay) begin
                @(posedge m_config.m_vif.clk);
            end
            // Write data and set data valid signal
            m_config.m_vif.data <= seq_item.data;
          
            m_config.m_vif.data_valid <= 1;
            `uvm_info(get_name(),$sformatf("Write parallel_data. Data=%0d", seq_item.data), UVM_FULL)
            m_config.m_vif.data_valid <= 1;
            seq_item_port.put(seq_item);
            // Wait one clock cycle with data valid 
            @(posedge m_config.m_vif.clk);
            m_config.m_vif.data_valid <= 0;
        end
    endtask : run_phase
endclass : parallel_data_driver
