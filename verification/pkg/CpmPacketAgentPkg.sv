/**
 * @file CpmPacketAgentPkg.sv
 * @brief CPM Packet Agent Package
 * 
 * Contains packet agent and its components: driver, sequencer, monitor, callbacks.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmPacketAgentPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;
    import CpmTransactionsPkg::*;
    import CpmConfigPkg::*;
    import CpmRalPkg::*;

    // Forward declaration needed for callback signatures
    // (Callback uses CpmPacketDriver in method params, but is included before Driver)
    typedef class CpmPacketDriver;

    // Sequencer (no dependencies on other agent components)
    `include "agent/packet/CpmPacketSequencer.sv"

    // Callbacks (need forward declaration of CpmPacketDriver)
    `include "callbacks/CpmBasePacketCb.sv"
    `include "callbacks/CpmBaseMonitorCb.sv"

    // Driver (uses callbacks)
    `include "agent/packet/CpmPacketDriver.sv"

    // Monitor (uses callbacks, RAL from CpmRalPkg)
    `include "agent/packet/CpmPacketMonitor.sv"

    // Agent (uses all above)
    `include "agent/packet/CpmPacketAgent.sv"

endpackage : CpmPacketAgentPkg
