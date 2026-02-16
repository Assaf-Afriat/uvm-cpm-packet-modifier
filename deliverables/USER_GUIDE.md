# CPM Verification User Guide

**Project**: Configurable Packet Modifier (CPM) Verification  
**Author**: Assaf Afriat  
**Date**: 2026-02-01

---

## Quick Start

### Prerequisites

- **QuestaSim 2025.1** or later
- **Python 3.x**
- **UVM 1.1d** library (included with QuestaSim)

### Running Your First Test

```bash
# Navigate to project directory
cd "Verification/Final Project"

# Run smoke test
python scripts/Run/run.py --test CpmSmokeTest --timeout 60
```

Expected output:
```
--- INFO: Running test: CpmSmokeTest ---
--- INFO: Compiling... ---
--- INFO: Compilation complete ---
--- INFO: Elaborating... ---
--- INFO: Elaboration complete ---
--- INFO: Simulating... ---
# UVM_INFO: Test passed!
--- INFO: Test completed ---
```

---

## Recommended: Graphical Test Runner (GUI)

**We highly recommend using the Premium GUI Test Runner** located in the `gui/` folder for the best verification experience. The GUI provides a modern, intuitive interface that significantly improves productivity and reduces the learning curve for running UVM tests.

### Why Use the GUI?

| Feature | Benefit |
|---------|---------|
| **One-Click Test Execution** | No need to remember command-line arguments |
| **Real-Time Console Output** | Color-coded output with syntax highlighting for errors, warnings, and successes |
| **Visual Test Configuration** | Dropdown menus and checkboxes for all test options |
| **Live Timer** | See elapsed time during test execution |
| **Quick Actions Panel** | Instant access to logs folder, coverage reports, and project demo |
| **Theme Support** | Dark/Light mode toggle for comfortable viewing |
| **Modern UI** | Clean, professional interface matching industry standards |

### Launching the GUI

```bash
# Navigate to project directory
cd "Verification/Final Project v01"

# Launch the GUI
python gui/test_runner.py
```

Or simply double-click `test_runner.py` in the `gui/` folder.

### GUI Features

**Test Configuration Card:**
- Select test from dropdown (CpmSmokeTest, CpmMainTest, CpmRalResetTest)
- Configure timeout in seconds
- Set seed value (or leave as "random")

**Options Card:**
- Generate Coverage Report - Creates detailed coverage HTML
- Modern HTML Report - Premium styled coverage report
- GUI Mode (QuestaSim) - Opens QuestaSim waveform viewer

**Quick Actions:**
- Open Logs Folder - Jump directly to simulation logs
- Coverage Report - View the latest coverage HTML report
- Project Demo - Open the interactive project documentation

**Status Bar:**
- Real-time status indicator (green = ready, amber = running)
- Elapsed time counter during test execution

### Screenshot of GUI Layout

```
+---------------------------------------------------------------------+
|  CPM  Verification Suite           3 Tests | 100% Pass | 100% Cov  |
+---------------------------------------------------------------------+
|                                                                     |
|  +-------------------+    +---------------------------------------+ |
|  | Test Config       |    | Console Output                        | |
|  | ----------------- |    | ------------------------------------- | |
|  | Select Test: [v]  |    | ===================================== | |
|  | Timeout: 120      |    |    CPM VERIFICATION SUITE - MainTest  | |
|  | Seed: random      |    | ===================================== | |
|  |                   |    |                                       | |
|  | Options           |    |    Command: python run.py --test ...  | |
|  | ----------------- |    |    Started: 2026-02-07 14:30:00       | |
|  | [x] Coverage      |    |                                       | |
|  | [x] Modern Report |    |    UVM_INFO: Starting test...         | |
|  | [ ] GUI Mode      |    |    UVM_INFO: Reset complete           | |
|  |                   |    |    UVM_INFO: Traffic phase started    | |
|  | [>] RUN TEST      |    |    ...                                | |
|  | [#] STOP          |    |                                       | |
|  |                   |    | ===================================== | |
|  | Quick Actions     |    |    [OK] TEST COMPLETED (5s)           | |
|  | ----------------- |    | ===================================== | |
|  | > Open Logs       |    |                                       | |
|  | > Coverage        |    |                                       | |
|  | > Project Demo    |    |                                       | |
|  +-------------------+    +---------------------------------------+ |
+---------------------------------------------------------------------+
|  [*] Ready to run                                       Timer: 5s   |
+---------------------------------------------------------------------+
```

---

## Project Structure

```
Verification/Final Project v01/
├── cpm_design/              # DUT RTL
│   └── cpm_rtl.sv
├── verification/            # UVM testbench
│   ├── pkg/                 # Packages
│   ├── interfaces/          # SystemVerilog interfaces
│   ├── transactions/        # UVM transactions
│   ├── config/              # Configuration objects
│   ├── driver/              # UVM drivers
│   ├── monitor/             # UVM monitors
│   ├── agent/               # UVM agents
│   ├── env/                 # UVM environment
│   ├── scoreboard/          # Scoreboard & ref model
│   ├── coverage/            # Coverage collectors
│   ├── callbacks/           # Callback classes
│   ├── sequences/           # Sequence library
│   ├── ral/                 # Register Abstraction Layer
│   ├── tests/               # UVM tests
│   └── tb_top.sv            # Testbench top
├── scripts/                 # Simulation scripts
│   ├── Run/                 # QuestaSim scripts
│   └── generate_coverage_report.py
├── gui/                     # Graphical Test Runner
│   └── test_runner.py       # Premium GUI application
├── deliverables/            # Project deliverables
│   ├── CPM_Verification_Plan.pdf
│   ├── CPM_SignOff.pdf
│   └── CPM_Reflection_Report.pdf
│   
├── logs/                    # Simulation logs
├── coverage/                # Coverage reports
├── tracking/                # Bug & test tracking CSVs
├── docs/                    # Documentation
│   ├── project_demo.html    # Interactive project demo
│   ├── ARCHITECTURE.md
│   ├── SIGNOFF.md
│   └── ...
└── spec/                    # Design specifications
```

---

## Running Tests

### Command Line Options

```bash
python scripts/Run/run.py [OPTIONS]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--test NAME` | Test name to run | Required |
| `--timeout SEC` | Timeout in seconds | 300 |
| `--seed NUM` | Random seed | Random |
| `--gui` | Launch GUI mode | False |
| `--coverage-report` | Generate coverage report | False |
| `--modern-report` | Generate modern HTML report | False |

### Examples

```bash
# Basic test run
python scripts/Run/run.py --test CpmSmokeTest

# With fixed seed for reproducibility
python scripts/Run/run.py --test CpmMainTest --seed 12345

# With coverage report
python scripts/Run/run.py --test CpmMainTest --coverage-report

# GUI mode for debugging
python scripts/Run/run.py --test CpmMainTest --gui
```

---

## Available Tests

| Test | Description | Duration |
|------|-------------|----------|
| `CpmSmokeTest` | Quick sanity check | ~1 sec |
| `CpmMainTest` | Full verification | ~5 sec |
| `CpmRalResetTest` | Register reset values | ~1 sec |

### Recommended Test Flow

1. **Smoke Test**: Quick check that environment works
2. **RAL Reset Test**: Verify register reset values
3. **Main Test**: Full verification with coverage

```bash
python scripts/Run/run.py --test CpmSmokeTest --timeout 60
python scripts/Run/run.py --test CpmRalResetTest --timeout 60
python scripts/Run/run.py --test CpmMainTest --timeout 120 --coverage-report
```

---

## Coverage Reports

### Standard QuestaSim Report

```bash
python scripts/Run/run.py --test CpmMainTest --coverage-report
```

This generates:
- `coverage/CpmMainTest.ucdb` - Coverage database
- `coverage/CpmMainTest_coverage.txt` - Text report
- `coverage/html/index.html` - HTML report

### Modern HTML Report

```bash
python scripts/generate_coverage_report.py
```

Features:
- Dark/Light mode toggle
- Detailed functional coverage
- DUT code coverage breakdown
- Uncovered items list

---

## Debugging

### Viewing Waveforms

1. Run test in GUI mode:
```bash
python scripts/Run/run.py --test CpmSmokeTest --gui
```

2. Or view saved waveforms:
```bash
vsim -view logs/CpmSmokeTest.wlf
```

### Log Files

All logs are saved in `logs/` directory:
- `logs/CpmSmokeTest.log`
- `logs/CpmMainTest.log`
- `logs/CpmRalResetTest.log`

### Increasing Verbosity

Edit `scripts/Run/run.py` or add to vsim command:
```
+UVM_VERBOSITY=UVM_HIGH
+UVM_VERBOSITY=UVM_DEBUG
```

---

## Filtering Log Output

After running a test, use these commands to filter the log for specific information.

### Windows PowerShell

```powershell
# Navigate to logs folder
cd "Verification/Final Project  v01/logs"

# Show only warnings
Select-String -Pattern "Warning|UVM_WARNING" CpmMainTest.log

# Show only errors
Select-String -Pattern "Error|UVM_ERROR|UVM_FATAL" CpmMainTest.log

# Show scoreboard messages
Select-String -Pattern "\[SCOREBOARD\]" CpmMainTest.log

# Show monitor messages
Select-String -Pattern "\[MON\]" CpmMainTest.log

# Show driver messages
Select-String -Pattern "\[DRV\]" CpmMainTest.log

# Show SVA assertion failures
Select-String -Pattern "\[SVA\]|assert|Error:.*assertion" CpmMainTest.log

# Show RAL/register messages
Select-String -Pattern "\[RegModel\]|\[RAL\]" CpmMainTest.log

# Show virtual sequence messages
Select-String -Pattern "\[VIRT_SEQ\]" CpmMainTest.log

# Show test messages
Select-String -Pattern "\[TEST\]" CpmMainTest.log

# Show coverage messages
Select-String -Pattern "\[COV\]" CpmMainTest.log

# Show config sequence messages
Select-String -Pattern "\[CONFIG_SEQ\]" CpmMainTest.log

# Show packet transactions (high verbosity)
Select-String -Pattern "Packet accepted|Input packet|Output packet" CpmMainTest.log

# Show counter values
Select-String -Pattern "COUNT_IN|COUNT_OUT|DROPPED|counter" CpmMainTest.log

# Show soft reset events
Select-String -Pattern "Soft Reset|soft_rst|SOFT_RST" CpmMainTest.log

# Show drop events
Select-String -Pattern "DROP|drop" CpmMainTest.log

# Combine multiple patterns (e.g., warnings AND errors)
Select-String -Pattern "Warning|Error|UVM_WARNING|UVM_ERROR" CpmMainTest.log

# Show summary at end of test
Select-String -Pattern "Report Summary|UVM_INFO.*Summary|report_phase" CpmMainTest.log
```

### Linux/Mac (bash/grep)

```bash
# Navigate to logs folder
cd "Verification/Final Project  v01/logs"

# Show only warnings
grep -E "Warning|UVM_WARNING" CpmMainTest.log

# Show only errors
grep -E "Error|UVM_ERROR|UVM_FATAL" CpmMainTest.log

# Show scoreboard messages
grep "\[SCOREBOARD\]" CpmMainTest.log

# Show monitor messages
grep "\[MON\]" CpmMainTest.log

# Show driver messages
grep "\[DRV\]" CpmMainTest.log

# Show SVA assertion failures
grep -E "\[SVA\]|assert|Error:.*assertion" CpmMainTest.log

# Show RAL/register messages
grep -E "\[RegModel\]|\[RAL\]" CpmMainTest.log

# Show virtual sequence messages
grep "\[VIRT_SEQ\]" CpmMainTest.log

# Show test messages
grep "\[TEST\]" CpmMainTest.log

# Show coverage messages
grep "\[COV\]" CpmMainTest.log

# Show counter values
grep -i "COUNT_IN\|COUNT_OUT\|DROPPED\|counter" CpmMainTest.log

# Count occurrences of each message type
grep -c "UVM_WARNING" CpmMainTest.log
grep -c "UVM_ERROR" CpmMainTest.log
grep -c "\[SCOREBOARD\]" CpmMainTest.log
```

### Quick Reference - Common Log Tags

| Tag | Component | Description |
|-----|-----------|-------------|
| `[SCOREBOARD]` | CpmScoreboard | Packet matching, counters, invariants |
| `[MON]` | CpmPacketMonitor, CpmRegMonitor | Observed transactions |
| `[DRV]` | CpmPacketDriver, CpmRegDriver | Driven transactions |
| `[TEST]` | CpmBaseTest, CpmMainTest | Test status messages |
| `[VIRT_SEQ]` | CpmTopVirtualSeq | Virtual sequence phases |
| `[CONFIG_SEQ]` | CpmConfigSeq | RAL configuration |
| `[COV]` | CpmPacketCoverage, CpmRegCoverage | Coverage statistics |
| `[RegModel]` | UVM RAL | Register reads/writes |
| `[SVA]` | CpmStreamIf | Assertion failures |
| `[TB_TOP]` | tb_top | Testbench startup |

### UVM Severity Levels

| Severity | Description |
|----------|-------------|
| `UVM_INFO` | Informational messages |
| `UVM_WARNING` | Non-fatal issues |
| `UVM_ERROR` | Errors (test continues) |
| `UVM_FATAL` | Fatal errors (test stops) |

---

## Configuration

### Modifying Test Parameters

Edit `CpmTopVirtualSeq.sv`:

```systemverilog
// Number of packets per mode
int m_num_traffic_packets = 50;  // Change this

// Number of stress packets
int m_num_stress_packets = 200;  // Change this
```

### Adding Factory Overrides

In your test's `build_phase`:

```systemverilog
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Override base sequence with coverage sequence
    CpmBaseTrafficSeq::type_id::set_type_override(
        CpmCoverageTrafficSeq::get_type()
    );
endfunction
```

---

## Compilation

### Manual Compilation

```bash
cd scripts/Run
vsim -c -do "do compile.do; do elaborate.do; quit"
```

### Recompiling After Changes

The `run.py` script automatically recompiles. For manual:

```bash
cd scripts/Run
vsim -c -do "do compile.do; quit"
```

---

## Common Workflows

### Adding a New Test

1. Create test file: `verification/tests/MyTest.sv`
2. Add to package: `verification/pkg/CpmTestPkg.sv`
3. Run: `python scripts/Run/run.py --test MyTest`

### Modifying Coverage

Edit `verification/coverage/CpmPacketCoverage.sv`:

```systemverilog
covergroup cg_packet;
    // Add your coverpoints here
    cp_new: coverpoint m_new_field;
endgroup
```

### Adding New Assertions

Edit `verification/interfaces/CpmStreamIf.sv`:

```systemverilog
property p_new_property;
    @(posedge clk) disable iff (rst)
    // Your property here
endproperty
assert_new: assert property (p_new_property);
```

---

## Frequently Asked Questions

### Q: Test hangs and doesn't complete?
A: Check that `out_ready` is driven high in `tb_top.sv`. Add timeout: `--timeout 60`

### Q: Coverage is 0%?
A: Ensure you compile with `-coverage` flag. Check compile.do includes coverage options.

### Q: Scoreboard reports mismatches?
A: Check the reference model configuration matches DUT. See `logs/*.log` for details.

### Q: How to run with different seeds?
A: Use `--seed NUM` option: `python scripts/Run/run.py --test CpmMainTest --seed 42`

### Q: Where are waveform files?
A: In `logs/` directory: `logs/TestName.wlf`

---

## Support

For issues or questions:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review simulation logs in `logs/` directory
3. Check QuestaSim transcript file

---

**Document End**
