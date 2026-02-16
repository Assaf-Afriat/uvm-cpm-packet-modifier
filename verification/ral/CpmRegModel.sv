/**
 * @file CpmRegModel.sv
 * @brief CPM Register Model (RAL)
 * 
 * Register Abstraction Layer model for all 8 CPM registers.
 * MANDATORY: Register model matching DUT spec.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

// Forward declarations
typedef class CpmRegCtrl;
typedef class CpmRegMode;
typedef class CpmRegParams;
typedef class CpmRegDropCfg;
typedef class CpmRegStatus;
typedef class CpmRegCountIn;
typedef class CpmRegCountOut;
typedef class CpmRegDroppedCount;

class CpmRegModel extends uvm_reg_block;

    `uvm_object_utils(CpmRegModel)

    // ============================================================================
    // Register Instances
    // ============================================================================
    CpmRegCtrl         m_ctrl;
    CpmRegMode         m_mode;
    CpmRegParams       m_params;
    CpmRegDropCfg      m_drop_cfg;
    CpmRegStatus       m_status;
    CpmRegCountIn      m_count_in;
    CpmRegCountOut     m_count_out;
    CpmRegDroppedCount m_dropped_count;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegModel");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    // ============================================================================
    // build
    // ============================================================================
    virtual function void build();
        // Create register instances
        m_ctrl          = CpmRegCtrl::type_id::create("m_ctrl");
        m_mode          = CpmRegMode::type_id::create("m_mode");
        m_params        = CpmRegParams::type_id::create("m_params");
        m_drop_cfg      = CpmRegDropCfg::type_id::create("m_drop_cfg");
        m_status        = CpmRegStatus::type_id::create("m_status");
        m_count_in      = CpmRegCountIn::type_id::create("m_count_in");
        m_count_out     = CpmRegCountOut::type_id::create("m_count_out");
        m_dropped_count = CpmRegDroppedCount::type_id::create("m_dropped_count");

        // Configure registers
        m_ctrl.configure(this, null, "");
        m_ctrl.build();

        m_mode.configure(this, null, "");
        m_mode.build();

        m_params.configure(this, null, "");
        m_params.build();

        m_drop_cfg.configure(this, null, "");
        m_drop_cfg.build();

        m_status.configure(this, null, "");
        m_status.build();

        m_count_in.configure(this, null, "");
        m_count_in.build();

        m_count_out.configure(this, null, "");
        m_count_out.build();

        m_dropped_count.configure(this, null, "");
        m_dropped_count.build();

        // Map registers to addresses
        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN, 0);
        default_map.add_reg(m_ctrl,         8'h00, "RW");
        default_map.add_reg(m_mode,         8'h04, "RW");
        default_map.add_reg(m_params,       8'h08, "RW");
        default_map.add_reg(m_drop_cfg,     8'h0C, "RW");
        default_map.add_reg(m_status,       8'h10, "RO");
        default_map.add_reg(m_count_in,     8'h14, "RO");
        default_map.add_reg(m_count_out,    8'h18, "RO");
        default_map.add_reg(m_dropped_count, 8'h1C, "RO");

        lock_model();
    endfunction

endclass : CpmRegModel

// ============================================================================
// Register Definitions
// ============================================================================

// CTRL Register (0x00)
class CpmRegCtrl extends uvm_reg;
    uvm_reg_field m_enable;
    uvm_reg_field m_soft_rst;

    `uvm_object_utils(CpmRegCtrl)

    function new(string name = "CpmRegCtrl");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_enable = uvm_reg_field::type_id::create("m_enable");
        m_enable.configure(this, 1, 0, "RW", 0, 1'b0, 1, 0, 1);

        m_soft_rst = uvm_reg_field::type_id::create("m_soft_rst");
        m_soft_rst.configure(this, 1, 1, "RW", 0, 1'b0, 1, 0, 0);
    endfunction
endclass

// MODE Register (0x04)
class CpmRegMode extends uvm_reg;
    uvm_reg_field m_mode;

    `uvm_object_utils(CpmRegMode)

    function new(string name = "CpmRegMode");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_mode = uvm_reg_field::type_id::create("m_mode");
        m_mode.configure(this, 2, 0, "RW", 0, 2'b00, 1, 0, 0);
    endfunction
endclass

// PARAMS Register (0x08)
class CpmRegParams extends uvm_reg;
    uvm_reg_field m_mask;
    uvm_reg_field m_add_const;

    `uvm_object_utils(CpmRegParams)

    function new(string name = "CpmRegParams");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_mask = uvm_reg_field::type_id::create("m_mask");
        m_mask.configure(this, 16, 0, "RW", 0, 16'h0000, 1, 0, 0);

        m_add_const = uvm_reg_field::type_id::create("m_add_const");
        m_add_const.configure(this, 16, 16, "RW", 0, 16'h0000, 1, 0, 0);
    endfunction
endclass

// DROP_CFG Register (0x0C)
class CpmRegDropCfg extends uvm_reg;
    uvm_reg_field m_drop_en;
    uvm_reg_field m_drop_opcode;

    `uvm_object_utils(CpmRegDropCfg)

    function new(string name = "CpmRegDropCfg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_drop_en = uvm_reg_field::type_id::create("m_drop_en");
        m_drop_en.configure(this, 1, 0, "RW", 0, 1'b0, 1, 0, 0);

        m_drop_opcode = uvm_reg_field::type_id::create("m_drop_opcode");
        m_drop_opcode.configure(this, 4, 4, "RW", 0, 4'h0, 1, 0, 0);
    endfunction
endclass

// STATUS Register (0x10) - Read Only
class CpmRegStatus extends uvm_reg;
    uvm_reg_field m_busy;

    `uvm_object_utils(CpmRegStatus)

    function new(string name = "CpmRegStatus");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_busy = uvm_reg_field::type_id::create("m_busy");
        m_busy.configure(this, 1, 0, "RO", 0, 1'b0, 1, 0, 0);
    endfunction
endclass

// COUNT_IN Register (0x14) - Read Only
class CpmRegCountIn extends uvm_reg;
    uvm_reg_field m_count_in;

    `uvm_object_utils(CpmRegCountIn)

    function new(string name = "CpmRegCountIn");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_count_in = uvm_reg_field::type_id::create("m_count_in");
        m_count_in.configure(this, 32, 0, "RO", 0, 32'h0000_0000, 1, 0, 0);
    endfunction
endclass

// COUNT_OUT Register (0x18) - Read Only
class CpmRegCountOut extends uvm_reg;
    uvm_reg_field m_count_out;

    `uvm_object_utils(CpmRegCountOut)

    function new(string name = "CpmRegCountOut");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_count_out = uvm_reg_field::type_id::create("m_count_out");
        m_count_out.configure(this, 32, 0, "RO", 0, 32'h0000_0000, 1, 0, 0);
    endfunction
endclass

// DROPPED_COUNT Register (0x1C) - Read Only
class CpmRegDroppedCount extends uvm_reg;
    uvm_reg_field m_dropped_count;

    `uvm_object_utils(CpmRegDroppedCount)

    function new(string name = "CpmRegDroppedCount");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        m_dropped_count = uvm_reg_field::type_id::create("m_dropped_count");
        m_dropped_count.configure(this, 32, 0, "RO", 0, 32'h0000_0000, 1, 0, 0);
    endfunction
endclass
