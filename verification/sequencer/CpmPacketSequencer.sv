/**
 * @file CpmPacketSequencer.sv
 * @brief CPM Packet Sequencer
 * 
 * Sequencer for packet stream transactions.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmPacketSequencer extends uvm_sequencer #(CpmPacketTxn);

    `uvm_component_utils(CpmPacketSequencer)

    // ============================================================================
    // Configuration
    // ============================================================================
    int m_max_outstanding = 10;  // Maximum outstanding transactions

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmPacketSequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Can retrieve configuration from config_db if needed
    endfunction

endclass : CpmPacketSequencer
