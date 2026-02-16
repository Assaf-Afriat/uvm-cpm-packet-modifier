/**
 * @file CpmRefModel.sv
 * @brief CPM Reference Model
 * 
 * Reference model for packet processing.
 * Implements all 4 operation modes with correct latencies.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRefModel extends uvm_component;

    `uvm_component_utils(CpmRefModel)

    // ============================================================================
    // RAL Model Handle (for reading configuration)
    // ============================================================================
    CpmRegModel m_reg_model;

    // ============================================================================
    // Configuration State (fallback if RAL not available)
    // ============================================================================
    cpm_mode_e m_mode;
    bit [15:0] m_mask;
    bit [15:0] m_add_const;
    bit        m_drop_en;
    bit [3:0]  m_drop_opcode;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRefModel", uvm_component parent = null);
        super.new(name, parent);
        m_reg_model = null;
    endfunction

    // ============================================================================
    // process_packet
    // Apply transformation based on mode and parameters
    // ============================================================================
    function bit [15:0] process_packet(
        input bit [15:0] payload_in,
        input cpm_mode_e mode,
        input bit [15:0] mask,
        input bit [15:0] add_const
    );
        bit [15:0] payload_out;
        case (mode)
            CPM_MODE_PASS: payload_out = payload_in;
            CPM_MODE_XOR:  payload_out = payload_in ^ mask;
            CPM_MODE_ADD:  payload_out = payload_in + add_const;
            CPM_MODE_ROT:  payload_out = {payload_in[11:0], payload_in[15:12]}; // Rotate left by 4
            default:       payload_out = payload_in;
        endcase
        return payload_out;
    endfunction

    // ============================================================================
    // should_drop
    // Check if packet should be dropped
    // ============================================================================
    function bit should_drop(
        input bit [3:0] opcode,
        input bit drop_en,
        input bit [3:0] drop_opcode
    );
        return (drop_en && (opcode == drop_opcode));
    endfunction

    // ============================================================================
    // get_latency
    // Get latency for a given mode
    // ============================================================================
    function int get_latency(cpm_mode_e mode);
        case (mode)
            CPM_MODE_PASS: return CPM_LATENCY_PASS;
            CPM_MODE_XOR:  return CPM_LATENCY_XOR;
            CPM_MODE_ADD:  return CPM_LATENCY_ADD;
            CPM_MODE_ROT:  return CPM_LATENCY_ROT;
            default:       return 0;
        endcase
    endfunction

    // ============================================================================
    // predict_output
    // Predict expected output payload based on input transaction and current config
    // Returns the expected payload and whether the packet should be dropped.
    // MANDATORY: Use configuration that was active when packet was accepted
    // ============================================================================
    function void predict_output(
        input CpmPacketTxn i_txn,
        output bit [15:0] o_expected_payload,
        output bit o_is_dropped
    );
        // Use the configuration that was active when the packet was accepted
        // The monitor sets m_mode_at_accept when the packet is accepted at input
        cpm_mode_e mode_to_use = i_txn.m_mode_at_accept;
        bit [15:0] mask_to_use;
        bit [15:0] add_const_to_use;
        bit        drop_en_to_use;
        bit [3:0]  drop_opcode_to_use;
        
        // Get configuration from RAL model if available
        if (m_reg_model != null)
        begin
            mask_to_use = m_reg_model.m_params.m_mask.get_mirrored_value();
            add_const_to_use = m_reg_model.m_params.m_add_const.get_mirrored_value();
            drop_en_to_use = m_reg_model.m_drop_cfg.m_drop_en.get_mirrored_value();
            drop_opcode_to_use = m_reg_model.m_drop_cfg.m_drop_opcode.get_mirrored_value();
        end
        else
        begin
            // Fallback to internal state
            mask_to_use = m_mask;
            add_const_to_use = m_add_const;
            drop_en_to_use = m_drop_en;
            drop_opcode_to_use = m_drop_opcode;
        end
        
        // Check if packet should be dropped
        o_is_dropped = should_drop(i_txn.m_opcode, drop_en_to_use, drop_opcode_to_use);
        
        if (!o_is_dropped)
        begin
            // Apply transformation based on mode at acceptance time
            o_expected_payload = process_packet(i_txn.m_payload, mode_to_use, mask_to_use, add_const_to_use);
        end
        else
        begin
            o_expected_payload = 0; // Dropped packets don't produce output
        end
    endfunction

    // ============================================================================
    // update_configuration
    // Update configuration state
    // ============================================================================
    function void update_configuration(
        input cpm_mode_e mode,
        input bit [15:0] mask,
        input bit [15:0] add_const,
        input bit drop_en,
        input bit [3:0] drop_opcode
    );
        m_mode = mode;
        m_mask = mask;
        m_add_const = add_const;
        m_drop_en = drop_en;
        m_drop_opcode = drop_opcode;
    endfunction

endclass : CpmRefModel
