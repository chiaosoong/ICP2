//------------------------------------------------------------------------------
// Testbench package.
//
// The tb_pkg package provides a collection of files and
// uVCs that are used for testbench development
//
// It includes:
// - Clock uVC
// - Reset uVC
// - Serial Data uVC
// - Parallel Data uVC
// - Test Environment
// - Scoreboard
// - Tests
//
// The package also imports the UVM package and includes
// the necessary UVM macros to support UVM-based testbenches
//
//------------------------------------------------------------------------------
`timescale 1ns/1ns 
package tb_pkg;
    // Import from UVM package
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    // Include files from the clock uVC
    `include "clock_config.svh"
    `include "clock_driver.svh"
    `include "clock_agent.svh"
    // Include files from the reset uVC
    `include "reset_seq_item.svh"
    `include "reset_seq.svh"
    `include "reset_config.svh"
    `include "reset_driver.svh"
    `include "reset_monitor.svh"
    `include "reset_agent.svh"
    // Include files from the serial data uVC
    `include "serial_data_seq_item.svh"
    `include "serial_data_seq.svh"
    `include "serial_data_config.svh"
    `include "serial_data_driver.svh"
    `include "serial_data_monitor.svh"
    `include "serial_data_agent.svh"
    // Include files from the parallel data uVC
    `include "parallel_data_seq_item.svh"
    `include "parallel_data_config.svh"
    `include "parallel_data_driver.svh"
    `include "parallel_data_monitor.svh"
    `include "parallel_data_agent.svh"
    // Include files from the TB
    `include "scoreboard.svh"
    `include "top_config.svh"
    `include "tb_env.svh"
    `include "base_test.svh"
    `include "basic_test.svh"
    `include "parity_test.svh"
endpackage: tb_pkg
