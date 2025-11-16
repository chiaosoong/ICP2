// =================================================================================
// APB Scoreboard
// Description: Scoreboard component that receives APB transactions from driver
//              and monitor, collects expected and actual data packets in queues,
//              and compares them to detect functional violations during simulation.
// =================================================================================

`uvm_analysis_imp_decl(_drv2scb)
`uvm_analysis_imp_decl(_mntr2scb)
class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)
    
    // =================================================================================
    // Data storage for comparison
    // - exp_seq_item  : temporary holder for expected packets
    // - exp_seq_item_q: queue of expected packets received from driver
    // - rcvd_seq_item_q: queue of actual packets received from monitor
    // =================================================================================
    apb_seq_item            exp_seq_item;       // temporary expected data holder
    apb_seq_item            exp_seq_item_q[$];  // queue of expected sequence items
    apb_seq_item            rcvd_seq_item_q[$]; // queue of received sequence items
    
    // =================================================================================
    // Analysis implementation imports (IMP)
    // - ap_drv2scb  : receives expected transactions from the driver
    // - ap_mntr2scb : receives actual transactions from the monitor
    // These analysis ports allow the scoreboard to subscribe to transaction streams.
    // =================================================================================
    uvm_analysis_imp_drv2scb#(apb_seq_item, apb_scoreboard)     ap_drv2scb;     // driver to scoreboard
    uvm_analysis_imp_mntr2scb#(apb_seq_item, apb_scoreboard)    ap_mntr2scb;    // monitor to scoreboard

    // =================================================================================
    // Constructor
    // Description: creates the analysis implementation ports (ap_drv2scb, ap_mntr2scb)
    //              which will receive notifications when transactions are published.
    // =================================================================================
    function new(string name="apb_scoreboard", uvm_component parent);
        super.new(name, parent);
        // create analysis implementation ports
        ap_drv2scb = new("ap_drv2scb", this);
        ap_mntr2scb = new("ap_mntr2scb", this);
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
    // Description: main simulation loop (currently disabled via comment). When
    //              enabled, this would continuously pop expected and received
    //              packets from their respective queues and compare them.
    // =================================================================================
    virtual task run_phase(uvm_phase phase);
        apb_seq_item  exp_pkt, rcvd_pkt;
        super.run_phase(phase);
        
 /*       forever begin
            wait(exp_seq_item_q.size() !=0 && rcvd_seq_item_q.size() !=0);
                exp_pkt = exp_seq_item_q.pop_front();
                rcvd_pkt = rcvd_seq_item_q.pop_front();
                compare_pkt(exp_pkt, rcvd_pkt);                
        end  
*/      
    endtask: run_phase
    
    // =================================================================================
    // write_drv2scb (Analysis IMP write function for driver transactions)
    // Description: callback invoked when driver publishes a transaction via ap_drv2scb.
    //              Logs the transaction and pushes it to the expected queue.
    // =================================================================================
    function void write_drv2scb(apb_seq_item item);
        // print seq_item details received from driver
        `uvm_info("SCB", $sformatf("Seq_item written from driver: \n"), UVM_HIGH)
        item.print();
        
        // push the expected seq_item into the queue
        exp_seq_item_q.push_back(item);
    endfunction: write_drv2scb
    
    // =================================================================================
    // write_mntr2scb (Analysis IMP write function for monitor transactions)
    // Description: callback invoked when monitor publishes a transaction via ap_mntr2scb.
    //              Logs the transaction and pushes it to the received queue.
    // =================================================================================
    function void write_mntr2scb(apb_seq_item item);
        // print seq_item details received from monitor
        `uvm_info("SCB", $sformatf("Seq_item written from monitor: \n"), UVM_HIGH)
        item.print();
        
        // push captured seq_item into the received queue
        rcvd_seq_item_q.push_back(item);
    endfunction: write_mntr2scb
    
    // =================================================================================
    // compare_pkt (comparison function)
    // Description: compares an expected packet with a received packet. Checks
    //              that ADDR and DATA fields match; reports errors if mismatches
    //              are detected (useful for functional verification).
    // =================================================================================
    function void compare_pkt(input apb_seq_item exp_pkt, apb_seq_item rcvd_pkt);
        if(exp_pkt.ADDR == rcvd_pkt.ADDR) begin
            if(exp_pkt.DATA != rcvd_pkt.DATA) begin
                `uvm_error("DATA MISMATCH ERROR", $sformatf("SCB:: For ADDR: %0h Expecting DATA:%0h but Received DATA: %0h", exp_pkt.ADDR, exp_pkt.DATA, rcvd_pkt.DATA))
            end
        end
        else begin
            `uvm_error("ADDR MISMATCH ERROR", $sformatf("SCB:: Expected ADDR:%0h But received ADDR: %0h", exp_pkt.ADDR, rcvd_pkt.ADDR))
        end
    endfunction: compare_pkt
    
    // =================================================================================
    // construct_nd_push_exp_pkt (manual expected packet construction)
    // Description: manually constructs an expected packet from provided ADDR/DATA
    //              values and pushes it to the expected queue. Useful for scenarios
    //              where expected data is not obtained from the driver.
    // =================================================================================
    function void construct_nd_push_exp_pkt(input reg [`ADDR_WIDTH-1:0] ADDR, input reg [`DATA_WIDTH-1:0] DATA);
        // construct a new seq_item for expected data
        exp_seq_item = apb_seq_item::type_id::create("exp_seq_item");
        // populate expected values
        exp_seq_item.ADDR = ADDR;
        exp_seq_item.DATA = DATA;
        // push the constructed expected packet into the queue
        exp_seq_item_q.push_back(exp_seq_item);
    endfunction: construct_nd_push_exp_pkt
endclass: apb_scoreboard