class apb_base_sequence extends uvm_sequence#(apb_seq_item, apb_seq_item);
    `uvm_object_utils(apb_base_sequence)
    
    // sequence fields
    bit [`ADDR_WIDTH-1:0] addr; // for holding addr
    bit [`DATA_WIDTH-1:0] data; // for holding data

    // seq_item instance
    apb_seq_item item;
    
    // constructor function
    function new(string name="apb_base_sequence");
        super.new(name);
    endfunction: new
    
    virtual task body();
    
    endtask: body
endclass: apb_base_sequence