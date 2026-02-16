/**
 * @file CpmBasePacketCb.sv
 * @brief CPM Base Packet Callback
 * 
 * Base callback class for packet driver.
 * MANDATORY: At least one callback with real purpose.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmBasePacketCb extends uvm_callback;

    `uvm_object_utils(CpmBasePacketCb)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmBasePacketCb");
        super.new(name);
    endfunction

    // ============================================================================
    // Callback Methods
    // ============================================================================
    virtual task pre_drive(CpmPacketDriver driver, CpmPacketTxn txn);
        // Override in derived classes
        // Example: Modify transaction, add metadata, log information
    endtask

    virtual task post_drive(CpmPacketDriver driver, CpmPacketTxn txn);
        // Override in derived classes
        // Example: Measure latency, update statistics, log completion
        // MANDATORY: Must have real purpose (e.g., latency measurement, statistics)
    endtask

endclass : CpmBasePacketCb


// ============================================================================
// CpmPacketStatsCb - Concrete callback with real purpose
// Tracks packet statistics: count per opcode, min/max payload values
// ============================================================================
class CpmPacketStatsCb extends CpmBasePacketCb;

    `uvm_object_utils(CpmPacketStatsCb)

    // Statistics tracking
    int m_opcode_count[16];       // Count of packets per opcode
    int m_total_packets;          // Total packets driven
    bit [15:0] m_min_payload;     // Minimum payload value seen
    bit [15:0] m_max_payload;     // Maximum payload value seen
    time m_first_packet_time;     // Time of first packet
    time m_last_packet_time;      // Time of last packet

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmPacketStatsCb");
        super.new(name);
        m_total_packets = 0;
        m_min_payload = 16'hFFFF;
        m_max_payload = 16'h0000;
        m_first_packet_time = 0;
        foreach (m_opcode_count[i]) m_opcode_count[i] = 0;
    endfunction

    // ============================================================================
    // pre_drive - Called before packet is driven
    // Real purpose: Tag packet with sequence number for debugging
    // ============================================================================
    virtual task pre_drive(CpmPacketDriver driver, CpmPacketTxn txn);
        if (m_total_packets == 0) begin
            m_first_packet_time = $time;
        end
    endtask

    // ============================================================================
    // post_drive - Called after packet is driven
    // Real purpose: Collect statistics on driven packets
    // ============================================================================
    virtual task post_drive(CpmPacketDriver driver, CpmPacketTxn txn);
        // Update statistics
        m_total_packets++;
        m_opcode_count[txn.m_opcode]++;
        m_last_packet_time = $time;
        
        // Track payload range
        if (txn.m_payload < m_min_payload) m_min_payload = txn.m_payload;
        if (txn.m_payload > m_max_payload) m_max_payload = txn.m_payload;
        
        // Log every 100th packet for progress tracking
        if (m_total_packets % 100 == 0) begin
            `uvm_info("PACKET_CB", $sformatf("Progress: %0d packets driven", m_total_packets), UVM_MEDIUM)
        end
    endtask

    // ============================================================================
    // get_statistics - Return formatted statistics string
    // ============================================================================
    function string get_statistics();
        string s;
        int opcodes_used = 0;
        
        foreach (m_opcode_count[i]) begin
            if (m_opcode_count[i] > 0) opcodes_used++;
        end
        
        s = $sformatf("Packet Callback Statistics:\n");
        s = {s, $sformatf("  Total packets: %0d\n", m_total_packets)};
        s = {s, $sformatf("  Opcodes used: %0d/16\n", opcodes_used)};
        s = {s, $sformatf("  Payload range: 0x%04h - 0x%04h\n", m_min_payload, m_max_payload)};
        s = {s, $sformatf("  Duration: %0t - %0t\n", m_first_packet_time, m_last_packet_time)};
        return s;
    endfunction

endclass : CpmPacketStatsCb
