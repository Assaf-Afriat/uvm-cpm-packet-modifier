/**
 * @file CpmEnv.sv
 * @brief CPM Environment
 * 
 * Top-level verification environment.
 * Contains agents, scoreboard, coverage collectors, and RAL.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmEnv extends uvm_env;

    `uvm_component_utils(CpmEnv)

    // ============================================================================
    // Agents
    // ============================================================================
    CpmPacketAgent m_packet_agent;
    CpmRegAgent    m_reg_agent;

    // ============================================================================
    // Scoreboard and Reference Model
    // ============================================================================
    CpmScoreboard m_scoreboard;
    CpmRefModel   m_ref_model;

    // ============================================================================
    // Coverage Collectors
    // ============================================================================
    CpmPacketCoverage m_packet_cov;
    CpmRegCoverage    m_reg_cov;

    // ============================================================================
    // RAL Components (MANDATORY)
    // ============================================================================
    CpmRegModel     m_reg_model;
    CpmRegAdapter   m_reg_adapter;
    CpmRegPredictor m_reg_predictor;

    // ============================================================================
    // Configuration
    // ============================================================================
    CpmEnvConfig m_cfg;

    virtual CpmStreamIf m_stream_if;
    virtual CpmRegIf m_reg_if;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmEnv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get configuration
        if (!uvm_config_db#(CpmEnvConfig)::get(this, "", "cfg", m_cfg)) begin
            `uvm_fatal("NO_CFG", "Environment configuration not set")
        end

        // Get virtual interfaces
        if (!uvm_config_db#(virtual CpmStreamIf)::get(this, "", "stream_if", m_stream_if)) begin
            `uvm_fatal("NO_STREAM_IF", "Stream interface not set")
        end
        if (!uvm_config_db#(virtual CpmRegIf)::get(this, "", "reg_if", m_reg_if)) begin
            `uvm_fatal("NO_REG_IF", "Reg interface not set")
        end

        // Create agents
        m_packet_agent = CpmPacketAgent::type_id::create("m_packet_agent", this);
        m_reg_agent = CpmRegAgent::type_id::create("m_reg_agent", this);

        // Create scoreboard and reference model
        m_scoreboard = CpmScoreboard::type_id::create("m_scoreboard", this);
        m_ref_model = CpmRefModel::type_id::create("m_ref_model", this);

        // Create coverage collectors
        m_packet_cov = CpmPacketCoverage::type_id::create("m_packet_cov", this);
        m_reg_cov = CpmRegCoverage::type_id::create("m_reg_cov", this);

        // Create RAL components (MANDATORY)
        m_reg_model = CpmRegModel::type_id::create("m_reg_model");
        m_reg_model.build();  // Must call build() to initialize registers and default_map
        m_reg_adapter = CpmRegAdapter::type_id::create("m_reg_adapter", this);
        m_reg_predictor = CpmRegPredictor::type_id::create("m_reg_predictor", this);

        // Configure agents (virtual interfaces will be set in connect_phase)
        uvm_config_db#(CpmStreamAgentConfig)::set(this, "m_packet_agent", "cfg", m_cfg.m_stream_cfg);
        uvm_config_db#(CpmRegAgentConfig)::set(this, "m_reg_agent", "cfg", m_cfg.m_reg_cfg);
        
        // Note: Virtual interfaces are set in test's connect_phase after config_db retrieval
    endfunction

    // ============================================================================
    // connect_phase
    // ============================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect packet monitor input port to scoreboard and coverage
        m_packet_agent.m_monitor.m_ap_input.connect(m_scoreboard.m_export_input);
        m_packet_agent.m_monitor.m_ap_input.connect(m_packet_cov.analysis_export);

        // Connect packet monitor output port to scoreboard (via uvm_subscriber's analysis_export)
        m_packet_agent.m_monitor.m_ap_output.connect(m_scoreboard.m_export_output.analysis_export);

        // Connect register monitor to predictor and coverage
        m_reg_agent.m_monitor.m_ap.connect(m_reg_predictor.bus_in);
        m_reg_agent.m_monitor.m_ap.connect(m_reg_cov.analysis_export);

        // Connect reference model to scoreboard (shared instance)
        m_scoreboard.m_ref_model = m_ref_model;
        
        // Connect RAL model to reference model (for reading mask/add_const/drop config)
        m_ref_model.m_reg_model = m_reg_model;
        
        // Connect register model to scoreboard (for counter invariant check)
        m_scoreboard.m_reg_model = m_reg_model;
        
        // Connect reference model to packet monitor (for mode_at_accept tracking)
        m_packet_agent.m_monitor.m_ref_model = m_ref_model;
        
        // Connect RAL model to packet monitor (for accurate mode tracking via mirrored value)
        m_packet_agent.m_monitor.m_reg_model = m_reg_model;

        // Connect RAL predictor to register model
        if (m_reg_model != null && m_reg_model.default_map != null) begin
            m_reg_predictor.map = m_reg_model.default_map;
            m_reg_predictor.adapter = m_reg_adapter;

            // Connect register sequencer to RAL
            if (m_reg_agent.m_sequencer != null) begin
                m_reg_model.default_map.set_sequencer(m_reg_agent.m_sequencer, m_reg_adapter);
            end
        end else begin
            `uvm_warning("ENV", "RAL model or default_map is null - RAL connections skipped")
        end
    endfunction

    // ============================================================================
    // update_configuration
    // Update reference model and coverage configuration
    // Called when registers are written
    // ============================================================================
    function void update_configuration(
        input cpm_mode_e i_mode,
        input bit [15:0] i_mask,
        input bit [15:0] i_add_const,
        input bit i_drop_en,
        input bit [3:0] i_drop_opcode
    );
        // Update reference model
        m_ref_model.update_configuration(i_mode, i_mask, i_add_const, i_drop_en, i_drop_opcode);
        
        // Update coverage
        m_packet_cov.update_configuration(i_mode, i_drop_en, i_drop_opcode);
        
        `uvm_info("ENV", $sformatf("Configuration updated: mode=%s", i_mode.name()), UVM_MEDIUM)
    endfunction

endclass : CpmEnv
