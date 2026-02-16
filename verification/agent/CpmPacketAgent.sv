/**
 * @file CpmPacketAgent.sv
 * @brief CPM Packet Agent
 * 
 * Agent for packet stream interface.
 * Contains driver, sequencer, and monitor.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmPacketAgent extends uvm_agent;

    `uvm_component_utils(CpmPacketAgent)

    // ============================================================================
    // Components
    // ============================================================================
    CpmPacketDriver    m_driver;
    CpmPacketSequencer m_sequencer;
    CpmPacketMonitor   m_monitor;

    // ============================================================================
    // Configuration
    // ============================================================================
    CpmStreamAgentConfig m_cfg;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmPacketAgent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration
        if (!uvm_config_db#(CpmStreamAgentConfig)::get(this, "", "cfg", m_cfg)) begin
            `uvm_fatal("NO_CFG", "Configuration not set")
        end

        // Create monitor (always needed)
        m_monitor = CpmPacketMonitor::type_id::create("m_monitor", this);

        // Create driver and sequencer if active
        if (m_cfg.m_is_active) begin
            m_driver = CpmPacketDriver::type_id::create("m_driver", this);
            m_sequencer = CpmPacketSequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    // ============================================================================
    // connect_phase
    // ============================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect driver to sequencer if active
        if (m_cfg.m_is_active) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end

        // Note: Virtual interfaces are obtained by driver/monitor directly from
        // config_db (set by tb_top). No need to set interfaces explicitly here.
    endfunction

endclass : CpmPacketAgent
