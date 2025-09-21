//------------------------------------------------------------------------------
// parallel_data_seq_item class
//
// This class represents a sequence item for parallel data transmission.
// 
// A sequence item contains:
// - start_delay: clock delay before sending data
// - data: the data to be sent
// - parity_error: indicates if a parity error occurred during transmission
// 
//------------------------------------------------------------------------------
class parallel_data_seq_item extends uvm_sequence_item;

    // Clock delay before send data
    rand int unsigned start_delay;
    // Parallel data 
    rand bit [7:0] data;
    // Parity error during trasmission
    rand bit parity_error;

    // Specify how variables shall be printed out
    `uvm_object_utils_begin(parallel_data_seq_item)
    `uvm_field_int(start_delay,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(data,UVM_ALL_ON|UVM_DEC)
    `uvm_field_int(parity_error,UVM_ALL_ON|UVM_DEC)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new (string name = "parallel_data_seq_item");
        super.new(name);
    endfunction : new

endclass : parallel_data_seq_item
