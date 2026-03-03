/**
 * @file CpmStreamAgentConfig.sv
 * @brief CPM Stream Agent Configuration
 * 
 * Configuration object for packet stream agent.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmStreamAgentConfig extends uvm_object;

    `uvm_object_utils(CpmStreamAgentConfig)

    // ============================================================================
    // Configuration Fields
    // ============================================================================
    bit m_is_active = 1;  // 1 = active (driver+sequencer), 0 = passive (monitor only)
    string m_agent_id;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmStreamAgentConfig", string agent_id = "packet");
        super.new(name);
        m_agent_id = agent_id;
    endfunction

endclass : CpmStreamAgentConfig
