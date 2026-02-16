# CPM Verification Plan

**Project**: Configurable Packet Modifier (CPM)  
**Author**: Assaf Afriat  
**Date**: 2026-02-01  
**Version**: 1.0  
**Status**: Planning Phase

---

## Phase 1 - Requirements & Stakeholder Analysis

### Digital Design Team - My Questions:

1. **Fixed vs. Variable Latency**: According to the specification, latency is mode-dependent (0-2 cycles). Does each MODE always result in a fixed latency (PASS=0, XOR=1, ADD=2, ROT=1), or can it vary dynamically?

2. **Configuration Timing**: If the MODE or PARAMS registers are updated while `in_valid` is high and a packet is being accepted, does the DUT apply the new configuration to the current packet immediately, or is the configuration captured at the moment of acceptance?

3. **ROT_AMT Parameter**: The ROT mode rotates left, but ROT_AMT is defined as a localparam in the RTL. Is this intentionally fixed at 4 bits, or should it be configurable via a register?

4. **Counter Invariant Timing**: The invariant `COUNT_OUT + DROPPED_COUNT == COUNT_IN` - at what point in simulation is this guaranteed to hold? Only when STATUS.BUSY = 0?

### Firmware/Software Team - My Questions:

1. **Counter Monitoring**: The DROPPED_COUNT register tracks discarded packets. Will your drivers poll this register regularly, or do you expect hardware notification when packets are dropped?

2. **Soft Reset Behavior**: In what scenarios do you plan to use the SOFT_RST bit in the CTRL register? Should the pipeline flush completely, and should counters reset to zero?

3. **Counter Overflow**: What is the expected behavior when COUNT_IN, COUNT_OUT, or DROPPED_COUNT overflow their 32-bit range? Standard wrap-around or saturation?

### System Architect - My Questions:

1. **Traffic Patterns**: What is the expected distribution between different modes? Do you anticipate long bursts or frequent mode switches? This helps tune our randomized test constraints.

2. **Backpressure Scenarios**: If the downstream component fails (permanently low `out_ready`), how should the CPM behave after its internal 2-slot buffer fills? Block input or signal error?

3. **Opcode Usage**: Are certain opcodes reserved or more frequently used? This affects our coverage bin weighting.

### Board Design Team - My Questions:

1. **Clock and Reset**: Are there specific power-up sequencing requirements for `clk` and `rst` that we should model to ensure the DUT initializes correctly?

---

## Phase 2 - Verification Plan (vPlan) Development

### Section 2.1 - Scope

#### IN SCOPE:

The verification will focus on the following domains based on the CPM specification:

1. **Data Path Functionality**: Verification of all four transformation modes (PASS, XOR, ADD, ROT). Validating that `out_payload` matches the expected result based on `in_payload` and the PARAMS register values.

2. **Register Functionality**: Validating all 8 registers (CTRL, MODE, PARAMS, DROP_CFG, STATUS, COUNT_IN, COUNT_OUT, DROPPED_COUNT). Verifying that register writes correctly configure DUT behavior.

3. **Streaming Protocol**: Validation of the `CpmStreamIf` interface using valid/ready handshake. Testing backpressure handling when `out_ready` is deasserted.

4. **Packet Drop Mechanism**: Verification that packets with opcodes matching DROP_CFG.DROP_OPCODE are discarded when DROP_CFG.DROP_EN is set, and that DROPPED_COUNT increments correctly.

5. **Reset Compliance**: Verifying the DUT enters a known state after hardware reset (`rst`), and that SOFT_RST in CTRL register functions correctly.

6. **Counter Invariant**: Verification that `COUNT_IN == COUNT_OUT + DROPPED_COUNT` holds when STATUS.BUSY = 0.

#### OUT OF SCOPE:

- Gate-level timing and physical verification
- Register bus protocol edge cases (focus is on functional behavior)
- Performance/throughput measurement
- Multi-beat packets (DUT is single-beat only)

### Section 2.2 - Verification Strategy

#### Section 2.2.1 Methodology:

- **UVM 1.1d Framework**: Modular, reusable testbench architecture
- **Dual-Agent Architecture**: Separate `CpmPacketAgent` for streaming and `CpmRegAgent` for configuration
- **RAL Integration**: `CpmRegModel` with `CpmRegAdapter` for register abstraction
- **Self-Checking**: `CpmScoreboard` with `CpmRefModel` for automatic comparison

#### Section 2.2.2 Stimulus Strategy

**Constrained Random Verification**:
- `CpmPacketTxn`: Randomized `m_id`, `m_opcode`, `m_payload` within valid ranges
- Timing variation: Random inter-packet delays and backpressure patterns

**Sequence Hierarchy**:
- `CpmTopVirtualSeq`: Orchestrates complete test flow
- `CpmConfigSeq`: RAL-based register configuration
- `CpmBaseTrafficSeq`: Random packet generation
- `CpmStressSeq`: Burst traffic patterns
- `CpmDropSeq`: Targeted drop testing
- `CpmCoverageTrafficSeq`: Coverage-directed traffic (factory override target)

#### Section 2.2.3 Checking Strategy

**Scoreboard Architecture (`CpmScoreboard`)**:
- `CpmRefModel` computes expected output based on mode captured at input time (`m_mode_at_accept`)
- Input packets stored in expected queue with transformation prediction
- Output packets matched by `m_id` + `m_opcode` key
- Drop tracking reconciled against DROPPED_COUNT register

**Reference Model Transformations (`CpmRefModel`)**:
```
PASS: m_payload (unchanged)
XOR:  m_payload ^ PARAMS.MASK
ADD:  m_payload + PARAMS.ADD_CONST
ROT:  {m_payload[11:0], m_payload[15:12]}  // rotate left by 4
```

**Protocol Assertions (SVA in `CpmStreamIf`)**:
- `p_input_stability`: Input signals stable during stall
- `p_output_stability`: Output signals stable during stall
- `p_bounded_liveness`: Output appears within latency bound (disabled for dropped packets)

#### Section 2.2.4 Coverage Strategy

- **Functional Coverage (`CpmPacketCoverage`)**: MODE, OPCODE, Cross, Drop, Stall coverpoints
- **Register Coverage (`CpmRegCoverage`)**: Address, operation type, cross coverage
- **Code Coverage**: Statement, Branch, Expression, Condition, Toggle

### Section 2.3 - Metrics for Success (Exit Criteria)

#### 2.3.1 Functional Coverage Targets

| Coverpoint | Target |
|------------|--------|
| `cp_mode` | 100% (all 4 modes) |
| `cp_opcode` | 90%+ (all 16 opcodes) |
| `cp_mode_opcode` | 80%+ (64 combinations) |
| `cp_drop` | Hit at least once |
| `cp_stall` | Hit at least once |

#### 2.3.2 Code Coverage Targets

| Metric | Target |
|--------|--------|
| Statement | 95%+ |
| Branch | 90%+ |
| Expression | 90%+ |
| Condition | 80%+ |
| Toggle | 50%+ |
| **Total DUT** | 85%+ |

#### 2.3.3 Error-Free Execution

- Zero UVM_ERROR or UVM_FATAL
- All SVA assertions pass (0 violations)
- Scoreboard: 0 mismatches
- Counter invariant verified

---

## Phase 3 - Testbench Architecture

### Section 3.1 - Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              CpmEnv                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────────┐  │
│  │  CpmPacketAgent  │  │   CpmRegAgent    │  │     CpmScoreboard      │  │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────────┐   │  │
│  │  │CpmPacket   │  │  │  │CpmReg      │  │  │  │  CpmRefModel   │   │  │
│  │  │  Driver    │  │  │  │  Driver    │  │  │  │  Expected Queue│   │  │
│  │  │CpmPacket   │  │  │  │CpmReg      │  │  │  │  Compare Logic │   │  │
│  │  │  Monitor   │  │  │  │  Monitor   │  │  │  └────────────────┘   │  │
│  │  │CpmPacket   │  │  │  │CpmReg      │  │  └────────────────────────┘  │
│  │  │  Sequencer │  │  │  │  Sequencer │  │                              │
│  │  └────────────┘  │  │  └────────────┘  │                              │
│  └──────────────────┘  └──────────────────┘                              │
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────────┐  │
│  │CpmPacketCoverage │  │ CpmRegCoverage   │  │     CpmRegModel        │  │
│  │  cg_packet       │  │  cg_register     │  │  (RAL Block)           │  │
│  │  - cp_mode       │  │  - cp_addr       │  │  - CpmRegAdapter       │  │
│  │  - cp_opcode     │  │  - cp_op         │  │  - uvm_reg_predictor   │  │
│  │  - cp_mode_opcode│  │  - cp_addr_op    │  │                        │  │
│  │  - cp_drop       │  │                  │  │                        │  │
│  │  - cp_stall      │  │                  │  │                        │  │
│  └──────────────────┘  └──────────────────┘  └────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                            tb_top.sv                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────────┐  │
│  │   CpmStreamIf    │  │    CpmRegIf      │  │       CPM DUT          │  │
│  │   (with SVA)     │  │                  │  │     (cpm_rtl.sv)       │  │
│  └──────────────────┘  └──────────────────┘  └────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

### Section 3.2 - Transactions

#### CpmPacketTxn (Packet Transaction)

| Field | Type | Description |
|-------|------|-------------|
| `m_id` | `rand bit [3:0]` | Packet identifier for tracking |
| `m_opcode` | `rand bit [3:0]` | Opcode for drop mechanism comparison |
| `m_payload` | `rand bit [15:0]` | Data payload for transformation |
| `m_mode_at_accept` | `cpm_mode_e` | Mode captured at input acceptance |
| `m_timestamp` | `time` | Timestamp for latency measurement |
| `m_expected_payload` | `bit [15:0]` | Expected output (for scoreboard) |

#### CpmRegTxn (Register Transaction)

| Field | Type | Description |
|-------|------|-------------|
| `m_addr` | `rand bit [7:0]` | Register address (0x00-0x1C) |
| `m_wdata` | `rand bit [31:0]` | Write data |
| `m_rdata` | `bit [31:0]` | Read data (response) |
| `m_write_en` | `rand bit` | 1 = Write, 0 = Read |

#### RAL Integration Flow

1. `CpmConfigSeq` calls `m_reg_model.m_mode.write(status, value)`
2. `CpmRegAdapter.reg2bus()` converts to `CpmRegTxn`
3. `CpmRegDriver` drives signals on `CpmRegIf`
4. `CpmRegMonitor` captures transaction
5. `uvm_reg_predictor` updates RAL mirror via `bus2reg()`

### Section 3.3 - Test Scenarios

#### Scenario 1: Basic Transform Sequence

1. Configure MODE to XOR via `CpmConfigSeq`
2. Set PARAMS.MASK to test value
3. Send 10+ packets via `CpmBaseTrafficSeq`
4. `CpmScoreboard` verifies each output matches `m_payload ^ MASK`

#### Scenario 2: All Modes Sweep

1. For each mode (PASS, XOR, ADD, ROT):
   - Configure via RAL
   - Send traffic burst
   - Verify correct transformation in `CpmRefModel`

#### Scenario 3: Latency Verification

1. Verify mode-dependent latency:
   - PASS: 0 cycles
   - XOR: 1 cycle
   - ADD: 2 cycles
   - ROT: 1 cycle
2. `CpmPacketMonitor` tracks input/output timing

#### Scenario 4: Drop Sequence (`CpmDropSeq`)

1. Configure DROP_CFG: DROP_EN=1, DROP_OPCODE=target
2. Send packets with target opcode
3. Verify packets do not appear at output
4. Read DROPPED_COUNT via RAL, verify count

#### Scenario 5: Backpressure Stress (`CpmStressSeq`)

1. Start continuous packet stream
2. Deassert `out_ready` for multiple cycles
3. Verify `in_ready` drops when buffer full
4. Resume and verify no data loss
5. SVA `p_output_stability` checks signal stability

#### Scenario 6: Counter Invariant Check

1. Send mixed traffic (some dropped, some passed)
2. Wait for STATUS.BUSY = 0
3. Read COUNT_IN, COUNT_OUT, DROPPED_COUNT via RAL
4. Verify: `COUNT_IN == COUNT_OUT + DROPPED_COUNT`

#### Scenario 7: RAL Reset Verification (MANDATORY)

1. Execute `uvm_reg_hw_reset_seq` in `CpmRalResetTest`
2. Verify all registers match reset values from spec

### Section 3.4 - Components

#### Environment Components

| Component | File | Description |
|-----------|------|-------------|
| `CpmEnv` | `env/CpmEnv.sv` | Top environment container |
| `CpmPacketAgent` | `agent/CpmPacketAgent.sv` | Stream interface agent |
| `CpmRegAgent` | `agent/CpmRegAgent.sv` | Register bus agent |
| `CpmScoreboard` | `scoreboard/CpmScoreboard.sv` | Packet comparison checker |
| `CpmRefModel` | `scoreboard/CpmRefModel.sv` | Golden reference model |
| `CpmPacketCoverage` | `coverage/CpmPacketCoverage.sv` | Packet functional coverage |
| `CpmRegCoverage` | `coverage/CpmRegCoverage.sv` | Register access coverage |

#### RAL Components

| Component | File | Description |
|-----------|------|-------------|
| `CpmRegModel` | `ral/CpmRegModel.sv` | Register block with 8 registers |
| `CpmRegAdapter` | `ral/CpmRegAdapter.sv` | reg2bus/bus2reg conversion |
| `CpmRegPredictor` | `ral/CpmRegPredictor.sv` | Predictor wrapper |

#### RAL Register Instances (in `CpmRegModel`)

| Instance | Address | Access |
|----------|---------|--------|
| `m_ctrl` | 0x00 | RW |
| `m_mode` | 0x04 | RW |
| `m_params` | 0x08 | RW |
| `m_drop_cfg` | 0x0C | RW |
| `m_status` | 0x10 | RO |
| `m_count_in` | 0x14 | RO |
| `m_count_out` | 0x18 | RO |
| `m_dropped_count` | 0x1C | RO |

#### Sequences

| Sequence | File | Description |
|----------|------|-------------|
| `CpmTopVirtualSeq` | `sequences/virtual/CpmTopVirtualSeq.sv` | 8-step orchestrator |
| `CpmConfigSeq` | `sequences/ral/CpmConfigSeq.sv` | RAL configuration |
| `CpmBaseTrafficSeq` | `sequences/packet/CpmBaseTrafficSeq.sv` | Random packets |
| `CpmStressSeq` | `sequences/packet/CpmStressSeq.sv` | Burst traffic |
| `CpmDropSeq` | `sequences/packet/CpmDropSeq.sv` | Drop testing |
| `CpmCoverageTrafficSeq` | `sequences/packet/CpmCoverageTrafficSeq.sv` | Coverage-directed |

#### Tests

| Test | File | Description |
|------|------|-------------|
| `CpmBaseTest` | `tests/CpmBaseTest.sv` | Common test base |
| `CpmMainTest` | `tests/CpmMainTest.sv` | Full flow with factory override + callback |
| `CpmSmokeTest` | `tests/CpmSmokeTest.sv` | Quick sanity check |
| `CpmRalResetTest` | `tests/CpmRalResetTest.sv` | RAL reset verification |

#### Mandatory UVM Features

| Feature | Implementation |
|---------|----------------|
| RAL | `CpmRegModel` + `CpmRegAdapter` + predictor |
| Virtual Sequence | `CpmTopVirtualSeq` with 8-step flow |
| Factory Override | `CpmBaseTrafficSeq` → `CpmCoverageTrafficSeq` in `CpmMainTest` |
| Callbacks | `CpmBasePacketCb` with `pre_drive`/`post_drive` hooks |
| Functional Coverage | `cg_packet` in `CpmPacketCoverage` |
| SVA | `p_input_stability`, `p_output_stability`, `p_bounded_liveness` |

---

## Phase 4 - Coverage Plan Development

### Transformation Modes Coverage

| # | Name | Type | Definition |
|---|------|------|------------|
| 1 | `cg_packet` | Covergroup | Main packet coverage group in `CpmPacketCoverage` |
| 2 | `cp_mode` | Coverpoint | Bins: `mode_pass`, `mode_xor`, `mode_add`, `mode_rot` |
| 3 | `cp_opcode` | Coverpoint | 16 bins for opcodes 0-15 |
| 4 | `cp_mode_opcode` | Cross | MODE × OPCODE (64 combinations, target 80%) |

### Drop/Stall Coverage

| # | Name | Type | Definition |
|---|------|------|------------|
| 1 | `cp_drop` | Coverpoint | Bins: `drop_hit`, `no_drop` |
| 2 | `cp_stall` | Coverpoint | Bins: `stall_hit`, `no_stall` |

### Register Coverage

| # | Name | Type | Definition |
|---|------|------|------------|
| 1 | `cg_register` | Covergroup | Register access coverage in `CpmRegCoverage` |
| 2 | `cp_addr` | Coverpoint | 8 bins for register addresses (0x00-0x1C) |
| 3 | `cp_op` | Coverpoint | Bins: `read`, `write` |
| 4 | `cp_addr_op` | Cross | Address × Operation |

### Covergroup Implementation (`CpmPacketCoverage.sv`)

```systemverilog
covergroup cg_packet with function sample(cpm_mode_e mode, bit [3:0] opcode, 
                                         bit drop_event, bit stall_event);
    cp_mode: coverpoint mode {
        bins mode_pass = {CPM_MODE_PASS};
        bins mode_xor  = {CPM_MODE_XOR};
        bins mode_add  = {CPM_MODE_ADD};
        bins mode_rot  = {CPM_MODE_ROT};
    }

    cp_opcode: coverpoint opcode {
        bins opcode[16] = {[0:15]};
    }

    cp_mode_opcode: cross cp_mode, cp_opcode;

    cp_drop: coverpoint drop_event {
        bins drop_hit = {1};
        bins no_drop  = {0};
    }

    cp_stall: coverpoint stall_event {
        bins stall_hit = {1};
        bins no_stall  = {0};
    }
endgroup
```

---

## Phase 5 - Detailed Test Case Design

### Test 1: Basic Transformation & RAL Consistency

**Goal**: Verify data transformation and RAL mirror synchronization.

**Steps**:
1. `CpmConfigSeq`: Write `m_mode` = XOR, `m_params` = {ADD_CONST, MASK}
2. Send `CpmPacketTxn` with `m_payload` = 0x5555, MASK = 0xAAAA
3. Wait for output (1 cycle latency for XOR)
4. `CpmScoreboard`: Verify output = 0xFFFF (0x5555 XOR 0xAAAA)
5. RAL mirror check: `m_reg_model.m_mode.get()` matches written value

### Test 2: All Modes Sweep

**Goal**: Verify all 4 transformation modes produce correct results.

**Steps**:
1. For each mode in {PASS, XOR, ADD, ROT}:
   - Configure via `CpmConfigSeq`
   - Send 10+ packets via `CpmBaseTrafficSeq`
   - `CpmRefModel` predicts expected output
   - `CpmScoreboard` verifies all packets

### Test 3: Drop Mechanism & Counter Accuracy

**Goal**: Verify DROP_CFG functionality and DROPPED_COUNT.

**Steps**:
1. Configure `m_drop_cfg`: DROP_EN=1, DROP_OPCODE=0x8
2. `CpmDropSeq`: Send packets with `m_opcode`=0x8 (should drop)
3. Send packets with other opcodes (should pass)
4. Verify dropped packets not at output
5. RAL read `m_dropped_count`, verify matches drop count

### Test 4: Backpressure & Pipeline Recovery

**Goal**: Verify `out_ready` backpressure handling.

**Steps**:
1. Configure MODE = ADD via `CpmConfigSeq`
2. `CpmStressSeq`: Start packet burst
3. Deassert `out_ready` for 20+ cycles
4. Verify `in_ready` drops (buffer full)
5. Reassert `out_ready`
6. Verify no data loss, correct sequence
7. SVA `p_output_stability` passes

### Test 5: Counter Invariant Verification

**Goal**: Verify `COUNT_IN == COUNT_OUT + DROPPED_COUNT`.

**Steps**:
1. Enable drop for specific opcode
2. Send mixed traffic
3. Poll `m_status.m_busy` until 0
4. RAL read: `m_count_in`, `m_count_out`, `m_dropped_count`
5. Verify invariant holds

### Test 6: RAL Reset Verification (`CpmRalResetTest`)

**Goal**: Verify all registers have correct reset values.

**Steps**:
1. Apply hardware reset
2. Execute `uvm_reg_hw_reset_seq` on `m_reg_model`
3. Verify each register matches spec reset value

### Test 7: Full Virtual Sequence Flow (`CpmMainTest`)

**Goal**: Demonstrate all mandatory features.

**Steps** (`CpmTopVirtualSeq` 8-step flow):
1. **Reset Wait**: Wait for `rst` deassert
2. **Configure**: `CpmConfigSeq` programs registers
3. **Traffic**: `CpmBaseTrafficSeq` sends 200 packets
4. **Reconfigure**: Cycle all 4 modes with traffic
5. **Stress**: `CpmStressSeq` burst traffic
6. **Drop Test**: `CpmDropSeq` targeted drops
7. **Readback**: RAL read all counters
8. **End Check**: Verify counter invariant

**Mandatory Features in `CpmMainTest`**:
- Factory Override: `CpmBaseTrafficSeq::type_id::set_type_override(CpmCoverageTrafficSeq::get_type())`
- Callback: `CpmBasePacketCb` registered on `CpmPacketDriver`

---

## Phase 6 - Closure & Reporting Strategy

### 6.1 Key Performance Indicators (KPIs)

| KPI | Target |
|-----|--------|
| Test Pass Rate | 100% (zero UVM_ERROR/UVM_FATAL) |
| Scoreboard Mismatches | 0 |
| SVA Violations | 0 |
| Coverage Achievement | All targets met |

### 6.2 Verification Sign-off Criteria

#### Functional Coverage

| Metric | Target |
|--------|--------|
| `cp_mode` | 100% |
| `cp_opcode` | 90%+ |
| `cp_mode_opcode` | 80%+ |
| `cp_drop` | Hit |
| `cp_stall` | Hit |

#### Code Coverage

| Metric | Target |
|--------|--------|
| Statement | 95%+ |
| Branch | 90%+ |
| Total DUT | 85%+ |

#### Mandatory Features Checklist

| Feature | Verification |
|---------|--------------|
| RAL | `CpmRalResetTest` passes, all registers accessible |
| Virtual Sequence | `CpmTopVirtualSeq` completes 8-step flow |
| Factory Override | Log confirms override in `CpmMainTest` |
| Callbacks | `CpmBasePacketCb` hooks execute |
| SVA | 0 violations for all assertions |
| Functional Coverage | Report meets targets |

#### Data Integrity

- Counter invariant verified via RAL
- No packets lost during backpressure
- All `CpmScoreboard` comparisons pass

### 6.3 Deliverables

| Deliverable | Description |
|-------------|-------------|
| Verification Plan | This document |
| UVM Testbench | Complete environment in `verification/` |
| Test Suite | `CpmSmokeTest`, `CpmMainTest`, `CpmRalResetTest` |
| Coverage Report | Functional and code coverage results |
| Bug Reports | Documented in `tracking/bug_tracker.csv` |
| Sign-off Document | `docs/SIGNOFF.md` |

### 6.4 Risk Assessment

| Risk | Mitigation |
|------|------------|
| Spec ambiguity (ROT_AMT, counter timing) | Document assumptions, clarify with design |
| DUT bugs blocking progress | Track in `bug_tracker.csv`, prioritize |
| Coverage gaps | Add directed sequences |

---

**Document End**

*This verification plan is written prior to implementation and describes the planned approach, targets, and expected outcomes for the CPM verification project.*
