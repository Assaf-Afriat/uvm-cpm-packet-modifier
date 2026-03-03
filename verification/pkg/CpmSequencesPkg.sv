/**
 * @file CpmSequencesPkg.sv
 * @brief CPM Sequences Package
 * 
 * Contains all sequences: RAL, packet, and virtual sequences.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmSequencesPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;
    import CpmTransactionsPkg::*;
    import CpmRalPkg::*;
    import CpmPacketAgentPkg::*;
    import CpmRegAgentPkg::*;
    import CpmScoreboardPkg::*;

    // RAL Sequences
    `include "sequences/ral/CpmConfigSeq.sv"
    
    // Packet Sequences
    `include "sequences/packet/CpmBaseTrafficSeq.sv"
    `include "sequences/packet/CpmStressSeq.sv"
    `include "sequences/packet/CpmDropSeq.sv"
    `include "sequences/packet/CpmCoverageTrafficSeq.sv"
    
    // Virtual Sequences
    `include "sequences/virtual/CpmTopVirtualSeq.sv"

endpackage : CpmSequencesPkg
