class apb_read_ofm_seq extends uvm_sequence#(apb_seq_item);
    `uvm_object_utils(apb_read_ofm_seq)

    // number of OUTPUT reads expected (e.g. 784)
    int unsigned read_count = 784;

    function new(string name = "apb_read_ofm_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_seq_item req;
        apb_seq_item rreq;

        // 1) Issue READ_CTRL (write 1 to READ_CTRL_ADDR) to start APB READ state
        req = apb_seq_item::type_id::create("req_read_ctrl");
        req.op_type = WRITE;
        req.ADDR = READ_CTRL_ADDR;
        req.DATA = 1;
        start_item(req);
        finish_item(req);

    // Note: If needed, caller/sequence can poll CA_FINISHED or insert delays
    // before starting the read burst. Here we immediately start issuing reads.

        // 2) Perform read_count reads from OUTPUT_ADDR
        for (int i = 0; i < read_count; i++) begin
            rreq = apb_seq_item::type_id::create($sformatf("rreq_%0d", i));
            rreq.op_type = READ;
            rreq.ADDR = OUTPUT_ADDR;
            rreq.DATA = 0; // driver will fill this on read
            start_item(rreq);
            finish_item(rreq);
        end
    endtask

endclass: apb_read_ofm_burst_seq
