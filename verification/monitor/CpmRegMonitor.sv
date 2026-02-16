/**
 * @file CpmRegMonitor.sv
 * @brief CPM Register Monitor
 * 
 * Monitor for register bus interface.
 * Observes transactions and sends to RAL predictor/coverage via TLM.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegMonitor extends uvm_monitor;

    `uvm_component_utils(CpmRegMonitor)

    // ============================================================================
    // Virtual Interface
    // ============================================================================
    virtual CpmRegIf m_vif;

    // ============================================================================
    // TLM Analysis Port
    // ============================================================================
    uvm_analysis_port #(CpmRegTxn) m_ap;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegMonitor", uvm_component parent = null);
        super.new(name, parent);
        m_ap = new("m_ap", this);
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
        virtual CpmRegIf reg_if;
        super.connect_phase(phase);
        // Get virtual interface from config_db (set by tb_top)
        if (!uvm_config_db#(virtual CpmRegIf)::get(this, "", "reg_if", reg_if)) begin
            `uvm_fatal("NO_REG_IF", "Reg interface not set - check tb_top")
        end
        m_vif = reg_if;
    endfunction

    // ============================================================================
    // run_phase
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
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
            if (m_vif.reg_fire) 
            begin
                monitor_reg_transaction();
            end
        end
    endtask

    // ============================================================================
    // monitor_reg_transaction
    // Extract register transaction from interface
    // ============================================================================
    virtual task monitor_reg_transaction();
        CpmRegTxn txn;
        txn = CpmRegTxn::type_id::create("txn");
        txn.m_addr = m_vif.addr;
        txn.m_write_en = m_vif.write_en;
        if (m_vif.write_en) begin
            txn.m_wdata = m_vif.wdata;
            `uvm_info("MON", $sformatf("Register WRITE: addr=0x%0h wdata=0x%0h",
                txn.m_addr, txn.m_wdata), UVM_HIGH)
        end else begin
            txn.m_rdata = m_vif.rdata;
            `uvm_info("MON", $sformatf("Register READ: addr=0x%0h rdata=0x%0h",
                txn.m_addr, txn.m_rdata), UVM_HIGH)
        end
        m_ap.write(txn);
    endtask

endclass : CpmRegMonitor
