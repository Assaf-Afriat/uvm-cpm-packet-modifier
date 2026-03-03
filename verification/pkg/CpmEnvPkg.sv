/**
 * @file CpmEnvPkg.sv
 * @brief CPM Environment Package
 * 
 * Contains the top-level verification environment.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmEnvPkg;

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

    `include "env/CpmEnv.sv"

endpackage : CpmEnvPkg
