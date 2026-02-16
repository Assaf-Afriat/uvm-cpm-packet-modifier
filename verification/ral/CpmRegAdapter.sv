/**
 * @file CpmRegAdapter.sv
 * @brief CPM RAL Adapter
 * 
 * RAL adapter for register bus interface.
 * MANDATORY: uvm_reg_adapter for register bus.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegAdapter extends uvm_reg_adapter;

    `uvm_object_utils(CpmRegAdapter)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegAdapter");
        super.new(name);
    endfunction

    // ============================================================================
    // reg2bus
    // Convert RAL transaction to bus transaction
    // ============================================================================
    function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        CpmRegTxn txn;
        txn = CpmRegTxn::type_id::create("txn");
        txn.m_addr = rw.addr;
        txn.m_write_en = (rw.kind == UVM_WRITE);
        if (rw.kind == UVM_WRITE) begin
            txn.m_wdata = rw.data;
        end
        return txn;
    endfunction

    // ============================================================================
    // bus2reg
    // Convert bus transaction to RAL transaction
    // ============================================================================
    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        CpmRegTxn txn;
        if (!$cast(txn, bus_item)) begin
            `uvm_fatal("BUS2REG", "Failed to cast bus_item to CpmRegTxn")
            return;
        end
        rw.kind = (txn.m_write_en) ? UVM_WRITE : UVM_READ;
        rw.addr = txn.m_addr;
        rw.data = (txn.m_write_en) ? txn.m_wdata : txn.m_rdata;
        rw.status = UVM_IS_OK;
    endfunction

endclass : CpmRegAdapter
