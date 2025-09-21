//------------------------------------------------------------------------------
// data_fifo interface
//
// This data fifo interface is to be used for communication between DUT and TB top
// It includes the following signals:
// - clk: the clock signal for the interface.
// - rst_n: the active-low reset signal for the interface.
// - fifo_request_data: a signal that indicates ready to read fifo data
// - fifo_empty: a signal that indicate no more FIFO data
// - fifo_data: FIFO 8-bit data signal.
// - fifo_overflow: a signal that indicate FIFO buffer has overflow
//
//------------------------------------------------------------------------------
interface data_fifo_if (input logic clk, input logic rst_n);
    // Ready for FIFO data signal.
    logic fifo_request_data;
    // No more data in FIFO signal.
    logic fifo_empty;
    // FIFO data signal.
    logic [7:0] fifo_data;
    // FIFO overflow signal.
    logic fifo_overflow;
endinterface : data_fifo_if
