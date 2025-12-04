class apb_rd_sequence extends apb_base_sequence;
    `uvm_object_utils(apb_rd_sequence)
    
    bit rand_addr;  // flag for randomize addr
    
    // constructor function
    function new(string name="apb_rd_sequence");
        super.new(name);
    endfunction: new
    
    virtual task body();
//        $display("RD_SEQ:: addr:%0h", addr);
        if(rand_addr) begin  // random read 
            `uvm_do_with(item, {item.op_type == 0;})
        end
        else begin  // directed read
            `uvm_do_with(item, {
                                item.op_type == 0;
                                item.ADDR == local::addr;
                         })
        end
    endtask: body
endclass: apb_rd_sequence