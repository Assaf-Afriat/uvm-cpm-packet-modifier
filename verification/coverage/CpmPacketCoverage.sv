/**
 * @file CpmPacketCoverage.sv
 * @brief CPM Packet Functional Coverage
 * 
 * Functional coverage for packet transactions.
 * MANDATORY: MODE (100%), OPCODE (90%), MODE×OPCODE (80%).
 * MANDATORY: Drop event, Stall/backpressure event.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmPacketCoverage extends uvm_subscriber #(CpmPacketTxn);

    `uvm_component_utils(CpmPacketCoverage)

    // ============================================================================
    // Virtual Interface (for stall detection)
    // ============================================================================
    virtual CpmStreamIf m_vif;

    // ============================================================================
    // Configuration (for mode and drop detection)
    // ============================================================================
    cpm_mode_e m_current_mode = CPM_MODE_PASS;
    bit        m_drop_en = 0;
    bit [3:0]  m_drop_opcode = 0;

    // ============================================================================
    // Covergroups
    // ============================================================================
    covergroup cg_packet with function sample(cpm_mode_e mode, bit [3:0] opcode, 
                                             bit drop_event, bit stall_event);
        // MODE coverage (MANDATORY - Target: 100%)
        cp_mode: coverpoint mode {
            bins mode_pass = {CPM_MODE_PASS};
            bins mode_xor  = {CPM_MODE_XOR};
            bins mode_add  = {CPM_MODE_ADD};
            bins mode_rot  = {CPM_MODE_ROT};
        }

        // OPCODE coverage (MANDATORY - Target: 90%)
        cp_opcode: coverpoint opcode {
            bins opcode[16] = {[0:15]};
        }

        // MODE × OPCODE cross (MANDATORY - Target: 80%)
        // 80% of 64 combinations = 51.2 combinations
        cp_mode_opcode: cross cp_mode, cp_opcode;

        // Drop event coverage (MANDATORY - At least one bin, hit at least once)
        cp_drop: coverpoint drop_event {
            bins drop_hit = {1};
            bins no_drop  = {0};
        }

        // Stall/backpressure event coverage (MANDATORY - At least one bin, hit at least once)
        cp_stall: coverpoint stall_event {
            bins stall_hit = {1};
            bins no_stall  = {0};
        }

        // Optional: Payload ranges (will be sampled from transaction in write function)
        // cp_payload_range: coverpoint t.m_payload {
        //     bins low  = {[0:4095]};
        //     bins mid  = {[4096:28671]};
        //     bins high = {[28672:65535]};
        // }

        // Optional: ID values (will be sampled from transaction in write function)
        // cp_id: coverpoint t.m_id {
        //     bins id[16] = {[0:15]};
        // }

        // Optional: Cross coverage (commented out since payload_range is optional)
        // cp_mode_payload: cross cp_mode, cp_payload_range;
    endgroup

    // ============================================================================
    // Coverage Variables
    // ============================================================================
    bit [15:0] m_payload;
    bit [3:0]  m_id;

    // ============================================================================
    // Statistics
    // ============================================================================
    int m_total_samples = 0;
    int m_drop_samples = 0;
    int m_stall_samples = 0;

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmPacketCoverage", uvm_component parent = null);
        super.new(name, parent);
        cg_packet = new();
    endfunction

    // ============================================================================
    // build_phase
    // ============================================================================
    virtual function void build_phase(uvm_phase phase);
        virtual CpmStreamIf stream_if;
        super.build_phase(phase);
        // Get virtual interface from config_db for stall detection
        if (uvm_config_db#(virtual CpmStreamIf)::get(this, "", "stream_if", stream_if)) begin
            m_vif = stream_if;
        end else begin
            `uvm_warning("NO_STREAM_IF", "Stream interface not set, stall detection disabled")
        end
    endfunction

    // ============================================================================
    // update_configuration
    // Update current mode and drop configuration
    // ============================================================================
    function void update_configuration(
        input cpm_mode_e i_mode,
        input bit i_drop_en,
        input bit [3:0] i_drop_opcode
    );
        m_current_mode = i_mode;
        m_drop_en = i_drop_en;
        m_drop_opcode = i_drop_opcode;
    endfunction

    // ============================================================================
    // write
    // Called when monitor observes a packet (from input monitor)
    // ============================================================================
    virtual function void write(CpmPacketTxn t);
        bit drop_event = 0;
        bit stall_event = 0;

        // Determine if packet was dropped
        if (m_drop_en && (t.m_opcode == m_drop_opcode)) begin
            drop_event = 1;
            m_drop_samples++;
        end

        // Detect stall (valid && !ready at input)
        if (m_vif != null) begin
            // Check if there was a stall during this packet's acceptance
            // This is a simplified check - in practice, we'd track this per packet
            if (m_vif.in_valid && !m_vif.in_ready) begin
                stall_event = 1;
                m_stall_samples++;
            end
        end

        // Sample coverage using mode_at_accept from transaction (correct behavior)
        // This ensures we sample the actual mode that was active when packet was accepted
        m_payload = t.m_payload;
        m_id = t.m_id;
        cg_packet.sample(t.m_mode_at_accept, t.m_opcode, drop_event, stall_event);
        m_total_samples++;

        `uvm_info("COV", $sformatf("Coverage sample: mode=%s opcode=0x%0h drop=%0b stall=%0b",
            t.m_mode_at_accept.name(), t.m_opcode, drop_event, stall_event), UVM_HIGH)
    endfunction

    // ============================================================================
    // report_phase
    // Report coverage statistics
    // ============================================================================
    virtual function void report_phase(uvm_phase phase);
        real mode_cov, opcode_cov, cross_cov, drop_cov, stall_cov;
        
        mode_cov = cg_packet.cp_mode.get_coverage();
        opcode_cov = cg_packet.cp_opcode.get_coverage();
        cross_cov = cg_packet.cp_mode_opcode.get_coverage();
        drop_cov = cg_packet.cp_drop.get_coverage();
        stall_cov = cg_packet.cp_stall.get_coverage();

        `uvm_info("COV", $sformatf("Packet Coverage: MODE=%.2f%% OPCODE=%.2f%% CROSS=%.2f%% DROP=%.2f%% STALL=%.2f%% Samples=%0d",
            mode_cov, opcode_cov, cross_cov, drop_cov, stall_cov, m_total_samples), UVM_MEDIUM)
    endfunction

endclass : CpmPacketCoverage
