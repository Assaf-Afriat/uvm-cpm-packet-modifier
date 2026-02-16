/**
 * @file CpmRegAgentConfig.sv
 * @brief CPM Register Agent Configuration
 * 
 * Configuration object for register bus agent.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegAgentConfig extends uvm_object;

    `uvm_object_utils(CpmRegAgentConfig)

    // ============================================================================
    // Configuration Fields
    // ============================================================================
    bit m_is_active = 1;  // 1 = active (driver+sequencer), 0 = passive (monitor only)
    //virtual CpmRegIf m_vif;
    string m_agent_id = "register";

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegAgentConfig");
        super.new(name);
    endfunction

endclass : CpmRegAgentConfig
