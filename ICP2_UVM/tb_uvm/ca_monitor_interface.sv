// =================================================================================
// ca_monitor_interface.sv 
// Purpose:
//   Virtual interface to monitor/capture IFM and kernel data that CA receives
//   from the RAM controller.
//   Simplified to only capture ifm0, ifm1, ifm2, kernel and the read handshake.
// =================================================================================

interface ca_monitor_interface (
    input logic clk,
    input logic rst_n
);

    // =================================================================================
    // IFM Data Outputs from RAM Controller (what CA receives)
    // These are the 3-lane outputs of the RAM controller that feed the CA
    // =================================================================================
    logic [`DATA_WIDTH-1:0] ifm0 [2:0]; // Channel 0: 3 lanes (patch elements)
    logic [`DATA_WIDTH-1:0] ifm1 [2:0]; // Channel 1: 3 lanes
    logic [`DATA_WIDTH-1:0] ifm2 [2:0]; // Channel 2: 3 lanes

    // =================================================================================
    // IFM Read Indicators
    // When CA_MU state is active, IFM patch data flows
    // =================================================================================
    logic rd_ifm_hs; // RAM controller grants IFM read (rd_ifm_hs in ca_mem_interface)
    logic rd_knl_hs; // RAM controller grants Kernel read (rd_knl_hs in ca_mem_interface)
    logic valid_patch; // Indicates valid IFM patch data

    // =================================================================================
    // Clocking Block for UVM Monitors
    // Sample on positive clock edge within clocking region
    // =================================================================================
    clocking cb @(posedge clk);
        input ifm0, ifm1, ifm2;
        input rd_ifm_hs, rd_knl_hs, valid_patch;
    endclocking

    // =================================================================================
    // Modport for Monitor (read-only)
    // =================================================================================
    modport monitor (
        clocking cb,
        input clk, rst_n
    );
endinterface