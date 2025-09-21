//------------------------------------------------------------------------------
// serial_data_seq class
//
// This sequence is used to generate random serial data with start bit delay and length.
//
// The sequence has two constraints on the start bit delay and start bit length.
// The start bit delay must be less than 10 clocks,
// The start bit length must be less than 10 clocks.
//
//------------------------------------------------------------------------------
class serial_data_seq extends uvm_sequence #(serial_data_seq_item);
    `uvm_object_utils(serial_data_seq)

    // Random delay before activate start bit
    rand int unsigned start_delay;
    // Random start bit length
    rand int unsigned start_length;
    // Random data
    rand bit[7:0] data;

    // Random constraint start bit delay must be less than 10
    constraint delay_c {
        start_delay < 10;
    }
    // Random constraint start bit length must be less than 10
    constraint length_c {
        start_length < 10;
    }

    //------------------------------------------------------------------------------
    // The constructor for the sequence.
    //------------------------------------------------------------------------------
    function new(string name="serial_data_seq");
        super.new(name);
    endfunction : new

    //------------------------------------------------------------------------------
    // The main task to be executed within the sequence.
    //------------------------------------------------------------------------------
    task body();
        // Create sequence
        req = serial_data_seq_item::type_id::create("req");
        // Wait for sequencer ready
        start_item(req);
        // Randomize sequence item
        if (!(req.randomize() with {
            req.start_bit_delay == local::start_delay;
            req.start_bit_length == local::start_length;
            req.serial_data == local::data;
        })) `uvm_fatal(get_name(), "Failed to randomize")
        // Send to sequencer
        finish_item(req);
        // Wait until request is completed
        get_response(rsp, req.get_transaction_id());
    endtask : body

endclass : serial_data_seq
