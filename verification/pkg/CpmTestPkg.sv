/**
 * @file CpmTestPkg.sv
 * @brief CPM Verification Test Package
 * 
 * Main package that includes all UVM components for the CPM verification environment.
 * This package imports all necessary components and provides the central namespace.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmTestPkg;

    // ============================================================================
    // UVM Macros (must be included before using UVM macros)
    // ============================================================================
    `include "uvm_macros.svh"

    // ============================================================================
    // Package Imports
    // ============================================================================
    import uvm_pkg::*;
    import CpmParamsPkg::*;

    // ============================================================================
    // Forward Declarations
    // ============================================================================
    typedef class CpmPacketTxn;
    typedef class CpmRegTxn;
    typedef class CpmStreamAgentConfig;
    typedef class CpmRegAgentConfig;
    typedef class CpmEnvConfig;
    typedef class CpmBaseMonitorCb;
    typedef class CpmScoreboard;
    typedef class CpmRefModel;
    typedef class CpmPacketDriver;
    typedef class CpmRegDriver;

    // ============================================================================
    // Transaction Includes
    // ============================================================================
    `include "transactions/CpmPacketTxn.sv"
    `include "transactions/CpmRegTxn.sv"

    // ============================================================================
    // Configuration Includes
    // ============================================================================
    `include "config/CpmStreamAgentConfig.sv"
    `include "config/CpmRegAgentConfig.sv"
    `include "config/CpmEnvConfig.sv"

    // ============================================================================
    // RAL Includes (MANDATORY)
    // ============================================================================
    `include "ral/CpmRegModel.sv"
    `include "ral/CpmRegAdapter.sv"
    `include "ral/CpmRegPredictor.sv"

    // ============================================================================
    // Callback Includes (MUST be before drivers/monitors that use them)
    // ============================================================================
    `include "callbacks/CpmBasePacketCb.sv"
    `include "callbacks/CpmBaseRegCb.sv"
    `include "callbacks/CpmBaseMonitorCb.sv"

    // ============================================================================
    // Sequencer Includes
    // ============================================================================
    `include "sequencer/CpmPacketSequencer.sv"
    `include "sequencer/CpmRegSequencer.sv"

    // ============================================================================
    // Driver Includes
    // ============================================================================
    `include "driver/CpmPacketDriver.sv"
    `include "driver/CpmRegDriver.sv"

    // ============================================================================
    // Monitor Includes
    // ============================================================================
    `include "monitor/CpmPacketMonitor.sv"
    `include "monitor/CpmRegMonitor.sv"

    // ============================================================================
    // Agent Includes
    // ============================================================================
    `include "agent/CpmPacketAgent.sv"
    `include "agent/CpmRegAgent.sv"

    // ============================================================================
    // Scoreboard Includes
    // ============================================================================
    `include "scoreboard/CpmRefModel.sv"
    `include "scoreboard/CpmScoreboardOutputImp.sv"  // Must be before CpmScoreboard
    `include "scoreboard/CpmScoreboard.sv"

    // ============================================================================
    // Coverage Includes
    // ============================================================================
    `include "coverage/CpmPacketCoverage.sv"
    `include "coverage/CpmRegCoverage.sv"

    // ============================================================================
    // Environment Includes
    // ============================================================================
    `include "env/CpmEnv.sv"

    // ============================================================================
    // Sequence Includes
    // ============================================================================
    // RAL Sequences (MANDATORY)
    `include "sequences/ral/CpmConfigSeq.sv"
    
    // Leaf Sequences (MANDATORY) - Must be before virtual sequences
    `include "sequences/packet/CpmBaseTrafficSeq.sv"
    `include "sequences/packet/CpmStressSeq.sv"
    `include "sequences/packet/CpmDropSeq.sv"
    `include "sequences/packet/CpmCoverageTrafficSeq.sv"
    
    // Virtual Sequences (MANDATORY) - Must be after leaf sequences
    `include "sequences/virtual/CpmTopVirtualSeq.sv"

    // ============================================================================
    // Test Includes
    // ============================================================================
    `include "tests/CpmBaseTest.sv"
    `include "tests/CpmMainTest.sv"
    `include "tests/CpmRalResetTest.sv"
    `include "tests/CpmSmokeTest.sv"

endpackage : CpmTestPkg
