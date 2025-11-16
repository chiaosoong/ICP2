package apb_agent_pkg;
    // include and import uvm_pkg
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    `include "tb_defines.sv"
    
    // typedefines
    typedef enum {READ=0, WRITE=1} op_type_e;
    
    // APB Register Address Enum
    typedef enum logic [11:0] {
        DATA_ADDR           = 12'h000,  // 0x000 - Data write register
        INPUT_MODE_ADDR     = 12'h008,  // 0x008 - Input mode select
        KERNEL_MODE_ADDR    = 12'h00C,  // 0x00C - Kernel mode select
        OUTPUT_ADDR         = 12'h014,  // 0x014 - Output read register
        CA_FINISHED_ADDR    = 12'h018,  // 0x018 - CA finished status
        ALL_READ_DONE_ADDR  = 12'h01C,  // 0x01C - All read done status
        READ_CTRL_ADDR      = 12'h020   // 0x020 - Burst read control
    } apb_register_addr_e;

    // include agent files
    `include "apb_seq_item.sv"
    //`include "apb_read_ofm_seq.sv"
    //`include "apb_write_seq.sv"
    `include "apb_mstr_agent_config.sv"
    `include "apb_mstr_driver.sv"
    `include "apb_monitor.sv"
    `include "apb_mstr_sequencer.sv"
    `include "apb_coverage_monitor.sv"
    `include "apb_mstr_agent.sv"
endpackage: apb_agent_pkg