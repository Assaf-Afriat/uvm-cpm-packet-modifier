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
    //virtual CpmStreamIf m_vif;
    string m_agent_id = "packet";

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmStreamAgentConfig");
        super.new(name);
    endfunction

endclass : CpmStreamAgentConfig
