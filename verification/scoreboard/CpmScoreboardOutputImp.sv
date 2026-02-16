/**
 * @file CpmScoreboardOutputImp.sv
 * @brief CPM Scoreboard Output Analysis Imp
 * 
 * Custom uvm_subscriber for output packets.
 * Routes to write_output() method in scoreboard.
 * Note: We extend uvm_subscriber instead of uvm_analysis_imp to properly
 * be a uvm_component that can be used with analysis ports.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

// Forward declaration
typedef class CpmScoreboard;

class CpmScoreboardOutputImp extends uvm_subscriber #(CpmPacketTxn);

    `uvm_component_utils(CpmScoreboardOutputImp)

    // ============================================================================
    // Parent Scoreboard Reference
    // ============================================================================
    CpmScoreboard m_scoreboard;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmScoreboardOutputImp", uvm_component parent = null);
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
    // Required by uvm_subscriber - routes to write_output() in scoreboard
    // ============================================================================
    virtual function void write(CpmPacketTxn t);
        if (m_scoreboard == null) begin
            `uvm_fatal("SCOREBOARD_IMP", "Scoreboard reference not set")
            return;
        end
        m_scoreboard.write_output(t);
    endfunction

endclass : CpmScoreboardOutputImp
