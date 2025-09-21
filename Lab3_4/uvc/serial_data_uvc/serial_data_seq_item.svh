//------------------------------------------------------------------------------
// serial_data_seq_item class
//
// This class is used to represent the serial data sequence item
//
// This class is used to represent the serial data sequence item for
// the test bench. It is used to create a serial data sequence with 
// the following fields:
//    start_bit_delay - The delay in clock cycles before start bit is activated
//    start_bit_length - The length in clock cycles of the start bit
//    serial_data - The data to transmit
//    parity_error - Whether to introduce a parity error
//    monitor_start_bit_value - The actual value of the start bit
//    monitor_start_bit_valid - Whether the start bit is valid
//    monitor_data_valid - Whether the serial data is valid
//
//------------------------------------------------------------------------------
class serial_data_seq_item extends uvm_sequence_item;

    // Clock delay before activate start bit
    rand bit [7:0] start_bit_delay;
    // Clock length before deactivate start bit
    rand bit [7:0] start_bit_length;
    // Array with serial data bits
    rand bit [7:0] serial_data;
    // Generate parity error if parity is enabled
    //TASK 2.4: Introduce a random bit for parity_error.
    
    // Monitor start bit value
    bit monitor_start_bit_value;
    // Monitor start bit value valid
    bit monitor_start_bit_valid;
    // Monitor finshed of serial data
    bit monitor_data_valid;

    // Specify how variables shall be printed out
    `uvm_object_utils_begin(serial_data_seq_item)
    `uvm_field_int(start_bit_delay,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(start_bit_length,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(serial_data,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(monitor_start_bit_value,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(monitor_start_bit_valid,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(monitor_data_valid,UVM_ALL_ON|UVM_DEC)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new (string name = "serial_data_seq_item");
        super.new(name);
    endfunction : new

endclass : serial_data_seq_item
