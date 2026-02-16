/**
 * @file CpmRegTxn.sv
 * @brief CPM Register Transaction Class
 * 
 * Transaction class for register bus interface.
 * Note: Most register transactions will be handled via RAL.
 * This class is for legacy/direct register access if needed.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegTxn extends uvm_sequence_item;

    // ============================================================================
    // Register Transaction Fields
    // ============================================================================
    rand bit [7:0]  m_addr;
    rand bit [31:0] m_wdata;
    bit [31:0]      m_rdata;
    rand bit        m_write_en;  // 1 = write, 0 = read

    // ============================================================================
    // Constraints
    // ============================================================================
    constraint c_valid_addr {
        m_addr inside {
            8'h00, 8'h04, 8'h08, 8'h0C,  // CTRL, MODE, PARAMS, DROP_CFG
            8'h10, 8'h14, 8'h18, 8'h1C   // STATUS, COUNT_IN, COUNT_OUT, DROPPED_COUNT
        };
    }

    constraint c_valid_wdata {
        // Write data can be any 32-bit value
        m_wdata inside {[0:32'hFFFF_FFFF]};
    }

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegTxn");
        super.new(name);
        m_rdata = 0;
    endfunction

    // ============================================================================
    // UVM Field Macros
    // ============================================================================
    `uvm_object_utils_begin(CpmRegTxn)
        `uvm_field_int(m_addr, UVM_ALL_ON)
        `uvm_field_int(m_wdata, UVM_ALL_ON)
        `uvm_field_int(m_rdata, UVM_ALL_ON)
        `uvm_field_int(m_write_en, UVM_ALL_ON)
    `uvm_object_utils_end

    // ============================================================================
    // do_copy
    // ============================================================================
    function void do_copy(uvm_object rhs);
        CpmRegTxn rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("DO_COPY", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        m_addr = rhs_.m_addr;
        m_wdata = rhs_.m_wdata;
        m_rdata = rhs_.m_rdata;
        m_write_en = rhs_.m_write_en;
    endfunction

    // ============================================================================
    // do_compare
    // ============================================================================
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        CpmRegTxn rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (
            (m_addr == rhs_.m_addr) &&
            (m_write_en == rhs_.m_write_en) &&
            ((!m_write_en) ? (m_rdata == rhs_.m_rdata) : (m_wdata == rhs_.m_wdata))
        );
    endfunction

    // ============================================================================
    // do_print
    // ============================================================================
    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("addr", m_addr, 8, UVM_HEX);
        printer.print_field("write_en", m_write_en, 1, UVM_BIN);
        if (m_write_en) begin
            printer.print_field("wdata", m_wdata, 32, UVM_HEX);
        end else begin
            printer.print_field("rdata", m_rdata, 32, UVM_HEX);
        end
    endfunction

    // ============================================================================
    // convert2string
    // ============================================================================
    function string convert2string();
        string op_str = (m_write_en) ? "WRITE" : "READ";
        string data_str = (m_write_en) ? $sformatf("wdata=0x%0h", m_wdata) : 
                                          $sformatf("rdata=0x%0h", m_rdata);
        return $sformatf("CpmRegTxn: %s addr=0x%0h %s", op_str, m_addr, data_str);
    endfunction

endclass : CpmRegTxn
