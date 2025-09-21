/**
 * Module description
 * =================
 *
 * Serial to parallel data converter with parity
 * 
 * This module receives a serial data stream on a single wire and converts it into
 * a parallel 8 bits data bus. The module also generates a data valid signal
 * whenever a full 8 bits data is received. The module uses a start bit to
 * synchronize the data input stream and to know when a data byte is being received.
 * 
 * The module has a single clock input and a reset input. On each clock edge the
 * start bit is sampled and if it is set the module starts sampling the serial data
 * for the following 8 bits. If the start bit is not set the module ignores the
 * serial data input. Whenever a full 8 bits data is received the data valid signal
 * is set and the module generates the 8 bits parallel data. The data valid signal
 * remains set until the module receives another start bit. The module also has a
 * reset input to reset the module to its initial state.
 * 
 * The module also receives an enable signal to generate the parity bit, if the parity enable is
 * enabled the module will also generate the parity bit, if the parity enable is disabled the module
 * will not generate the parity bit. The module also generates a parity error output port that is set
 * when the parity bit error is detected.
 * 
 * Inputs
 * -------
 *  clock: clock input signal
 *  reset_n: asynchronous reset signal
 *  start_bit: input signal to synchronize the data input stream
 *  serial_data: input signal with the serial data to be converted
 *  parity_enable: enable signal to generate the parity bit
 * 
 * Outputs
 * -------
 *  data_valid: output signal indicating that a new data byte is available
 *  data: output 8-bit parallel data
 *  parity_error: output signal indicating that a parity error occurred
 * 
 */
module serial_to_parallel(
    input  logic       clock,
    input  logic       reset_n,
    input  logic       start_bit,
    input  logic       serial_data,
    input  logic       parity_enable,
    output logic       data_valid,
    output logic [7:0] data,
    output logic       parity_error);

    // Internal signals
    logic       active;
    logic [3:0] counter;

    // Processing serial to parallel data
    always_ff @(posedge clock or negedge reset_n) begin
        // Asynchronous reset
        if(~reset_n) begin
            data_valid   <= '0;
            data         <= '0;
            counter      <= '0;
            active       <= '0; // Bug to be introduced here by comment the code out
            parity_error <= '0;
        end
        else begin
            // Deactivate data valid and parity signals
            if (data_valid) begin
                data_valid   <= '0;
                parity_error <= '0;
            end
            // Sample serial data into a parallel data value
            if (start_bit || active) begin
                // Store serial data
                if (counter <= 7) begin
                    data[counter] <= serial_data;
                end
                // Check if all serial bits are received
                if (counter == (parity_enable ? 8 : 7)) begin
                    // All 8 serial bits received then set data_valid signal and reset internal signals
                    if (parity_enable) begin
                        parity_error <= (serial_data ^ data[7] ^ data[6] ^ data[5] ^ data[4] ^ data[3] ^ data[2] ^ data[1] ^ data[0]);
                    end
                    data_valid <= 1'b1;
                    active     <= '0;
                    counter    <= '0;
                end
                else begin
                    // serial data storing is ongoing
                    active  <= 1'b1;
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule
