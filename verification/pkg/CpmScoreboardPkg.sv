/**
 * @file CpmScoreboardPkg.sv
 * @brief CPM Scoreboard Package
 * 
 * Contains scoreboard and reference model.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmScoreboardPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;
    import CpmTransactionsPkg::*;
    import CpmRalPkg::*;

    `include "scoreboard/CpmRefModel.sv"
    `include "scoreboard/CpmScoreboardOutputImp.sv"
    `include "scoreboard/CpmScoreboardModeImp.sv"
    `include "scoreboard/CpmScoreboard.sv"

endpackage : CpmScoreboardPkg
