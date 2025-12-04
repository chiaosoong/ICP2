class apb_err_wr_sequence extends apb_base_sequence;
    `uvm_object_utils(apb_err_wr_sequence)
    
    bit rand_addr;  // flag for enabling randomized address
    bit rand_data;  // flag for enabling randomized data
    
    // constructor function
    function new(string name="apb_err_wr_sequence");
        super.new(name);
    endfunction: new
    
    // body
    virtual task body();
        // construct seq item
        item = apb_seq_item::type_id::create("item");
        
        start_item(item);
            // turn off default constraints for address to allow invalid addresses
            item.addr_constr.constraint_mode(0);
            // turn off op_type vs addr constraint to allow invalid combinations
            item.addr_op_type_constr.constraint_mode(0);

            if(rand_data) begin  // random data
                if(rand_addr) begin  // random address
                    assert(item.randomize() with {item.op_type == WRITE;
                                                  // Generate address NOT in the valid write set
                                                  !(item.ADDR inside {DATA_ADDR, INPUT_MODE_ADDR, KERNEL_MODE_ADDR, READ_CTRL_ADDR});
                                });
                end
                else begin  // directed address
                    assert(item.randomize() with {item.op_type == WRITE;
                                                  item.ADDR == local::addr;
                                });
                end
            end
            else begin  // directed data
                if(rand_addr) begin  // random address
                    assert(item.randomize() with {item.op_type == WRITE;
                                                  // Generate address NOT in the valid write set
                                                  !(item.ADDR inside {DATA_ADDR, INPUT_MODE_ADDR, KERNEL_MODE_ADDR, READ_CTRL_ADDR});
                                                  item.DATA == local::data;
                                });
                end
                else begin  // directed address
                    assert(item.randomize() with {item.op_type == WRITE;
                                                  item.ADDR == local::addr;
                                                  item.DATA == local::data;
                                });
                end
            end
        finish_item(item);    
    endtask: body
endclass: apb_err_wr_sequence