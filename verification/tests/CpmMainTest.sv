/**
 * @file CpmMainTest.sv
 * @brief CPM Main Test
 * 
 * Main test demonstrating all mandatory features.
 * MANDATORY: Demonstrates RAL, virtual seq, factory override, callbacks, coverage, SVA.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmMainTest extends CpmBaseTest;

    `uvm_component_utils(CpmMainTest)

    // ============================================================================
    // Callback instance (MANDATORY - demonstrates callback mechanism)
    // ============================================================================
    CpmPacketStatsCb m_packet_stats_cb;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmMainTest", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // MANDATORY: Apply factory overrides, set configuration knobs
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Factory override (MANDATORY) - demonstrate polymorphism
        // Override base traffic sequence with coverage traffic sequence
        CpmBaseTrafficSeq::type_id::set_type_override(CpmCoverageTrafficSeq::get_type());

        // Set configuration knobs (counts, mode schedule, stress level)
        m_env_cfg.m_num_packets = 200;
        m_env_cfg.m_stress_level = 2;
        
        // Set via config_db for sequences
        uvm_config_db#(int)::set(this, "*", "num_packets", m_env_cfg.m_num_packets);
    endfunction

    // ============================================================================
    // connect_phase
    // MANDATORY: Add callbacks
    // ============================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Add callbacks (MANDATORY) - demonstrate callback mechanism
        // CpmPacketStatsCb tracks packet statistics (opcode distribution, payload range)
        m_packet_stats_cb = CpmPacketStatsCb::type_id::create("m_packet_stats_cb");
        uvm_callbacks#(CpmPacketDriver, CpmBasePacketCb)::add(m_env.m_packet_agent.m_driver, m_packet_stats_cb);
        `uvm_info("TEST", "Packet statistics callback registered", UVM_MEDIUM)
    endfunction

    // ============================================================================
    // run_phase
    // MANDATORY: Start virtual sequence, end cleanly (no hangs)
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        CpmTopVirtualSeq virt_seq;

        phase.raise_objection(this);

        `uvm_info("TEST", "Starting main test with virtual sequence", UVM_MEDIUM)

        // Start virtual sequence (MANDATORY)
        // Virtual sequence orchestrates complete system flow
        virt_seq = CpmTopVirtualSeq::type_id::create("virt_seq");
        virt_seq.m_packet_seqr = m_env.m_packet_agent.m_sequencer;
        virt_seq.m_reg_seqr = m_env.m_reg_agent.m_sequencer;
        virt_seq.m_reg_model = m_env.m_reg_model;  // Pass register model for RAL operations
        virt_seq.m_scoreboard = m_env.m_scoreboard;  // Pass scoreboard for counter invariant checks
        virt_seq.start(null);

        `uvm_info("TEST", "Virtual sequence completed", UVM_MEDIUM)

        // Wait for final transactions to complete and pipeline to drain
        // Get VIF for clock access (similar to CpmSmokeTest)
        begin
            repeat (500) @(posedge m_env.m_stream_if.clk);  // Increased from 100 to 500 for post-reset traffic
        end

        // Check counter invariant (MANDATORY)
        // Note: The virtual sequence already verifies the counter invariant BEFORE soft reset
        // (with all traffic: 100 + 64 + 200 packets). After soft reset, counters are cleared,
        // so this check verifies counters work correctly after soft reset with the 50 post-reset packets.
        // If counters are zero, it means the post-reset packets haven't been processed yet,
        // which is expected if the wait time wasn't sufficient.
        m_env.m_scoreboard.check_counter_invariant();

        // Report callback statistics (demonstrates callback has real purpose)
        `uvm_info("TEST", m_packet_stats_cb.get_statistics(), UVM_MEDIUM)

        phase.drop_objection(this);
    endtask

endclass : CpmMainTest
