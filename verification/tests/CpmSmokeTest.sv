/**
 * @file CpmSmokeTest.sv
 * @brief CPM Smoke Test
 * 
 * Basic smoke test for functionality verification.
 * Quick test to verify basic operation.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmSmokeTest extends CpmBaseTest;

    `uvm_component_utils(CpmSmokeTest)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmSmokeTest", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Configure for quick smoke test
        m_env_cfg.m_num_packets = 10;
        m_env_cfg.m_stress_level = 1;
    endfunction
    
    // ============================================================================
    // run_phase
    // Basic functionality verification
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        CpmConfigSeq config_seq;
        CpmBaseTrafficSeq traffic_seq;
        uvm_status_e status;
        virtual CpmStreamIf stream_if;
        virtual CpmRegIf reg_if;

        phase.raise_objection(this);

        `uvm_info("TEST", "Starting smoke test", UVM_MEDIUM)

        // Get virtual interfaces from config_db (set by tb_top)
        if (!uvm_config_db#(virtual CpmStreamIf)::get(null, "*", "stream_if", stream_if)) begin
            `uvm_fatal("TEST", "Stream interface not found - check tb_top")
        end
        if (!uvm_config_db#(virtual CpmRegIf)::get(null, "*", "reg_if", reg_if)) begin
            `uvm_fatal("TEST", "Reg interface not found - check tb_top")
        end
        
        // Wait for reset deassertion
        wait (!stream_if.rst);
        @(posedge stream_if.clk);
        `uvm_info("TEST", "Reset deasserted, starting sequences", UVM_MEDIUM)

        // 1. Configure via RAL
        // Null pointer check
        if (m_env.m_reg_model == null) begin
            `uvm_fatal("TEST", "Register model is null - environment not properly initialized")
            return;
        end
        
        config_seq = CpmConfigSeq::type_id::create("config_seq");
        config_seq.m_reg_model = m_env.m_reg_model;
        config_seq.m_mode = CPM_MODE_PASS;
        config_seq.m_mask = 16'h0000;
        config_seq.m_add_const = 16'h0000;
        config_seq.m_drop_en = 1'b0;
        config_seq.m_drop_opcode = 4'h0;
        config_seq.start(m_env.m_reg_agent.m_sequencer);

        // 2. Send minimal traffic
        traffic_seq = CpmBaseTrafficSeq::type_id::create("traffic_seq");
        traffic_seq.m_num_packets = 10;
        traffic_seq.start(m_env.m_packet_agent.m_sequencer);

        // 3. Wait for completion - wait for sequences to finish
        // Give time for packets to flow through
        repeat (20) @(posedge stream_if.clk);

        // 4. Check counter invariant (MANDATORY)
        m_env.m_scoreboard.check_counter_invariant();

        `uvm_info("TEST", "Smoke test completed", UVM_MEDIUM)

        phase.drop_objection(this);
    endtask

endclass : CpmSmokeTest
