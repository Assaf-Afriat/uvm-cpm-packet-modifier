/**
 * @file CpmCoverageTrafficSeq.sv
 * @brief CPM Coverage Traffic Sequence
 * 
 * Coverage traffic sequence for factory override demonstration.
 * Forces rare MODE/opcode combinations.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmCoverageTrafficSeq extends CpmBaseTrafficSeq;

    `uvm_object_utils(CpmCoverageTrafficSeq)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmCoverageTrafficSeq");
        super.new(name);
    endfunction

    // ============================================================================
    // body
    // Generates all 16 opcodes with varied payloads to maximize coverage
    // When called for each mode, this guarantees all 64 combinations
    // Also sends edge-case payloads for better toggle coverage
    // ============================================================================
    virtual task body();
        CpmPacketTxn txn;
        bit [15:0] edge_payloads[] = '{16'h0000, 16'hFFFF, 16'h5555, 16'hAAAA, 
                                       16'h0001, 16'h8000, 16'h7FFF, 16'hFFFE};
        
        `uvm_info("COV_TRAFFIC_SEQ", "Starting coverage traffic: ALL 16 opcodes + edge payloads", UVM_MEDIUM)
        
        // Generate all 16 opcodes explicitly to guarantee full coverage
        for (int opcode = 0; opcode < 16; opcode++)
        begin
            txn = CpmPacketTxn::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize() with {
                txn.m_opcode == opcode;  // Force specific opcode
            });
            finish_item(txn);
        end
        
        // Send edge-case payloads for better toggle coverage
        foreach (edge_payloads[i])
        begin
            txn = CpmPacketTxn::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize() with {
                txn.m_payload == edge_payloads[i];
            });
            finish_item(txn);
        end
        
        // Send all-IDs packets for ID toggle coverage
        for (int id = 0; id < 16; id++)
        begin
            txn = CpmPacketTxn::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize() with {
                txn.m_id == id;
            });
            finish_item(txn);
        end
        
        `uvm_info("COV_TRAFFIC_SEQ", "Coverage traffic complete: opcodes + payloads + IDs", UVM_MEDIUM)
    endtask

endclass : CpmCoverageTrafficSeq
