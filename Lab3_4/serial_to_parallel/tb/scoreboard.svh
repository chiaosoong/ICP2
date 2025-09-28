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
// The functional coverage is provided by the `serial_to_parallel_covergrp`
// coverage group.
//
//------------------------------------------------------------------------------
// Instance analysis defines
`uvm_analysis_imp_decl(_scoreboard_reset)
`uvm_analysis_imp_decl(_scoreboard_serial_data)
`uvm_analysis_imp_decl(_scoreboard_parallel_data)
class scoreboard extends uvm_component;
    `uvm_component_utils(scoreboard)

    // reset data instance analysis connection
    uvm_analysis_imp_scoreboard_reset #(reset_seq_item, scoreboard) m_reset_ap;
    // serial_data instance analysis connection
    uvm_analysis_imp_scoreboard_serial_data #(serial_data_seq_item, scoreboard) m_serial_data_ap;
    // parallel_data instance analysis connection
    uvm_analysis_imp_scoreboard_parallel_data #(parallel_data_seq_item, scoreboard) m_parallel_data_ap;

    // Indicates if the input serial data is valid.
    int unsigned input_data_valid;
    // Indicates if there is a parity error in the input serial data.
    int unsigned input_parity_error;
    // The input serial data.
    int unsigned input_data;
    // Indicates if the output parallel data is valid.
    int unsigned dut_data_valid;
    // Indicates if there is a parity error in the output  parallel data.
    int unsigned dut_parity_error;
    // The output parallel data.
    int unsigned dut_data;
    // Indicates if the reset signal is active.
    int unsigned reset_valid;
    // The value of the reset signal.
    int unsigned reset_value;
    // Indicates how often the data has been checked.
    int unsigned data_checked;
    // Indicates the state of the transmission.
    enum  { IDLE=0, START_BIT=1, ACTIVE=2} transmission_state;


    //------------------------------------------------------------------------------
    // Functional coverage definitions
    //------------------------------------------------------------------------------
    covergroup serial_to_parallel_covergrp;
        reset : coverpoint reset_value iff (reset_valid) {
            bins reset =  { 0 };
            bins run=  { 1 };
        }
        transmission : coverpoint transmission_state {
            bins ilde     =  { IDLE };
            bins active   =  { ACTIVE };
            bins start_bit=  { START_BIT };
        }
        parity_error : coverpoint input_parity_error iff (input_data_valid) {
            bins ok =   { 0 };
            bins error= { 1 };
        }
        data : coverpoint input_data iff (input_data_valid) {
            wildcard bins bit0_passive = { 8'b???????0 };
            wildcard bins bit1_passive = { 8'b??????0? };
            wildcard bins bit2_passive = { 8'b?????0?? };
            wildcard bins bit3_passive = { 8'b????0??? };
            wildcard bins bit4_passive = { 8'b???0???? };
            wildcard bins bit5_passive = { 8'b??0????? };
            wildcard bins bit6_passive = { 8'b?0?????? };
            wildcard bins bit7_passive = { 8'b0??????? };
            wildcard bins bit0_active  = { 8'b???????1 };
            wildcard bins bit1_active  = { 8'b??????1? };
            wildcard bins bit2_active  = { 8'b?????1?? };
            wildcard bins bit3_active  = { 8'b????1??? };
            wildcard bins bit4_active  = { 8'b???1???? };
            wildcard bins bit5_active  = { 8'b??1????? };
            wildcard bins bit6_active  = { 8'b?1?????? };
            wildcard bins bit7_active  = { 8'b1??????? };
        }
        state_cross : cross transmission_state, reset;
        pariry_cross : cross data, parity_error;
    endgroup

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new(string name = "scoreboard", uvm_component parent = null);
        super.new(name,parent);
        // Create coverage group
        serial_to_parallel_covergrp = new();
    endfunction : new

    //------------------------------------------------------------------------------
    // The build for the component.
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Create analysis connections
        m_reset_ap = new("m_reset_ap", this);
        m_serial_data_ap = new("m_serial_data_ap", this);
        m_parallel_data_ap = new("m_parallel_data_ap", this);
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
        input_data_valid= 0;
        input_data= 0;
        dut_data_valid= 0;
        dut_data= 0;
        // Sample reset coverage
        reset_valid= 1;
        reset_value= item.reset_value;
        serial_to_parallel_covergrp.sample();
        reset_valid= 0;
    endfunction :  write_scoreboard_reset

    //------------------------------------------------------------------------------
    // Write implementation for write_scoreboard_serial_data analyze port.
    //------------------------------------------------------------------------------
    virtual function void write_scoreboard_serial_data(serial_data_seq_item item);
        `uvm_info(get_name(),$sformatf("SERIAL_DATA_MONITOR:\n%s",item.sprint()),UVM_HIGH)
        // Check if last serial data has been checked against DUT output data
        if (item.monitor_data_valid && input_data_valid) begin
            `uvm_error(get_name(), $sformatf("DUT data_valid has not been activated after last received serial data! Previous serial data=%0d", input_data))
        end
        // Sample serial data and DUT output coverage
        input_data_valid= item.monitor_data_valid;
        input_data= item.serial_data;
        //input_parity_error= item.parity_error;
        serial_to_parallel_covergrp.sample();

        // Setup transmission_state which depends on monitor information
        if (item.monitor_start_bit_value && item.monitor_start_bit_valid) begin
            transmission_state = START_BIT;
        end
        else if (item.monitor_data_valid) begin
            transmission_state = IDLE;
        end
        else if (transmission_state==START_BIT) begin
            transmission_state = ACTIVE;
        end
        `uvm_info(get_name(), $sformatf("Transmission state=%s", transmission_state.name()), UVM_HIGH)
        // Check data and parity if also data from parallel data VIP
        check_data();
    endfunction :  write_scoreboard_serial_data

    //------------------------------------------------------------------------------
    // Write implementation for write_scoreboard_parallel_data analyze port.
    //------------------------------------------------------------------------------
    virtual function void write_scoreboard_parallel_data(parallel_data_seq_item item);
        `uvm_info(get_name(),$sformatf("PARALLEL_DATA_MONITOR:\n%s",item.sprint()),UVM_HIGH)
        // Check if last serial data has been checked against DUT output data
        if (dut_data_valid) begin
            `uvm_error(get_name(), $sformatf("Received DUT data is valid for the second time without any valid serial data before! Previous output data = %0d", dut_data))
        end
        dut_data= item.data;
        dut_parity_error= item.parity_error;
        dut_data_valid= 1;
        // Check data and parity if also data from serial data VIP
        check_data();
    endfunction :  write_scoreboard_parallel_data

    //------------------------------------------------------------------------------
    // Check data if both input serial data and output data are valid.
    //------------------------------------------------------------------------------
    virtual function void check_data();
        // Both serial data and parallel data need to valid before check the DUT data and parity error
        if (input_data_valid && dut_data_valid) begin
            // Check DUT data is correct
            if (dut_data != input_data) begin
                `uvm_error(get_name(), $sformatf("Data mismatch!!! Received data=%08b(%0d) Expected data=%08b(%0d)", dut_data, dut_data, input_data, input_data))
            end
            else begin
                `uvm_info(get_name(),$sformatf("Received complete 8 data bits as expected. Data=%0d", dut_data), UVM_MEDIUM)
            end
            data_checked++;
            // Check DUT parity error is correct
            if (dut_parity_error != input_parity_error) begin
                `uvm_error(get_name(), $sformatf("Parity error mismatch!!! Received parity error=%0s Expected=%0s", (dut_parity_error ? "PARITY_ERROR" : "OK"), input_parity_error ? "PARITY_ERROR" : "OK"))
            end
            // Clear valid to indicate the data and parity has been checked
            input_data_valid= 0;
            dut_data_valid= 0;
        end
    endfunction :  check_data

    //------------------------------------------------------------------------------
    // UVM check phase
    //------------------------------------------------------------------------------
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        // Complete simulation
        $display("*****************************************************");
        $display("Number of checked data %0d", data_checked);
        $display("*****************************************************");
        if (serial_to_parallel_covergrp.get_coverage() == 100.0) begin
            $display("FUNCTIONAL COVERAGE (100.0%%) PASSED....");
        end
        else begin
            $display("FUNCTIONAL COVERAGE FAILED!!!!!!!!!!!!!!!!!");
            $display("Coverage = %0f", serial_to_parallel_covergrp.get_coverage());
        end
        $display("*****************************************************");
    endfunction : check_phase

endclass : scoreboard
