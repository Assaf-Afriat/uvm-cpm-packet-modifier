/**
 * @file CpmRalResetTest.sv
 * @brief CPM RAL Reset Test
 * 
 * MANDATORY: RAL reset test using uvm_reg_hw_reset_seq.
 * Verifies reset values of all registers.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRalResetTest extends CpmBaseTest;

    `uvm_component_utils(CpmRalResetTest)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRalResetTest", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // run_phase
    // MANDATORY: Run uvm_reg_hw_reset_seq and verify reset values
    // ============================================================================
    virtual task run_phase(uvm_phase phase);
        uvm_reg_hw_reset_seq reset_seq;
        uvm_status_e status;
        uvm_reg_data_t data;

        phase.raise_objection(this);

        `uvm_info("TEST", "Starting RAL reset test", UVM_MEDIUM)

        // Run hardware reset sequence (MANDATORY)
        reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
        reset_seq.model = m_env.m_reg_model;
        reset_seq.start(m_env.m_reg_agent.m_sequencer);

        `uvm_info("TEST", "Hardware reset sequence completed", UVM_MEDIUM)

        // Verify reset values via RAL
        // CTRL: 0x0 (ENABLE=0, SOFT_RST=0)
        m_env.m_reg_model.m_ctrl.m_enable.read(status, data);
        if (status == UVM_IS_OK && data == 0) begin
            `uvm_info("TEST", "CTRL.ENABLE reset value verified: 0x0", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("CTRL.ENABLE reset value mismatch: expected=0x0, got=0x%0h", data))
        end

        // MODE: 0x0 (MODE=PASS)
        m_env.m_reg_model.m_mode.m_mode.read(status, data);
        if (status == UVM_IS_OK && data == CPM_MODE_PASS) begin
            `uvm_info("TEST", "MODE reset value verified: PASS", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("MODE reset value mismatch: expected=PASS, got=0x%0h", data))
        end

        // PARAMS: 0x0 (MASK=0, ADD_CONST=0)
        m_env.m_reg_model.m_params.m_mask.read(status, data);
        if (status == UVM_IS_OK && data == 0) begin
            `uvm_info("TEST", "PARAMS.MASK reset value verified: 0x0", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("PARAMS.MASK reset value mismatch: expected=0x0, got=0x%0h", data))
        end

        // DROP_CFG: 0x0 (DROP_EN=0, DROP_OPCODE=0)
        m_env.m_reg_model.m_drop_cfg.m_drop_en.read(status, data);
        if (status == UVM_IS_OK && data == 0) begin
            `uvm_info("TEST", "DROP_CFG.DROP_EN reset value verified: 0x0", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("DROP_CFG.DROP_EN reset value mismatch: expected=0x0, got=0x%0h", data))
        end

        // STATUS: 0x0 (BUSY=0)
        m_env.m_reg_model.m_status.m_busy.read(status, data);
        if (status == UVM_IS_OK && data == 0) begin
            `uvm_info("TEST", "STATUS.BUSY reset value verified: 0x0", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("STATUS.BUSY reset value mismatch: expected=0x0, got=0x%0h", data))
        end

        // COUNT_IN: 0x0
        m_env.m_reg_model.m_count_in.m_count_in.read(status, data);
        if (status == UVM_IS_OK && data == 0) begin
            `uvm_info("TEST", "COUNT_IN reset value verified: 0x0", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("COUNT_IN reset value mismatch: expected=0x0, got=0x%0h", data))
        end

        // COUNT_OUT: 0x0
        m_env.m_reg_model.m_count_out.m_count_out.read(status, data);
        if (status == UVM_IS_OK && data == 0) begin
            `uvm_info("TEST", "COUNT_OUT reset value verified: 0x0", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("COUNT_OUT reset value mismatch: expected=0x0, got=0x%0h", data))
        end

        // DROPPED_COUNT: 0x0
        m_env.m_reg_model.m_dropped_count.m_dropped_count.read(status, data);
        if (status == UVM_IS_OK && data == 0) begin
            `uvm_info("TEST", "DROPPED_COUNT reset value verified: 0x0", UVM_MEDIUM)
        end else begin
            `uvm_error("TEST", $sformatf("DROPPED_COUNT reset value mismatch: expected=0x0, got=0x%0h", data))
        end

        `uvm_info("TEST", "RAL reset test completed - all reset values verified", UVM_MEDIUM)

        phase.drop_objection(this);
    endtask

endclass : CpmRalResetTest
