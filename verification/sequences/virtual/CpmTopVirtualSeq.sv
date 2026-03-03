/**
 * @file CpmTopVirtualSeq.sv
 * @brief CPM Top Virtual Sequence
 * 
 * Top virtual sequence orchestrating complete system flow.
 * MANDATORY: Full scenario orchestration.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmTopVirtualSeq extends uvm_sequence;

    `uvm_object_utils(CpmTopVirtualSeq)

    // ============================================================================
    // Sequencer Handles (set by test in connect_phase)
    // ============================================================================
    CpmPacketSequencer m_packet_seqr;
    CpmRegSequencer    m_reg_seqr;

    // ============================================================================
    // Register Model (set by test in connect_phase)
    // ============================================================================
    CpmRegModel m_reg_model;

    // ============================================================================
    // Configuration Knobs (can be overridden by test)
    // ============================================================================
    int m_num_traffic_packets = 100;
    int m_num_stress_packets = 200;
    cpm_mode_e m_initial_mode = CPM_MODE_XOR;
    bit [15:0] m_initial_mask = 16'hAAAA;
    bit [15:0] m_initial_add_const = 16'h1234;
    bit [3:0] m_drop_opcode = 4'h5;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmTopVirtualSeq");
        super.new(name);
    endfunction

    // ============================================================================
    // body
    // Orchestrates complete system flow (MANDATORY):
    // 1. Reset
    // 2. Configure (via RAL)
    // 3. Traffic
    // 4. Reconfigure (MODE change during runtime)
    // 5. Stress
    // 6. Drop
    // 7. Readback (counters)
    // 8. End
    // ============================================================================
    virtual task body();
        `uvm_info("VIRT_SEQ", "Starting top virtual sequence", UVM_MEDIUM)

        // 1. Reset
        do_reset();

        // 2. Configure (via RAL)
        do_configure();

        // 3. Traffic
        do_traffic();

        // 4. Reconfigure (MODE change during runtime)
        do_reconfigure();

        // 5. Stress
        do_stress();

        // 6. Drop
        do_drop();

        // 7. Drain DUT pipeline (BEFORE readback to get accurate counters)
        do_drain();

        // 8. Readback (counters) - BEFORE soft reset (soft reset clears counters)
        do_readback();

        // 9. Soft Reset Test (for code coverage)
        do_soft_reset();

        // 10. Final drain
        do_drain();

        `uvm_info("VIRT_SEQ", "Top virtual sequence complete", UVM_MEDIUM)
    endtask

    // ============================================================================
    // Helper Tasks
    // ============================================================================
    virtual task do_reset();
        uvm_reg_hw_reset_seq reset_seq;
        `uvm_info("VIRT_SEQ", "Step 1: Reset", UVM_MEDIUM)
        
        if (m_reg_model == null) begin
            `uvm_fatal("VIRT_SEQ", "Register model is null - cannot run reset sequence")
            return;
        end
        
        reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
        reset_seq.model = m_reg_model;
        reset_seq.start(m_reg_seqr);
        
        // Wait for pipeline to be ready using STATUS.BUSY polling
        wait_for_idle();
    endtask

    virtual task do_configure();
        CpmConfigSeq config_seq;
        `uvm_info("VIRT_SEQ", "Step 2: Configure via RAL", UVM_MEDIUM)
        config_seq = CpmConfigSeq::type_id::create("config_seq");
        config_seq.m_reg_model = m_reg_model;
        // Use configuration knobs (can be overridden by test)
        config_seq.m_mode = m_initial_mode;
        config_seq.m_mask = m_initial_mask;
        config_seq.m_add_const = m_initial_add_const;
        config_seq.m_drop_en = 1'b0;
        config_seq.m_drop_opcode = 4'h0;
        config_seq.start(m_reg_seqr);
    endtask

    virtual task do_traffic();
        CpmBaseTrafficSeq traffic_seq;
        `uvm_info("VIRT_SEQ", "Step 3: Traffic", UVM_MEDIUM)
        traffic_seq = CpmBaseTrafficSeq::type_id::create("traffic_seq");
        traffic_seq.m_num_packets = m_num_traffic_packets;
        traffic_seq.start(m_packet_seqr);
    endtask

    virtual task do_reconfigure();
        uvm_status_e status;
        CpmCoverageTrafficSeq cov_seq;
        cpm_mode_e modes[$] = '{CPM_MODE_PASS, CPM_MODE_XOR, CPM_MODE_ADD, CPM_MODE_ROT};
        
        `uvm_info("VIRT_SEQ", "Step 4: Reconfigure - Testing ALL 4 MODES x 16 OPCODES for full cross coverage", UVM_MEDIUM)
        
        if (m_reg_model == null) begin
            `uvm_fatal("VIRT_SEQ", "Register model is null - cannot change MODE")
            return;
        end
        
        foreach (modes[i]) begin
            m_reg_model.m_mode.write(status, modes[i]);
            `uvm_info("VIRT_SEQ", $sformatf("MODE set to: %s - sending all 16 opcodes", modes[i].name()), UVM_MEDIUM)
            
            cov_seq = CpmCoverageTrafficSeq::type_id::create($sformatf("cov_%s", modes[i].name()));
            cov_seq.start(m_packet_seqr);
            
            // Wait for pipeline to drain before mode change
            wait_for_idle();
        end
        
        `uvm_info("VIRT_SEQ", "All 64 MODE x OPCODE combinations tested", UVM_MEDIUM)
    endtask

    virtual task do_stress();
        CpmStressSeq stress_seq;
        `uvm_info("VIRT_SEQ", "Step 5: Stress", UVM_MEDIUM)
        stress_seq = CpmStressSeq::type_id::create("stress_seq");
        stress_seq.m_num_packets = m_num_stress_packets;
        stress_seq.start(m_packet_seqr);
    endtask

    virtual task do_drop();
        uvm_status_e status;
        CpmDropSeq drop_seq;
        
        `uvm_info("VIRT_SEQ", "Step 6: Drop", UVM_MEDIUM)
        
        if (m_reg_model == null) begin
            `uvm_fatal("VIRT_SEQ", "Register model is null - cannot configure drop")
            return;
        end
        
        // Enable drop with configured opcode
        m_reg_model.m_drop_cfg.m_drop_en.set(1'b1);
        m_reg_model.m_drop_cfg.m_drop_opcode.set(m_drop_opcode);
        m_reg_model.m_drop_cfg.update(status);
        if (status != UVM_IS_OK) begin
            `uvm_error("VIRT_SEQ", "Failed to update DROP_CFG")
        end
        
        // Run drop sequence
        drop_seq = CpmDropSeq::type_id::create("drop_seq");
        drop_seq.m_drop_opcode = m_drop_opcode;
        drop_seq.start(m_packet_seqr);
        
        // Disable drop
        m_reg_model.m_drop_cfg.m_drop_en.set(1'b0);
        m_reg_model.m_drop_cfg.update(status);
        if (status != UVM_IS_OK) begin
            `uvm_error("VIRT_SEQ", "Failed to update DROP_CFG")
        end
    endtask

    virtual task do_soft_reset();
        uvm_status_e status;
        CpmBaseTrafficSeq traffic_seq;
        
        `uvm_info("VIRT_SEQ", "Step 7: Soft Reset Test (for code coverage)", UVM_MEDIUM)
        
        if (m_reg_model == null) begin
            `uvm_warning("VIRT_SEQ", "Register model is null - skipping soft reset test")
            return;
        end
        
        // Drain the pipeline before soft reset
        wait_for_idle();
        
        // Send some traffic first
        traffic_seq = CpmBaseTrafficSeq::type_id::create("traffic_seq");
        traffic_seq.m_num_packets = 20;
        traffic_seq.start(m_packet_seqr);
        
        // Wait for packets to exit before triggering reset
        wait_for_idle();
        
        // Trigger SOFT_RST
        m_reg_model.m_ctrl.write(status, 32'h0003);  // ENABLE=1, SOFT_RST=1
        `uvm_info("VIRT_SEQ", "Soft reset triggered", UVM_MEDIUM)
        
        // Signal the soft reset event so scoreboard can clear its expected queue
        // This is necessary because packets in DUT pipeline are lost during soft reset
        uvm_event_pool::get_global_pool().get(EVT_SOFT_RESET).trigger();
        
        // Re-enable after soft reset (SOFT_RST is self-clearing)
        m_reg_model.m_ctrl.write(status, 32'h0001);  // ENABLE=1, SOFT_RST=0
        
        // Reconfigure MODE after soft reset
        m_reg_model.m_mode.m_mode.set(CPM_MODE_PASS);
        m_reg_model.m_mode.update(status);
        if (status != UVM_IS_OK) begin
            `uvm_error("VIRT_SEQ", "Failed to update MODE")
        end
        `uvm_info("VIRT_SEQ", "Reconfigured MODE=PASS after soft reset", UVM_MEDIUM)
        
        // Send more traffic to verify recovery
        traffic_seq = CpmBaseTrafficSeq::type_id::create("traffic_seq");
        traffic_seq.m_num_packets = 50;
        traffic_seq.start(m_packet_seqr);
        
        // Wait for all packets to complete
        wait_for_idle();
        
        `uvm_info("VIRT_SEQ", "Soft reset test complete", UVM_MEDIUM)
    endtask

    virtual task do_readback();
        uvm_status_e status;
        uvm_reg_data_t count_in, count_out, dropped_count;
        
        `uvm_info("VIRT_SEQ", "Step 9: Readback counters", UVM_MEDIUM)
        
        if (m_reg_model == null) begin
            `uvm_fatal("VIRT_SEQ", "Register model is null - cannot readback counters")
            return;
        end
        
        // Read counters via RAL (for logging purposes only)
        // Counter verification is done by the scoreboard in check_phase
        m_reg_model.m_count_in.read(status, count_in);
        m_reg_model.m_count_out.read(status, count_out);
        m_reg_model.m_dropped_count.read(status, dropped_count);
        
        `uvm_info("VIRT_SEQ", $sformatf(
            "Counters: IN=%0d OUT=%0d DROPPED=%0d",
            count_in, count_out, dropped_count), UVM_MEDIUM)
    endtask

    virtual task do_drain();
        `uvm_info("VIRT_SEQ", "Step 8: Draining DUT pipeline...", UVM_MEDIUM)
        wait_for_idle();
        `uvm_info("VIRT_SEQ", "Pipeline drain complete", UVM_MEDIUM)
    endtask

    // ============================================================================
    // wait_for_idle
    // Wait for DUT pipeline to drain using event-based synchronization
    // Waits for scoreboard to signal all expected packets have been received
    // ============================================================================
    virtual task wait_for_idle();
        uvm_event idle_event;
        bit timeout_occurred;
        
        // Get the scoreboard idle event from the global pool
        idle_event = uvm_event_pool::get_global_pool().get(EVT_SCOREBOARD_IDLE);
        
        // Small delay to allow packets to propagate through the DUT pipeline
        // This ensures packets have entered the scoreboard before we check
        #10_000;
        
        // Check if already idle (event was triggered and is still "on")
        if (idle_event.is_on()) begin
            `uvm_info("VIRT_SEQ", "Scoreboard already idle - no wait needed", UVM_HIGH)
            return;
        end
        
        `uvm_info("VIRT_SEQ", $sformatf(
            "Waiting for scoreboard idle (timeout=%0d ns)...", 
            EVT_DEFAULT_TIMEOUT_NS), UVM_HIGH)
        
        // Wait for event with timeout protection
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
            // Timeout is not necessarily an error - could mean:
            // 1. No packets were sent yet (queue was already empty)
            // 2. DUT pipeline latency is higher than expected
            // Log as INFO, not WARNING, since this is expected in some cases
            `uvm_info("VIRT_SEQ", "Idle wait timeout (may be normal if queue was empty)", UVM_HIGH)
        end else begin
            `uvm_info("VIRT_SEQ", "Scoreboard idle - pipeline drained", UVM_HIGH)
        end
    endtask

endclass : CpmTopVirtualSeq
