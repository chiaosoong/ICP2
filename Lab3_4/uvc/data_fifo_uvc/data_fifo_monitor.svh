//------------------------------------------------------------------------------
// data_fifo_monitor class
//
// This class is used to monitor the data fifo interface and check its validity.
//
//
// The object is then written to the analysis port.
//
//------------------------------------------------------------------------------
class data_fifo_monitor  extends uvm_monitor;
    `uvm_component_param_utils(data_fifo_monitor)

    // DATA_FIFO uVC configuration object.
    data_fifo_config  m_config;
    // Monitor analysis port.
    uvm_analysis_port #(data_fifo_seq_item)  m_analysis_port;

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        if (!uvm_config_db #(data_fifo_config)::get(this,"","data_fifo_config", m_config)) begin
            `uvm_fatal(get_name(),"Cannot find the VC configuration!")
        end
        m_analysis_port = new("m_data_fifo_analysis_port", this);
    endfunction

    //------------------------------------------------------------------------------
    // The build phase for the component.
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // The run phase for the monitor.
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        process check_process;

        `uvm_info(get_name(),$sformatf("Starting parallel interface monitoring"),UVM_HIGH)
        forever begin
            // Wait for reset to be released
            `uvm_info(get_name(),$sformatf("Waiting for reset signal is released..."),UVM_HIGH)
            @(posedge m_config.m_vif.rst_n);
            // @(negedge m_config.m_vif.clk);
            `uvm_info(get_name(),$sformatf("Reset signal is released"),UVM_HIGH)
            fork
                // Detect reset during testing
                begin
                    @(negedge m_config.m_vif.rst_n);
                    `uvm_info(get_name(),$sformatf("Reset detected. Checking aborted!!"),UVM_HIGH)
                    if (check_process != null) begin
                        check_process.kill();
                    end
                end
                begin
                    data_fifo_seq_item  seq_item;
                    logic fifo_empty;
                    logic fifo_overflow;
                    // Save process info to be able to kill the process
                    check_process = process::self();
                    // Check output data_valid and parallel data
                    forever begin
                        // Sample empty and overflow in previous clock cycle
                        fifo_empty= m_config.m_vif.fifo_empty;
                        fifo_overflow= m_config.m_vif.fifo_overflow;
                        @(negedge m_config.m_vif.clk);
                        // check data_valid signal
                        if (m_config.m_vif.fifo_request_data==1 && m_config.m_vif.fifo_empty==0 ) begin
                            // Create a new data_fifo sequence item with expected data
                            `uvm_info(get_name(),$sformatf("Received data valid fifo_value=%0d fifo_empty=%0d  fifo_overflow=%0d", m_config.m_vif.fifo_data, fifo_empty, fifo_overflow),UVM_HIGH)
                            seq_item = data_fifo_seq_item::type_id::create("seq_item");
                            seq_item.fifo_request_data= m_config.m_vif.fifo_request_data;
                            seq_item.fifo_data= m_config.m_vif.fifo_data;
                            seq_item.fifo_empty= fifo_empty;
                            seq_item.fifo_overflow= fifo_overflow;
                            m_analysis_port.write(seq_item);
                        end
                    end
                end
            join_any
        end
    endtask : run_phase
endclass : data_fifo_monitor
