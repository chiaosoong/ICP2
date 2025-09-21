vlog -sv -timescale 1ns/1ns \
        +incdir+uvc/clock_uvc+uvc/reset_uvc+uvc/serial_data_uvc+uvc/parallel_data_uvc+serial_to_parallel/tb \
        uvc/clock_uvc/clock_if.sv uvc/reset_uvc/reset_if.sv uvc/serial_data_uvc/serial_data_if.sv uvc/parallel_data_uvc/parallel_data_if.sv \
        serial_to_parallel/dut/serial_to_parallel.sv serial_to_parallel/tb/tb_pkg.sv serial_to_parallel/tb/tb_top.sv
vsim  -i work.tb_top -sv_seed 7979700 -coverage +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_HIGH +UVM_TESTNAME=basic_test



