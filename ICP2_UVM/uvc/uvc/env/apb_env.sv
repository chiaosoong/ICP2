// =================================================================================
// APB Test Environment
// Description: Top-level environment component that instantiates and connects
//              the APB master agent and scoreboard. 
// =================================================================================
class apb_environment extends uvm_env;
    `uvm_component_utils(apb_environment)
    
    // instance of env_cfg
    apb_env_config  apb_env_cfg;
    // instance of scoreboard
    apb_scoreboard  apb_scb;
    // instance of agent
    apb_mstr_agent  apb_mstr_agnt;
    
    // constructor function
    function new(string name="apb_environment", uvm_component parent);
        super.new(name, parent);
    endfunction: new
    
    // =================================================================================
    // build_phase
    // Description: retrieves environment configuration from uvm_config_db,
    //              creates the APB master agent (always), conditionally creates
    //              the scoreboard, and publishes agent configuration to config DB
    //              so the agent can retrieve it during its own build_phase.
    // =================================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // retrieve environment configuration from uvm_config_db (fatal if not found)
        if(!uvm_config_db#(apb_env_config)::get(this, "", "APB_ENV_CFG", apb_env_cfg)) begin
            `uvm_fatal("ENV_CFG Not Found ERROR", $sformatf("Unable to retrieve env_cfg from uvm_config_db"))
        end
        
        // always create the APB master agent
        apb_mstr_agnt = apb_mstr_agent::type_id::create("apb_mstr_agnt", this);
        
        // create scoreboard only if enabled in environment configuration
        if(apb_env_cfg.has_scoreboard) begin
            apb_scb = apb_scoreboard::type_id::create("apb_scb", this);
        end
        
        // publish the agent configuration to config DB so agent can retrieve it
        uvm_config_db#(apb_mstr_agent_config)::set(null, "*", "APB_MSTR_AGNT_CFG", apb_env_cfg.apb_mstr_agnt_cfg);
    endfunction: build_phase
    
    // =================================================================================
    // connect_phase
    // Description: wire up analysis ports between agent (driver/monitor) and
    //              scoreboard if the scoreboard is enabled. This establishes the
    //              data flow: driver -> scoreboard and monitor -> scoreboard.
    // =================================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // connect scoreboard to monitor and driver if scoreboard was created
        if(apb_env_cfg.has_scoreboard) begin
            // connect monitor's analysis port (ap) to scoreboard's monitor import (ap_mntr2scb)
            apb_mstr_agnt.apb_mntr.ap.connect(apb_scb.ap_mntr2scb);
            // connect driver's analysis port (drv2scb) to scoreboard's driver import (ap_drv2scb)
            apb_mstr_agnt.apb_mstr_drvr.drv2scb.connect(apb_scb.ap_drv2scb);
        end    
    endfunction: connect_phase
    
    // run_phase
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask: run_phase
endclass: apb_environment

