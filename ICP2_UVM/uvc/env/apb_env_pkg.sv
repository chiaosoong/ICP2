package apb_env_pkg;
    // include and import uvm_pkg
    `include "uvm_macros.svh"
    import uvm_pkg::*;
    
    // import agent_pkg
    import apb_agent_pkg::*;
    
    `include "tb_defines.sv"
    
    // include env files
    `include "apb_env_config.sv"
    `include "apb_scoreboard.sv"
    `include "apb_env.sv"
endpackage: apb_env_pkg