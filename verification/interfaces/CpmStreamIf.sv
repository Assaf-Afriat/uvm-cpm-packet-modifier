/**
 * @file CpmStreamIf.sv
 * @brief CPM Stream Interface (Input and Output)
 * 
 * Defines the valid/ready handshake interface for packet stream.
 * Includes SVA assertions (MANDATORY) for protocol verification.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

interface CpmStreamIf(input logic clk, input logic rst);

    // ============================================================================
    // Input Stream Signals
    // ============================================================================
    logic                    in_valid;
    logic                    in_ready;
    logic [3:0]              in_id;
    logic [3:0]              in_opcode;
    logic [15:0]             in_payload;

    // ============================================================================
    // Output Stream Signals
    // ============================================================================
    logic                    out_valid;
    logic                    out_ready;
    logic [3:0]              out_id;
    logic [3:0]              out_opcode;
    logic [15:0]             out_payload;

    // ============================================================================
    // Drop Configuration Shadow (for SVA - updated by tb_top from reg bus)
    // These track the DROP_CFG register values by observing register writes
    // ============================================================================
    logic                    drop_en_shadow;       // Shadows DROP_CFG[0]
    logic [3:0]              drop_opcode_shadow;   // Shadows DROP_CFG[7:4]

    // ============================================================================
    // Handshake Signals
    // ============================================================================
    logic in_fire;
    logic out_fire;

    // Derived signal: packet will be dropped based on shadowed config
    logic packet_will_drop;
    assign packet_will_drop = drop_en_shadow && (in_opcode == drop_opcode_shadow);

    assign in_fire  = in_valid && in_ready;
    assign out_fire = out_valid && out_ready;

    // ============================================================================
    // SVA Assertions (MANDATORY per spec)
    // ============================================================================
    
    // Input Stability Under Stall (Spec Section 5.3)
    // "If in_valid == 1 and in_ready == 0, the following signals must remain stable"
    property p_input_stability;
        @(posedge clk) disable iff (rst)
        (in_valid && !in_ready) |=> ($stable(in_id) && $stable(in_opcode) && $stable(in_payload));
    endproperty
    assert property (p_input_stability)
        else $error("[SVA] Input signals not stable during stall");

    // Output Stability Under Stall (Spec Section 6.3)
    // "If out_valid == 1 and out_ready == 0, the following signals must remain stable"
    // NOTE: This assertion catches a REAL DUT BUG - see bug_tracker.csv
    property p_output_stability;
        @(posedge clk) disable iff (rst)
        (out_valid && !out_ready) |=> ($stable(out_id) && $stable(out_opcode) && $stable(out_payload));
    endproperty
    assert property (p_output_stability)
        else $error("[SVA] Output signals not stable during stall (DUT BUG)");

    // Bounded Liveness (Spec Section 5.4)
    // Disable when packet is dropped (drop_en_shadow && in_opcode matches drop_opcode_shadow)
    // because dropped packets never produce output - this is expected behavior
    property p_bounded_liveness;
        @(posedge clk) disable iff (rst || packet_will_drop)
        (in_fire && out_ready) |-> ##[0:10] out_fire;
    endproperty   
    assert property (p_bounded_liveness)
        else $error("[SVA] Output not produced within bounded latency for accepted packet");

    
    // Cover Properties (MANDATORY - at least one)
    cover property (@(posedge clk) disable iff (rst) (in_valid && !in_ready));   // Input stall
    cover property (@(posedge clk) disable iff (rst) (out_valid && !out_ready)); // Output stall
    cover property (@(posedge clk) disable iff (rst) in_fire);                   // Packet accepted
    cover property (@(posedge clk) disable iff (rst) out_fire);                  // Packet output

endinterface : CpmStreamIf
