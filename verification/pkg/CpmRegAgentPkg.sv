/**
 * @file CpmRegAgentPkg.sv
 * @brief CPM Register Agent Package
 * 
 * Contains register agent and its components: driver, sequencer, monitor, callbacks.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmRegAgentPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;
    import CpmTransactionsPkg::*;
    import CpmConfigPkg::*;

    // Forward declaration needed for callback signatures
    // (Callback uses CpmRegDriver in method params, but is included before Driver)
    typedef class CpmRegDriver;

    // Sequencer (no dependencies on other agent components)
    `include "agent/reg/CpmRegSequencer.sv"

    // Callbacks (need forward declaration of CpmRegDriver)
    `include "callbacks/CpmBaseRegCb.sv"

    // Driver (uses callbacks)
    `include "agent/reg/CpmRegDriver.sv"

    // Monitor (no special dependencies)
    `include "agent/reg/CpmRegMonitor.sv"

    // Agent (uses all above)
    `include "agent/reg/CpmRegAgent.sv"

endpackage : CpmRegAgentPkg
