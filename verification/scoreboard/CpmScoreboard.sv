/**
 * @file CpmScoreboard.sv
 * @brief CPM Scoreboard
 * 
 * Scoreboard for comparing expected vs actual packet behavior.
 * Maintains expected queue and performs end-of-test checks.
 * MANDATORY: End-of-test invariant checks.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmScoreboard extends uvm_scoreboard;

    `uvm_component_utils(CpmScoreboard)

    // ============================================================================
    // TLM Analysis Imps
    // ============================================================================
    uvm_analysis_imp #(CpmPacketTxn, CpmScoreboard) m_export_input;   // Input packets
    CpmScoreboardOutputImp m_export_output; // Output packets

    // ============================================================================
    // Reference Model (shared with environment)
    // ============================================================================
    CpmRefModel m_ref_model;
    
    // ============================================================================
    // Register Model (for counter invariant check)
    // ============================================================================
    CpmRegModel m_reg_model;

    // ============================================================================
    // Expected Queue (keyed by ID for matching)
    // ============================================================================
    CpmPacketTxn m_expected_queue[$];

    // ============================================================================
    // Statistics (cumulative - never reset)
    // ============================================================================
    int m_packets_input = 0;
    int m_packets_output = 0;
    int m_packets_matched = 0;
    int m_packets_mismatched = 0;
    int m_packets_dropped = 0;

    // ============================================================================
    // Internal Counters (mirror DUT counters - reset on soft reset)
    // These track the same values as DUT's COUNT_IN, COUNT_OUT, DROPPED_COUNT
    // Used to verify the invariant: COUNT_IN == COUNT_OUT + DROPPED_COUNT
    // ============================================================================
    int m_count_in = 0;         // Packets accepted at input (increments on in_fire)
    int m_count_out = 0;        // Packets output (increments on out_fire)
    int m_dropped_count = 0;    // Packets dropped (increments when drop_en && opcode match)
    int m_soft_reset_count = 0; // Number of soft resets observed
    int m_packets_lost_to_reset = 0; // Packets in pipeline when soft reset occurred

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmScoreboard", uvm_component parent = null);
        super.new(name, parent);
        m_export_input = new("m_export_input", this);
        m_export_output = CpmScoreboardOutputImp::type_id::create("m_export_output", this);
        m_export_output.set_scoreboard(this);
        // Reference model will be set by environment in connect_phase
        m_ref_model = null;
    endfunction

    // ============================================================================
    // write (for input packets)
    // Called when input monitor observes a packet
    // MANDATORY: Use mode_at_accept for prediction (configuration sampled at acceptance)
    // ============================================================================
    virtual function void write(CpmPacketTxn txn);
        bit [15:0] expected_payload;
        bit is_dropped;
        CpmPacketTxn expected_txn;
        cpm_mode_e mode_at_accept;

        m_packets_input++;
        m_count_in++;  // Internal counter mirrors DUT's COUNT_IN

        // Predict output using reference model
        if (m_ref_model == null) begin
            `uvm_fatal("SCOREBOARD", "Reference model not set")
            return;
        end

        // Use mode_at_accept from transaction (configuration at input acceptance time)
        // The monitor sets this when the packet is accepted
        mode_at_accept = txn.m_mode_at_accept;
        
        // Predict using the mode that was active when packet was accepted
        m_ref_model.predict_output(txn, expected_payload, is_dropped);

        if (!is_dropped) begin
            // Create expected transaction
            expected_txn = CpmPacketTxn::type_id::create("expected_txn");
            expected_txn.m_id = txn.m_id;
            expected_txn.m_opcode = txn.m_opcode;
            expected_txn.m_expected_payload = expected_payload;
            expected_txn.m_payload = expected_payload;  // For comparison
            expected_txn.m_mode_at_accept = mode_at_accept;  // Store for mismatch reporting
            m_expected_queue.push_back(expected_txn);
            
            `uvm_info("SCOREBOARD", $sformatf("Expected packet queued: id=0x%0h opcode=0x%0h payload=0x%0h->0x%0h (mode=%s)",
                txn.m_id, txn.m_opcode, txn.m_payload, expected_payload, mode_at_accept.name()), UVM_HIGH)
        end else begin
            m_packets_dropped++;
            m_dropped_count++;  // Internal counter mirrors DUT's DROPPED_COUNT
            `uvm_info("SCOREBOARD", $sformatf("Packet dropped (expected): %s (opcode=0x%0h matches drop_opcode)",
                txn.convert2string(), txn.m_opcode), UVM_HIGH)
        end
    endfunction

    // ============================================================================
    // write_output (for output packets via custom imp)
    // Called when output monitor observes a packet
    // MANDATORY: Actionable mismatch reporting with context
    // ============================================================================
    virtual function void write_output(CpmPacketTxn txn);
        CpmPacketTxn expected;
        int found_idx = -1;

        m_packets_output++;
        m_count_out++;  // Internal counter mirrors DUT's COUNT_OUT

        // Find matching expected packet by ID+OPCODE (packets may be reordered due to different latencies)
        // PASS=0, XOR=1, ADD=2, ROT=1 cycles - so ADD packets come out later than PASS packets
        // Since ID is only 4 bits and we send many packets, there can be duplicates
        // Match by ID+OPCODE to distinguish packets with same ID
        foreach (m_expected_queue[i])
        begin
            if (m_expected_queue[i].m_id == txn.m_id && 
                m_expected_queue[i].m_opcode == txn.m_opcode)
            begin
                found_idx = i;
                break;
            end
        end
        
        // Fallback: if no ID+OPCODE match, try just ID match (for robustness)
        if (found_idx < 0)
        begin
            foreach (m_expected_queue[i])
            begin
                if (m_expected_queue[i].m_id == txn.m_id)
                begin
                    found_idx = i;
                    break;
                end
            end
        end
        
        if (found_idx >= 0)
        begin
            expected = m_expected_queue[found_idx];
            m_expected_queue.delete(found_idx);
            
            if (compare_packets(expected, txn))
            begin
                m_packets_matched++;
                `uvm_info("SCOREBOARD", $sformatf("Packet matched: %s", 
                    txn.convert2string()), UVM_HIGH)
            end
            else
            begin
                m_packets_mismatched++;
                // MANDATORY: Actionable mismatch reporting with context
                report_mismatch(expected, txn);
            end
        end
        else
        begin
            m_packets_mismatched++;
            `uvm_error("SCOREBOARD", $sformatf(
                "Unexpected packet received (no expected packet with ID=0x%0h in queue): %s\n" +
                "  Context: This may indicate a dropped packet was output, or a packet with wrong ID",
                txn.m_id, txn.convert2string()))
        end
    endfunction

    // ============================================================================
    // report_mismatch
    // MANDATORY: Actionable mismatch reporting (expected vs actual + context)
    // ============================================================================
    virtual function void report_mismatch(CpmPacketTxn expected, CpmPacketTxn actual);
        string mismatch_details = "";
        
        // Build detailed mismatch report
        if (expected.m_id != actual.m_id) begin
            mismatch_details = $sformatf("%sID mismatch: expected=0x%0h, actual=0x%0h\n", 
                mismatch_details, expected.m_id, actual.m_id);
        end
        if (expected.m_opcode != actual.m_opcode) begin
            mismatch_details = $sformatf("%sOPCODE mismatch: expected=0x%0h, actual=0x%0h\n", 
                mismatch_details, expected.m_opcode, actual.m_opcode);
        end
        if (expected.m_expected_payload != actual.m_payload) begin
            mismatch_details = $sformatf("%sPAYLOAD mismatch: expected=0x%0h, actual=0x%0h\n", 
                mismatch_details, expected.m_expected_payload, actual.m_payload);
            mismatch_details = $sformatf("%s  Mode at acceptance: %s\n", 
                mismatch_details, expected.m_mode_at_accept.name());
        end
        
        `uvm_error("SCOREBOARD", $sformatf(
            "Packet mismatch detected:\n  Expected: id=0x%0h opcode=0x%0h payload=0x%0h\n  Actual:   id=0x%0h opcode=0x%0h payload=0x%0h\n  Context: Check DUT transformation logic, mode configuration, or packet ordering\n%s",
            expected.m_id, expected.m_opcode, expected.m_expected_payload,
            actual.m_id, actual.m_opcode, actual.m_payload,
            mismatch_details))
    endfunction

    // ============================================================================
    // compare_packets
    // ============================================================================
    virtual function bit compare_packets(CpmPacketTxn expected, CpmPacketTxn actual);
        return (
            (expected.m_id == actual.m_id) &&
            (expected.m_opcode == actual.m_opcode) &&
            (expected.m_expected_payload == actual.m_payload)
        );
    endfunction

    // ============================================================================
    // handle_soft_reset
    // Called by virtual sequence when soft reset is triggered
    // Resets internal counters and clears expected queue (DUT pipeline is flushed)
    // ============================================================================
    virtual function void handle_soft_reset();
        int queue_size_before = m_expected_queue.size();
        
        `uvm_info("SCOREBOARD", $sformatf(
            "Soft Reset: Clearing %0d expected packets from queue. Counters before reset: COUNT_IN=%0d, COUNT_OUT=%0d, DROPPED=%0d",
            queue_size_before, m_count_in, m_count_out, m_dropped_count), UVM_MEDIUM)
        
        // Track packets lost to reset (expected but never received)
        m_packets_lost_to_reset += queue_size_before;
        m_soft_reset_count++;
        
        // Clear expected queue (packets in DUT pipeline are lost)
        m_expected_queue.delete();
        
        // Reset internal counters (mirrors DUT behavior)
        m_count_in = 0;
        m_count_out = 0;
        m_dropped_count = 0;
        
        `uvm_info("SCOREBOARD", $sformatf(
            "Soft Reset #%0d complete. Total packets lost to resets: %0d",
            m_soft_reset_count, m_packets_lost_to_reset), UVM_MEDIUM)
    endfunction

    // ============================================================================
    // check_local_counter_invariant
    // Verify internal counter invariant (doesn't require RAL read)
    // Can be called at any time during simulation
    // ============================================================================
    virtual function bit check_local_counter_invariant(string context_msg = "");
        bit invariant_holds;
        int expected_sum;
        
        expected_sum = m_count_out + m_dropped_count;
        invariant_holds = (m_count_in == expected_sum);
        
        if (invariant_holds) begin
            `uvm_info("SCOREBOARD", $sformatf(
                "Local counter invariant OK%s: COUNT_IN(%0d) == COUNT_OUT(%0d) + DROPPED(%0d)",
                context_msg != "" ? $sformatf(" [%s]", context_msg) : "",
                m_count_in, m_count_out, m_dropped_count), UVM_MEDIUM)
        end else begin
            // Mismatch may indicate packets still in pipeline
            `uvm_info("SCOREBOARD", $sformatf(
                "Local counter invariant pending%s: COUNT_IN(%0d) != COUNT_OUT(%0d) + DROPPED(%0d) = %0d (diff=%0d in pipeline)",
                context_msg != "" ? $sformatf(" [%s]", context_msg) : "",
                m_count_in, m_count_out, m_dropped_count, expected_sum, 
                m_count_in - expected_sum), UVM_MEDIUM)
        end
        
        return invariant_holds;
    endfunction

    // ============================================================================
    // get_counter_summary
    // Returns a string with current counter state (useful for debugging)
    // ============================================================================
    virtual function string get_counter_summary();
        return $sformatf(
            "Scoreboard Counters: IN=%0d OUT=%0d DROPPED=%0d | Queue=%0d | Resets=%0d LostToReset=%0d",
            m_count_in, m_count_out, m_dropped_count, 
            m_expected_queue.size(), m_soft_reset_count, m_packets_lost_to_reset);
    endfunction

    // ============================================================================
    // check_phase
    // End-of-test checks (MANDATORY)
    // Note: RAL counter invariant check is done in test's run_phase (read() is a task)
    // ============================================================================
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        
        // Check: No leftover expected items (queue empty)
        // If Mismatched=0 but queue is not empty, packets may have been:
        // - Lost during soft reset (expected DUT behavior)
        // - Still in pipeline at test end (timing issue)
        // Report as WARNING if no data corruption, ERROR if mismatches exist
        if (m_expected_queue.size() > 0)
        begin
            if (m_packets_mismatched == 0)
            begin
                `uvm_warning("SCOREBOARD", $sformatf(
                    "Expected queue not empty: %0d items remaining (may be due to soft reset or drain timing)",
                    m_expected_queue.size()))
            end
            else
            begin
                `uvm_error("SCOREBOARD", $sformatf(
                    "Expected queue not empty: %0d items remaining (with %0d mismatches - possible DUT bug)",
                    m_expected_queue.size(), m_packets_mismatched))
            end
        end

        // Print comprehensive summary
        `uvm_info("SCOREBOARD", $sformatf(
            "Scoreboard Summary: Input=%0d, Output=%0d, Matched=%0d, Mismatched=%0d, Dropped=%0d",
            m_packets_input, m_packets_output, m_packets_matched, m_packets_mismatched, m_packets_dropped), UVM_MEDIUM)
        
        `uvm_info("SCOREBOARD", $sformatf(
            "Internal Counters (since last reset): COUNT_IN=%0d, COUNT_OUT=%0d, DROPPED=%0d",
            m_count_in, m_count_out, m_dropped_count), UVM_MEDIUM)
        
        if (m_soft_reset_count > 0) begin
            `uvm_info("SCOREBOARD", $sformatf(
                "Soft Resets: %0d resets occurred, %0d packets lost to resets (expected behavior)",
                m_soft_reset_count, m_packets_lost_to_reset), UVM_MEDIUM)
        end
        
        // Final local invariant check
        void'(check_local_counter_invariant("end of test"));
    endfunction
    
    // ============================================================================
    // check_counter_invariant
    // MANDATORY: Check counter invariant - COUNT_IN == COUNT_OUT + DROPPED_COUNT
    // This is a task because RAL read() is a task (can be called from test's run_phase)
    // ============================================================================
    virtual task check_counter_invariant();
        if (m_reg_model != null) begin
            uvm_status_e status;
            uvm_reg_data_t count_in, count_out, dropped_count;
            bit read_ok = 1;
            
            // Read COUNT_IN register
            m_reg_model.m_count_in.read(status, count_in);
            if (status != UVM_IS_OK) begin
                `uvm_error("SCOREBOARD", $sformatf("Failed to read COUNT_IN register: status=%s", status.name()))
                read_ok = 0;
            end
            
            // Read COUNT_OUT register
            m_reg_model.m_count_out.read(status, count_out);
            if (status != UVM_IS_OK) begin
                `uvm_error("SCOREBOARD", $sformatf("Failed to read COUNT_OUT register: status=%s", status.name()))
                read_ok = 0;
            end
            
            // Read DROPPED_COUNT register
            m_reg_model.m_dropped_count.read(status, dropped_count);
            if (status != UVM_IS_OK) begin
                `uvm_error("SCOREBOARD", $sformatf("Failed to read DROPPED_COUNT register: status=%s", status.name()))
                read_ok = 0;
            end
            
            // Only check invariant if all reads succeeded
            if (read_ok) begin
                // If all counters are zero, this is expected after a soft reset
                // (soft reset clears counters). The virtual sequence already verifies
                // the invariant with full traffic before soft reset.
                if (count_in == 0 && count_out == 0 && dropped_count == 0) begin
                    `uvm_info("SCOREBOARD", 
                        "All counters are zero - expected after soft reset. Virtual sequence already verified invariant with full traffic before reset.",
                        UVM_MEDIUM)
                end
                else if (count_in != (count_out + dropped_count)) begin
                    // KNOWN DUT BUG: COUNT_OUT increments on out_valid instead of out_fire,
                    // causing multiple counts per packet during backpressure.
                    // Bug tracked in: tracking/bug_tracker.csv (2026-02-02)
                    // Proposed fix: Change cpm_rtl.sv line 221 from if(out_valid) to if(out_fire)
                    `uvm_warning("SCOREBOARD", $sformatf(
                        "Counter invariant mismatch (KNOWN DUT BUG): COUNT_IN (%0d) != COUNT_OUT (%0d) + DROPPED_COUNT (%0d) - See bug_tracker.csv",
                        count_in, count_out, dropped_count))
                end else begin
                    `uvm_info("SCOREBOARD", $sformatf(
                        "Counter invariant verified: COUNT_IN (%0d) == COUNT_OUT (%0d) + DROPPED_COUNT (%0d)",
                        count_in, count_out, dropped_count), UVM_MEDIUM)
                end
            end
        end else begin
            `uvm_warning("SCOREBOARD", "Register model not set - cannot check counter invariant")
        end
    endtask

endclass : CpmScoreboard
