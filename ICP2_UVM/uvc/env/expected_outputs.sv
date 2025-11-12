class expected_outputs extends uvm_object;
    `uvm_object_utils(expected_outputs)

    // dynamic array to hold expected output values for bank4 (784 entries)
    int unsigned expected0[]; // caller should fill this before simulation

    function new(string name = "expected_outputs");
        super.new(name);
        expected0 = new[0];
    endfunction

endclass: expected_outputs
