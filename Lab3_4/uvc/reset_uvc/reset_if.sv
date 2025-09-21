//------------------------------------------------------------------------------
// reset_if interface
//
// This interface provides a reset signal.
//
//------------------------------------------------------------------------------
interface reset_if (input logic clk);
    logic reset_n;
endinterface : reset_if
