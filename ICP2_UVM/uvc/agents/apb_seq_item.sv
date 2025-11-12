class apb_seq_item extends uvm_sequence_item;
    rand bit [`ADDR_WIDTH-1:0]   ADDR;      // Address
    rand bit [`DATA_WIDTH-1:0]   DATA;      // data
    rand op_type_e              op_type;    // operation type

    // constructor function
    function new(string name="apb_seq_item");
        super.new(name);
    endfunction: new
    
    // default addr constraints - only valid APB register addresses
    constraint addr_constr{
        ADDR inside {
            DATA_ADDR,
            INPUT_MODE_ADDR,
            KERNEL_MODE_ADDR,
            OUTPUT_ADDR,
            CA_FINISHED_ADDR,
            ALL_READ_DONE_ADDR,
            READ_CTRL_ADDR
        };
    }
    
    // default operation type constraints
    constraint op_type_constr{
        op_type inside {WRITE, READ};
    }
    
    // ADDR and OP_TYPE relationship constraints
    // WRITE operations allowed on: DATA, INPUT_MODE, KERNEL_MODE, READ_CTRL
    // READ operations allowed on: OUTPUT, CA_FINISHED, ALL_READ_DONE
    constraint addr_op_type_constr{
        if (op_type == WRITE) {
            ADDR inside {DATA_ADDR, INPUT_MODE_ADDR, KERNEL_MODE_ADDR, READ_CTRL_ADDR};
        }
        else if (op_type == READ) {
            ADDR inside {OUTPUT_ADDR, CA_FINISHED_ADDR, ALL_READ_DONE_ADDR};
        }
    }
    
    // DATA constraints based on ADDR
    // DATA[0] for INPUT_MODE/KERNEL_MODE control bits
    // DATA[7:0] for DATA_ADDR writes
    // DATA[0] for READ_CTRL burst command
    constraint data_constr{
        if (ADDR == DATA_ADDR) {
            DATA[31:8] == 24'h0;  // Only use lower 8 bits for data
        }
        else if (ADDR == INPUT_MODE_ADDR || ADDR == KERNEL_MODE_ADDR) {
            DATA[31:1] == 31'h0;  // Only use bit[0] for mode select
        }
        else if (ADDR == READ_CTRL_ADDR) {
            DATA[31:1] == 31'h0;  // Only use bit[0] for burst read command
        }
    }
    
    // register fields with uvm_factory
    `uvm_object_utils_begin(apb_seq_item)
        `uvm_field_int(ADDR, UVM_ALL_ON)
        `uvm_field_int(DATA, UVM_ALL_ON)
        `uvm_field_enum(op_type_e, op_type, UVM_ALL_ON)
    `uvm_object_utils_end
    
endclass : apb_seq_item