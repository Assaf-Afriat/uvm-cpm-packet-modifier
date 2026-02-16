# CPM Verification Plan

**Project**: Configurable Packet Modifier (CPM) Verification  
**Version**: 1.1  
**Author**: Assaf Afriat  
**Date**: 2026-02-07  
**Status**: Complete ✅  
**RTL Version**: v1.1 (All bugs fixed)  
**Spec Version**: v1.1

---

## 1. Introduction

### 1.1 Purpose

This document describes the verification plan for the Configurable Packet Modifier (CPM) design. It outlines the verification strategy, methodology, environment architecture, test plan, and coverage goals.

### 1.2 Scope

The verification covers:
- All 4 operation modes (PASS, XOR, ADD, ROT)
- Packet processing with correct latencies
- Packet drop functionality
- Register configuration via RAL
- Backpressure handling
- Counter accuracy and invariants
- Output stability under backpressure

**Out of Scope:**
- Register bus protocol verification (assumed correct per spec)
- Multi-beat packets (DUT only supports single-beat)
- Interrupt generation
- DMA or memory interfaces

### 1.3 References

| Document | Description |
|----------|-------------|
| CPM Design Specification v1.1 | DUT functional specification |
| CPM Verification Requirements | Project requirements and deliverables |
| UVM Reference Manual | UVM 1.1d methodology guide |

### 1.4 Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-01 | Initial release |
| 1.1 | 2026-02-07 | Updated for RTL v1.1 bug fixes, callback implementation, spec v1.1 compliance |

---

## 2. DUT Overview

### 2.1 Functional Description

The CPM is a packet processing unit that:
- Accepts packets via stream interface (valid/ready handshake)
- Modifies packet payloads based on configurable operation mode
- Implements packet drop mechanism based on opcode matching
- Maintains 2-slot pipeline buffer with configurable latency
- Provides register bus for configuration and statistics

### 2.2 Interfaces

| Interface | Signals | Description |
|-----------|---------|-------------|
| Stream Input | `in_valid`, `in_ready`, `in_id[3:0]`, `in_opcode[3:0]`, `in_payload[15:0]` | Packet input with valid/ready handshake |
| Stream Output | `out_valid`, `out_ready`, `out_id[3:0]`, `out_opcode[3:0]`, `out_payload[15:0]` | Packet output with valid/ready handshake |
| Register Bus | `req`, `gnt`, `write_en`, `addr[7:0]`, `wdata[31:0]`, `rdata[31:0]` | Configuration and status registers |

### 2.3 Operation Modes

| Mode | Value | Transformation | Latency |
|------|-------|----------------|---------|
| PASS | 0 | `payload_out = payload_in` | 0 cycles |
| XOR | 1 | `payload_out = payload_in ^ MASK` | 1 cycle |
| ADD | 2 | `payload_out = payload_in + ADD_CONST` | 2 cycles |
| ROT | 3 | `payload_out = rotate_left(payload_in, 4)` | 1 cycle |

**Note**: ROT_AMT is fixed at 4 bits per Spec v1.1 (not configurable).

### 2.4 Registers

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| 0x00 | CTRL | RW | ENABLE[0], SOFT_RST[1] |
| 0x04 | MODE | RW | MODE[1:0] |
| 0x08 | PARAMS | RW | MASK[15:0], ADD_CONST[31:16] |
| 0x0C | DROP_CFG | RW | DROP_EN[0], DROP_OPCODE[7:4] |
| 0x10 | STATUS | RO | BUSY[0] - Asserted when packets in pipeline |
| 0x14 | COUNT_IN | RO | Input packet counter |
| 0x18 | COUNT_OUT | RO | Output packet counter |
| 0x1C | DROPPED_COUNT | RO | Dropped packet counter |

### 2.5 Critical Invariant

```
COUNT_OUT + DROPPED_COUNT == COUNT_IN
```

This invariant must hold when `STATUS.BUSY == 0` (pipeline empty).

---

## 3. Verification Strategy

### 3.1 Methodology

The verification uses **UVM (Universal Verification Methodology)** with the following key features:

- **Constrained Random Verification**: Random stimulus with targeted constraints
- **Coverage-Driven Verification**: Functional coverage guides test development
- **Self-Checking Testbench**: Scoreboard with reference model for automatic checking
- **Assertion-Based Verification**: SVA properties for protocol compliance

### 3.2 Control Model

The project enforces strict separation of responsibilities:

| Component | Responsibility |
|-----------|----------------|
| **Tests** | Choose scenario, configure environment |
| **Virtual Sequences** | Orchestrate execution flow |
| **Leaf Sequences** | Generate stimulus only |

**Rules:**
- No direct DUT signal access from tests
- No bus-level register access (use RAL only)
- No objections in driver/monitor
- Configuration via `uvm_config_db` only

### 3.3 Mandatory Verification Features

| Feature | Implementation | Status |
|---------|----------------|--------|
| RAL | Register model, adapter, predictor | ✅ Complete |
| Virtual Sequences | Full flow orchestration (8 steps) | ✅ Complete |
| Factory Overrides | CpmBaseTrafficSeq → CpmCoverageTrafficSeq | ✅ Complete |
| Callbacks | CpmPacketStatsCb with real statistics tracking | ✅ Complete |
| Functional Coverage | MODE, OPCODE, Cross, Drop, Stall | ✅ Complete |
| SVA Assertions | Stability, Liveness, Cover (drop-aware) | ✅ Complete |

---

## 4. Environment Architecture

### 4.1 Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              CpmEnv                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  CpmPacketAgent │  │   CpmRegAgent   │  │      CpmScoreboard      │  │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌─────────────────┐   │  │
│  │  │  Driver   │  │  │  │  Driver   │  │  │  │  CpmRefModel    │   │  │
│  │  │  Sequencer│  │  │  │  Sequencer│  │  │  │  Expected Queue │   │  │
│  │  │  Monitor  │──┼──┼──│  Monitor  │──┼──┼──│  Compare Logic  │   │  │
│  │  └───────────┘  │  │  └───────────┘  │  │  └─────────────────┘   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘  │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ CpmPacketCoverage│ │  CpmRegCoverage │  │      CpmRegModel        │  │
│  │  - MODE          │  │  - Address      │  │  (RAL)                  │  │
│  │  - OPCODE        │  │  - Operation    │  │  - Adapter              │  │
│  │  - Cross         │  │  - Fields       │  │  - Predictor            │  │
│  │  - Drop/Stall    │  │                 │  │                         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          tb_top.sv                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │   CpmStreamIf   │  │    CpmRegIf     │  │     CPM DUT (v1.1)      │  │
│  │   (with SVA)    │  │                 │  │      (cpm_rtl.sv)       │  │
│  │   Drop-aware    │  │                 │  │     ALL BUGS FIXED      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Component Summary

| Component | File | Description |
|-----------|------|-------------|
| `CpmEnv` | `CpmEnv.sv` | Top-level environment |
| `CpmPacketAgent` | `CpmPacketAgent.sv` | Packet stream agent |
| `CpmRegAgent` | `CpmRegAgent.sv` | Register bus agent |
| `CpmScoreboard` | `CpmScoreboard.sv` | Packet comparison |
| `CpmRefModel` | `CpmRefModel.sv` | Reference model |
| `CpmRegModel` | `CpmRegModel.sv` | RAL register model |
| `CpmPacketCoverage` | `CpmPacketCoverage.sv` | Functional coverage |
| `CpmPacketStatsCb` | `CpmBasePacketCb.sv` | Packet statistics callback |

### 4.3 TLM Connections

| Source | Destination | Purpose |
|--------|-------------|---------|
| `PacketMonitor.m_ap_input` | `Scoreboard.write_input()` | Input packets to expected queue |
| `PacketMonitor.m_ap_output` | `Scoreboard.write_output()` | Output packets for comparison |
| `PacketMonitor.m_ap_input` | `PacketCoverage.write()` | Functional coverage |
| `RegMonitor.m_ap` | `uvm_reg_predictor.write()` | RAL prediction |
| `RegMonitor.m_ap` | `RegCoverage.write()` | Register coverage |

---

## 5. Test Plan

### 5.1 Test Categories

| Category | Description | Tests |
|----------|-------------|-------|
| Smoke | Basic functionality | `CpmSmokeTest` |
| RAL | Register reset values | `CpmRalResetTest` |
| Functional | Complete verification | `CpmMainTest` |

### 5.2 Test Details

#### CpmSmokeTest
- **Purpose**: Quick sanity check
- **Duration**: ~10 packets
- **Coverage**: Basic packet flow

#### CpmRalResetTest
- **Purpose**: Verify all register reset values (MANDATORY)
- **Duration**: Immediate (no traffic)
- **Coverage**: All 8 registers via `uvm_reg_hw_reset_seq`

#### CpmMainTest (Primary Test)
- **Purpose**: Complete verification with all mandatory features
- **Duration**: 505 packets across all modes
- **Coverage**: Full MODE, OPCODE, Cross coverage
- **Features**:
  - Factory override: CpmBaseTrafficSeq → CpmCoverageTrafficSeq
  - Callback: CpmPacketStatsCb registered and reporting
  - Virtual sequence with 8-step flow
  - All 4 modes verified
  - Drop sequence executed (20 dropped packets)
  - Stress sequence executed
  - Counter invariant verification via RAL

### 5.3 Virtual Sequence Flow

The `CpmTopVirtualSeq` orchestrates 8 steps:

| Step | Name | Description |
|------|------|-------------|
| 1 | Reset Wait | Wait for reset deassert |
| 2 | Configure | CpmConfigSeq via RAL |
| 3 | Traffic | 200 random packets |
| 4 | Reconfigure | Cycle all 4 modes |
| 5 | Stress | Burst traffic (20/burst) |
| 6 | Drop Test | 20 dropped packets |
| 7 | Readback | RAL counter check |
| 8 | End Check | Verify invariant when BUSY=0 |

---

## 6. Callback Implementation

### 6.1 CpmPacketStatsCb (MANDATORY)

A concrete callback class with real purpose - tracking packet statistics:

```systemverilog
class CpmPacketStatsCb extends CpmBasePacketCb;
    int m_opcode_count[16];   // Count per opcode
    int m_total_packets;       // Total packets driven
    int m_min_payload;         // Minimum payload seen
    int m_max_payload;         // Maximum payload seen
    time m_first_packet_time;  // Test start time
    time m_last_packet_time;   // Test end time
    
    virtual task post_drive(CpmPacketDriver driver, CpmPacketTxn txn);
        m_total_packets++;
        m_opcode_count[txn.m_opcode]++;
        // Track payload range, timing, etc.
    endtask
    
    function string get_statistics();
        // Returns formatted statistics string
    endfunction
endclass
```

### 6.2 Registration

Callback is registered in `CpmMainTest.connect_phase()`:

```systemverilog
m_packet_stats_cb = CpmPacketStatsCb::type_id::create("m_packet_stats_cb");
uvm_callbacks#(CpmPacketDriver, CpmBasePacketCb)::add(
    m_env.m_packet_agent.m_driver, m_packet_stats_cb);
```

### 6.3 Results (from CpmMainTest)

| Metric | Value |
|--------|-------|
| Total packets | 505 |
| Opcodes used | 16/16 |
| Payload range | 0x0000 - 0xFFFF |
| Duration | 465ns - 169.3ms |

---

## 7. Coverage Plan

### 7.1 Functional Coverage Targets

| Coverpoint | Target | Achieved | Status |
|------------|--------|----------|--------|
| MODE | 100% | 100.00% | ✅ MET |
| OPCODE | 90% | 100.00% | ✅ MET |
| MODE×OPCODE Cross | 80% | 100.00% | ✅ MET |
| Drop bin | Hit once | 50% | ✅ MET |
| Stall bin | Hit once | 50% | ✅ MET |

### 7.2 Covergroup Details

#### cg_packet (Packet Coverage)
```systemverilog
covergroup cg_packet;
    cp_mode: coverpoint m_mode {
        bins mode_pass = {CPM_MODE_PASS};
        bins mode_xor  = {CPM_MODE_XOR};
        bins mode_add  = {CPM_MODE_ADD};
        bins mode_rot  = {CPM_MODE_ROT};
    }
    
    cp_opcode: coverpoint m_opcode {
        bins opcode[] = {[0:15]};
    }
    
    cp_mode_opcode: cross cp_mode, cp_opcode;
    
    cp_drop: coverpoint m_drop_event {
        bins drop_hit = {1};
        bins no_drop  = {0};
    }
    
    cp_stall: coverpoint m_stall_event {
        bins stall_hit = {1};
        bins no_stall  = {0};
    }
endgroup
```

### 7.3 Code Coverage

| Metric | DUT Coverage |
|--------|--------------|
| Statements | 100.00% |
| Branches | 95.55% |
| Expressions | 100.00% |
| Conditions | 88.88% |
| Toggles | 58.62% |
| **Total** | **88.61%** |

---

## 8. Assertion Plan

### 8.1 SVA Properties (in CpmStreamIf.sv)

| Property | Description | Type | Status |
|----------|-------------|------|--------|
| `p_input_stability` | Input signals stable during stall | Assert | ✅ 0 violations |
| `p_output_stability` | Output signals stable during stall | Assert | ✅ 0 violations |
| `p_bounded_liveness` | Output appears within latency bound (drop-aware) | Assert | ✅ 0 violations |
| `c_input_stall` | Cover input stall event | Cover | ✅ Hit |
| `c_output_stall` | Cover output stall event | Cover | ✅ Hit |
| `c_in_fire` | Cover input handshake | Cover | ✅ Hit |
| `c_out_fire` | Cover output handshake | Cover | ✅ Hit |

### 8.2 Drop-Aware Liveness

The `p_bounded_liveness` assertion is disabled when packets will be dropped:

```systemverilog
logic packet_will_drop;
assign packet_will_drop = drop_en_shadow && (in_opcode == drop_opcode_shadow);

property p_bounded_liveness;
    @(posedge clk) disable iff (rst || packet_will_drop)
    (in_fire && out_ready) |-> ##[0:10] out_fire;
endproperty
```

### 8.3 Assertion Results

| Metric | Result |
|--------|--------|
| Total Assertions | 7 |
| Passed | 7 (100%) |
| Failed | 0 |

---

## 9. Scoreboard Design

### 9.1 Reference Model

The `CpmRefModel` implements:
- All 4 operation modes with correct transformations
- Mode-dependent latency (0, 1, 2 cycles)
- Drop mechanism based on opcode matching
- Configuration sampled at input acceptance time (via RAL)

### 9.2 Comparison Strategy

1. Input packet received → Store in expected queue with `mode_at_accept`
2. Reference model predicts expected output
3. Output packet received → Match by ID + OPCODE
4. Compare payload transformation
5. Report mismatches with context

### 9.3 End-of-Test Checks

- **Counter Invariant**: `COUNT_OUT + DROPPED_COUNT == COUNT_IN`
- **BUSY Wait**: Polls `STATUS.BUSY` until 0 before checking counters
- **Queue Empty**: No leftover expected items (warning if non-zero but no corruption)

---

## 10. Bug Tracking Summary

### 10.1 DUT Bugs (All Fixed in RTL v1.1)

| Bug ID | Title | Status | Resolution |
|--------|-------|--------|------------|
| DUT-001 | COUNT_OUT Over-Count | ✅ FIXED | Changed from `out_valid` to `out_fire` |
| DUT-002 | Output Stability Violation | ✅ FIXED | s0 slot only updates on `out_fire` |
| DUT-003 | ROT_AMT Not Configurable | ✅ RESOLVED | Spec v1.1 confirms fixed at 4 bits |

### 10.2 Testbench Bugs (All Closed)

| Bug ID | Title | Status |
|--------|-------|--------|
| TB-001 | Virtual Interface config_db Collision | ✅ Closed |
| TB-002 | Reset Wait Race Condition | ✅ Closed |
| TB-003 | Zero-Time Loop in Monitor | ✅ Closed |
| TB-004 | Reference Model Config Stale | ✅ Closed |
| TB-005 | Scoreboard FIFO Ordering Assumption | ✅ Closed |
| TB-006 | RAL Model Not Built | ✅ Closed |

### 10.3 Spec Ambiguities

| Issue | Status | Resolution |
|-------|--------|------------|
| ROT_AMT value | ✅ Resolved | Spec v1.1 confirms fixed at 4 bits |
| Counter invariant timing | ✅ Resolved | STATUS.BUSY defines when invariant holds |
| SOFT_RST scope | ✅ Resolved | Clears counters and internal state |
| Ordering contradiction | ⚠️ Open | Different latencies vs "no reordering" |
| Counter overflow behavior | ⚠️ Open | Standard wrap assumed |

---

## 11. Results Summary

### 11.1 Test Results

| Test | Packets | Matched | Dropped | Mismatched | Status |
|------|---------|---------|---------|------------|--------|
| CpmSmokeTest | 10 | 10 | 0 | 0 | ✅ PASS |
| CpmMainTest | 505 | 485 | 20 | 0 | ✅ PASS |
| CpmRalResetTest | N/A | N/A | N/A | N/A | ✅ PASS |

### 11.2 Coverage Results

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| MODE | 100% | 100% | ✅ |
| OPCODE | 90% | 100% | ✅ |
| MODE×OPCODE | 80% | 100% | ✅ |
| Drop | Hit | 50% | ✅ |
| Stall | Hit | 50% | ✅ |

### 11.3 Closure Criteria

| Criterion | Status |
|-----------|--------|
| All tests pass (no runtime hangs) | ✅ |
| Scoreboard reports 0 mismatches | ✅ |
| All 4 SVA assertions pass (0 violations) | ✅ |
| Functional coverage targets achieved | ✅ |
| RAL reset sequence passes cleanly | ✅ |
| Counter invariant verified via RAL | ✅ |
| UVM_ERROR count = 0 | ✅ |
| All 4 operation modes verified | ✅ |
| Factory override demonstrated | ✅ |
| Callback with real purpose (CpmPacketStatsCb) | ✅ |
| Virtual sequence orchestrates complete flow | ✅ |
| All DUT bugs fixed in RTL v1.1 | ✅ |
| Spec v1.1 compliance verified | ✅ |
| Documentation complete | ✅ |

---

## 12. Appendix

### 12.1 File Structure

See [FILE_STRUCTURE.md](FILE_STRUCTURE.md) for complete listing.

### 12.2 Running Tests

```bash
# Smoke test
python scripts/Run/run.py --test CpmSmokeTest --timeout 60

# Main test with coverage
python scripts/Run/run.py --test CpmMainTest --timeout 120 --coverage-report

# RAL reset test
python scripts/Run/run.py --test CpmRalResetTest --timeout 60
```

### 12.3 Log Filtering

```powershell
# View only UVM_WARNING and UVM_ERROR
Select-String -Pattern "UVM_WARNING|UVM_ERROR" CpmMainTest.log

# View scoreboard messages
Select-String -Pattern "\[SCOREBOARD\]" CpmMainTest.log

# View SVA violations
Select-String -Pattern "Assertion.*failed|Error.*assert" CpmMainTest.log

# View callback statistics
Select-String -Pattern "\[CALLBACK\]|Packet Callback Statistics" CpmMainTest.log
```

### 12.4 Coverage Report Generation

```bash
# Generate modern HTML report
python scripts/generate_coverage_report.py
```

---

**Document End**

*Last Updated: 2026-02-07*  
*RTL Version: v1.1*  
*Spec Version: v1.1*
