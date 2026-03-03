/**
 * @file CpmConfigPkg.sv
 * @brief CPM Configuration Package
 * 
 * Contains configuration objects for agents and environment.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmConfigPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;

    `include "config/CpmStreamAgentConfig.sv"
    `include "config/CpmRegAgentConfig.sv"
    `include "config/CpmEnvConfig.sv"

endpackage : CpmConfigPkg
