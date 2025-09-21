//------------------------------------------------------------------------------
// serial_data_config class
//
// The configuration of clock.
// This class contains the configuration of serial data, and the virtual interface.
//
// The configuration of serial data includes:
//  is_active     - indicate whether the sequencer and driver are activated.
//  has_monitor   - indicate whether the monitor is activated.
//  parity_enable( not yet) - indicate whether the even parity is enabled
//                  by adding exstra bit in the serial data as the last serial bit
//
// The virtual interface includes:
//  m_vif - the serial data uVC virtual serial_data_if interface.
//
//------------------------------------------------------------------------------
class serial_data_config extends uvm_object;

    // The Sequencer and driver are activated
    bit is_active = 1;
    // The monitor is active. 
    bit has_monitor = 1;
    //TASK 2.2: Parity bit enabled -> add parity bit as the 9th serial bit
    
    // serial_data uVC virtual SERIAL_DATA_IF interface.
    virtual serial_data_if m_vif;

    `uvm_object_utils_begin(serial_data_config)
    `uvm_field_int(is_active,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(has_monitor,UVM_ALL_ON|UVM_DEC)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new (string name = "serial_data_config");
        super.new(name);
    endfunction : new

endclass : serial_data_config
