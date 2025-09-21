//------------------------------------------------------------------------------
//
// This module is a top-level module for the TB with data to fifo DUT
//
// It instantiates all of the uVC interface instances and connects them to the RTL top.
// It also initializes the UVM test environment and runs the test and
// it creates the default top-level test configuration.
//
// The testbench uses the following uVC interfaces:
// - CLOCK IF: Generates a system clock.
// - RESET IF: Generates the reset signal.
// - PARALLEL_DATA IF: Generate parallel data to the DUT input interface
// - DATA_FIFO IF: Passes the DUT output infterface to data fifo uVC
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
    logic tb_clock_d;
    logic tb_reset_n;
    logic tb_data_valid;
    logic tb_parity_error;
    logic [7:0] tb_data;
    logic tb_fifo_request_data;
    logic tb_fifo_empty;
    logic tb_fifo_overflow;
    logic [7:0] tb_fifo_data;

    // Instantiation of CLOCK uVC interface signal
    clock_if  i_clock_if();
    assign tb_clock = i_clock_if.clock;

    // Instantiation of RESET uVC interface signal
    reset_if  i_reset_if(.clk(tb_clock));
    assign tb_reset_n = i_reset_if.reset_n;

    // Instantiation of PARALLEL_DATA uVC interface signal
    parallel_data_if  i_parallel_data_if(.clk(tb_clock),.rst_n(tb_reset_n));
    assign tb_data_valid = i_parallel_data_if.data_valid;
    assign tb_data = i_parallel_data_if.data;
    assign tb_parity_error = 1'b0;

    // Instantiation of DATA_FIFO uVC interface signal
    data_fifo_if  i_data_fifo_if(.clk(tb_clock),.rst_n(tb_reset_n));
    assign tb_fifo_request_data = i_data_fifo_if.fifo_request_data;
    assign i_data_fifo_if.fifo_empty = tb_fifo_empty;
    assign i_data_fifo_if.fifo_overflow = tb_fifo_overflow;
    assign i_data_fifo_if.fifo_data = tb_fifo_data;

    // Make a small bit of delay on the clock to the DUT to avoid delta time problem
    assign #1ns tb_clock_d = tb_clock;

    // Instantiation of the DATA_FIFO RTL top
    data_to_fifo data_to_fifo_dut 
    (
        .clock(tb_clock_d),
        .reset_n(tb_reset_n),
        .data_valid(tb_data_valid),
        .data(tb_data),
        .parity_error(tb_parity_error),
        .fifo_request_data(tb_fifo_request_data),
        .fifo_empty(tb_fifo_empty),
        .fifo_overflow(tb_fifo_overflow),
        .fifo_data(tb_fifo_data)
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
        m_top_config.m_parallel_data_config.m_vif = i_parallel_data_if;
        m_top_config.m_data_fifo_config.m_vif = i_data_fifo_if;
    end

    // Start UVM test_base environment
    initial begin
        run_test("basic_test");
    end

endmodule
