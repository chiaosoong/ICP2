//------------------------------------------------------------------------------
// data_fifo_config class
//
// The configuration of clock.
// This class contains the configuration of data fifo, and the virtual interface.
//
// The configuration of parallel data includes:
//  is_active   - indicate whether the sequencer and driver are activated.
//  has_monitor - indicate whether the monitor is activated.
//  fifo_depth  - fifo depth in the DUT.
//
// The virtual interface includes:
//  m_vif - The data fifo uVC virtual data_fifo_if interface.
//
//------------------------------------------------------------------------------
class data_fifo_config extends uvm_object;

    // The Sequencer and driver are activated
    bit is_active = 1;
    // The monitor is active. 
    bit has_monitor = 1;
    // fifo depth in the DUT
    bit fifo_depth = 4;
    // data_fifo uVC virtual DATA_FIFO_IF interface.
    virtual data_fifo_if m_vif;

    `uvm_object_utils_begin(data_fifo_config)
    `uvm_field_int(is_active,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(has_monitor,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(fifo_depth,UVM_ALL_ON|UVM_DEC)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new (string name = "data_fifo_config");
        super.new(name);
    endfunction : new

endclass : data_fifo_config
