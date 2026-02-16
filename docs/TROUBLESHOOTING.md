# CPM Verification Troubleshooting Guide

**Project**: Configurable Packet Modifier (CPM) Verification  
**Author**: Assaf Afriat  
**Date**: 2026-02-01

---

## Quick Fixes

| Problem | Solution |
|---------|----------|
| Test hangs | Add `--timeout 60` to command |
| Coverage is 0% | Recompile with `--coverage-report` |
| "Unexpected EOF on RPC channel" | Kill stuck vsim processes |
| Scoreboard mismatches | Check log for details |

---

## Common Issues

### 1. Test Hangs (No Progress)

**Symptoms:**
- Simulation runs indefinitely
- No UVM messages appearing
- CPU at 100%

**Causes & Solutions:**

#### Cause A: Missing `out_ready` signal
```systemverilog
// In tb_top.sv, ensure out_ready is driven
initial begin
    stream_if.out_ready = 1'b1;  // ADD THIS
end
```

#### Cause B: Infinite loop in sequence
Check your sequences don't have `forever` loops without clock edges:
```systemverilog
// BAD - will hang
forever begin
    // no @(posedge clk)
end

// GOOD - advances time
forever begin
    @(posedge m_vif.clk);
    // do work
end
```

#### Cause C: Reset never deasserts
Check `tb_top.sv` reset generation:
```systemverilog
// Ensure reset deasserts
initial begin
    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;  // MUST deassert
end
```

---

### 2. "Unexpected EOF on RPC channel"

**Symptoms:**
- Simulation crashes immediately
- QuestaSim shows RPC error
- No useful error message

**Causes & Solutions:**

#### Cause A: Stuck vsim processes
```powershell
# Kill all vsim processes
Get-Process | Where-Object {$_.ProcessName -like "*vsim*"} | Stop-Process -Force

# Or on Linux/Mac
pkill vsim
```

#### Cause B: License contention
- Close other QuestaSim instances
- Check license availability
- Wait and retry

#### Cause C: Zero-delay loop
```systemverilog
// BAD - zero delay loop
always clk = ~clk;

// GOOD - has delay
always #5 clk = ~clk;
```

#### Cause D: Null pointer access
Check that virtual interfaces are set before use:
```systemverilog
if (m_vif == null) begin
    `uvm_fatal("NO_VIF", "Virtual interface not set")
end
```

---

### 3. Scoreboard Mismatches

**Symptoms:**
- "Packet mismatch" errors
- Expected vs Actual differ

**Diagnostic Steps:**

1. **Check log for mismatch details:**
```
UVM_ERROR: Packet mismatch at ID=5
  Expected: payload=0x1234
  Actual:   payload=0x5678
```

2. **Verify mode_at_accept:**
The reference model uses the mode sampled when the packet was accepted, not current mode.

3. **Check packet ordering:**
Packets with different modes have different latencies (0-2 cycles). The scoreboard matches by ID+OPCODE.

4. **Verify reference model:**
```systemverilog
// In CpmRefModel.sv
case (mode)
    CPM_MODE_PASS: result = payload;
    CPM_MODE_XOR:  result = payload ^ mask;
    CPM_MODE_ADD:  result = payload + add_const;
    CPM_MODE_ROT:  result = {payload[11:0], payload[15:12]};
endcase
```

---

### 4. Coverage is 0%

**Symptoms:**
- Coverage report shows 0% for all metrics
- UCDB file is empty or missing

**Solutions:**

#### Check compile.do has coverage flags:
```tcl
vlog -sv -work work -coverage verification/pkg/CpmTestPkg.sv
```

#### Check elaborate.do has coverage flags:
```tcl
vopt -coverage +acc=npr -o tb_top_opt work.tb_top
```

#### Run with coverage save:
```bash
python scripts/Run/run.py --test CpmMainTest --coverage-report
```

#### Verify UCDB exists:
```powershell
ls coverage/*.ucdb
```

---

### 5. Compilation Errors

**Symptoms:**
- `vlog` fails with syntax errors
- "Undefined variable" errors

**Common Fixes:**

#### Missing package import:
```systemverilog
import uvm_pkg::*;
import CpmTestPkg::*;
```

#### Wrong include order in CpmTestPkg.sv:
```systemverilog
// Order matters! Include dependencies first
`include "transactions/CpmPacketTxn.sv"  // Before driver
`include "driver/CpmPacketDriver.sv"      // Uses transaction
```

#### Forward declaration needed:
```systemverilog
typedef class CpmPacketDriver;  // Forward declare
```

---

### 6. RAL Errors

**Symptoms:**
- "Register not found" errors
- RAL read/write fails

**Solutions:**

#### Ensure RAL model is built:
```systemverilog
// In CpmEnv.sv build_phase
m_reg_model = CpmRegModel::type_id::create("m_reg_model", this);
m_reg_model.build();  // MANDATORY
```

#### Check register addresses match DUT:
```systemverilog
// In CpmRegModel.sv
m_ctrl.configure(this, null, "CTRL");
default_map.add_reg(m_ctrl, 'h00);  // Address 0x00
```

---

### 7. Virtual Interface Not Found

**Symptoms:**
- `UVM_FATAL: Virtual interface not found`
- Null pointer crashes

**Solutions:**

#### Check tb_top.sv sets interface correctly:
```systemverilog
initial begin
    CpmVifConfig vif_cfg = CpmVifConfig::type_id::create("vif_cfg");
    vif_cfg.stream_vif = stream_if;
    vif_cfg.reg_vif = reg_if;
    uvm_config_db#(CpmVifConfig)::set(null, "*", "vif_cfg", vif_cfg);
end
```

#### Check component retrieves interface in connect_phase:
```systemverilog
function void connect_phase(uvm_phase phase);
    CpmVifConfig vif_cfg;
    if (!uvm_config_db#(CpmVifConfig)::get(this, "", "vif_cfg", vif_cfg)) begin
        `uvm_fatal("NO_VIF_CFG", "CpmVifConfig not found")
    end
    m_vif = vif_cfg.stream_vif;
endfunction
```

---

### 8. Assertion Failures

**Symptoms:**
- SVA assertion failures
- "Property violated" messages

**Common Issues:**

#### Input stability violation:
The DUT is seeing inputs change during stall. Check driver:
```systemverilog
// Inputs must remain stable when valid && !ready
// Driver should not change signals until handshake completes
```

#### Bounded liveness failure:
Packet didn't appear within expected latency. Check:
- Mode latency (PASS=0, XOR=1, ADD=2, ROT=1)
- Backpressure on output
- Drop condition

---

## Diagnostic Commands

### Check Running Processes

```powershell
# Windows
Get-Process | Where-Object {$_.ProcessName -like "*vsim*"}

# Linux/Mac
ps aux | grep vsim
```

### Kill Stuck Processes

```powershell
# Windows
taskkill /F /IM vsim.exe

# Linux/Mac
pkill -9 vsim
```

### View Log Files

```powershell
# Windows
Get-Content logs/CpmSmokeTest.log -Tail 100

# Linux/Mac
tail -100 logs/CpmSmokeTest.log
```

### Check Coverage

```bash
vcover report -summary coverage/merged.ucdb
```

### Generate Coverage Report

```bash
python scripts/generate_coverage_report.py
```

---

## Debug Mode

### Enable UVM Debug Verbosity

In `run.py`, the command already includes:
```
+UVM_VERBOSITY=UVM_DEBUG
```

For even more detail, add to vsim command:
```
+UVM_PHASE_TRACE
+UVM_CONFIG_DB_TRACE
```

### Factory Debug

Add in test's build_phase:
```systemverilog
factory.print();
```

### Config DB Debug

```systemverilog
uvm_config_db#(int)::dump();
```

---

## Contact & Support

If issues persist:
1. Check all log files in `logs/` directory
2. Review QuestaSim transcript
3. Verify DUT RTL matches specification
4. Check for recent code changes

---

**Document End**
