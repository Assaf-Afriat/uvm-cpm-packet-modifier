/**
 * @file CpmEnvConfig.sv
 * @brief CPM Environment Configuration
 * 
 * Top-level environment configuration object.
 * Contains configuration for all agents and test parameters.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmEnvConfig extends uvm_object;

    `uvm_object_utils(CpmEnvConfig)

    // ============================================================================
    // Agent Configurations
    // ============================================================================
    CpmStreamAgentConfig m_stream_cfg;
    CpmRegAgentConfig m_reg_cfg;

    // ============================================================================
    // Test Configuration Parameters
    // ============================================================================
    int m_num_packets = 100;
    int m_stress_level = 1;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmEnvConfig");
        super.new(name);
        m_stream_cfg = CpmStreamAgentConfig::type_id::create("m_stream_cfg");
        m_reg_cfg = CpmRegAgentConfig::type_id::create("m_reg_cfg");
    endfunction

endclass : CpmEnvConfig
