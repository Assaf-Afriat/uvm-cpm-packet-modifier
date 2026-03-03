/**
 * @file CpmPacketTxn.sv
 * @brief CPM Packet Transaction Class
 * 
 * Transaction class for packet stream interface.
 * Contains packet fields: id, opcode, payload.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmPacketTxn extends uvm_sequence_item;

    // ============================================================================
    // Packet Fields
    // ============================================================================
    rand bit [3:0]  m_id;
    rand bit [3:0]  m_opcode;
    rand bit [15:0] m_payload;

    // ============================================================================
    // Metadata Fields
    // ============================================================================
    time m_timestamp;              // Timestamp for latency measurement
    bit [15:0] m_expected_payload; // Expected payload (for scoreboard)
    cpm_mode_e m_mode_at_accept;   // Mode at input acceptance time

    // ============================================================================
    // Constraints
    // ============================================================================
    constraint c_valid_opcode {
        m_opcode inside {[0:15]};
    }

    constraint c_valid_id {
        m_id inside {[0:15]};
    }

    constraint c_valid_payload {
        // Payload can be any 16-bit value
        m_payload inside {[0:65535]};
    }

    // Optional: Constraint for specific test scenarios
    constraint c_payload_ranges {
        // Can be used to create low/mid/high payload ranges for coverage
    }

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmPacketTxn");
        super.new(name);
        m_timestamp = 0;
        m_expected_payload = 0;
    endfunction

    // ============================================================================
    // UVM Field Macros
    // ============================================================================
    `uvm_object_utils_begin(CpmPacketTxn)
        `uvm_field_int(m_id, UVM_ALL_ON)
        `uvm_field_int(m_opcode, UVM_ALL_ON)
        `uvm_field_int(m_payload, UVM_ALL_ON)
        `uvm_field_int(m_timestamp, UVM_ALL_ON)
        `uvm_field_int(m_expected_payload, UVM_ALL_ON)
    `uvm_object_utils_end

    // ============================================================================
    // do_copy
    // ============================================================================
    function void do_copy(uvm_object rhs);
        CpmPacketTxn rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("DO_COPY", "Cast failed")
            return;
        end
        super.do_copy(rhs);
        m_id = rhs_.m_id;
        m_opcode = rhs_.m_opcode;
        m_payload = rhs_.m_payload;
        m_timestamp = rhs_.m_timestamp;
        m_expected_payload = rhs_.m_expected_payload;
        m_mode_at_accept = rhs_.m_mode_at_accept;
    endfunction

    // ============================================================================
    // do_compare
    // ============================================================================
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        CpmPacketTxn rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (
            (m_id == rhs_.m_id) &&
            (m_opcode == rhs_.m_opcode) &&
            (m_payload == rhs_.m_payload)
        );
    endfunction

    // ============================================================================
    // do_print
    // ============================================================================
    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("id", m_id, 4, UVM_HEX);
        printer.print_field("opcode", m_opcode, 4, UVM_HEX);
        printer.print_field("payload", m_payload, 16, UVM_HEX);
        if (m_timestamp > 0) begin
            printer.print_field("timestamp", m_timestamp, 64, UVM_TIME);
        end
        if (m_expected_payload != 0) begin
            printer.print_field("expected_payload", m_expected_payload, 16, UVM_HEX);
        end
    endfunction

    // ============================================================================
    // convert2string
    // ============================================================================
    function string convert2string();
        return $sformatf("CpmPacketTxn: id=0x%0h opcode=0x%0h payload=0x%0h",
            m_id, m_opcode, m_payload);
    endfunction

endclass : CpmPacketTxn
