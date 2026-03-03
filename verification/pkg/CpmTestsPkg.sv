/**
 * @file CpmTestsPkg.sv
 * @brief CPM Tests Package
 * 
 * Contains all test classes.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmTestsPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;
    import CpmTransactionsPkg::*;
    import CpmConfigPkg::*;
    import CpmRalPkg::*;
    import CpmPacketAgentPkg::*;
    import CpmRegAgentPkg::*;
    import CpmScoreboardPkg::*;
    import CpmCoveragePkg::*;
    import CpmEnvPkg::*;
    import CpmSequencesPkg::*;

    `include "tests/CpmBaseTest.sv"
    `include "tests/CpmMainTest.sv"
    `include "tests/CpmRalResetTest.sv"
    `include "tests/CpmSmokeTest.sv"

endpackage : CpmTestsPkg
