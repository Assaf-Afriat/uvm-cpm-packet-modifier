/**
 * @file CpmStressSeq.sv
 * @brief CPM Stress Sequence
 * 
 * Stress sequence for burst traffic to cause stalls/backpressure.
 * MANDATORY: Burst traffic to cause stalls/backpressure.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmStressSeq extends uvm_sequence #(CpmPacketTxn);

    `uvm_object_utils(CpmStressSeq)

    // ============================================================================
    // Configuration
    // ============================================================================
    int m_num_packets = 200;   // Increased for better coverage
    int m_burst_size = 20;     // Larger bursts to stress pipeline

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmStressSeq");
        super.new(name);
    endfunction

    // ============================================================================
    // body
    // MANDATORY: Burst traffic to cause stalls/backpressure
    // ============================================================================
    virtual task body();
        CpmPacketTxn txn;
        int num_bursts = m_num_packets / m_burst_size;
        
        `uvm_info("STRESS_SEQ", $sformatf("Starting stress sequence: %0d packets in %0d bursts",
            m_num_packets, num_bursts), UVM_MEDIUM)
        
        // Send burst of packets to cause backpressure
        repeat (num_bursts) begin
            // Send burst without delays to stress the pipeline
            repeat (m_burst_size) begin
                txn = CpmPacketTxn::type_id::create("txn");
                start_item(txn);
                assert(txn.randomize());
                finish_item(txn);
            end
            // Small delay between bursts
            #10;
        end
        
        `uvm_info("STRESS_SEQ", "Stress sequence complete", UVM_MEDIUM)
    endtask

endclass : CpmStressSeq
