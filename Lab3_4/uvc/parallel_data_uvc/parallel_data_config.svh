//------------------------------------------------------------------------------
// parallel_data_config class
//
// The configuration of clock.
// This class contains the configuration of parallel data, and the virtual interface.
//
// The configuration of parallel data includes:
//  is_active   - indicate whether the sequencer and driver are activated.
//  has_monitor - indicate whether the monitor is activated.
//
// The virtual interface includes:
//  m_vif - the parallel data uVC virtual parallel_data_if interface.
//
//------------------------------------------------------------------------------
class parallel_data_config extends uvm_object;

    // The Sequencer and driver are activated
    bit is_active = 1;
    // The monitor is active. 
    bit has_monitor = 1;
    // Parallel_data uVC virtual PARALLEL_DATA_IF interface.
    virtual parallel_data_if m_vif;

    `uvm_object_utils_begin(parallel_data_config)
    `uvm_field_int(is_active,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(has_monitor,UVM_ALL_ON|UVM_DEC)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new (string name = "parallel_data_config");
        super.new(name);
    endfunction : new

endclass : parallel_data_config
