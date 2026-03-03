/**
 * @file CpmTransactionsPkg.sv
 * @brief CPM Transactions Package
 * 
 * Contains transaction classes for packet and register interfaces.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmTransactionsPkg;

    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import CpmParamsPkg::*;

    `include "transactions/CpmPacketTxn.sv"
    `include "transactions/CpmRegTxn.sv"

endpackage : CpmTransactionsPkg
