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
    string m_agent_id;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegAgentConfig", string agent_id = "register");
        super.new(name);
        m_agent_id = agent_id;
    endfunction

endclass : CpmRegAgentConfig
