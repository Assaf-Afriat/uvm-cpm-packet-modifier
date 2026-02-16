/**
 * @file CpmBaseTrafficSeq.sv
 * @brief CPM Base Traffic Sequence
 * 
 * Base traffic sequence for random packet stimulus.
 * MANDATORY: Random packet stimulus.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmBaseTrafficSeq extends uvm_sequence #(CpmPacketTxn);

    `uvm_object_utils(CpmBaseTrafficSeq)

    // ============================================================================
    // Configuration
    // ============================================================================
    int m_num_packets = 100;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmBaseTrafficSeq");
        super.new(name);
    endfunction

    // ============================================================================
    // body
    // ============================================================================
    virtual task body();
        CpmPacketTxn txn;
        repeat (m_num_packets) begin
            txn = CpmPacketTxn::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize());
            finish_item(txn);
        end
    endtask

endclass : CpmBaseTrafficSeq
