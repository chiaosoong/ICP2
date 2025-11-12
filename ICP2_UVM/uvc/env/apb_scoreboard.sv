class apb_scoreboard extends uvm_component;
    `uvm_component_utils(apb_scoreboard)

    // analysis imp to receive transactions from driver
    uvm_analysis_imp#(apb_seq_item, apb_scoreboard) apb_imp;

    // expected outputs container (provided by test via config DB)
    expected_outputs exp;

    // internal read index (for OUTPUT register reads)
    int unsigned read_idx;

    function new(string name = "apb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        apb_imp = new("apb_imp", this);
        read_idx = 0;
    endfunction

    // build_phase: get expected outputs from config DB if available
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(expected_outputs)::get(this, "", "EXPECTED_OUTPUTS", exp)) begin
            `uvm_info(get_type_name(), "No expected outputs found in config DB; scoreboard will collect transactions but not compare", UVM_LOW)
        end
    endfunction

    // write method called by apb_imp when a transaction arrives
    function void write(apb_seq_item t);
        // Only act on READ transactions to OUTPUT_ADDR
        if (t.op_type == READ) begin
            if (t.ADDR == OUTPUT_ADDR) begin
                // Compare lower 8 bits with expected if provided
                if (exp.size() > 0) begin
                    if (read_idx >= exp.expected0.size()) begin
                        `uvm_error(get_type_name(), $sformatf("Read index %0d out of range (expected size %0d)", read_idx, exp.expected0.size()));
                    end else begin
                        int unsigned got = t.DATA[7:0];
                        int unsigned want = exp.expected0[read_idx] & 8'hFF;
                        if (got !== want) begin
                            `uvm_error(get_type_name(), $sformatf("DATA mismatch at index %0d: got 0x%0h, expected 0x%0h", read_idx, got, want));
                        end else begin
                            `uvm_info(get_type_name(), $sformatf("Match at index %0d: 0x%0h", read_idx, got), UVM_LOW)
                        end
                    end
                end
                read_idx++;
            end
            else begin
                // other read registers (CA_FINISHED, ALL_READ_DONE) could be used to reset/stop counters
                if (t.ADDR == CA_FINISHED_ADDR) begin
                    `uvm_info(get_type_name(), "CA_FINISHED read observed", UVM_LOW)
                end
                else if (t.ADDR == ALL_READ_DONE_ADDR) begin
                    `uvm_info(get_type_name(), "ALL_READ_DONE read observed", UVM_LOW)
                end
            end
        end else begin
            // For writes, we may track writes if needed (e.g., to build a model)
            // Currently just log write ops for debug
            `uvm_debug(get_type_name(), $sformatf("Write observed: ADDR=0x%0h DATA=0x%0h", t.ADDR, t.DATA));
        end
    endfunction

endclass: apb_scoreboard
