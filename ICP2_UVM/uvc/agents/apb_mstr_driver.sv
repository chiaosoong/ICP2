// =================================================================================
// APB Master Driver
// Description: Active driver that receives `apb_seq_item` transactions from the
//              sequencer, executes APB transfers on the DUT via the virtual
//              interface, captures read data, and publishes completed
//              transactions to the scoreboard via `drv2scb`.
// =================================================================================
class apb_master_driver extends uvm_driver#(apb_seq_item);
    `uvm_component_utils(apb_master_driver)
    
    // =================================================================================
    // Configuration and interface handles
    // - `apb_mstr_agnt_cfg`: agent configuration object provided by the env/agent
    // - `apb_intf`        : virtual APB interface used to drive/sample DUT signals
    // =================================================================================
    apb_mstr_agent_config   apb_mstr_agnt_cfg;
    virtual apb_interface   apb_intf;
    
    // =================================================================================
    // Analysis port
    // - `drv2scb`: used to publish completed transactions (writes and read results)
    //             to the scoreboard for functional checking.
    // =================================================================================
    uvm_analysis_port#(apb_seq_item) drv2scb;
    
    // constructor function
    function new(string name="apb_master_driver", uvm_component parent=null);
        super.new(name, parent);
        // create the analysis port
        drv2scb = new("drv2scb", this);
    endfunction: new
    
    // build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction: build_phase
    
    // connect_phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction: connect_phase
    
    // =================================================================================
    // run_phase
    // Description: main driver loop that resets the interface once then
    //              repeatedly fetches sequence items from the sequencer and
    //              executes the corresponding APB transfer. After the transfer
    //              completes the driver publishes the (possibly updated) item
    //              to `drv2scb` for the scoreboard.
    // =================================================================================
    virtual task run_phase(uvm_phase phase);
        apb_seq_item item;
        
        // reset the interface
        apb_intf.reset_intf();
        
        // get data from sequencer and drive to DUT
        forever begin
            @(apb_intf.cb);
            // obtain next sequence item from sequencer (blocking call)
            seq_item_port.get_next_item(item);
                if(item.op_type == WRITE) begin
                    // perform APB write; then publish the expected transaction
                    wr_data(item);
                    drv2scb.write(item);
                end
                else if(item.op_type == READ) begin
                    // perform APB read (rd_data captures PRDATA into item.DATA)
                    rd_data(item);
                    // publish read transaction (with captured DATA) to scoreboard
                    drv2scb.write(item);
                end
            seq_item_port.item_done();
        end    
    endtask: run_phase
    
    ////////////////////////////////////////////////////////////////////
    // task name: wr_data
    // input parameter: apb_seq_item
    // Description: write data to dut (APB write transaction)
    ////////////////////////////////////////////////////////////////////
    task wr_data(input apb_seq_item item);
        apb_intf.cb.PSEL <= 1;
        apb_intf.cb.PWRITE <= 1;
        apb_intf.cb.PADDR <= item.ADDR;
        apb_intf.cb.PWDATA <= item.DATA;
        apb_intf.cb.PENABLE <= 0;
        @(apb_intf.cb);
        apb_intf.cb.PENABLE <= 1;
        @(apb_intf.cb);
        wait(apb_intf.cb.PREADY == 1);
        apb_intf.cb.PENABLE <= 0;
        apb_intf.cb.PSEL <= 0;
        @(apb_intf.cb);
    endtask: wr_data
    
    ////////////////////////////////////////////////////////////////////
    // task name: rd_data
    // input parameter: addr, data
    // Description: perform APB read transaction and capture PRDATA into item.DATA
    ////////////////////////////////////////////////////////////////////
    task rd_data(input apb_seq_item item);
        apb_intf.cb.PSEL <= 1;
        apb_intf.cb.PWRITE <= 0;
        apb_intf.cb.PADDR <= item.ADDR;
        apb_intf.cb.PENABLE <= 0;
        @(apb_intf.cb);
        apb_intf.cb.PENABLE <= 1;
        wait(apb_intf.cb.PREADY == 1);
        // capture read data into the sequence item so scoreboard can compare
        item.DATA = apb_intf.cb.PRDATA;
        apb_intf.cb.PENABLE <= 0;
        apb_intf.cb.PSEL <= 0;
    endtask: rd_data
endclass: apb_master_driver