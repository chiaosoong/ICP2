//------------------------------------------------------------------------------
// data_fifo_seq class
//
// This sequence is used to generate random data fifo with/without parity error.
//
// The sequence has two constraints on ....
//
//------------------------------------------------------------------------------
class data_fifo_seq extends uvm_sequence #(data_fifo_seq_item);
    `uvm_object_utils(data_fifo_seq)

    // Random response start delay
    rand int unsigned start_delay;
    // Random fifo request data
    rand bit fifo_request;

    // Random constraint start bit delay should be less than 256
    constraint delay_c {
        start_delay < 256;
    }

    //------------------------------------------------------------------------------
    // The constructor for the sequence.
    //------------------------------------------------------------------------------
    function new(string name="data_fifo_seq");
        super.new(name);
    endfunction : new

    //------------------------------------------------------------------------------
    // The main task to be executed within the sequence.
    //------------------------------------------------------------------------------
    task body();
        // Create sequence
        req = data_fifo_seq_item::type_id::create("req");
        // Wait for sequencer ready
        start_item(req);
        // Randomize sequence item
        if (!(req.randomize() with {
            req.start_delay == local::start_delay;
            req.fifo_request_data == local::fifo_request;
            req.fifo_data == 0;  // Not used
            req.fifo_overflow == 0;  // Not used
            req.fifo_empty == 0;  // Not used
        })) `uvm_fatal(get_name(), "Failed to randomize")
        // Send to sequencer
        finish_item(req);
        // Wait until request is completed
        get_response(rsp, req.get_transaction_id());
    endtask : body

endclass : data_fifo_seq
