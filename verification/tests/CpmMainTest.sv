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
    // Virtual Sequence (created in build, connected in connect, started in run)
    // ============================================================================
    CpmTopVirtualSeq m_virt_seq;

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

        // Create virtual sequence
        m_virt_seq = CpmTopVirtualSeq::type_id::create("m_virt_seq");
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
        if (m_env.m_packet_agent.m_driver != null) begin
            uvm_callbacks#(CpmPacketDriver, CpmBasePacketCb)::add(m_env.m_packet_agent.m_driver, m_packet_stats_cb);
            `uvm_info("TEST", "Packet statistics callback registered", UVM_MEDIUM)
        end else begin
            `uvm_warning("TEST", "Packet agent is passive - callback not registered")
        end

        // Connect virtual sequence to sequencers and models
        m_virt_seq.m_packet_seqr = m_env.m_packet_agent.m_sequencer;
        m_virt_seq.m_reg_seqr = m_env.m_reg_agent.m_sequencer;
        m_virt_seq.m_reg_model = m_env.m_reg_model;
    endfunction

    // ============================================================================
    // run_phase
    // MANDATORY: Start virtual sequence, end cleanly (no hangs)
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        `uvm_info("TEST", "Starting main test with virtual sequence", UVM_MEDIUM)

        // Start virtual sequence (MANDATORY)
        // Virtual sequence orchestrates complete system flow
        m_virt_seq.start(null);

        `uvm_info("TEST", "Virtual sequence completed", UVM_MEDIUM)

        // Wait for scoreboard to finish processing all expected packets
        // Uses uvm_event_pool for proper synchronization instead of fixed delays
        wait_for_scoreboard_idle();

        // Check counter invariant (MANDATORY)
        m_env.m_scoreboard.check_counter_invariant();

        // Report callback statistics (demonstrates callback has real purpose)
        if (m_packet_stats_cb != null) begin
            `uvm_info("TEST", m_packet_stats_cb.get_statistics(), UVM_MEDIUM)
        end

        phase.drop_objection(this);
    endtask

    // ============================================================================
    // wait_for_scoreboard_idle
    // Waits for the scoreboard to signal it has processed all expected packets
    // Uses uvm_event_pool for proper synchronization with timeout protection
    // ============================================================================
    virtual task wait_for_scoreboard_idle();
        uvm_event idle_event;
        bit timeout_occurred;
        
        // Get the idle event from the global pool (same event scoreboard triggers)
        idle_event = uvm_event_pool::get_global_pool().get(EVT_SCOREBOARD_IDLE);
        
        // Check if already idle (event is "on" and queue is empty)
        if (idle_event.is_on() && m_env.m_scoreboard.m_expected_queue.size() == 0) begin
            `uvm_info("TEST", "Scoreboard already idle - no wait needed", UVM_MEDIUM)
            return;
        end
        
        `uvm_info("TEST", $sformatf(
            "Waiting for scoreboard idle event (timeout=%0d ns)", 
            EVT_DEFAULT_TIMEOUT_NS), UVM_MEDIUM)
        
        // Wait for idle event with timeout protection
        fork
            begin
                idle_event.wait_trigger();
                timeout_occurred = 0;
            end
            begin
                #(EVT_DEFAULT_TIMEOUT_NS);
                timeout_occurred = 1;
            end
        join_any
        disable fork;
        
        if (timeout_occurred) begin
            `uvm_warning("TEST", $sformatf(
                "Timeout waiting for scoreboard idle (expected queue size=%0d). Proceeding with test completion.",
                m_env.m_scoreboard.m_expected_queue.size()))
        end else begin
            `uvm_info("TEST", "Scoreboard idle event received - all packets processed", UVM_MEDIUM)
        end
    endtask

endclass : CpmMainTest
