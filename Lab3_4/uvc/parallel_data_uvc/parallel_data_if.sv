//------------------------------------------------------------------------------
// parallel_data interface
//
// This parallel data interface is to be used for communication between DUT and TB top
// It includes the following signals:
// - clk: the clock signal for the interface.
// - rst_n: the active-low reset signal for the interface.
// - data_valid: a signal that indicates when data is valid.
// - data: an 8-bit data signal.
// - parity_error: a signal that indicates if there is a parity error in the data.
//
//------------------------------------------------------------------------------
interface parallel_data_if (input logic clk, input logic rst_n);
    // Data_valid signal.
    logic data_valid;
    // Data signal.
    logic [7:0] data;
    // Parity error signal
    logic parity_error;
endinterface : parallel_data_if
