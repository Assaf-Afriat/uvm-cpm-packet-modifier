/**
 * @file CpmRegIf.sv
 * @brief CPM Register Bus Interface
 * 
 * Defines the register bus interface (req/gnt protocol).
 * Note: Protocol verification is out of scope - this interface is for
 * functional use only via RAL.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

interface CpmRegIf(input logic clk, input logic rst);

    // ============================================================================
    // Register Bus Signals
    // ============================================================================
    logic                    req;
    logic                    gnt;
    logic                    write_en;
    logic [7:0]              addr;
    logic [31:0]             wdata;
    logic [31:0]             rdata;

    // ============================================================================
    // Transaction Handshake
    // ============================================================================
    logic reg_fire;

    assign reg_fire = req && gnt;

    // ============================================================================
    // Note on Protocol Verification
    // ============================================================================
    // Per specification: "The CPM register interface is intended for functional
    // control and configuration only. Protocol-level aspects such as arbitration,
    // retries, errors, wait states, or bus contention are out of scope and shall
    // not be verified as part of this project."
    //
    // This interface is used functionally via RAL. The RAL adapter handles
    // bus transactions, but we do not verify the protocol itself.

endinterface : CpmRegIf
