//------------------------------------------------------------------------------
// top_config class
//
// Top level configuration object for top level component.
// This class is intended to be used by the UVM configuration database.
//
// It contains the configuration objects for each agent in the system and
// configures them appropriately for the test.
//
//------------------------------------------------------------------------------
class top_config extends uvm_object;
    `uvm_object_param_utils(top_config)

    // clock configuration instance for clock agent uVC.
    clock_config m_clock_config;
    // reset configuration instance for reset agent uVC.
    reset_config m_reset_config;
    // serial_data configuration instance for serial_data agent uVC.
    serial_data_config m_serial_data_config;
    // parallel_data configuration instance for parallel_data agent uVC.
    parallel_data_config m_parallel_data_config;

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new (string name="top_config");
        super.new(name);
        // Create and configure clock uVC with 10ns clock generation
        m_clock_config = new("m_clock_config");
        m_clock_config.is_active = 1;
        m_clock_config.clock_period = 10;
        // Create and configure reset uVC configuration with driver and monitor
        m_reset_config = new("m_reset_config");
        m_reset_config.is_active = 1;
        m_reset_config.has_monitor = 1;
        // Create and configure serial_data uVC configuration with driver and monitor
        m_serial_data_config = new("m_serial_data_config");
        m_serial_data_config.is_active = 1;
        m_serial_data_config.has_monitor = 1;
        //TASK 2:

        // Create and configure parallel_data uVC configuration with only monitor
        m_parallel_data_config = new("m_parallel_data_config");
        m_parallel_data_config.is_active = 0;
        m_parallel_data_config.has_monitor = 1;
    endfunction : new

endclass : top_config
