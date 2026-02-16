
# uvm-cpm-packet-modifier

# UVM Final Project - CPM (Configurable Packet Modifier) Verification

## ▶ Live Project Demo
🔗 Interactive HTML demo:
https://assaf-afriat.github.io/uvm-cpm-packet-modifier/deliverables/project_demo.html

## Project Overview

This project implements a comprehensive UVM verification environment for the **CPM (Configurable Packet Modifier)** design.

### DUT Description

**CPM** is a packet processing unit that:
- Accepts packets via stream interface (valid/ready handshake)
- Modifies packet payloads based on configurable operation mode
- Supports 4 operation modes:
  - **PASS (0)**: Payload unchanged, latency 0 cycles
  - **XOR (1)**: Payload XOR with mask, latency 1 cycle
  - **ADD (2)**: Payload + constant, latency 2 cycles
  - **ROT (3)**: Payload rotated left by 4 bits, latency 1 cycle
- Implements packet drop mechanism based on opcode matching
- Maintains 2-slot pipeline buffer with configurable latency
- Provides register bus for configuration and statistics

### Interfaces

- **Stream Interface**: `in_valid`, `in_ready`, `in_id[3:0]`, `in_opcode[3:0]`, `in_payload[15:0]`
- **Stream Output**: `out_valid`, `out_ready`, `out_id[3:0]`, `out_opcode[3:0]`, `out_payload[15:0]`
- **Register Bus**: `req`, `gnt`, `write_en`, `addr[7:0]`, `wdata[31:0]`, `rdata[31:0]`

### Registers

- **CTRL (0x00)**: ENABLE, SOFT_RST
- **MODE (0x04)**: MODE[1:0] - Operation mode selection
- **PARAMS (0x08)**: MASK[15:0], ADD_CONST[31:16] - Mode parameters
- **DROP_CFG (0x0C)**: DROP_EN, DROP_OPCODE[7:4] - Drop configuration
- **STATUS (0x10)**: BUSY - Pipeline status (read-only)
- **COUNT_IN (0x14)**: Input packet counter (read-only)
- **COUNT_OUT (0x18)**: Output packet counter (read-only)
- **DROPPED_COUNT (0x1C)**: Dropped packet counter (read-only)

## Project Status

**Current Phase**: ✅ COMPLETE  
**Status**: All phases complete, verification signed off  
**Files Created**: 40+ SystemVerilog files, 7 documentation files  

### Test Results (All Passing - 0 Errors)

| Test | Status | Details |
|------|--------|---------|
| `CpmSmokeTest` | ✅ PASS | 10 packets matched, 0 mismatches, 0 errors |
| `CpmMainTest` | ✅ PASS | 185 packets matched, all 4 modes verified, 0 errors |
| `CpmRalResetTest` | ✅ PASS | All 8 registers verified, 0 errors |

### Mode Verification Summary

All 4 operation modes verified with correct transformations:
- **PASS (0)**: Payload unchanged, latency 0 cycles ✅
- **XOR (1)**: Payload XOR with mask, latency 1 cycle ✅
- **ADD (2)**: Payload + constant, latency 2 cycles ✅
- **ROT (3)**: Payload rotated left by 4 bits, latency 1 cycle ✅

### Coverage Results (ALL TARGETS MET ✅)

| Metric | Result | Target | Status |
|--------|--------|--------|--------|
| MODE | 100.00% | 100% | ✅ MET |
| OPCODE | 100.00% | 90% | ✅ MET |
| MODE×OPCODE | 100.00% | 80% | ✅ MET |
| DROP bin | 50% | Hit once | ✅ MET |
| STALL bin | 50% | Hit once | ✅ MET |
| Register ADDR | 100% | 100% | ✅ MET |
| Register OP | 100% | 100% | ✅ MET |

### Phase 1 Completion Summary
- ✅ Directory structure created
- ✅ Package files (CpmParamsPkg.sv, CpmTestPkg.sv)
- ✅ Interface files with SVA assertions
- ✅ Transaction classes
- ✅ Configuration objects
- ✅ RAL components (Model, Adapter, Predictor)
- ✅ All UVM components (Drivers, Monitors, Agents, Environment)
- ✅ Scoreboard and Reference Model
- ✅ Coverage collectors
- ✅ Callbacks
- ✅ Sequences (RAL, Virtual, Packet)
- ✅ Tests (Base, Main)
- ✅ Testbench top module
- ✅ Simulation scripts

## Quick Start

### Prerequisites
- QuestaSim 2025.1 or later
- Python 3.x
- UVM 1.1d library

### Running Tests

```bash
# From the project root directory:
cd "Verification/Final Project"

# Run smoke test (quick verification)
python scripts/Run/run.py --test CpmSmokeTest --timeout 60

# Run main test (factory override + full virtual sequence)
python scripts/Run/run.py --test CpmMainTest --timeout 120

# Run RAL reset test (verifies all register reset values)
python scripts/Run/run.py --test CpmRalResetTest --timeout 60

# Run with custom seed
python scripts/Run/run.py --test CpmSmokeTest --seed 12345
```

### Output Files
- Log files: `logs/<TestName>.log`
- Waveforms: `logs/<TestName>.wlf`

## Project Structure

See [FILE_STRUCTURE.md](FILE_STRUCTURE.md) for complete file listing.

## Documentation

### Core Documents
- [VERIFICATION_PLAN.md](VERIFICATION_PLAN.md) - Comprehensive verification plan
- [ARCHITECTURE.md](ARCHITECTURE.md) - Verification architecture with component diagrams
- [TEST_SUITE.md](TEST_SUITE.md) - Test suite documentation
- [USER_GUIDE.md](USER_GUIDE.md) - User guide with quick start
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting guide
- [SIGNOFF.md](SIGNOFF.md) - Verification sign-off document
- [BUG_REPORT.md](BUG_REPORT.md) - Bug report summary (0 DUT bugs found)

### Project Tracking
- [MASTER_PLAN.md](MASTER_PLAN.md) - Master verification plan with progress tracking
- [FILE_STRUCTURE.md](FILE_STRUCTURE.md) - Complete file structure (41 SV files)
- [PHASE1_STATUS.md](PHASE1_STATUS.md) - Phase 1 implementation status
- [PHASE11_STATUS.md](PHASE11_STATUS.md) - Phase 11 completion status (tests & coverage)
- [SPEC_REVIEW_SUMMARY.md](SPEC_REVIEW_SUMMARY.md) - Specification review summary
- [Spec/](Spec/) - Design specification documents

## Tracking

- [tracking/test_plan.csv](tracking/test_plan.csv) - Test plan and execution tracking
- [tracking/verification_bug_tracker.csv](tracking/verification_bug_tracker.csv) - Verification bug tracking
- [tracking/coverage_tracking.csv](tracking/coverage_tracking.csv) - Coverage tracking

## Verification Features (Mandatory Requirements)

- **RAL (Register Abstraction Layer)**: MANDATORY - Register model, adapter, predictor
- **Virtual Sequences**: MANDATORY - Top virtual sequence orchestrates complete flow
- **Dual Agent Architecture**: Separate agents for packet stream and register bus
- **SVA Assertions**: MANDATORY - Assertions in interfaces (not UVM classes)
- **Comprehensive Test Suite**: 27+ test cases covering all functionality
- **Functional Coverage**: MANDATORY - MODE (100%), OPCODE (90%), MODE×OPCODE (80%)
- **Reference Model**: Software model with correct latencies (PASS=0, XOR=1, ADD=2, ROT=1)
- **Scoreboard**: Automatic comparison with end-of-test invariant checks
- **Callbacks**: MANDATORY - At least one callback with real purpose
- **Factory Overrides**: MANDATORY - At least one meaningful override
- **Control Model**: Strict separation - Tests configure, Virtual sequences orchestrate, Leaf sequences generate

## Author

Assaf Afriat

## License

