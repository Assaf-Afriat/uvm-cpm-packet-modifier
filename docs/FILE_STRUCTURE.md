# CPM Verification Project - File Structure

**Status**: Complete - All files implemented and organized ✅  
**Version**: 1.1

## Directory Layout

```
Verification/Final Project v01/
├── README.md                          # Project overview and quick start
├── MASTER_PLAN.md                     # Master verification plan with progress
├── modelsim.ini                       # QuestaSim configuration
├── .cursorrules                       # Cursor AI rules
│
├── docs/                              # Documentation
│   ├── project_demo.html              # Interactive project demo (main docs)
│   ├── FILE_STRUCTURE.md              # This file - complete file listing
│   ├── ARCHITECTURE.md                # Verification architecture & hierarchy
│   ├── VERIFICATION_PLAN.md           # Verification strategy and goals
│   ├── TEST_SUITE.md                  # Test descriptions and organization
│   ├── USER_GUIDE.md                  # How to run tests (GUI recommended)
│   ├── TROUBLESHOOTING.md             # Common issues and solutions
│   ├── SIGNOFF.md                     # Verification sign-off checklist
│   ├── BUG_REPORT.md                  # Bug summary report
│   ├── SPEC_REVIEW_SUMMARY.md         # Specification review summary
│   └── archive/                       # Archived status files
│       ├── index.html
│       ├── PHASE1_STATUS.md
│       └── PHASE11_STATUS.md
│
├── deliverables/                      # Project deliverables (HTML/PDF/DOCX)
│   ├── Verification Plan/
│   │   ├── CPM_Verification_Plan.html
│   │   ├── CPM_Verification_Plan.md
│   │   ├── CPM Verification Plan.docx
│   │   └── CPM Verification Plan.pdf
│   ├── Sign Off/
│   │   ├── CPM_SignOff.html
│   │   ├── CPM Verification Sign Off.docx
│   │   └── CPM Verification Sign Off.pdf
│   ├── Reflection Report/
│   │   ├── CPM_Reflection_Report.html
│   │   ├── Reflection Report.docx
│   │   └── Reflection Report.pdf
│   ├── CPM_hierarchy.png              # UVM hierarchy diagram
│   ├── project_demo.html              # Copy of main demo
│   └── USER_GUIDE.md                  # Copy of user guide
│
├── spec/                              # Specification documents
│   ├── Configurable-Packet-Modifier-CPM-Design-Specification-Version-1.1.pdf
│   ├── Configurable-Packet-Modifier-CPM-Design-Specification-Version-1.1_extracted.txt
│   ├── CPM-Final-Project-Verification-Requirements-and-Deliverables.pdf
│   ├── CPM-Final-Project-Verification-Requirements-and-Deliverables_extracted.txt
│   └── old/                           # Archived v1.0 specs
│       ├── Configurable-Packet-Modifier-CPM-Design-Specification-Version-1.0.pdf
│       └── ...
│
├── cpm_design/                        # DUT source files
│   ├── cpm_rtl.sv                     # CPM RTL design v1.1 (BLACK BOX)
│   └── cpm_registers.csv              # Register map
│
├── verification/                      # UVM verification code
│   │
│   ├── pkg/                           # Package files
│   │   ├── CpmTestPkg.sv              # Main verification package (includes all)
│   │   └── CpmParamsPkg.sv            # Parameters, enums, constants
│   │
│   ├── transactions/                  # Transaction classes
│   │   ├── CpmPacketTxn.sv            # Packet transaction (id, opcode, payload, metadata)
│   │   └── CpmRegTxn.sv               # Register transaction (addr, data, write_en)
│   │
│   ├── interfaces/                    # Interface definitions
│   │   ├── CpmStreamIf.sv             # Stream interface with SVA assertions
│   │   └── CpmRegIf.sv                # Register bus interface
│   │
│   ├── config/                        # Configuration objects
│   │   ├── CpmStreamAgentConfig.sv    # Stream agent configuration
│   │   ├── CpmRegAgentConfig.sv       # Register agent configuration
│   │   └── CpmEnvConfig.sv            # Environment configuration
│   │
│   ├── ral/                           # RAL (Register Abstraction Layer)
│   │   ├── CpmRegModel.sv             # Register model (all 8 registers)
│   │   ├── CpmRegAdapter.sv           # RAL adapter (reg2bus, bus2reg)
│   │   └── CpmRegPredictor.sv         # RAL predictor (auto-updates mirrors)
│   │
│   ├── driver/                        # Driver components
│   │   ├── CpmPacketDriver.sv         # Packet stream driver with callbacks
│   │   └── CpmRegDriver.sv            # Register bus driver with callbacks
│   │
│   ├── sequencer/                     # Sequencer components
│   │   ├── CpmPacketSequencer.sv      # Packet sequencer
│   │   └── CpmRegSequencer.sv         # Register sequencer
│   │
│   ├── monitor/                       # Monitor components
│   │   ├── CpmPacketMonitor.sv        # Packet monitor (captures config at accept)
│   │   └── CpmRegMonitor.sv           # Register monitor
│   │
│   ├── coverage/                      # Coverage components
│   │   ├── CpmPacketCoverage.sv       # Packet coverage (MODE, OPCODE, cross)
│   │   └── CpmRegCoverage.sv          # Register coverage (ADDR, OP)
│   │
│   ├── agent/                         # Agent components
│   │   ├── CpmPacketAgent.sv          # Packet stream agent
│   │   └── CpmRegAgent.sv             # Register bus agent
│   │
│   ├── env/                           # Environment components
│   │   └── CpmEnv.sv                  # Top-level environment
│   │
│   ├── scoreboard/                    # Scoreboard and checkers
│   │   ├── CpmScoreboard.sv           # Main scoreboard with expected queue
│   │   ├── CpmScoreboardOutputImp.sv  # Output analysis imp
│   │   └── CpmRefModel.sv             # Reference model (uses txn metadata)
│   │
│   ├── callbacks/                     # Callback classes
│   │   ├── CpmBasePacketCb.sv         # Packet driver callbacks
│   │   ├── CpmBaseRegCb.sv            # Register driver callbacks
│   │   └── CpmBaseMonitorCb.sv        # Monitor callbacks
│   │
│   ├── sequences/                     # Sequence library
│   │   ├── ral/                       # RAL sequences
│   │   │   └── CpmConfigSeq.sv        # RAL-based config sequence
│   │   │
│   │   ├── virtual/                   # Virtual sequences
│   │   │   └── CpmTopVirtualSeq.sv    # Top virtual sequence (8-step flow)
│   │   │
│   │   └── packet/                    # Leaf packet sequences
│   │       ├── CpmBaseTrafficSeq.sv   # Base random traffic sequence
│   │       ├── CpmStressSeq.sv        # Stress/burst sequence
│   │       ├── CpmDropSeq.sv          # Drop test sequence
│   │       └── CpmCoverageTrafficSeq.sv # All 16 opcodes for coverage
│   │
│   ├── tests/                         # Test classes
│   │   ├── CpmBaseTest.sv             # Base test class
│   │   ├── CpmMainTest.sv             # Main test (all mandatory features)
│   │   ├── CpmSmokeTest.sv            # Smoke test (quick verification)
│   │   └── CpmRalResetTest.sv         # RAL reset test
│   │
│   └── tb_top.sv                      # Top-level testbench module
│
├── scripts/                           # Simulation scripts
│   ├── Run/                           # QuestaSim run directory
│   │   ├── compile.do                 # Compile script
│   │   ├── elaborate.do               # Elaborate script
│   │   ├── run.py                     # Python test runner
│   │   └── transcript                 # Run transcript
│   │
│   ├── generate_coverage_report.py    # Modern HTML coverage generator
│   ├── extract_pdf_text.py            # PDF text extractor
│   ├── commands.md                    # Common command reference
│   ├── README.md                      # Scripts documentation
│   └── requirements.txt               # Python dependencies
│
├── gui/                               # GUI Application
│   └── test_runner.py                 # Premium Tkinter test runner GUI
│
├── logs/                              # Simulation outputs (generated)
│   ├── CpmMainTest.log
│   ├── CpmSmokeTest.log
│   ├── CpmRalResetTest.log
│   └── transcript                     # QuestaSim transcript
│
├── coverage/                          # Code coverage reports (generated)
│   ├── CpmMainTest.ucdb               # Raw coverage database
│   ├── CpmMainTest_coverage.txt       # Text coverage report
│   ├── merged.ucdb                    # Merged coverage database
│   ├── modern_report.html             # Beautiful modern coverage report
│   └── html/                          # QuestaSim HTML report
│       └── index.html
│
├── tracking/                          # Project tracking files
│   ├── test_plan.csv                  # Test plan spreadsheet
│   ├── bug_tracker.csv                # DUT/Spec bug tracking
│   ├── verification_bug_tracker.csv   # Testbench bug tracking
│   ├── coverage_tracking.csv          # Coverage tracking
│   └── CpmMainTest_analysis.csv       # Test analysis log
│
└── sim/                               # Simulation artifacts (generated)
    ├── work/                          # QuestaSim work library
    ├── test_lib/                      # QuestaSim test library
    └── vsim.wlf                       # Waveform file
```

## File Count Summary

| Category | Files |
|----------|-------|
| Packages | 2 |
| Transactions | 2 |
| Interfaces | 2 |
| Configurations | 3 |
| RAL Components | 3 |
| Drivers | 2 |
| Sequencers | 2 |
| Monitors | 2 |
| Coverage | 2 |
| Agents | 2 |
| Environment | 1 |
| Scoreboard/RefModel | 3 |
| Callbacks | 3 |
| Sequences | 5 |
| Tests | 4 |
| Testbench Top | 1 |
| **Total SV Files** | **39** |

## Key Folders

| Folder | Purpose |
|--------|---------|
| `docs/` | All documentation (markdown and HTML) |
| `deliverables/` | Final project deliverables (HTML, DOCX, PDF) |
| `verification/` | UVM testbench source code |
| `cpm_design/` | DUT RTL v1.1 (black box) |
| `scripts/` | Build and run scripts |
| `gui/` | Premium test runner GUI application |
| `logs/` | Simulation log files |
| `coverage/` | Coverage reports and UCDB files |
| `tracking/` | CSV tracking files |
| `sim/` | Generated simulation artifacts |
| `spec/` | Design and requirements specifications (v1.1) |

## Key Files

### Package Files
- `CpmTestPkg.sv` - Main package, includes all components in correct order
- `CpmParamsPkg.sv` - Defines `cpm_mode_e`, widths, addresses

### Virtual Interface Distribution
- Virtual interfaces are set directly in `uvm_config_db` from `tb_top.sv`
- Components retrieve interfaces via `config_db::get("stream_if")` or `config_db::get("reg_if")`
- Standard UVM approach - no wrapper class needed

### Coverage
- `CpmPacketCoverage.sv` - MODE (100%), OPCODE (100%), CROSS (100%), DROP, STALL
- `CpmRegCoverage.sv` - ADDR (100%), OP (100%), CROSS (75%)

### Tests
- `CpmMainTest.sv` - Demonstrates all mandatory features (500+ txns)
- `CpmSmokeTest.sv` - Quick 10-packet verification
- `CpmRalResetTest.sv` - Verifies all 8 register reset values

### GUI
- `gui/test_runner.py` - Premium test runner with real-time output, coverage reports, and theme support

### Deliverables
- `deliverables/Verification Plan/` - Verification plan (HTML, DOCX, PDF)
- `deliverables/Sign Off/` - Sign-off document (HTML, DOCX, PDF)
- `deliverables/Reflection Report/` - Reflection report (HTML, DOCX, PDF)

---

*Last Updated: 2026-02-07*
