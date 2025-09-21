//------------------------------------------------------------------------------
//
// This module is a top-level module for the TB with serial data to parallel  DUT
//
// It instantiates all of the uVC interface instances and connects them to the RTL top.
// It also initializes the UVM test environment and runs the test and
// it creates the default top-level test configuration.
//
// The testbench uses the following uVC interfaces:
// - CLOCK IF: Generates a system clock.
// - RESET IF: Generates the reset signal.
// - SERIAL_DATA IF: Generate parallel data to the DUT input interface
// - PARALLEL_DATA IF: Passes the DUT output infterface to parallel data uVC
//
//------------------------------------------------------------------------------
module tb_top;

    // Include basic packages
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Include optional packages
    import tb_pkg::*;

    // uVC TB signal variables 
    logic tb_clock;
    logic tb_reset_n;
    logic tb_start_bit;
    logic tb_serial_data;
    logic tb_parity_enable;
    logic tb_data_valid;
    logic tb_parity_error;
    logic [7:0] tb_data;

    // Instantiation of CLOCK uVC interface signal
    clock_if  i_clock_if();
    assign tb_clock = i_clock_if.clock;

    // Instantiation of RESET uVC interface signal
    reset_if  i_reset_if(.clk(tb_clock));
    assign tb_reset_n = i_reset_if.reset_n;

    // Instantiation of SERIAL_DATA uVC interface signal
    serial_data_if  i_serial_data_if(.clk(tb_clock),.rst_n(tb_reset_n));
    assign tb_start_bit = i_serial_data_if.start_bit;
    assign tb_serial_data = i_serial_data_if.serial_data;
    assign tb_parity_enable = i_serial_data_if.parity_enable;

    // Instantiation of PARALLEL_DATA uVC interface signal
    parallel_data_if  i_parallel_data_if(.clk(tb_clock),.rst_n(tb_reset_n));
    assign i_parallel_data_if.data_valid = tb_data_valid;
    assign i_parallel_data_if.data = tb_data;
    assign i_parallel_data_if.parity_error = tb_parity_error;

    // Instantiation of the SERIAL_TO_PARALLEL RTL top
    serial_to_parallel serial_to_parallel_dut 
    (
        .clock(tb_clock),
        .reset_n(tb_reset_n),
        .start_bit(tb_start_bit),
        .serial_data(tb_serial_data),
        .parity_enable(tb_parity_enable),
        .data_valid(tb_data_valid),
        .data(tb_data),
        .parity_error(tb_parity_error)
    );

    // Initialize TB configuration
    initial begin
        top_config  m_top_config;
        // Create TB top configuration and store it into UVM config DB.
        m_top_config = new("m_top_config");
        uvm_config_db #(top_config)::set(null,"tb_top","top_config", m_top_config);
        // Save all virtual interface instances into configuration
        m_top_config.m_clock_config.m_vif = i_clock_if;
        m_top_config.m_reset_config.m_vif = i_reset_if;
        m_top_config.m_serial_data_config.m_vif = i_serial_data_if;
        m_top_config.m_parallel_data_config.m_vif = i_parallel_data_if;
    end

    // Start UVM test_base environment
    initial begin
        run_test("basic_test");
    end

endmodule
