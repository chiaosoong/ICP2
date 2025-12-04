set UVM_HOME E:/Questasim/verilog_src/uvm-1.1d

vlog -sv -timescale 1ns/1ns +acc=pr \
        +incdir+$UVM_HOME/src \
        +incdir+tb_uvm+uvc/agents+uvc/defines+uvc/env+uvc/sequence_lib+uvc/test_lib \
        uvc/defines/tb_defines.sv \
        uvc/sequence_lib/apb_seq_lib_pkg.sv \
        uvc/agents/apb_agent_pkg.sv \
        uvc/env/apb_env_pkg.sv \
        uvc/test_lib/apb_test_pkg.sv \
        tb_uvm/tb_uvm_top.sv
vsim  -i work.tb_uvm_top -coverage +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_HIGH +UVM_TESTNAME=apb_slv_err_test


