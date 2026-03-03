/**
 * @file CpmParamsPkg.sv
 * @brief CPM Verification Parameters and Constants Package
 * 
 * This package contains all parameters, constants, and type definitions
 * used throughout the CPM verification environment.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

package CpmParamsPkg;

    // ============================================================================
    // Package Imports
    // ============================================================================
    import uvm_pkg::*;

    // ============================================================================
    // Packet Field Widths
    // ============================================================================
    parameter int CPM_PKT_ID_WIDTH      = 4;
    parameter int CPM_PKT_OPCODE_WIDTH  = 4;
    parameter int CPM_PKT_PAYLOAD_WIDTH = 16;
    parameter int CPM_PKT_TOTAL_WIDTH    = CPM_PKT_ID_WIDTH + CPM_PKT_OPCODE_WIDTH + CPM_PKT_PAYLOAD_WIDTH;

    // ============================================================================
    // Register Interface Parameters
    // ============================================================================
    parameter int CPM_REG_ADDR_WIDTH    = 8;
    parameter int CPM_REG_DATA_WIDTH    = 32;

    // ============================================================================
    // Register Addresses
    // ============================================================================
    parameter bit [7:0] CPM_REG_CTRL_ADDR         = 8'h00;
    parameter bit [7:0] CPM_REG_MODE_ADDR        = 8'h04;
    parameter bit [7:0] CPM_REG_PARAMS_ADDR      = 8'h08;
    parameter bit [7:0] CPM_REG_DROP_CFG_ADDR    = 8'h0C;
    parameter bit [7:0] CPM_REG_STATUS_ADDR      = 8'h10;
    parameter bit [7:0] CPM_REG_COUNT_IN_ADDR    = 8'h14;
    parameter bit [7:0] CPM_REG_COUNT_OUT_ADDR   = 8'h18;
    parameter bit [7:0] CPM_REG_DROPPED_COUNT_ADDR = 8'h1C;

    // ============================================================================
    // Register Field Masks and Offsets
    // ============================================================================
    // CTRL Register (0x00)
    parameter bit [31:0] CPM_CTRL_ENABLE_MASK     = 32'h0000_0001;
    parameter bit [31:0] CPM_CTRL_SOFT_RST_MASK  = 32'h0000_0002;

    // MODE Register (0x04)
    parameter bit [31:0] CPM_MODE_MASK           = 32'h0000_0003;

    // PARAMS Register (0x08)
    parameter bit [31:0] CPM_PARAMS_MASK_MASK    = 32'h0000_FFFF;
    parameter bit [31:0] CPM_PARAMS_ADD_CONST_MASK = 32'hFFFF_0000;

    // DROP_CFG Register (0x0C)
    parameter bit [31:0] CPM_DROP_CFG_EN_MASK    = 32'h0000_0001;
    parameter bit [31:0] CPM_DROP_CFG_OPCODE_MASK = 32'h0000_00F0;

    // STATUS Register (0x10)
    parameter bit [31:0] CPM_STATUS_BUSY_MASK    = 32'h0000_0001;

    // ============================================================================
    // Operation Modes
    // ============================================================================
    typedef enum bit [1:0] {
        CPM_MODE_PASS = 2'b00,
        CPM_MODE_XOR  = 2'b01,
        CPM_MODE_ADD  = 2'b10,
        CPM_MODE_ROT  = 2'b11
    } cpm_mode_e;

    // ============================================================================
    // Latency Constants (cycles)
    // ============================================================================
    parameter int CPM_LATENCY_PASS = 0;
    parameter int CPM_LATENCY_XOR  = 1;
    parameter int CPM_LATENCY_ADD  = 2;
    parameter int CPM_LATENCY_ROT  = 1;
    parameter int CPM_LATENCY_MAX  = 2;

    // ============================================================================
    // Pipeline Parameters
    // ============================================================================
    parameter int CPM_PIPELINE_DEPTH = 2;  // 2-slot pipeline buffer

    // ============================================================================
    // Coverage Targets (MANDATORY)
    // ============================================================================
    parameter real CPM_COV_MODE_TARGET        = 100.0;  // 100%
    parameter real CPM_COV_OPCODE_TARGET      = 90.0;   // 90%
    parameter real CPM_COV_MODE_OPCODE_TARGET = 80.0;   // 80%

    // ============================================================================
    // UVM Event Names (for uvm_event_pool synchronization)
    // ============================================================================
    // These string constants are used to access named events from the global pool.
    // Using constants prevents typos and makes event names discoverable.
    //
    // Usage:
    //   Trigger:  uvm_event_pool::get_global_pool().get(EVT_SCOREBOARD_IDLE).trigger();
    //   Wait:     uvm_event_pool::get_global_pool().get(EVT_SCOREBOARD_IDLE).wait_trigger();
    //
    parameter string EVT_SCOREBOARD_IDLE    = "cpm_scoreboard_idle";     // Scoreboard has processed all expected packets
    parameter string EVT_TRAFFIC_COMPLETE   = "cpm_traffic_complete";    // Virtual sequence finished sending traffic
    parameter string EVT_DRAIN_TIMEOUT_MS   = "cpm_drain_timeout";       // Timeout value for drain operations (10ms default)
    parameter string EVT_SOFT_RESET         = "cpm_soft_reset";          // DUT soft reset triggered (clears pipeline)

    // Default timeout for event waits (in simulation time units, assuming 1ns timescale)
    // 1ms is sufficient for pipeline drain; event-based sync handles normal cases
    parameter int    EVT_DEFAULT_TIMEOUT_NS = 1_000_000;  // 1ms = 1,000,000 ns

endpackage : CpmParamsPkg
