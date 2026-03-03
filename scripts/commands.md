# CPM Verification - Common Commands Reference

Quick reference guide for running CPM verification tests. All commands should be run from the `scripts/Run` directory.

## 📋 Table of Contents
- [Basic Test Execution](#basic-test-execution)
- [Compilation Commands](#compilation-commands)
- [Test Execution with Options](#test-execution-with-options)
- [Code Coverage](#code-coverage)
- [Available Tests](#available-tests)
- [Troubleshooting](#troubleshooting)

---

## Basic Test Execution

### Run Smoke Test (Quick Verification)
```bash
cd scripts/Run
python run.py --test CpmSmokeTest
```

### Run Main Test (Full Feature Demo)
```bash
cd scripts/Run
python run.py --test CpmMainTest
```

### Run RAL Reset Test (Mandatory)
```bash
cd scripts/Run
python run.py --test CpmRalResetTest
```

---

## Compilation Commands

### Compile Only (No Test Run)
```bash
cd scripts/Run
python run.py --compile-only
```

### Run Test Without Recompiling (Faster)
```bash
cd scripts/Run
python run.py --test CpmSmokeTest --no-compile
```

### Manual Compilation (Using QuestaSim Directly)
```bash
cd scripts/Run
vsim -c -do "source compile.do; quit -f"
```

---

## Test Execution with Options

### Run with GUI (For Debugging)
```bash
cd scripts/Run
python run.py --test CpmSmokeTest --gui
```

### Run with Timeout (5 minutes)
```bash
cd scripts/Run
python run.py --test CpmSmokeTest --timeout 300
```

### Run with Timeout and Skip Compilation
```bash
cd scripts/Run
python run.py --test CpmMainTest --no-compile --timeout 600
```

### List All Available Tests
```bash
cd scripts/Run
python run.py --list
```

---

## Code Coverage

### Run Test with Coverage Report
```bash
cd scripts/Run
python run.py --test CpmMainTest --coverage-report
```

### Output Files
- **UCDB Database**: `coverage/<TestName>.ucdb` - Raw coverage data
- **Text Report**: `coverage/<TestName>_coverage.txt` - Summary
- **HTML Report**: `coverage/html/index.html` - Detailed interactive report

### View Coverage Report in Browser
```powershell
# Windows
start coverage/html/index.html

# Linux/Mac
open coverage/html/index.html
```

### Coverage Types Collected
| Type | Description | Flag |
|------|-------------|------|
| **Statement** | Lines executed | `s` |
| **Branch** | If/else/case branches taken | `b` |
| **Condition** | Boolean sub-expressions | `c` |
| **Expression** | Complex expressions | `e` |
| **FSM** | State machine transitions | `f` |
| **Toggle** | Signal transitions 0→1, 1→0 | `t` |

### Merge Coverage from Multiple Tests
```bash
cd "Verification/Final Project"
vcover merge coverage/merged.ucdb coverage/CpmSmokeTest.ucdb coverage/CpmMainTest.ucdb coverage/CpmRalResetTest.ucdb
vcover report -html -htmldir coverage/merged_html coverage/merged.ucdb
```

### View Coverage Summary (Text)
```powershell
Get-Content coverage/CpmMainTest_coverage.txt | Select-Object -First 100
```

### Manual Coverage Report Commands
```bash
# Generate text report
vcover report -details -output coverage/report.txt coverage/CpmMainTest.ucdb

# Generate HTML report
vcover report -html -htmldir coverage/html coverage/CpmMainTest.ucdb

# Show coverage summary in terminal
vcover report -summary coverage/CpmMainTest.ucdb
```

---

## Available Tests

### Core Tests (Implemented)
- `CpmSmokeTest` - Basic smoke test for quick verification
- `CpmMainTest` - Main test demonstrating all mandatory features
- `CpmRalResetTest` - RAL reset test (MANDATORY)

### Additional Tests (Placeholder - To Be Implemented)
- `CpmPassModeTest` - PASS mode verification
- `CpmXorModeTest` - XOR mode verification
- `CpmAddModeTest` - ADD mode verification (2-cycle latency)
- `CpmRotModeTest` - ROT mode verification
- `CpmDropTest` - Packet drop mechanism test
- `CpmCounterTest` - Counter verification test
- `CpmResetTest` - Hard/soft reset test
- `CpmEnableTest` - Enable/disable transitions test
- `CpmBackpressureTest` - Buffer full condition test
- `CpmModeSwitchTest` - Mode switching during operation
- `CpmCornerCaseTest` - Boundary conditions and edge cases
- `CpmStressTest` - High load and long sequence tests

---

## Common Workflows

### Quick Verification Workflow
```bash
cd scripts/Run
# 1. Compile
python run.py --compile-only

# 2. Run smoke test
python run.py --test CpmSmokeTest --no-compile

# 3. Run main test
python run.py --test CpmMainTest --no-compile
```

### Full Regression Workflow
```bash
cd scripts/Run
# Compile once
python run.py --compile-only

# Run all core tests
python run.py --test CpmSmokeTest --no-compile
python run.py --test CpmMainTest --no-compile
python run.py --test CpmRalResetTest --no-compile
```

### Debug Workflow (With GUI)
```bash
cd scripts/Run
# Compile
python run.py --compile-only

# Run with GUI for debugging
python run.py --test CpmSmokeTest --gui --no-compile
```

### Long-Running Test with Timeout
```bash
cd scripts/Run
# Run stress test with 10-minute timeout
python run.py --test CpmStressTest --timeout 600
```

---

## Advanced Usage

### Run Multiple Tests in Sequence
```bash
cd scripts/Run
# Compile once
python run.py --compile-only

# Run tests sequentially
for test in CpmSmokeTest CpmMainTest CpmRalResetTest; do
    python run.py --test $test --no-compile
done
```

### Run with Custom Timeout (Windows PowerShell)
```powershell
cd scripts\Run
python run.py --test CpmSmokeTest --timeout 300
```

### Check Help
```bash
cd scripts/Run
python run.py --help
```

---

## Interrupting Simulations

### Stop Running Simulation
- Press **Ctrl+C** to gracefully interrupt
- The script will clean up and show elapsed time

### Force Stop (If Ctrl+C Doesn't Work)
- Close the terminal window
- Or use Task Manager to kill the process

---

## Troubleshooting

### QuestaSim Errors

#### "Unexpected EOF on RPC channel"
This indicates a QuestaSim process communication error. The simulation engine died suddenly, leaving the communication channel open.

**Common Causes:**
- Fatal compilation/elaboration errors (circular dependencies, null pointers)
- Memory access violations
- Zero-delay loops (infinite forever loops without @posedge clk or #delay)
- License or resource issues (firewall, antivirus, out of RAM)
- Stale binaries in work library

**Solutions (in order):**

1. **Kill stuck QuestaSim processes**
   ```powershell
   # Windows PowerShell - Find processes
   Get-Process | Where-Object {$_.ProcessName -like "*vsim*"}
   
   # Kill all vsim processes (be careful!)
   Get-Process | Where-Object {$_.ProcessName -like "*vsim*"} | Stop-Process -Force
   ```

2. **Clean and recompile** (fixes stale binaries)
   ```bash
   # Use the --clean option
   python run.py --test CpmSmokeTest --clean
   
   # Or manually
   cd "Verification/Final Project"
   Remove-Item -Path "work" -Recurse -Force -ErrorAction SilentlyContinue
   cd scripts/Run
   python run.py --compile-only
   ```

3. **Check simulation.log for errors**
   ```powershell
   # View last 50 lines of log
   Get-Content "Verification\Final Project\simulation.log" -Tail 50
   
   # Search for errors
   Select-String -Path "Verification\Final Project\simulation.log" -Pattern "Error|Fatal|Null|SIGSEGV"
   ```

4. **Verify no zero-delay loops**
   - All `forever` loops must have `@(posedge clk)` or `#delay`
   - Check drivers and monitors for proper synchronization

5. **Restart QuestaSim**
   - Close all QuestaSim windows
   - Wait a few seconds
   - Try again

6. **Check for license issues**
   - May be related to license server disconnection
   - Wait and retry

#### "All Verilog licenses are currently in use"
This means all QuestaSim licenses are busy. Solutions:

1. **Wait for license** (recommended)
   - The request is queued and will run automatically when a license becomes available
   - Usually takes a few seconds to minutes

2. **Check running QuestaSim processes**
   ```powershell
   # Windows PowerShell
   Get-Process | Where-Object {$_.ProcessName -like "*vsim*"}
   ```

3. **Close other QuestaSim instances**
   - Close any QuestaSim GUI windows
   - Kill stuck processes if needed

4. **Check license server status**
   ```bash
   # Check license availability
   lmutil lmstat -a -c @<license_server>
   ```

5. **Use license queuing** (automatic)
   - QuestaSim will wait automatically
   - No action needed, just wait

### If Compilation Fails
```bash
cd scripts/Run
# Check compilation errors
python run.py --compile-only
```

### If Test Can't Find work.tb_top
```bash
# Make sure you're in the project root when running
cd "Verification/Final Project"
cd scripts/Run
python run.py --test CpmSmokeTest
```

### If QuestaSim Not Found
```bash
# Make sure QuestaSim is in your PATH
# Or use full path to vsim
```

### View Compilation Output
```bash
cd scripts/Run
vsim -c -do "source compile.do; quit -f"
```

---

## Quick Copy-Paste Commands

### Most Common Commands (Copy These!)

```bash
# Quick smoke test
cd scripts/Run && python run.py --test CpmSmokeTest

# Full main test
cd scripts/Run && python run.py --test CpmMainTest

# RAL reset test
cd scripts/Run && python run.py --test CpmRalResetTest

# Compile only
cd scripts/Run && python run.py --compile-only

# List tests
cd scripts/Run && python run.py --list
```

---

## Notes

- All commands assume you're in the `scripts/Run` directory
- Use `--no-compile` to skip compilation for faster iteration
- Use `--timeout` for long-running tests to prevent hanging
- Use `--gui` for interactive debugging
- Press **Ctrl+C** at any time to interrupt gracefully

---

## File Locations

- **Test Runner**: `scripts/Run/run.py`
- **Compile Script**: `scripts/Run/compile.do`
- **Testbench Top**: `verification/tb_top.sv`
- **Test Files**: `verification/tests/`
- **DUT**: `cpm_design/cpm_rtl.sv`
- **Log Files**: `logs/<TestName>.log`
- **Waveforms**: `logs/<TestName>.wlf`
- **Coverage Data**: `coverage/<TestName>.ucdb`
- **Coverage Report**: `coverage/html/index.html`

---

*Last Updated: 2026-02-01*
