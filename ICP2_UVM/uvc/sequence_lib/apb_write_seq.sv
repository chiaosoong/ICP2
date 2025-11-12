class apb_write_seq extends uvm_sequence#(apb_seq_item);
    `uvm_object_utils(apb_write_seq)

    // data to write (dynamic array) - caller should populate before start
    int unsigned ifm_data[];

    // kernel data to write (dynamic array)
    int unsigned ker_data[];

    function new(string name = "apb_write_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_seq_item req;

        // 1) set input mode (write 1 to INPUT_MODE_ADDR)
        req = apb_seq_item::type_id::create("req");
        req.op_type = WRITE;
        req.ADDR = INPUT_MODE_ADDR;
        req.DATA = 1;
        start_item(req);
        finish_item(req);

        // 2) write IFM data to DATA_ADDR sequentially
        for (int i = 0; i < ifm_data.size(); i++) begin
            req = apb_seq_item::type_id::create($sformatf("req_%0d", i));
            req.op_type = WRITE;
            req.ADDR = DATA_ADDR;
            req.DATA = ifm_data[i];
            start_item(req);
            finish_item(req);
        end

        // 3) set kernel mode (write 1 to KERNEL_MODE_ADDR)
        req = apb_seq_item::type_id::create("req_kmode");
        req.op_type = WRITE;
        req.ADDR = KERNEL_MODE_ADDR;
        req.DATA = 1;
        start_item(req);
        finish_item(req);

        // 4) write kernel values to DATA_ADDR sequentially
        for (int i = 0; i < ker_data.size(); i++) begin
            req = apb_seq_item::type_id::create($sformatf("req_k_%0d", i));
            req.op_type = WRITE;
            req.ADDR = DATA_ADDR;
            req.DATA = ker_data[i];
            start_item(req);
            finish_item(req);
        end
    endtask

endclass: apb_write_seq
