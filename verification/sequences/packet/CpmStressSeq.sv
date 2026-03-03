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
    int m_num_packets = 200;

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
        
        `uvm_info("STRESS_SEQ", $sformatf("Starting stress sequence: %0d packets", m_num_packets), UVM_MEDIUM)
        
        // Send packets back-to-back to stress the pipeline and cause backpressure
        repeat (m_num_packets) begin
            txn = CpmPacketTxn::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize());
            finish_item(txn);
        end
        
        `uvm_info("STRESS_SEQ", "Stress sequence complete", UVM_MEDIUM)
    endtask

endclass : CpmStressSeq
