set UVM_HOME E:/Questasim/verilog_src/uvm-1.1d

vlog -sv -timescale 1ns/1ns +acc=pr \
        +incdir+$UVM_HOME/src \
        +incdir+tb_uvm+uvc/agents+uvc/defines+uvc/env+uvc/sequence_lib+uvc/test_lib \
        uvc/defines/tb_defines.sv \
        uvc/agents/apb_agent_pkg.sv \
        tb_uvm/tb_uvm_top.sv \
        tb_uvm/apb_interface.sv
vsim  -i work.tb_uvm_top -coverage +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_HIGH +UVM_TESTNAME=basic_test

