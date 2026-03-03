/**
 * @file CpmCoveragePkg.sv
 * @brief CPM Coverage Package
 * 
 * Contains functional coverage collectors.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmCoveragePkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;
    import CpmTransactionsPkg::*;

    `include "coverage/CpmPacketCoverage.sv"
    `include "coverage/CpmRegCoverage.sv"

endpackage : CpmCoveragePkg
