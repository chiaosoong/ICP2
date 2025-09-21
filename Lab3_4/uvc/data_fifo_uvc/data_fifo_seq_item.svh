//------------------------------------------------------------------------------
// data_fifo_seq_item class
//
// This class represents a sequence item for data FIFO
// 
// A sequence item contains:
// - start_delay: clock delay before sending data
// - fifo_request_data: a signal that indicates ready to read fifo data
// - fifo_data: FIFO 8-bit data signal.
// - fifo_overflow: a signal that indicate FIFO buffer has overflow
// - fifo_empty: a signal that indicate no more FIFO data
// 
//------------------------------------------------------------------------------
class data_fifo_seq_item extends uvm_sequence_item;

    // Clock delay before send data
    rand int unsigned start_delay;
    // FIFO request data 
    rand bit fifo_request_data;
    // FIFO data 
    rand bit [7:0] fifo_data;
    // FIFO overflow
    rand bit fifo_overflow;
    // FIFO empty 
    rand bit fifo_empty;

    // Specify how variables shall be printed out
    `uvm_object_utils_begin(data_fifo_seq_item)
    `uvm_field_int(start_delay,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(fifo_request_data,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(fifo_data,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(fifo_empty,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(fifo_overflow,UVM_ALL_ON|UVM_DEC)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new (string name = "data_fifo_seq_item");
        super.new(name);
    endfunction : new

endclass : data_fifo_seq_item
