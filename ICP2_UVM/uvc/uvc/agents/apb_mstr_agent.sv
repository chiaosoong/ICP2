// =================================================================================
// APB Master Agent
// Description: Encapsulates driver, sequencer, monitor and optional coverage
//              monitor for APB master functionality. The agent reads its
//              configuration from apb_mstr_agent_config and builds/connects
//              components according to the configuration.
// =================================================================================
class apb_mstr_agent extends uvm_agent;
    `uvm_component_utils(apb_mstr_agent)
    
    // agent config instance
    apb_mstr_agent_config   apb_mstr_agnt_cfg;
    
    // apb_mstr_driver instance
    apb_master_driver       apb_mstr_drvr;
    
    // apb_monitor instance
    apb_monitor             apb_mntr;
    
    // apb_coverage_monitor instance
    apb_coverage_monitor    apb_cov_mntr;
    
    // apb_mstr_sequencer instance
    apb_mstr_sequencer      apb_mstr_seqr;
    
    // constructor function
    function new(string name="apb_mstr_agent", uvm_component parent);
        super.new(name, parent);
    endfunction: new

    // =================================================================================
    // build_phase
    // Description: retrieve agent configuration from uvm_config_db and create
    //              the monitor unconditionally. Create driver and sequencer
    //              only if agent is configured as ACTIVE. Create the coverage
    //              monitor if functional coverage is enabled in the config.
    // =================================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // get agent config from uvm_config_db (fatal if not found)
        if(!uvm_config_db#(apb_mstr_agent_config)::get(this, "", "APB_MSTR_AGNT_CFG", apb_mstr_agnt_cfg)) begin
            `uvm_fatal("AGENT CONFIG OBJECT NOT FOUND ERROR", $sformatf("ERROR:: Unable to retrieve apb_mstr_agnt_cfg from uvm_config_db"))
        end

        // always build monitor to observe DUT APB traffic
        apb_mntr = apb_monitor::type_id::create("apb_mntr", this);

        // build driver and sequencer only if agent is active (agent will drive DUT)
        if(apb_mstr_agnt_cfg.is_active == UVM_ACTIVE) begin
            apb_mstr_drvr = apb_master_driver::type_id::create("apb_mstr_drvr", this);
            apb_mstr_seqr = apb_mstr_sequencer::type_id::create("apb_mstr_seqr", this);
        end

        // build coverage monitor if functional coverage is enabled in config
        if(apb_mstr_agnt_cfg.has_functional_coverage) begin
            apb_cov_mntr = apb_coverage_monitor::type_id::create("apb_cov_mntr", this);
        end
    endfunction: build_phase

    // =================================================================================
    // connect_phase
    // Description: wire up the driver/sequencer, monitor and coverage monitor
    //              according to the configuration. Assign the virtual interface
    //              handle from the config to the monitor and driver.
    // =================================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // If agent is active, connect driver to sequencer and pass configuration
        if(apb_mstr_agnt_cfg.is_active == UVM_ACTIVE) begin
            // pass the config object to the driver for runtime behavior control
            apb_mstr_drvr.apb_mstr_agnt_cfg = apb_mstr_agnt_cfg;
            // give the driver access to the virtual interface
            apb_mstr_drvr.apb_intf = apb_mstr_agnt_cfg.apb_intf;

            // connect the driver's sequence item port to the sequencer
            apb_mstr_drvr.seq_item_port.connect(apb_mstr_seqr.seq_item_export);
        end

        // connect monitor -> coverage monitor if coverage was enabled
        if(apb_mstr_agnt_cfg.has_functional_coverage) begin
            apb_mntr.mntr2cov.connect(apb_cov_mntr.analysis_export);
        end

        // connect monitor's virtual interface and config
        apb_mntr.apb_intf = apb_mstr_agnt_cfg.apb_intf;
        apb_mntr.apb_mstr_agnt_cfg = apb_mstr_agnt_cfg;
    endfunction: connect_phase
endclass: apb_mstr_agent