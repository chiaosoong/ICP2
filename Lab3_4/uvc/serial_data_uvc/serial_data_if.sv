//------------------------------------------------------------------------------
// serial_data_if interface
//
// This serial data interface is to be used for communication between DUT and TB top
// It includes the following signals:
// - clk: the clock signal for the interface.
// - rst_n: the active-low reset signal for the interface.
// - start_bit: a signal that indicates when data when ther serial data is started.
// - serial_data: Serial data with 8-bit data and parity bit if enabled.
// - parity_enable: a signal that indicates if the parity is enabled as the 9th bit.
//
//------------------------------------------------------------------------------
interface serial_data_if (input logic clk, input logic rst_n);
    // Start bit signal.
    logic start_bit;
    // Serial data signal.
    logic serial_data;
    // Parity enable signal.
    logic parity_enable;
endinterface : serial_data_if
