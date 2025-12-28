// =================================================================================
// Monitor: passively sample APB interface signals and publish transactions
// Description：This component converts observed transfers into `apb_seq_item` and
// forwards them to analysis ports for scoreboard and coverage collection.
// =================================================================================
class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    
    // Agent configuration handle
    // Holds runtime options (e.g. `exp_err`) supplied by test via config DB.
    apb_mstr_agent_config   apb_mstr_agnt_cfg;
    
    // Virtual interface handle
    // Used to read APB signals (PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY, PSLVERR)
    virtual apb_interface apb_intf;
    
    // Analysis ports
    uvm_analysis_port#(apb_seq_item)    ap;         // analysis port to be connected with scoreboard
    uvm_analysis_port#(apb_seq_item)    mntr2cov;   // analysis port to be connected with coverage monitor      
    
    // Constructor: create analysis ports used to publish sampled transactions
    function new(string name="apb_monitor", uvm_component parent);
        super.new(name, parent);
        
        // instantiate analysis ports
        ap = new("ap", this);
        mntr2cov = new("mntr2cov", this);
    endfunction: new 
    
    // build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction: build_phase
    
    // connect_phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction: connect_phase
    
    // ======================================================
    // run_phase: continuously sample APB transfers when PSEL/PENABLE indicate an active transfer.
    // For each completed transfer (when PREADY==1) create an `apb_seq_item` and
    // forward it to appropriate analysis ports or report PSLVERR according to config.
    // ======================================================
    virtual task run_phase(uvm_phase phase);
        apb_seq_item item;
        super.run_phase(phase);
        
        // Main monitoring loop: wait for transfers and sample at response time (PREADY)
        forever begin
            @(apb_intf.cb);
            // Capture transaction on the cycle it completes (PSEL=1, PENABLE=1, PREADY=1)
            if (apb_intf.PSEL && apb_intf.PENABLE && apb_intf.PREADY) begin
                item = apb_seq_item::type_id::create("item");
                item.ADDR = apb_intf.PADDR;
                
                if (apb_intf.PWRITE) begin
                    item.op_type = WRITE;
                    item.DATA = apb_intf.PWDATA;
                    
                    // Error handling
                    if (apb_intf.PSLVERR) begin
                         if(apb_mstr_agnt_cfg.exp_err) begin
                             `uvm_info("DUT_ERROR_TEST", "Detected expected PSLVERR on WRITE", UVM_NONE)
                         end else begin
                             `uvm_error("DUT_OP_ERROR", "Unexpected PSLVERR on WRITE")
                         end
                    end else begin
                        if(apb_mstr_agnt_cfg.exp_err) begin
                             `uvm_error("DUT_ERROR_TEST", "Can't detect expected PSLVERR on WRITE")
                        end
                        // Send to coverage
                        mntr2cov.write(item);
                    end
                    
                end else begin
                    item.op_type = READ;
                    item.DATA = apb_intf.PRDATA;
                    
                    // Error handling
                    if (apb_intf.PSLVERR) begin
                         if(apb_mstr_agnt_cfg.exp_err) begin
                             `uvm_info("DUT_ERROR_TEST", "Detected expected PSLVERR on READ", UVM_NONE)
                         end else begin
                             `uvm_error("DUT_OP_ERROR", "Unexpected PSLVERR on READ")
                         end
                    end else begin
                        if(apb_mstr_agnt_cfg.exp_err) begin
                             `uvm_error("DUT_ERROR_TEST", "Can't detect expected PSLVERR on READ")
                        end
                        // Send to scoreboard and coverage
                        ap.write(item);
                        mntr2cov.write(item);
                    end
                end
            end
        end
    endtask: run_phase
endclass: apb_monitor