/**
 * @file CpmRegCoverage.sv
 * @brief CPM Register Functional Coverage
 * 
 * Functional coverage for register transactions.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegCoverage extends uvm_subscriber #(CpmRegTxn);

    `uvm_component_utils(CpmRegCoverage)

    // ============================================================================
    // Covergroups
    // ============================================================================
    covergroup cg_register with function sample(bit [7:0] addr, bit write_en, 
                                                  bit [31:0] wdata, bit [31:0] rdata);
        // Register address coverage
        cp_addr: coverpoint addr {
            bins addr_ctrl         = {8'h00};
            bins addr_mode         = {8'h04};
            bins addr_params       = {8'h08};
            bins addr_drop_cfg     = {8'h0C};
            bins addr_status       = {8'h10};
            bins addr_count_in     = {8'h14};
            bins addr_count_out    = {8'h18};
            bins addr_dropped_count = {8'h1C};
        }

        // Read/Write operation coverage
        cp_op: coverpoint write_en {
            bins read  = {0};
            bins write = {1};
        }

        // Address × Operation cross coverage
        cp_addr_op: cross cp_addr, cp_op;

        // Register field value coverage (for specific registers)
        cp_mode_value: coverpoint wdata[1:0] iff (addr == 8'h04 && write_en) {
            bins mode_pass = {CPM_MODE_PASS};
            bins mode_xor  = {CPM_MODE_XOR};
            bins mode_add  = {CPM_MODE_ADD};
            bins mode_rot  = {CPM_MODE_ROT};
        }

        cp_ctrl_enable: coverpoint wdata[0] iff (addr == 8'h00 && write_en) {
            bins disabled = {0};
            bins enabled  = {1};
        }

        cp_drop_en: coverpoint wdata[0] iff (addr == 8'h0C && write_en) {
            bins drop_disabled = {0};
            bins drop_enabled  = {1};
        }

        cp_drop_opcode: coverpoint wdata[7:4] iff (addr == 8'h0C && write_en) {
            bins opcode[16] = {[0:15]};
        }
    endgroup

    // ============================================================================
    // Coverage Variables
    // ============================================================================
    bit [7:0]  m_addr;
    bit        m_write_en;
    bit [31:0] m_wdata;
    bit [31:0] m_rdata;

    // ============================================================================
    // Statistics
    // ============================================================================
    int m_total_samples = 0;
    int m_read_samples = 0;
    int m_write_samples = 0;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegCoverage", uvm_component parent = null);
        super.new(name, parent);
        cg_register = new();
    endfunction

    // ============================================================================
    // write
    // Called when monitor observes a register transaction
    // ============================================================================
    virtual function void write(CpmRegTxn t);
        m_addr = t.m_addr;
        m_write_en = t.m_write_en;
        m_wdata = t.m_wdata;
        m_rdata = t.m_rdata;

        cg_register.sample(m_addr, m_write_en, m_wdata, m_rdata);
        m_total_samples++;
        if (m_write_en) m_write_samples++;
        else m_read_samples++;

        `uvm_info("COV", $sformatf("Register coverage sample: %s addr=0x%0h",
            (m_write_en ? "WRITE" : "READ"), m_addr), UVM_HIGH)
    endfunction

    // ============================================================================
    // report_phase
    // Report coverage statistics
    // ============================================================================
    virtual function void report_phase(uvm_phase phase);
        real addr_cov, op_cov, cross_cov;
        
        addr_cov = cg_register.cp_addr.get_coverage();
        op_cov = cg_register.cp_op.get_coverage();
        cross_cov = cg_register.cp_addr_op.get_coverage();

        `uvm_info("COV", $sformatf("Register Coverage: ADDR=%.2f%% OP=%.2f%% CROSS=%.2f%% Samples=%0d (R=%0d W=%0d)",
            addr_cov, op_cov, cross_cov, m_total_samples, m_read_samples, m_write_samples), UVM_MEDIUM)
    endfunction

endclass : CpmRegCoverage
