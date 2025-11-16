// =================================================================================
// apb_seq_item
// Description:
//   UVM sequence item representing a single APB transaction used by the
//   APB master sequencer/driver. The item contains an address, data payload
//   and an operation type (READ/WRITE). Several constraints enforce legal
//   address choices and limit which DATA bits are meaningful for each
//   register (so randomization does not produce illegal/unused bit patterns).
// =================================================================================
class apb_seq_item extends uvm_sequence_item;
    // Transaction fields
    rand bit [`ADDR_WIDTH-1:0]   ADDR;      // Address (width follows `ADDR_WIDTH`)
    rand bit [`DATA_WIDTH-1:0]   DATA;      // Data payload (width follows `DATA_WIDTH`)
    rand op_type_e              op_type;   // Operation type enum: READ or WRITE

    // constructor function
    function new(string name="apb_seq_item");
        super.new(name);
    endfunction: new
    
    // -----------------------------------------------------------------
    // Address constraint
    // Restricts randomized ADDR values to the set of valid APB register
    // addresses defined in the register map (these symbols are defined in
    // the shared package). This prevents generation of illegal addresses
    // during randomized tests.
    // -----------------------------------------------------------------
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
    
    // -----------------------------------------------------------------
    // Operation type constraint
    // Ensure op_type is either a WRITE or READ (helps randomization tools).
    // -----------------------------------------------------------------
    constraint op_type_constr{
        op_type inside {WRITE, READ};
    }
    
    // -----------------------------------------------------------------
    // Address <-> Operation relationship
    // Constrains which addresses can be used with WRITE vs READ operations.
    // Example: DATA_ADDR is a write-only register while OUTPUT_ADDR is
    // read-only. This prevents illegal op_type/ADDR combinations.
    // -----------------------------------------------------------------
    constraint addr_op_type_constr{
        if (op_type == WRITE) {
            ADDR inside {DATA_ADDR, INPUT_MODE_ADDR, KERNEL_MODE_ADDR, READ_CTRL_ADDR};
        }
        else if (op_type == READ) {
            ADDR inside {OUTPUT_ADDR, CA_FINISHED_ADDR, ALL_READ_DONE_ADDR};
        }
    }
    
    // -----------------------------------------------------------------
    // DATA field constraints
    // Limit which DATA bits may be driven depending on the target register.
    // - Writes to `DATA_ADDR` only use the lower 8 bits (DATA[7:0])
    // - Mode-control registers (`INPUT_MODE_ADDR`, `KERNEL_MODE_ADDR`) only
    //   use bit[0] as the enable/select bit
    // - `READ_CTRL_ADDR` uses bit[0] to trigger a burst read command
    // These constraints zero the unused bits so randomized DATA values are
    // meaningful for the DUT and easier to reason about in debugging.
    // -----------------------------------------------------------------
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