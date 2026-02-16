/**
 * @file CpmBaseTest.sv
 * @brief CPM Base Test
 * 
 * Base test class with common setup.
 * Recommended: Single base test configurable via plusargs/config knobs.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmBaseTest extends uvm_test;

    `uvm_component_utils(CpmBaseTest)

    // ============================================================================
    // Environment
    // ============================================================================
    CpmEnv m_env;

    // ============================================================================
    // Configuration
    // ============================================================================
    CpmEnvConfig m_env_cfg;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmBaseTest", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // MANDATORY: Configure environment via uvm_config_db (no direct DUT access)
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Debug: Print factory to catch crashes early
        `uvm_info("TEST", "Entering build_phase", UVM_MEDIUM)
        factory.print();

        // Create environment configuration
        m_env_cfg = CpmEnvConfig::type_id::create("m_env_cfg");
        
        // Configure agent modes (active/passive)
        m_env_cfg.m_stream_cfg.m_is_active = UVM_ACTIVE;
        m_env_cfg.m_reg_cfg.m_is_active = UVM_ACTIVE;
        
        // Set virtual interfaces (will be set by testbench)
        // These are set in tb_top.sv, but we can verify they exist
        
        // Set configuration via config_db (no direct DUT access)
        uvm_config_db#(CpmEnvConfig)::set(this, "*", "cfg", m_env_cfg);

        // Create environment
        m_env = CpmEnv::type_id::create("m_env", this);
        
        `uvm_info("TEST", "build_phase complete", UVM_MEDIUM)
    endfunction


    virtual CpmStreamIf stream_if;
    virtual CpmRegIf reg_if;
    // ============================================================================
    // connect_phase
    // Set virtual interfaces in agent configurations
    // ============================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Get virtual interfaces from config_db (set by tb_top)
        if (!uvm_config_db#(virtual CpmStreamIf)::get(this, "", "stream_if", stream_if)) begin
            `uvm_fatal("TEST", "Stream interface not found - check tb_top")
        end
        if (!uvm_config_db#(virtual CpmRegIf)::get(this, "", "reg_if", reg_if)) begin
            `uvm_fatal("TEST", "Reg interface not found - check tb_top")
        end
    endfunction

    // ============================================================================
    // run_phase
    // Base class run_phase - derived classes should override this
    // DO NOT raise/drop objection here - let derived classes handle it
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        // Base class does nothing - derived classes override this
        // Derived classes should raise/drop objections as needed
    endtask

    // ============================================================================
    // report_phase
    // ============================================================================
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("TEST", "Test completed", UVM_MEDIUM)
    endfunction

endclass : CpmBaseTest
