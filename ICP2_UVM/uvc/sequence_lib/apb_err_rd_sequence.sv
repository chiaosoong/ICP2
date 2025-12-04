class apb_err_rd_sequence extends apb_base_sequence;
    `uvm_object_utils(apb_err_rd_sequence)
    
    bit rand_addr;  // flag for enabling randomized address
    
    // constructor function
    function new(string name="apb_err_rd_sequence");
        super.new(name);
    endfunction: new
    
    // body
    virtual task body();
        // construct seq item
        item = apb_seq_item::type_id::create("item");
        
        start_item(item);
            // turn off default constraints for address
            item.addr_constr.constraint_mode(0);
            // turn off op_type vs addr constraint to allow invalid combinations
            item.addr_op_type_constr.constraint_mode(0);

            if(rand_addr) begin  // random address
                assert(item.randomize() with {item.op_type == READ;
                                              // Generate address NOT in the valid read set
                                              !(item.ADDR inside {OUTPUT_ADDR, CA_FINISHED_ADDR, ALL_READ_DONE_ADDR});
                            });
            end
            else begin  // directed address
                assert(item.randomize() with {item.op_type == READ;
                                              item.ADDR == local::addr;
                            });
            end
            
        finish_item(item);    
    endtask: body
endclass: apb_err_rd_sequence