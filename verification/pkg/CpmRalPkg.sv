/**
 * @file CpmRalPkg.sv
 * @brief CPM RAL (Register Abstraction Layer) Package
 * 
 * Contains RAL model, adapter, and predictor.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmRalPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;
    import CpmTransactionsPkg::*;

    `include "ral/CpmRegModel.sv"
    `include "ral/CpmRegAdapter.sv"
    `include "ral/CpmRegPredictor.sv"

endpackage : CpmRalPkg
