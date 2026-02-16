/**
 * @file CpmPacketDriver.sv
 * @brief CPM Packet Driver
 * 
 * Driver for packet stream interface.
 * Implements valid/ready handshake protocol.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmPacketDriver extends uvm_driver #(CpmPacketTxn);

    `uvm_component_utils(CpmPacketDriver)
    `uvm_register_cb(CpmPacketDriver, CpmBasePacketCb)

    // ============================================================================
    // Virtual Interface
    // ============================================================================
    virtual CpmStreamIf m_vif;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmPacketDriver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Virtual interface will be set in connect_phase by agent
    endfunction

    // ============================================================================
    // connect_phase
    // Get virtual interface (set by agent in connect_phase)
    // ============================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Get virtual interface from config_db (set by tb_top)
        if (!uvm_config_db#(virtual CpmStreamIf)::get(this, "", "stream_if", m_vif)) begin
            `uvm_fatal("NO_STREAM_IF", "Stream interface not set - check tb_top")
        end
    endfunction

    // ============================================================================
    // run_phase
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        // Null pointer check
        if (m_vif == null) 
        begin
            `uvm_fatal("DRV", "Virtual interface is null - driver cannot run")
            return;
        end
        
        // Initialize driver state
        reset_driver();
        
        // Wait for reset to deassert
        do 
        begin
            @(posedge m_vif.clk);
        end 
        while (m_vif.rst);

        // Main driver loop - get_next_item blocks until sequence provides item
        forever 
        begin
            seq_item_port.get_next_item(req);
            `uvm_do_callbacks(CpmPacketDriver, CpmBasePacketCb, pre_drive(this, req))
            drive_packet(req);
            `uvm_do_callbacks(CpmPacketDriver, CpmBasePacketCb, post_drive(this, req))
            seq_item_port.item_done();
        end
    endtask

    // ============================================================================
    // drive_packet
    // Implements valid/ready handshake protocol with backpressure handling
    // ============================================================================
    virtual task drive_packet(CpmPacketTxn txn);
        // Set timestamp for latency measurement
        txn.m_timestamp = $time;

        // Drive packet fields (must be stable until accepted)
        m_vif.in_id <= txn.m_id;
        m_vif.in_opcode <= txn.m_opcode;
        m_vif.in_payload <= txn.m_payload;

        // Assert valid and wait for ready (handshake)
        m_vif.in_valid <= 1'b1;
        
        // Wait for acceptance: in_fire = in_valid && in_ready
        @(posedge m_vif.clk);
        while (!m_vif.in_ready) begin
            // Backpressure: ready deasserted, keep signals stable
            // Per spec: if in_valid && !in_ready, signals must remain stable
            @(posedge m_vif.clk);
        end

        // Packet accepted (in_fire occurred)
        `uvm_info("DRV", $sformatf("Packet accepted: %s", txn.convert2string()), UVM_HIGH)

        // Deassert valid after acceptance
        m_vif.in_valid <= 1'b0;
        
        // Clear data signals (optional, but clean)
        @(posedge m_vif.clk);
    endtask

    // ============================================================================
    // reset_driver
    // Reset driver state (called during reset)
    // ============================================================================
    virtual task reset_driver();
        m_vif.in_valid <= 1'b0;
        m_vif.in_id <= 4'h0;
        m_vif.in_opcode <= 4'h0;
        m_vif.in_payload <= 16'h0;
    endtask

endclass : CpmPacketDriver
