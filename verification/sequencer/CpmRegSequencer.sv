/**
 * @file CpmRegSequencer.sv
 * @brief CPM Register Sequencer
 * 
 * Sequencer for register bus transactions.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegSequencer extends uvm_sequencer #(CpmRegTxn);

    `uvm_component_utils(CpmRegSequencer)

    // ============================================================================
    // Configuration
    // ============================================================================
    int m_max_outstanding = 5;  // Maximum outstanding transactions

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegSequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Can retrieve configuration from config_db if needed
    endfunction

endclass : CpmRegSequencer
