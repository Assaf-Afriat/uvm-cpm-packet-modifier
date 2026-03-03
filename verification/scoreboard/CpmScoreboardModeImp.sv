/**
 * @file CpmScoreboardModeImp.sv
 * @brief CPM Scoreboard Mode Analysis Imp
 * 
 * Custom uvm_subscriber for mode changes from register monitor.
 * Routes to write_mode() method in scoreboard.
 * This allows the scoreboard to track the current mode without
 * the packet monitor needing to access RAL directly.
 * 
 * @author Assaf Afriat
 * @date 2026-02-07
 */

// Forward declaration
typedef class CpmScoreboard;

class CpmScoreboardModeImp extends uvm_subscriber #(cpm_mode_e);

    `uvm_component_utils(CpmScoreboardModeImp)

    // ============================================================================
    // Parent Scoreboard Reference
    // ============================================================================
    CpmScoreboard m_scoreboard;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmScoreboardModeImp", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // set_scoreboard
    // Set the scoreboard reference
    // ============================================================================
    function void set_scoreboard(CpmScoreboard sb);
        m_scoreboard = sb;
    endfunction

    // ============================================================================
    // write
    // Required by uvm_subscriber - routes to write_mode() in scoreboard
    // ============================================================================
    virtual function void write(cpm_mode_e t);
        if (m_scoreboard == null) begin
            `uvm_fatal("SCOREBOARD_IMP", "Scoreboard reference not set")
            return;
        end
        m_scoreboard.write_mode(t);
    endfunction

endclass : CpmScoreboardModeImp
