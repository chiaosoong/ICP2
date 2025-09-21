//------------------------------------------------------------------------------
// parallel_data_seq class
//
// This sequence is used to generate random parallel data with/without parirt error.
//
// The sequence has two constraints on the start bit delay and start bit length.
// The start delay must be less than 256 clocks,
// The parity error should only be weighted about 1 per 10 times data.
//
//------------------------------------------------------------------------------
class parallel_data_seq extends uvm_sequence #(parallel_data_seq_item);
    `uvm_object_utils(parallel_data_seq)

    // Random delay before activate start bit
    rand int unsigned start_delay;
    // Random data
    rand bit[7:0] data;
    // Set parity error for the data
    rand bit parity_error;

    // Random constraint start bit delay should be less than 256
    constraint delay_c {
        start_delay < 256;
    }
    // Random constraint parity error should only be weighted about 1 per 10 times data
    constraint parity_error_c {
        parity_error dist { 0 := 10, 1 := 1 };
    }

    //------------------------------------------------------------------------------
    // The constructor for the sequence.
    //------------------------------------------------------------------------------
    function new(string name="parallel_data_seq");
        super.new(name);
    endfunction : new

    //------------------------------------------------------------------------------
    // The main task to be executed within the sequence.
    //------------------------------------------------------------------------------
    task body();
        // Create sequence
        req = parallel_data_seq_item::type_id::create("req");
        // Wait for sequencer ready
        start_item(req);
        // Randomize sequence item
        if (!(req.randomize() with {
            req.start_delay == local::start_delay;
            req.data == local::data;
            req.parity_error == local::parity_error;
        })) `uvm_fatal(get_name(), "Failed to randomize")
        // Send to sequencer
        finish_item(req);
        // Wait until request is completed
        get_response(rsp, req.get_transaction_id());
    endtask : body

endclass : parallel_data_seq
