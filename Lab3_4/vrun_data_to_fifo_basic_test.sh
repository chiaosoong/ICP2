vlog -sv -timescale 1ns/1ns +acc=pr \
        +incdir+uvc/clock_uvc+uvc/reset_uvc+uvc/parallel_data_uvc+uvc/data_fifo_uvc+data_to_fifo/tb \
        uvc/clock_uvc/clock_if.sv uvc/reset_uvc/reset_if.sv uvc/parallel_data_uvc/parallel_data_if.sv uvc/data_fifo_uvc/data_fifo_if.sv \
        data_to_fifo/dut/data_to_fifo.sv data_to_fifo/tb/tb_pkg.sv data_to_fifo/tb/tb_top.sv
vsim  -i work.tb_top -coverage +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_HIGH +UVM_TESTNAME=basic_test

