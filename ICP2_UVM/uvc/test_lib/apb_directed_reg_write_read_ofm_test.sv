class apb_directed_reg_write_read_test extends apb_base_test;
    `uvm_component_utils(apb_directed_reg_write_read_test)

    // constructor function
    function new(string name="apb_directed_reg_write_read_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction: new
    
    // build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction: build_phase
    
    // connect_phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction: connect_phase
    
    // run_phase
    virtual task run_phase(uvm_phase phase);
        // Use sequence-based write/read: write IFM and kernel via apb_write_seq
        // then trigger and perform OFM reads via apb_read_ofm_seq.
        super.run_phase(phase);
        phase.raise_objection(this);

        // Create and populate write sequence
        apb_write_seq wr_seq;
        wr_seq = apb_write_seq::type_id::create("wr_seq", this);

        // Populate IFM and kernel arrays with a deterministic pattern here.
        // Ideally replace these with the real stimulus arrays from TB via
        // uvm_config_db or by copying from top-level arrays if available.
        int ifm_count = 2352; // 3 * 784
        int ker_count = 27;   // 3 * 9
        wr_seq.ifm_data = new[ifm_count];
        for (int i = 0; i < ifm_count; i++) begin
            wr_seq.ifm_data[i] = i % (2**`DATA_WIDTH);
        end
        wr_seq.ker_data = new[ker_count];
        for (int k = 0; k < ker_count; k++) begin
            wr_seq.ker_data[k] = (k + 1) % (2**`DATA_WIDTH);
        end

        // Start the write sequence on the APB master sequencer
        wr_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);

        // Small delay to allow APB writes to propagate and CA to start loading
        // In a stricter flow you would wait on CA_finished or a handshake
        // signal from the DUT. Adjust as needed for your DUT timing.
        #100us;

        // Issue read bursts: start the simple read sequence 784 times
        // Note: `apb_rd_sequence` (in `uvc/sequence_lib`) performs a single
        // directed read when `addr` is set. We loop here to perform the full
        // OFM read burst (784 reads). This avoids relying on a non-existent
        // `read_count` field in the lightweight sequence.
        for (int i = 0; i < 784; i++) begin
            apb_rd_sequence rd_seq;
            rd_seq = apb_rd_sequence::type_id::create($sformatf("rd_seq_%0d", i), this);
            rd_seq.rand_addr = 0; // directed read
            rd_seq.addr = OUTPUT_ADDR;
            rd_seq.start(apb_env.apb_mstr_agnt.apb_mstr_seqr);
        end

        phase.drop_objection(this);
    endtask: run_phase
    
endclass: apb_directed_reg_write_read_test