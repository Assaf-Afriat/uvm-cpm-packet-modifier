# Specification Review Summary

## Date: 2026-01-31
## Status: Planning Updated Based on Specification Review

---

## Critical Corrections Made

### 1. ADD Mode Latency (CORRECTED)
- **Previous**: ADD mode latency = 1 cycle
- **Correct**: ADD mode latency = 2 cycles
- **Impact**: Reference model, scoreboard, and latency tests must be updated

### 2. RAL is MANDATORY (NEW REQUIREMENT)
- **Previous**: RAL was optional
- **Correct**: RAL is MANDATORY
- **Requirements**:
  - Register model matching DUT spec (all 8 registers)
  - `uvm_reg_adapter` for register bus
  - `uvm_reg_predictor` for automatic prediction
  - Run `uvm_reg_hw_reset_seq`
  - Custom RAL configuration sequence
  - **NO direct bus-level register access from tests**

### 3. Virtual Sequence is MANDATORY (NEW REQUIREMENT)
- **Previous**: Virtual sequences were optional
- **Correct**: `top_virtual_seq` is MANDATORY
- **Requirements**:
  - Must orchestrate complete system flow:
    1. Reset
    2. Configure (via RAL)
    3. Traffic
    4. Reconfigure (MODE change during runtime)
    5. Stress
    6. Drop
    7. Readback (counters)
    8. End
  - Raise/drop objections only at test or virtual sequence level
  - Verify MODE change behavior (sampled at input accept time)

### 4. Mandatory Sequences (NEW REQUIREMENTS)
- **config_seq**: RAL-based sequence to program registers
- **base_traffic_seq**: Random packet stimulus
- **stress_seq**: Burst traffic to cause stalls/backpressure
- **drop_seq**: Force opcode matching drop configuration
- **top_virtual_seq**: Full scenario orchestration

### 5. SVA Assertions are MANDATORY (NEW REQUIREMENT)
- **Previous**: Assertions were optional
- **Correct**: SVA assertions are MANDATORY
- **Requirements**:
  - Assertions must be in stream interface (NOT in UVM classes)
  - Input stability under stall
  - Output stability under stall
  - Bounded liveness property
  - At least one cover property (stall event, mode=ADD, drop event)

### 6. Coverage Targets (UPDATED)
- **MODE coverage**: 100% (MANDATORY)
- **OPCODE coverage**: 90% (MANDATORY)
- **MODE × OPCODE cross**: 80% (MANDATORY)
- **Drop bin**: Hit at least once (MANDATORY)
- **Stall bin**: Hit at least once (MANDATORY)

### 7. Scoreboard Requirements (UPDATED)
- **End-of-test checks (MANDATORY)**:
  - Counter invariant: COUNT_OUT + DROPPED_COUNT == COUNT_IN
  - No leftover expected items (queue empty)
- **Reference model must**:
  - Apply transformation based on MODE/PARAMS sampled at input acceptance time
  - Handle drop rule (no expected output for dropped packets)
  - Use correct latencies: PASS=0, XOR=1, ADD=2, ROT=1

### 8. Control Model (NEW MANDATORY RULE)
- **Strict separation of responsibilities**:
  - Tests: Choose scenario + configure environment (via uvm_config_db)
  - Virtual Sequences: Orchestrate execution
  - Leaf Sequences: Generate stimulus only
- **Violations (architectural errors)**:
  - Test drives transactions directly
  - Driver raises objections
  - Leaf sequences perform configuration/checking
- **Rules**:
  - No direct DUT signal access from tests
  - No bus-level register access from tests (use RAL)
  - No objections inside driver/monitor

### 9. Factory Override (MANDATORY)
- Must demonstrate at least one meaningful factory override
- Example: Override `base_traffic_seq` → `coverage_traffic_seq`
- Override applied in test, not scattered across components

### 10. Callbacks (MANDATORY)
- Must implement at least one callback mechanism
- Options: Driver callback, Monitor callback, or Scoreboard callback
- Must have real purpose, not dummy

---

## Closure Criteria (MANDATORY)

A submission is considered closed only when ALL are true:

1. ✅ All tests pass (no runtime hangs)
2. ✅ Scoreboard reports 0 mismatches
3. ✅ All assertions pass (no failures)
4. ✅ Functional coverage targets achieved:
   - MODE: 100%
   - OPCODE: 90%
   - MODE × OPCODE: 80%
   - Drop bin: hit at least once
   - Stall bin: hit at least once
5. ✅ RAL reset sequence passes cleanly
6. ✅ End-of-test invariants checked and pass:
   - COUNT_OUT + DROPPED_COUNT == COUNT_IN
   - No leftover expected items

---

## Deliverables (MANDATORY)

Submit a single ZIP containing:

1. **Full source code** (UVM TB + assertions + RAL code)
2. **Verification Plan** (see template)
3. **Coverage report** (screenshot or text summary)
4. **Assertion report** (tool output summary)
5. **Reflection Report** (Challenges, limitations, future work)

**Professional requirement**: Organize code using packages.

---

## Files Updated

1. ✅ `MASTER_PLAN.md` - Updated with all mandatory requirements
2. ✅ `FILE_STRUCTURE.md` - Added RAL files and virtual sequence structure
3. ✅ `ARCHITECTURE.md` - Added RAL integration and control model
4. ✅ `test_plan.csv` - Updated with mandatory sequences and requirements
5. ✅ `coverage_tracking.csv` - Updated with correct coverage targets

---

## Next Steps

1. ✅ Phase 1: Project Setup & Architecture Definition - **COMPLETE**
2. ✅ Create RAL register model (MANDATORY) - **COMPLETE**
3. ✅ Create virtual sequence structure (MANDATORY) - **COMPLETE**
4. ✅ Implement SVA assertions in interfaces (MANDATORY) - **COMPLETE**
5. ✅ Update reference model with correct ADD latency (2 cycles) - **COMPLETE**

## Current Status

**Phase 1 Complete**: All placeholder files created (35+ files)
- All components have proper structure and headers
- RAL model implemented with all 8 registers
- SVA assertions included in stream interface
- Reference model has correct latencies
- Ready for Phase 2: Transaction & Interface Layer implementation
