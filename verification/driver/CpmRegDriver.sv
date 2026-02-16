/**
 * @file CpmRegDriver.sv
 * @brief CPM Register Driver
 * 
 * Driver for register bus interface.
 * Implements req/gnt handshake protocol.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegDriver extends uvm_driver #(CpmRegTxn);

    `uvm_component_utils(CpmRegDriver)
    `uvm_register_cb(CpmRegDriver, CpmBaseRegCb)

    // ============================================================================
    // Virtual Interface
    // ============================================================================
    virtual CpmRegIf m_vif;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegDriver", uvm_component parent = null);
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
        if (!uvm_config_db#(virtual CpmRegIf)::get(this, "", "reg_if", m_vif)) begin
            `uvm_fatal("NO_REG_IF", "Reg interface not set - check tb_top")
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
            `uvm_do_callbacks(CpmRegDriver, CpmBaseRegCb, pre_drive(this, req))
            drive_reg_transaction(req);
            `uvm_do_callbacks(CpmRegDriver, CpmBaseRegCb, post_drive(this, req))
            seq_item_port.item_done();
        end
    endtask

    // ============================================================================
    // drive_reg_transaction
    // Implements req/gnt handshake protocol
    // Per spec: gnt is always asserted when req is asserted (no wait states)
    // ============================================================================
    virtual task drive_reg_transaction(CpmRegTxn txn);
        string op_str = (txn.m_write_en) ? "WRITE" : "READ";
        
        // Setup transaction signals
        m_vif.write_en <= txn.m_write_en;
        m_vif.addr <= txn.m_addr;
        if (txn.m_write_en) begin
            m_vif.wdata <= txn.m_wdata;
        end

        // Assert req (transaction starts)
        @(posedge m_vif.clk);
        m_vif.req <= 1'b1;

        // Per spec: gnt is always asserted when req is asserted (no wait states)
        // Transaction completes in the same cycle - sample data immediately
        @(posedge m_vif.clk);
        
        // Transaction accepted (req && gnt) - per spec, gnt is always asserted
        // No need to wait for gnt, it's guaranteed to be high
        if (txn.m_write_en) begin
            `uvm_info("DRV", $sformatf("Register WRITE: addr=0x%0h wdata=0x%0h", 
                txn.m_addr, txn.m_wdata), UVM_HIGH)
        end else begin
            txn.m_rdata = m_vif.rdata;
            `uvm_info("DRV", $sformatf("Register READ: addr=0x%0h rdata=0x%0h", 
                txn.m_addr, txn.m_rdata), UVM_HIGH)
        end

        // Deassert req
        m_vif.req <= 1'b0;
        
        // Clear signals
        @(posedge m_vif.clk);
    endtask

    // ============================================================================
    // reset_driver
    // Reset driver state (called during reset)
    // ============================================================================
    virtual task reset_driver();
        m_vif.req <= 1'b0;
        m_vif.write_en <= 1'b0;
        m_vif.addr <= 8'h0;
        m_vif.wdata <= 32'h0;
    endtask

endclass : CpmRegDriver
