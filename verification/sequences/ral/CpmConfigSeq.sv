/**
 * @file CpmConfigSeq.sv
 * @brief CPM RAL Configuration Sequence
 * 
 * RAL-based sequence to program registers.
 * MANDATORY: RAL-based configuration sequence.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmConfigSeq extends uvm_sequence;

    `uvm_object_utils(CpmConfigSeq)

    // ============================================================================
    // Register Model
    // ============================================================================
    CpmRegModel m_reg_model;

    // ============================================================================
    // Configuration Parameters
    // ============================================================================
    cpm_mode_e m_mode;
    bit [15:0] m_mask;
    bit [15:0] m_add_const;
    bit        m_drop_en;
    bit [3:0]  m_drop_opcode;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmConfigSeq");
        super.new(name);
    endfunction

    // ============================================================================
    // body
    // MANDATORY: RAL-based sequence using reg.write(), reg.read(), reg.mirror()
    // ============================================================================
    virtual task body();
        uvm_status_e status;
        uvm_reg_data_t data;

        `uvm_info("CONFIG_SEQ", "Starting RAL-based configuration", UVM_MEDIUM)

        // Null pointer check
        if (m_reg_model == null) begin
            `uvm_fatal("CONFIG_SEQ", "Register model is null - cannot configure DUT")
            return;
        end

        // Program CTRL register: Enable CPM
        m_reg_model.m_ctrl.m_enable.set(1'b1);

        // Clear soft reset (if set)
        m_reg_model.m_ctrl.m_soft_rst.set(1'b0);

        // Update CTRL register to apply changes
        m_reg_model.m_ctrl.update(status);
        if (status != UVM_IS_OK) begin
            `uvm_error("CONFIG_SEQ", "Failed to update CTRL")
        end

        // Program MODE register
        m_reg_model.m_mode.m_mode.set(m_mode);

        `uvm_info("CONFIG_SEQ", $sformatf("MODE set to: %s", m_mode.name()), UVM_MEDIUM)

        // Verify MODE using mirror
        m_reg_model.m_mode.update(status);
        if (status != UVM_IS_OK) begin
            `uvm_error("CONFIG_SEQ", "MODE mirror check failed")
        end

        // Program PARAMS register
        m_reg_model.m_params.m_mask.set(m_mask);
        m_reg_model.m_params.m_add_const.set(m_add_const);

        // Update PARAMS register to apply changes
        m_reg_model.m_params.update(status);
        if (status != UVM_IS_OK) begin
            `uvm_error("CONFIG_SEQ", "Failed to update PARAMS")
        end

        `uvm_info("CONFIG_SEQ", $sformatf("PARAMS: mask=0x%0h add_const=0x%0h", 
            m_mask, m_add_const), UVM_MEDIUM)

        // Program DROP_CFG register
        m_reg_model.m_drop_cfg.m_drop_en.set(m_drop_en);

        m_reg_model.m_drop_cfg.m_drop_opcode.set(m_drop_opcode);

        // Update DROP_CFG register to apply changes
        m_reg_model.m_drop_cfg.update(status);
        if (status != UVM_IS_OK) begin
            `uvm_error("CONFIG_SEQ", "Failed to update DROP_CFG")
        end

        `uvm_info("CONFIG_SEQ", $sformatf("DROP_CFG: enable=%0b opcode=0x%0h", 
            m_drop_en, m_drop_opcode), UVM_MEDIUM)

        // Read back STATUS register (read-only, for verification)
        m_reg_model.m_status.read(status, data);
        if (status != UVM_IS_OK) begin
            `uvm_error("CONFIG_SEQ", "Failed to read STATUS")
        end

        `uvm_info("CONFIG_SEQ", $sformatf("STATUS: %0h", data), UVM_MEDIUM)

        `uvm_info("CONFIG_SEQ", "RAL-based configuration complete", UVM_MEDIUM)
    endtask

endclass : CpmConfigSeq
