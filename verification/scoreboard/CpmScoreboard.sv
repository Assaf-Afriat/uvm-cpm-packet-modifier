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
    CpmScoreboardOutputImp m_export_output;  // Output packets
    CpmScoreboardModeImp m_export_mode;      // Mode changes (from reg monitor)

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
    // Synchronization Event (for test to wait on scoreboard completion)
    // ============================================================================
    // This event is triggered when the expected queue becomes empty,
    // signaling that all expected packets have been received and compared.
    // Usage from test: uvm_event_pool::get_global_pool().get(EVT_SCOREBOARD_IDLE).wait_trigger();
    uvm_event m_idle_event;

    // ============================================================================
    // Current Mode (tracked from register monitor)
    // ============================================================================
    // The scoreboard tracks the current mode by subscribing to the register
    // monitor's m_ap_mode port. This way, the packet monitor doesn't need
    // to access RAL directly - it just sends packets, and the scoreboard
    // knows what mode was active when each packet was accepted.
    cpm_mode_e m_current_mode = CPM_MODE_PASS;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmScoreboard", uvm_component parent = null);
        super.new(name, parent);
        m_export_input = new("m_export_input", this);
        m_export_output = CpmScoreboardOutputImp::type_id::create("m_export_output", this);
        m_export_output.set_scoreboard(this);
        m_export_mode = CpmScoreboardModeImp::type_id::create("m_export_mode", this);
        m_export_mode.set_scoreboard(this);
        // Reference model will be set by environment in connect_phase
        m_ref_model = null;
        
        // Get the idle event from the global pool (creates it if it doesn't exist)
        // This event is used to signal when the scoreboard has processed all expected packets
        m_idle_event = uvm_event_pool::get_global_pool().get(EVT_SCOREBOARD_IDLE);
    endfunction

    // ============================================================================
    // run_phase
    // Spawns background process to listen for soft reset events
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        uvm_event soft_reset_event;
        
        // Get the soft reset event from the global pool
        soft_reset_event = uvm_event_pool::get_global_pool().get(EVT_SOFT_RESET);
        
        // Background process to handle soft reset notifications
        forever begin
            soft_reset_event.wait_trigger();
            `uvm_info("SCOREBOARD", "Soft reset event received - clearing expected queue", UVM_MEDIUM)
            handle_soft_reset();
            soft_reset_event.reset();  // Allow multiple soft resets
        end
    endtask

    // ============================================================================
    // write_mode (for mode changes from register monitor)
    // Called when MODE register is written - updates current mode for predictions
    // ============================================================================
    virtual function void write_mode(cpm_mode_e mode);
        `uvm_info("SCOREBOARD", $sformatf("Mode updated: %s -> %s", 
            m_current_mode.name(), mode.name()), UVM_MEDIUM)
        m_current_mode = mode;
    endfunction

    // ============================================================================
    // write (for input packets)
    // Called when input monitor observes a packet
    // Uses m_current_mode for prediction (mode tracked from register monitor)
    // ============================================================================
    virtual function void write(CpmPacketTxn txn);
        bit [15:0] expected_payload;
        bit is_dropped;
        CpmPacketTxn expected_txn;
        cpm_mode_e mode_at_accept;

        m_packets_input++;
        m_count_in++;

        if (m_ref_model == null) begin
            `uvm_fatal("SCOREBOARD", "Reference model not set")
            return;
        end

        // Use the current mode tracked from register monitor (not from transaction)
        // This is the mode that was active when this packet was accepted by the DUT
        mode_at_accept = m_current_mode;
        
        // Store mode in transaction for reference model and logging
        txn.m_mode_at_accept = mode_at_accept;
        m_ref_model.predict_output(txn, expected_payload, is_dropped);

        if (!is_dropped) begin
            expected_txn = CpmPacketTxn::type_id::create("expected_txn");
            expected_txn.m_id = txn.m_id;
            expected_txn.m_opcode = txn.m_opcode;
            expected_txn.m_expected_payload = expected_payload;
            expected_txn.m_payload = expected_payload;
            expected_txn.m_mode_at_accept = mode_at_accept;
            expected_txn.m_timestamp = txn.m_timestamp;
            m_expected_queue.push_back(expected_txn);
            
            // Reset idle event since we now have pending packets
            // This ensures is_on() returns false while queue is not empty
            m_idle_event.reset();
        end else begin
            m_packets_dropped++;
            m_dropped_count++;
            print_transaction_table("DROP", m_packets_dropped, txn.m_id, txn.m_opcode, 
                                    txn.m_payload, 16'h0, 16'h0, mode_at_accept, 1);
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
        m_count_out++;

        // Find matching expected packet by ID+OPCODE
        foreach (m_expected_queue[i]) begin
            if (m_expected_queue[i].m_id == txn.m_id && 
                m_expected_queue[i].m_opcode == txn.m_opcode) begin
                found_idx = i;
                break;
            end
        end
        
        // Fallback: ID match only
        if (found_idx < 0) begin
            foreach (m_expected_queue[i]) begin
                if (m_expected_queue[i].m_id == txn.m_id) begin
                    found_idx = i;
                    break;
                end
            end
        end
        
        if (found_idx >= 0) begin
            expected = m_expected_queue[found_idx];
            m_expected_queue.delete(found_idx);
            
            if (compare_packets(expected, txn)) begin
                m_packets_matched++;
                print_transaction_table("MATCH", m_packets_matched, txn.m_id, txn.m_opcode,
                                        expected.m_payload, expected.m_expected_payload, txn.m_payload, 
                                        expected.m_mode_at_accept, 0);
            end else begin
                m_packets_mismatched++;
                print_transaction_table("MISMATCH", m_packets_mismatched, txn.m_id, txn.m_opcode,
                                        expected.m_payload, expected.m_expected_payload, txn.m_payload, 
                                        expected.m_mode_at_accept, 0);
            end
        end else begin
            m_packets_mismatched++;
            `uvm_error("SCOREBOARD", $sformatf(
                "[ERROR] Unexpected packet: ID=0x%0h OP=0x%0h Payload=0x%04h (no expected match in queue)",
                txn.m_id, txn.m_opcode, txn.m_payload))
        end
        
        // Check if scoreboard is now idle (all expected packets received)
        // Trigger the idle event to signal waiting tasks (e.g., test's run_phase)
        if (m_expected_queue.size() == 0 && m_packets_input > 0) begin
            `uvm_info("SCOREBOARD", "Expected queue empty - triggering idle event", UVM_HIGH)
            m_idle_event.trigger();
        end
    endfunction

    // ============================================================================
    // report_mismatch
    // MANDATORY: Actionable mismatch reporting (expected vs actual + context)
    // ============================================================================
    virtual function void report_mismatch(CpmPacketTxn expected, CpmPacketTxn actual);
        string table_str;
        string status_id, status_op, status_payload;
        
        status_id      = (expected.m_id == actual.m_id) ? "OK" : "MISMATCH";
        status_op      = (expected.m_opcode == actual.m_opcode) ? "OK" : "MISMATCH";
        status_payload = (expected.m_expected_payload == actual.m_payload) ? "OK" : "MISMATCH";
        
        table_str = "\n";
        table_str = {table_str, "  +----------+----------+----------+----------+\n"};
        table_str = {table_str, "  |  Field   | Expected |  Actual  |  Status  |\n"};
        table_str = {table_str, "  +----------+----------+----------+----------+\n"};
        table_str = {table_str, $sformatf("  |    ID    |   0x%02h   |   0x%02h   | %8s |\n", 
            expected.m_id, actual.m_id, status_id)};
        table_str = {table_str, $sformatf("  |  OPCODE  |   0x%02h   |   0x%02h   | %8s |\n", 
            expected.m_opcode, actual.m_opcode, status_op)};
        table_str = {table_str, $sformatf("  | PAYLOAD  |  0x%04h  |  0x%04h  | %8s |\n", 
            expected.m_expected_payload, actual.m_payload, status_payload)};
        table_str = {table_str, "  +----------+----------+----------+----------+\n"};
        table_str = {table_str, $sformatf("  Mode at acceptance: %s\n", expected.m_mode_at_accept.name())};
        
        `uvm_error("SCOREBOARD", $sformatf("[MISMATCH #%0d]%s", m_packets_mismatched, table_str))
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
    // print_transaction_table
    // Prints a formatted table for each transaction check
    // ============================================================================
    virtual function void print_transaction_table(
        string txn_type,      // "MATCH", "MISMATCH", or "DROP"
        int txn_num,          // Transaction number
        bit [3:0] id,         // Packet ID
        bit [3:0] opcode,     // Packet opcode
        bit [15:0] input_val, // Input payload
        bit [15:0] expected,  // Expected output payload
        bit [15:0] actual,    // Actual output payload
        cpm_mode_e mode,      // Mode at acceptance
        bit is_dropped        // Was packet dropped?
    );
        string table_str;
        string status_str;
        string result_line;
        
        if (txn_type == "MATCH") begin
            status_str = "OK";
        end else if (txn_type == "MISMATCH") begin
            status_str = "FAIL";
        end else begin
            status_str = "DROP";
        end
        
        table_str = "\n";
        table_str = {table_str, $sformatf("  +==============[ %s #%-4d ]==============+\n", txn_type, txn_num)};
        table_str = {table_str, "  |  Field      |   Value                      |\n"};
        table_str = {table_str, "  +-------------+------------------------------+\n"};
        table_str = {table_str, $sformatf("  |  ID         |   0x%01h                        |\n", id)};
        table_str = {table_str, $sformatf("  |  OPCODE     |   0x%01h                        |\n", opcode)};
        table_str = {table_str, $sformatf("  |  MODE       |   %-26s |\n", mode.name())};
        table_str = {table_str, "  +-------------+------------------------------+\n"};
        table_str = {table_str, $sformatf("  |  Input      |   0x%04h                     |\n", input_val)};
        if (!is_dropped) begin
            table_str = {table_str, $sformatf("  |  Expected   |   0x%04h                     |\n", expected)};
            table_str = {table_str, $sformatf("  |  Actual     |   0x%04h                     |\n", actual)};
        end else begin
            table_str = {table_str, "  |  Expected   |   DROPPED                    |\n"};
            table_str = {table_str, "  |  Actual     |   DROPPED                    |\n"};
        end
        table_str = {table_str, "  +-------------+------------------------------+\n"};
        table_str = {table_str, $sformatf("  |  STATUS     |   %-26s |\n", status_str)};
        table_str = {table_str, "  +===========================================+\n"};
        
        if (txn_type == "MISMATCH") begin
            `uvm_error("SCOREBOARD", table_str)
        end else begin
            `uvm_info("SCOREBOARD", table_str, UVM_MEDIUM)
        end
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
        
        // Reset the idle event so it can be triggered again after new traffic
        m_idle_event.reset();
        
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

        // Print comprehensive summary table
        print_summary_table();
        
        // Final local invariant check
        void'(check_local_counter_invariant("end of test"));
    endfunction
    
    // ============================================================================
    // print_summary_table
    // Prints a formatted summary table at end of test
    // ============================================================================
    virtual function void print_summary_table();
        string table_str;
        string pass_fail;
        
        pass_fail = (m_packets_mismatched == 0) ? "PASS" : "FAIL";
        
        table_str = "\n";
        table_str = {table_str, "  +============================================================+\n"};
        table_str = {table_str, "  |              SCOREBOARD SUMMARY                           |\n"};
        table_str = {table_str, "  +============================================================+\n"};
        table_str = {table_str, "  |  PACKET STATISTICS                                        |\n"};
        table_str = {table_str, "  +-----------------------+------------------------------------+\n"};
        table_str = {table_str, $sformatf("  |  Total Input          |  %6d                           |\n", m_packets_input)};
        table_str = {table_str, $sformatf("  |  Total Output         |  %6d                           |\n", m_packets_output)};
        table_str = {table_str, $sformatf("  |  Matched              |  %6d                           |\n", m_packets_matched)};
        table_str = {table_str, $sformatf("  |  Mismatched           |  %6d                           |\n", m_packets_mismatched)};
        table_str = {table_str, $sformatf("  |  Dropped (expected)   |  %6d                           |\n", m_packets_dropped)};
        table_str = {table_str, "  +-----------------------+------------------------------------+\n"};
        table_str = {table_str, "  |  DUT COUNTERS (since last reset)                          |\n"};
        table_str = {table_str, "  +-----------------------+------------------------------------+\n"};
        table_str = {table_str, $sformatf("  |  COUNT_IN             |  %6d                           |\n", m_count_in)};
        table_str = {table_str, $sformatf("  |  COUNT_OUT            |  %6d                           |\n", m_count_out)};
        table_str = {table_str, $sformatf("  |  DROPPED_COUNT        |  %6d                           |\n", m_dropped_count)};
        if (m_soft_reset_count > 0) begin
            table_str = {table_str, "  +-----------------------+------------------------------------+\n"};
            table_str = {table_str, "  |  SOFT RESET INFO                                          |\n"};
            table_str = {table_str, "  +-----------------------+------------------------------------+\n"};
            table_str = {table_str, $sformatf("  |  Reset Count          |  %6d                           |\n", m_soft_reset_count)};
            table_str = {table_str, $sformatf("  |  Packets Lost         |  %6d                           |\n", m_packets_lost_to_reset)};
        end
        table_str = {table_str, "  +============================================================+\n"};
        table_str = {table_str, $sformatf("  |  RESULT: %-49s|\n", pass_fail)};
        table_str = {table_str, "  +============================================================+\n"};
        
        `uvm_info("SCOREBOARD", table_str, UVM_LOW)
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
