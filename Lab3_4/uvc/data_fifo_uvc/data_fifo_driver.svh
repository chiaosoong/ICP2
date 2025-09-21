//------------------------------------------------------------------------------
// data_fifo_driver class
//
// This class represents the driver for the data fifo interface.
// The driver handles the generation of FIFO data transactions.
//
// The driver has the following functionality:
//
//------------------------------------------------------------------------------
class data_fifo_driver extends uvm_driver #(data_fifo_seq_item);
    `uvm_component_param_utils(data_fifo_driver)

    // DATA_FIFO uVC configuration object.
    data_fifo_config  m_config;

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        if (!uvm_config_db #(data_fifo_config)::get(this,"","data_fifo_config", m_config)) begin
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
        data_fifo_seq_item seq_item;
        // Reset signals
        m_config.m_vif.fifo_request_data <= 0;
        // Loop forever
        forever begin
            // Wait for sequence item
            seq_item_port.get(seq_item);
            `uvm_info(get_name(),$sformatf("Set FIFO request signal to %0d after %0d clock cycles", seq_item.fifo_request_data, seq_item.start_delay),UVM_HIGH)
            // Wait a number clocks
            repeat (seq_item.start_delay) begin
                @(posedge m_config.m_vif.clk);
            end
            // Write data and set data valid signal
            m_config.m_vif.fifo_request_data <= seq_item.fifo_request_data;
            @(posedge m_config.m_vif.clk);
            seq_item_port.put(seq_item);
        end
    endtask : run_phase
endclass : data_fifo_driver
