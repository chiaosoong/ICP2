//----------------------------------------------------------------------------
// data_to_fifo module
//
// This module implements a FIFO buffer with a depth of 4 bytes. It can store
// up to 4 bytes of data and has an input and output interface. The FIFO has
// signals for overflow, empty and data availability.
//
// The FIFO has the following signals:
// - clock: System clock
// - reset_n: Active low reset signal
// - data_valid: Signal indicating that new data is valid on the input
// - parity_error: Signal indicating that the input data has a parity error
 //- fifo_request_data: Signal indicating that the output is requesting data
// - fifo_empty: Signal indicating that the FIFO is empty
// - fifo_overflow: Signal indicating that the FIFO is overflowing
// - fifo_data: Output data
//
// The FIFO buffer is implemented using a shift register. The read and write
// pointers are implemented using 4-bit counters. The FIFO has a depth of 4
// bytes and the maximum number of data that can be stored in it is 4 bytes.
//
//----------------------------------------------------------------------------
module data_to_fifo(
    input logic         clock,
    input logic         reset_n,
    input logic         data_valid,
    input logic [7:0]   data,
    input logic         parity_error,
    input logic         fifo_request_data,
    output logic        fifo_empty,
    output logic        fifo_overflow,
    output logic [7:0]  fifo_data);

    parameter depth = 4;
    logic [depth-1:0][7:0] fifo_buffer;
    logic [depth-1:0] fifo_write_pointer, fifo_read_pointer;
    logic [depth-1:0] counter;
    logic overflow;

    always_ff @(posedge clock or negedge reset_n) begin
        if (~reset_n) begin
            fifo_write_pointer <= '0;
            fifo_read_pointer <= '0;
            fifo_empty <= '1;
            fifo_overflow <= '0;
            fifo_data <= '0;
            overflow = '0;
            counter = '0;
        end
        else begin
            fifo_empty <= (counter == 0 ? 1 : 0);
            if (fifo_request_data==1 && counter != 0) begin
                fifo_data <= fifo_buffer[fifo_read_pointer];
                fifo_read_pointer = (fifo_read_pointer == depth-1 ? 0 : fifo_read_pointer+1);
                counter -= 1;
                overflow = 0;
            end
            if (data_valid==1 && parity_error==0 && overflow==0) begin
                if (counter < depth) begin
                    fifo_buffer[fifo_write_pointer] = data;
                    fifo_write_pointer = (fifo_write_pointer == depth-1 ? 0 : fifo_write_pointer+1);
                    counter += 1;
                end
                else overflow = 1;
            end
            fifo_overflow <= overflow;
        end
    end
endmodule
