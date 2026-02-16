/**
 * @file CpmPacketMonitor.sv
 * @brief CPM Packet Monitor
 * 
 * Monitor for packet stream interface.
 * Observes transactions and sends to scoreboard/coverage via TLM.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmPacketMonitor extends uvm_monitor;

    `uvm_component_utils(CpmPacketMonitor)
    `uvm_register_cb(CpmPacketMonitor, CpmBaseMonitorCb)

    // ============================================================================
    // Virtual Interface
    // ============================================================================
    virtual CpmStreamIf m_vif;

    // ============================================================================
    // TLM Analysis Ports
    // ============================================================================
    uvm_analysis_port #(CpmPacketTxn) m_ap_input;   // Input transactions
    uvm_analysis_port #(CpmPacketTxn) m_ap_output;  // Output transactions

    // ============================================================================
    // Latency Tracking
    // ============================================================================
    typedef struct {
        time timestamp;
        bit [3:0] id;
        bit [3:0] opcode;
        bit [15:0] payload;
        cpm_mode_e mode_at_accept;  // Mode at input acceptance time
    } input_packet_t;

    input_packet_t m_input_queue[$];  // Queue to track input packets for latency

    // ============================================================================
    // Reference Model and RAL Model (for getting current mode)
    // ============================================================================
    CpmRefModel m_ref_model;
    CpmRegModel m_reg_model;  // RAL model for reading current mode

    // ============================================================================
    // Statistics
    // ============================================================================
    int m_packets_in = 0;
    int m_packets_out = 0;
    int m_packets_dropped = 0;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmPacketMonitor", uvm_component parent = null);
        super.new(name, parent);
        m_ap_input = new("m_ap_input", this);
        m_ap_output = new("m_ap_output", this);
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Virtual interface will be set in connect_phase by agent
        // Reference model will be set by environment in connect_phase
        m_ref_model = null;
    endfunction

    // ============================================================================
    // connect_phase
    // Get virtual interface (set by agent in connect_phase)
    // ============================================================================
    virtual function void connect_phase(uvm_phase phase);
        virtual CpmStreamIf stream_if;
        super.connect_phase(phase);
        // Get virtual interface from config_db (set by tb_top)
        if (!uvm_config_db#(virtual CpmStreamIf)::get(this, "", "stream_if", stream_if)) begin
            `uvm_fatal("NO_STREAM_IF", "Stream interface not set - check tb_top")
        end
        m_vif = stream_if;
    endfunction

    // ============================================================================
    // run_phase
    // Monitor both input and output streams
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        fork
            monitor_input();
            monitor_output();
        join
    endtask

    // ============================================================================
    // monitor_input
    // Monitor input stream for latency measurement
    // ============================================================================
    virtual task monitor_input();
        // Null pointer check
        if (m_vif == null) 
        begin
            `uvm_fatal("MON", "Virtual interface is null - monitor cannot run")
            return;
        end
        
        // Wait for reset to deassert
        do 
        begin
            @(posedge m_vif.clk);
        end 
        while (m_vif.rst);

        // Main monitoring loop - clock edge MUST be first to prevent zero-time hang
        forever 
        begin
            @(posedge m_vif.clk);  // Time advancement guaranteed here
            if (m_vif.in_fire) 
            begin
                monitor_input_packet();
            end
        end
    endtask

    // ============================================================================
    // monitor_output
    // Monitor output stream
    // ============================================================================
    virtual task monitor_output();
        // Null pointer check
        if (m_vif == null) 
        begin
            `uvm_fatal("MON", "Virtual interface is null - monitor cannot run")
            return;
        end
        
        // Wait for reset to deassert
        do 
        begin
            @(posedge m_vif.clk);
        end 
        while (m_vif.rst);

        // Main monitoring loop - clock edge MUST be first to prevent zero-time hang
        forever 
        begin
            @(posedge m_vif.clk);  // Time advancement guaranteed here
            if (m_vif.out_fire) 
            begin
                monitor_output_packet();
            end
        end
    endtask

    // ============================================================================
    // monitor_input_packet
    // Extract input packet and track for latency
    // MANDATORY: Capture mode_at_accept (configuration at input acceptance time)
    // ============================================================================
    virtual task monitor_input_packet();
        CpmPacketTxn txn;
        input_packet_t pkt;
        cpm_mode_e mode_at_accept;
        
        `uvm_do_callbacks(CpmPacketMonitor, CpmBaseMonitorCb, pre_monitor_input())

        // Get current mode from RAL model's mirrored value (configuration at acceptance time)
        // The RAL predictor automatically updates this when MODE register is written
        if (m_reg_model != null) begin
            mode_at_accept = cpm_mode_e'(m_reg_model.m_mode.m_mode.get_mirrored_value());
        end else if (m_ref_model != null) begin
            mode_at_accept = m_ref_model.m_mode;  // Fallback to ref model
        end else begin
            mode_at_accept = CPM_MODE_PASS;  // Default fallback
        end

        txn = CpmPacketTxn::type_id::create("txn");
        txn.m_id = m_vif.in_id;
        txn.m_opcode = m_vif.in_opcode;
        txn.m_payload = m_vif.in_payload;
        txn.m_timestamp = $time;
        txn.m_mode_at_accept = mode_at_accept;  // MANDATORY: Store mode at acceptance

        // Store in queue for latency matching
        pkt.timestamp = $time;
        pkt.id = m_vif.in_id;
        pkt.opcode = m_vif.in_opcode;
        pkt.payload = m_vif.in_payload;
        pkt.mode_at_accept = mode_at_accept;
        m_input_queue.push_back(pkt);

        m_packets_in++;
        m_ap_input.write(txn);

        `uvm_do_callbacks(CpmPacketMonitor, CpmBaseMonitorCb, post_monitor_input(txn))
        
        `uvm_info("MON", $sformatf("Input packet: %s (mode_at_accept=%s)", 
            txn.convert2string(), mode_at_accept.name()), UVM_HIGH)
    endtask

    // ============================================================================
    // monitor_output_packet
    // Extract output packet and calculate latency
    // ============================================================================
    virtual task monitor_output_packet();
        CpmPacketTxn txn;
        input_packet_t pkt;
        time latency = 0;
        int found_idx = -1;

        `uvm_do_callbacks(CpmPacketMonitor, CpmBaseMonitorCb, pre_monitor_output())

        txn = CpmPacketTxn::type_id::create("txn");
        txn.m_id = m_vif.out_id;
        txn.m_opcode = m_vif.out_opcode;
        txn.m_payload = m_vif.out_payload;
        txn.m_timestamp = $time;

        // Find matching input packet by ID (FIFO order)
        // Note: In a real system, we'd match by ID, but for simplicity, use FIFO
        if (m_input_queue.size() > 0) begin
            pkt = m_input_queue.pop_front();
            latency = $time - pkt.timestamp;
            txn.m_timestamp = pkt.timestamp;  // Store input timestamp
        end

        m_packets_out++;
        m_ap_output.write(txn);

        `uvm_do_callbacks(CpmPacketMonitor, CpmBaseMonitorCb, post_monitor_output(txn))
        
        `uvm_info("MON", $sformatf("Output packet: %s (latency=%0t)", 
            txn.convert2string(), latency), UVM_HIGH)
    endtask

    // ============================================================================
    // report_phase
    // Report statistics and check for lost packets (queue desync)
    // ============================================================================
    virtual function void report_phase(uvm_phase phase);
        int queue_size;
        queue_size = m_input_queue.size();
        
        `uvm_info("MON", $sformatf("Packet Monitor Statistics: In=%0d Out=%0d Dropped=%0d",
            m_packets_in, m_packets_out, m_packets_dropped), UVM_MEDIUM)
        
        // Check for desynchronized queue (lost packets or timing issues)
        if (queue_size > 0) 
        begin
            `uvm_warning("MON", $sformatf(
                "Input queue has %0d unmatched packets - possible dropped packets or DUT bug",
                queue_size))
        end
    endfunction

endclass : CpmPacketMonitor
