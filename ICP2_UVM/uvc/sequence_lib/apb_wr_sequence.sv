class apb_wr_sequence extends apb_base_sequence;
    `uvm_object_utils(apb_wr_sequence)
    
    bit rand_addr;  // flag for enabling randomized address
    bit rand_data;  // flag for enabling randomized data
    
    // constructor function
    function new(string name="apb_wr_sequence");
        super.new(name);
    endfunction: new
    
    // body
    virtual task body();
        if(rand_data) begin  // random data
            if(rand_addr) begin  // random address
                `uvm_do_with(item, {item.op_type == WRITE;})
            end
            else begin  // directed address
                `uvm_do_with(item, {
                                    item.op_type == WRITE; 
                                    item.ADDR == local::addr;
                            })
            end
        end
        else begin  // directed data
            if(rand_addr) begin  // random address
                `uvm_do_with(item, {
                                    item.op_type == WRITE;
                                    item.DATA == local::data;
                                   })
            end
            else begin  // directed address
                `uvm_do_with(item, {
                                    item.op_type == WRITE; 
                                    item.ADDR == local::addr;
                                    item.DATA == local::data;
                            })
            end
        end
    endtask: body
endclass: apb_wr_sequence