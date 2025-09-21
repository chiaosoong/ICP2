//------------------------------------------------------------------------------
// parallel_data_monitor class
//
// This class is used to monitor the parallel data interface and check its validity.
// It monitors the data_valid and data signals. Before the monitor starts it waits
// for reset is released and every time reset is activated it reset the monitor state.
//
// The class checks if the data_valid signal is asserted, and if so, it creates a new
// parallel_data_seq_item object with the data and parity_error fields filled in.
// The object is then written to the analysis port.
//
//------------------------------------------------------------------------------
class parallel_data_monitor  extends uvm_monitor;
    `uvm_component_param_utils(parallel_data_monitor)

    // PARALLEL_DATA uVC configuration object.
    parallel_data_config  m_config;
    // Monitor analysis port.
    uvm_analysis_port #(parallel_data_seq_item)  m_analysis_port;

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        if (!uvm_config_db #(parallel_data_config)::get(this,"","parallel_data_config", m_config)) begin
            `uvm_fatal(get_name(),"Cannot find the VC configuration!")
        end
        m_analysis_port = new("m_parallel_data_analysis_port", this);
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
                    parallel_data_seq_item  seq_item;
                    // Save process info to be able to kill the process
                    check_process = process::self();
                    // Check output data_valid and parallel data
                    forever begin
                        @(negedge m_config.m_vif.clk);
                        // check data_valid signal
                        if (m_config.m_vif.data_valid) begin
                            // Create a new parallel_data sequence item with expected data
                            `uvm_info(get_name(),$sformatf("Received data valid value=%0d parity_error=%0d", m_config.m_vif.data, m_config.m_vif.parity_error),UVM_HIGH)
                            seq_item = parallel_data_seq_item::type_id::create("seq_item");
                            seq_item.data= m_config.m_vif.data;
                            seq_item.parity_error= m_config.m_vif.parity_error;
                            m_analysis_port.write(seq_item);
                        end
                    end
                end
            join_any
        end
    endtask : run_phase
endclass : parallel_data_monitor
