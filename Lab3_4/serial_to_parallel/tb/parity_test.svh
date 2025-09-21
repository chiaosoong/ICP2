//------------------------------------------------------------------------------
// class parity_test
//
// This class is used to verify that the parity bit is correctly generated
// and checked on the serial data lines. The test class inherits from the
// base_test class which provides the basic framework for the test.
//
// The test class creates a test bench environment which includes a DUT,
// a stimulus provider, and a checker. The stimulus provider generates
// random data with the correct parity settings and the checker checks
// that the parity bit is correctly generated and checked by the DUT.
//
// The build_phase function sets the parity enable bit on the config block
// of the DUT. The run_phase function runs the test by calling the
// run_phase function in the base_test class.
//
// See more detailed information in base_test
//------------------------------------------------------------------------------
class parity_test extends base_test;
    `uvm_component_utils(parity_test)

    //------------------------------------------------------------------------------
    // FUNCTION: new
    // Creates and constructs the sequence.
    //------------------------------------------------------------------------------
    function new (string name = "test",uvm_component parent = null);
        super.new(name,parent);
    endfunction : new

    //------------------------------------------------------------------------------
    // FUNCTION: build_phase
    // Function to build the class within UVM build phase.
    //------------------------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);

        //TASK 6: Enable parity on DUT in the test. This is gonna be a lot of code...
        // Create and build TB environment as defined in base test
        super.build_phase(phase);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // FUNCTION: run_phase
    // Start UVM test in running phase.
    //------------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        // Set number data transactions
        no_of_data_loop = 80;
        // Run the test as defined in base test
        super.run_phase(phase);
    endtask : run_phase

endclass : parity_test
