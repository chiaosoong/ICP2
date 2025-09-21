//------------------------------------------------------------------------------
// Scoreboard for the TBUVM TB.
//
// This class is an implementation of the scoreboard that monitors the TBUVM
// testbench and checks the behavior of the DUT with regard to the
// serial-to-parallel conversion. It provides the following features:
//
// - Monitors the input serial data and the output parallel data of the DUT.
// - Checks if the output data of the DUT is correct with regard to the
//   input serial data.
// - Checks if the DUT is in the correct state during the transmission of data.
// - Provides functional coverage for the transmission of data and the
//   activation of the DUT's output.
// - Provides error reporting for any errors that are detected during the simulation.
//
// This class is derived from the `uvm_component` class and implements the
// `uvm_analysis_imp_scoreboard_reset`, `uvm_analysis_imp_scoreboard_serial_data`
// and `uvm_analysis_imp_scoreboard_parallel_data` analysis ports.
//
// The functional coverage is provided by the `data_fifo_covergrp`
// coverage group.
//
//------------------------------------------------------------------------------
// Instance analysis defines
`uvm_analysis_imp_decl(_scoreboard_reset)
class scoreboard extends uvm_component;
    `uvm_component_utils(scoreboard)

    // reset data instance analysis connection
    uvm_analysis_imp_scoreboard_reset #(reset_seq_item, scoreboard) m_reset_ap;
    // parallel_data fifo analysis connection
    uvm_tlm_analysis_fifo #(parallel_data_seq_item) m_parallel_data_fifo;
    // data_fifo fifo analysis connection
    uvm_tlm_analysis_fifo #(data_fifo_seq_item) m_data_fifo_fifo;

    // Indicates how often the data has been checked.
    int unsigned data_checked;
    // Indicates if the reset signal is active.
    bit reset_valid;
    // The value of the reset signal.
    bit reset_value;
    // Indicates if the input serial data is valid.
    bit data_valid;
    // Indicates if there is a parity error in the input serial data.
    bit parity_error;
    // Indicates input data has overrun
    bit data_overrun;
    // The input data.
    bit [7:0] data;
    // The input data data_queue.
    bit [7:0] data_queue[$];
    // Indicates if the output fifo data is valid.
    bit fifo_data_valid;
    // Indicates if there is no fifo data
    bit fifo_empty;
    // Indicates if there is fifo overflow
    bit fifo_overflow;
    // The output fifo data.
    bit [7:0] fifo_data;
    // Number of coherent_fifo reads
    int unsigned data_queue_numbers;

    //------------------------------------------------------------------------------
    // Functional coverage definitions
    //------------------------------------------------------------------------------
    covergroup data_fifo_covergrp;
        reset : coverpoint reset_value iff (reset_valid) {
            bins reset = { 0 };
            bins run   = { 1 };
        }
        parity_error : coverpoint parity_error iff (data_valid) {
            bins ok    = { 0 };
            bins error = { 1 };
        }
        data : coverpoint data iff (data_valid && parity_error==0) {
            bins data[8] = { [0:255] };
        }
        fifo_data_numbers : coverpoint data_queue_numbers iff (data_valid) {
            bins empty = { 0 };
            bins _1_   = { 1 };
            bins _2_   = { 2 };
            bins _3_   = { 3 };
            bins _4_   = { 4 };
        }
        fifo_empty : coverpoint fifo_empty iff (fifo_data_valid) {
            bins data  = { 0 };
            bins empty = { 1 };
        }
        fifo_overflow : coverpoint fifo_overflow iff (fifo_data_valid) {
            bins ok       = { 0 };
            bins overflow = { 1 };
        }
    endgroup

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new(string name = "scoreboard", uvm_component parent = null);
        super.new(name,parent);
        // Create coverage group
        data_fifo_covergrp = new();
    endfunction : new

    //------------------------------------------------------------------------------
    // The build for the component.
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Create analysis connections
        m_reset_ap = new("m_reset_ap", this);
        m_parallel_data_fifo = new("m_parallel_data_fido", this);
        m_data_fifo_fifo = new("m_data_fifo_fido", this);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // The connection phase for the component.
    //------------------------------------------------------------------------------
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction : connect_phase

    //------------------------------------------------------------------------------
    // Write implementation for write_scoreboard_reset analyze port.
    //------------------------------------------------------------------------------
    virtual function void write_scoreboard_reset(reset_seq_item item);
        `uvm_info(get_name(),$sformatf("RESET_MONITOR:\n%s",item.sprint()),UVM_HIGH)
        // Clear start bit and data
        if (item.reset_value==0) begin
            data_valid = 0;
            data_overrun = 0;
            parity_error = 0;
            data = 0;
            data_queue.delete();
            fifo_data_valid = 0;
            fifo_empty = 0;
            fifo_overflow = 0;
            fifo_data = 0;
            data_queue_numbers = 0;
        end
        // Sample reset coverage
        reset_value = item.reset_value;
        reset_valid = 1;
        data_fifo_covergrp.sample();
        reset_valid = 0;
    endfunction :  write_scoreboard_reset

    //------------------------------------------------------------------------------
    // Handle scoreboard parallel_data fifo port.
    //------------------------------------------------------------------------------
    virtual function void parallel_data(parallel_data_seq_item item);
        `uvm_info(get_name(),$sformatf("PARALLEL_DATA_MONITOR:\n%s",item.sprint()),UVM_HIGH)
        // Sample coverage
        data = item.data;
        //parity_error = item.parity_error;
        data_queue_numbers = data_queue.size();
        data_valid = 1;
        data_fifo_covergrp.sample();
        data_valid = 0;
        // Check if data is without error then it store in FIFO
        if (parity_error==0) begin
            data_overrun = (data_queue.size() == 4 ?  1 : 0);
            // Data where Overrun don't store
            if (data_overrun==0) begin
                void'(data_queue.push_back(data));
            end
        end
    endfunction : parallel_data

    //------------------------------------------------------------------------------
    // Handle scoreboard data_fifo fifo port.
    //------------------------------------------------------------------------------
    virtual function void data_fifo(data_fifo_seq_item item);
        `uvm_info(get_name(),$sformatf("DATA_FIFO_MONITOR:\n%s",item.sprint()),UVM_HIGH)
        // Sample coverage
        fifo_data_valid = 1;
        fifo_empty = item.fifo_empty;
        fifo_overflow = item.fifo_overflow;
        fifo_data = item.fifo_data;
        data_fifo_covergrp.sample();
        fifo_data_valid = 0;
        // Check if input data exist
        if (data_queue.size() == 0) begin
            `uvm_error(get_name(), $sformatf("DUT sets not empty, but there is no valid input data fifo_data=%0d fifo_empty=%0d  fifo_overflow=%0d", fifo_data, fifo_empty, fifo_overflow))
            return;
        end
        data_checked++;
        // Check fifo data is as expected
        data= data_queue.pop_front();
        if (data != fifo_data) begin
            `uvm_error(get_name(), $sformatf("Data mismatch!!! Received data=%0d Expected data=%0d", fifo_data, data))
        end
        else begin
            `uvm_info(get_name(),$sformatf("Compared FIFO output data as expected. fifo_data=%0d", fifo_data), UVM_MEDIUM)
        end
        // Check fifo_overflow is correct state
        if (data_overrun != fifo_overflow) begin
            `uvm_error(get_name(), $sformatf("fifo_overflow mismatch!!! Received fifo_overflow=%0d Expected=%0d", fifo_overflow, data_overrun))
        end
        // Clear overrun
        data_overrun= 0;
    endfunction : data_fifo

    //------------------------------------------------------------------------------
    // UVM run phase
    //------------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        // Create threads to get data from parallel_data and data_fifo monitor forever
        fork
            forever begin
                parallel_data_seq_item  item;
                // Wait for data from the export port
                m_parallel_data_fifo.get(item);
                // Create a small delay to be sure of the order
                // Data_fifo item must be handled before this item in case of it comes in the same simulation cycle
                #1ns;
                // Got item from parallel data monitor then process the item
                parallel_data(item);
            end
            forever begin
                data_fifo_seq_item  item;
                // Wait for data from the export port
                m_data_fifo_fifo.get(item);
                // Got item from data fifo monitor then process the item
                data_fifo(item);
            end
        join_none
    endtask : run_phase;

    //------------------------------------------------------------------------------
    // UVM check phase
    //------------------------------------------------------------------------------
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        // Check all input data has been checked
        while (data_queue.size() > 0) begin
            data= data_queue.pop_front();
            `uvm_error(get_name(), $sformatf("All input data has not been output to the FIFO output. input_data=%0d", data))
        end
        // Complete simulation
        $display("*****************************************************");
        $display("Number of checked data %0d", data_checked);
        $display("*****************************************************");
        if (data_fifo_covergrp.get_coverage() == 100.0) begin
            $display("FUNCTIONAL COVERAGE (100.0%%) PASSED....");
        end
        else begin
            $display("FUNCTIONAL COVERAGE FAILED!!!!!!!!!!!!!!!!!");
            $display("Coverage = %0f", data_fifo_covergrp.get_coverage());
        end
        $display("*****************************************************");
    endfunction : check_phase

endclass : scoreboard
