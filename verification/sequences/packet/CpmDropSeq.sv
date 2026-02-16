/**
 * @file CpmDropSeq.sv
 * @brief CPM Drop Sequence
 * 
 * Sequence to force opcode matching drop configuration.
 * MANDATORY: Force opcode matching drop configuration.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmDropSeq extends uvm_sequence #(CpmPacketTxn);

    `uvm_object_utils(CpmDropSeq)

    // ============================================================================
    // Configuration
    // ============================================================================
    bit [3:0] m_drop_opcode;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmDropSeq");
        super.new(name);
    endfunction

    // ============================================================================
    // Configuration
    // ============================================================================
    int m_num_packets = 20;

    // ============================================================================
    // body
    // MANDATORY: Force opcode matching drop configuration
    // ============================================================================
    virtual task body();
        CpmPacketTxn txn;
        
        `uvm_info("DROP_SEQ", $sformatf("Starting drop sequence: opcode=0x%0h, num_packets=%0d",
            m_drop_opcode, m_num_packets), UVM_MEDIUM)
        
        // Send packets with opcode that matches drop configuration
        repeat (m_num_packets) begin
            txn = CpmPacketTxn::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize() with {txn.m_opcode == m_drop_opcode;});
            finish_item(txn);
        end
        
        // Also send some packets with different opcodes (should not be dropped)
        repeat (5) begin
            txn = CpmPacketTxn::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize() with {txn.m_opcode != m_drop_opcode;});
            finish_item(txn);
        end
        
        `uvm_info("DROP_SEQ", "Drop sequence complete", UVM_MEDIUM)
    endtask

endclass : CpmDropSeq
