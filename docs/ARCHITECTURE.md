# UVM Verification Architecture - CPM (Configurable Packet Modifier)

## Overview

This document describes the verification architecture for the CPM (Configurable Packet Modifier) design.

**Status**: Phase 11 Complete - All tests passing, coverage targets met ✅

## DUT Overview

**CPM** is a packet processing unit that:
- Processes packets via stream interface (valid/ready handshake)
- Modifies packet payloads based on 4 operation modes: PASS, XOR, ADD, ROT
- Implements packet drop mechanism based on opcode matching
- Maintains 2-slot pipeline buffer with configurable latency
- Provides register bus for configuration and statistics

## Operation Mode Latencies
- **PASS (0)**: Payload unchanged, latency 0 cycles
- **XOR (1)**: Payload XOR with mask, latency 1 cycle
- **ADD (2)**: Payload + constant, latency 2 cycles
- **ROT (3)**: Payload rotated left by 4 bits, latency 1 cycle

---

## Component Hierarchy (Containment)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              tb_top (Module)                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │  clk/rst    │  │ CpmStreamIf │  │  CpmRegIf    │  │    cpm (DUT)          │  │
│  │  generation │  │  stream_if  │  │   reg_if     │  │                       │  │
│  └─────────────┘  └─────────────┘  └──────────────┘  └───────────────────────┘  │
│                           │                │                    ▲               │
│                           └────────────────┴────────────────────┘               │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                           uvm_config_db                                 │    │
│  │              stream_if (virtual CpmStreamIf)                            │    │
│  │              reg_if    (virtual CpmRegIf)                               │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CpmBaseTest / CpmMainTest                               │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  CONTAINS:                                                                 │ │
│  │  • m_env           : CpmEnv                                                │ │
│  │  • m_env_cfg       : CpmEnvConfig                                          │ │
│  │  • m_virt_seq      : CpmTopVirtualSeq (started in run_phase)               │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               CpmEnv                                            │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  CONTAINS:                                                               │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐   │   │
│  │  │ m_packet_agent  │  │ m_reg_agent     │  │ m_scoreboard            │   │   │
│  │  │ CpmPacketAgent  │  │ CpmRegAgent     │  │ CpmScoreboard           │   │   │
│  │  └─────────────────┘  └─────────────────┘  │  • m_ref_model          │   │   │
│  │                                            │  • m_reg_model          │   │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  │  • m_export_input       │   │   │
│  │  │ m_packet_cov    │  │ m_reg_cov       │  │  • m_export_output      │   │   │
│  │  │CpmPacketCoverage│  │ CpmRegCoverage  │  └─────────────────────────┘   │   │
│  │  └─────────────────┘  └─────────────────┘                                │   │
│  │                                                                          │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐   │   │
│  │  │ m_ref_model     │  │ m_reg_model     │  │ m_reg_predictor         │   │   │
│  │  │ CpmRefModel     │  │ CpmRegModel     │  │ CpmRegPredictor         │   │   │
│  │  └─────────────────┘  │ (RAL)           │  └─────────────────────────┘   │   │
│  │                       └─────────────────┘                                │   │
│  │  ┌─────────────────┐                                                     │   │
│  │  │ m_reg_adapter   │                                                     │   │
│  │  │ CpmRegAdapter   │                                                     │   │
│  │  └─────────────────┘                                                     │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Agent Internal Structure

### CpmPacketAgent (Stream Interface)
```
┌─────────────────────────────────────────────────────────────┐
│                      CpmPacketAgent                         │
│  CONTAINS:                                                  │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ m_driver        │  │ m_sequencer     │                   │
│  │ CpmPacketDriver │  │CpmPacketSequencer│                  │
│  │  • m_vif        │  │  (uvm_sequencer) │                  │
│  │  • callbacks    │  └─────────────────┘                   │
│  └─────────────────┘           │                            │
│           │                    │                            │
│           └────────────────────┘ (seq_item_port connection) │
│                                                             │
│  ┌─────────────────────────────────────────────┐            │
│  │ m_monitor                                   │            │
│  │ CpmPacketMonitor                            │            │
│  │  • m_vif          : virtual CpmStreamIf     │            │
│  │  • m_reg_model    : CpmRegModel (for mode)  │            │
│  │  • m_ref_model    : CpmRefModel             │            │
│  │  • m_ap_input     : uvm_analysis_port       │            │
│  │  • m_ap_output    : uvm_analysis_port       │            │
│  │  • m_input_queue  : latency tracking        │            │
│  │  • callbacks      : CpmBaseMonitorCb        │            │
│  └─────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### CpmRegAgent (Register Interface)
```
┌─────────────────────────────────────────────────────────────┐
│                       CpmRegAgent                           │
│  CONTAINS:                                                  │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ m_driver        │  │ m_sequencer     │                   │
│  │ CpmRegDriver    │  │ CpmRegSequencer │                   │
│  │  • m_vif        │  │  (uvm_sequencer)│                   │
│  │  • callbacks    │  └─────────────────┘                   │
│  └─────────────────┘           │                            │
│           │                    │                            │
│           └────────────────────┘ (seq_item_port connection) │
│                                                             │
│  ┌─────────────────────────────────────────────┐            │
│  │ m_monitor                                   │            │
│  │ CpmRegMonitor                               │            │
│  │  • m_vif     : virtual CpmRegIf             │            │
│  │  • m_ap      : uvm_analysis_port            │            │
│  └─────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

---

## TLM Connections Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            TLM Connection Map                                │
└──────────────────────────────────────────────────────────────────────────────┘

  CpmPacketMonitor                                         CpmScoreboard
  ┌──────────────────┐                                   ┌──────────────────┐
  │                  │                                   │                  │
  │   m_ap_input  ●──┼───────────────────────────────────┼──► m_export_input│
  │                  │                                   │                  │
  │   m_ap_output ●──┼────────────────┬──────────────────┼──► m_export_output
  │                  │                │                  │     .analysis_   │
  └──────────────────┘                │                  │      export      │
                                      │                  └──────────────────┘
                                      │
                     ┌────────────────┘
                     │
                     ▼
              CpmPacketCoverage
              ┌──────────────────┐
              │  analysis_export │
              │  (uvm_subscriber)│
              │                  │
              │  cg_packet:      │
              │  • cp_mode       │
              │  • cp_opcode     │
              │  • cp_mode_opcode│
              │  • cp_drop       │
              │  • cp_stall      │
              └──────────────────┘


  CpmRegMonitor                        CpmRegPredictor           CpmRegCoverage
  ┌──────────────────┐               ┌──────────────────┐     ┌──────────────────┐
  │                  │               │                  │     │                  │
  │      m_ap     ●──┼───────────────┼──► bus_in        │     │  analysis_export │
  │                  │               │                  │     │  (uvm_subscriber)│
  │                  │               │  map ──► RAL     │     │                  │
  │                  │               │  adapter         │     │  cg_register:    │
  │                  │               └──────────────────┘     │  • cp_addr       │
  │                  │                                        │  • cp_op         │
  │      m_ap     ●──┼────────────────────────────────────────┼──► cp_addr_op    │
  │                  │                                        │                  │
  └──────────────────┘                                        └──────────────────┘


  CpmRefModel                          CpmScoreboard
  ┌──────────────────┐               ┌──────────────────┐
  │ (shared instance)│               │                  │
  │                  │  assigned     │  m_ref_model ────┼──► predict_output()
  │  predict_output()│◄──────────────┤                  │
  │                  │               │  m_reg_model ────┼──► counter checks
  │  m_reg_model ────┼──► RAL model  │                  │
  │  (reads mask,    │   (mirrored)  └──────────────────┘
  │   add_const,     │
  │   drop_en,       │  Reads config from RAL instead of
  │   drop_opcode)   │  stale internal state
  └──────────────────┘
```

---

## Virtual Interface Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Virtual Interface Distribution                         │
└─────────────────────────────────────────────────────────────────────────────┘

  tb_top.sv (initial block)
       │
       │  // Standard UVM approach - set each interface directly
       │  uvm_config_db#(virtual CpmStreamIf)::set(null, "*", "stream_if", stream_if);
       │  uvm_config_db#(virtual CpmRegIf)::set(null, "*", "reg_if", reg_if);
       ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                         uvm_config_db                                   │
  │  ┌─────────────────────────────┐  ┌─────────────────────────────┐       │
  │  │ "stream_if"                 │  │ "reg_if"                    │       │
  │  │ virtual CpmStreamIf         │  │ virtual CpmRegIf            │       │
  │  └─────────────────────────────┘  └─────────────────────────────┘       │
  └─────────────────────────────────────────────────────────────────────────┘
       │
       │  uvm_config_db#(virtual CpmStreamIf)::get(this, "", "stream_if", m_vif)
       │  uvm_config_db#(virtual CpmRegIf)::get(this, "", "reg_if", m_vif)
       ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Component.connect_phase() - Each component retrieves its VIF directly  │
  │    • CpmPacketDriver.m_vif     ◄── config_db::get("stream_if")          │
  │    • CpmPacketMonitor.m_vif    ◄── config_db::get("stream_if")          │
  │    • CpmRegDriver.m_vif        ◄── config_db::get("reg_if")             │
  │    • CpmRegMonitor.m_vif       ◄── config_db::get("reg_if")             │
  │    • CpmPacketCoverage.m_vif   ◄── config_db::get("stream_if")          │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## Sequence Execution Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Sequence Execution Flow                              │
└─────────────────────────────────────────────────────────────────────────────┘

  CpmMainTest.run_phase()
       │
       │  Create and start virtual sequence
       ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  CpmTopVirtualSeq.body()                                                │
  │                                                                         │
  │  1. do_reset()        ─► uvm_reg_hw_reset_seq on m_reg_seqr             │
  │         │                                                               │
  │  2. do_configure()    ─► CpmConfigSeq on m_reg_seqr                     │
  │         │                  (RAL writes: MODE, PARAMS, DROP_CFG)         │
  │         │                                                               │
  │  3. do_traffic()      ─► CpmBaseTrafficSeq on m_packet_seqr             │
  │         │                                                               │
  │  4. do_reconfigure()  ─► For each MODE (PASS, XOR, ADD, ROT):           │
  │         │                  • RAL write MODE                             │
  │         │                  • CpmCoverageTrafficSeq (all 16 opcodes)     │
  │         │                                                               │
  │  5. do_stress()       ─► CpmStressSeq on m_packet_seqr                  │
  │         │                                                               │
  │  6. do_drop()         ─► RAL configure drop + CpmDropSeq                │
  │         │                                                               │
  │  7. do_readback()     ─► RAL read counters, verify invariant            │
  │         │                  COUNT_IN == COUNT_OUT + DROPPED_COUNT        │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## RAL Integration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          RAL Component Connections                          │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────┐          ┌─────────────────┐
  │  CpmRegModel    │          │  CpmRegAdapter  │
  │  (uvm_reg_block)│          │(uvm_reg_adapter)│
  │                 │          │                 │
  │  • m_ctrl       │          │  reg2bus()      │ ◄── Converts RAL→CpmRegTxn
  │  • m_mode       │          │  bus2reg()      │ ◄── Converts CpmRegTxn→RAL
  │  • m_params     │          │                 │
  │  • m_drop_cfg   │          └────────┬────────┘
  │  • m_status     │                   │
  │  • m_count_in   │                   │
  │  • m_count_out  │                   ▼
  │  • m_dropped    │          ┌─────────────────┐
  │                 │          │CpmRegPredictor  │
  │  default_map────┼─────────►│(uvm_reg_predict)│
  │                 │          │                 │
  └─────────────────┘          │  bus_in  ◄──────┼── CpmRegMonitor.m_ap
                               │  map     ──────►│   (auto-updates mirrors)
                               │  adapter ──────►│
                               └─────────────────┘

  Usage in Sequences:
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  // RAL write (in CpmConfigSeq)                                         │
  │  m_reg_model.m_mode.m_mode.write(status, CPM_MODE_XOR);                 │
  │                                                                         │
  │  // RAL read                                                            │
  │  m_reg_model.m_count_in.m_count_in.read(status, count_val);             │
  │                                                                         │
  │  // RAL mirror (verify against DUT)                                     │
  │  m_reg_model.m_mode.m_mode.mirror(status, UVM_CHECK);                   │
  │                                                                         │
  │  // RAL get mirrored value (no bus access)                              │
  │  current_mode = m_reg_model.m_mode.m_mode.get_mirrored_value();         │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## Callback Integration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Callback Registration & Execution                   │
└─────────────────────────────────────────────────────────────────────────────┘

  Class Definition:
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  class CpmPacketDriver extends uvm_driver #(CpmPacketTxn);              │
  │      `uvm_register_cb(CpmPacketDriver, CpmBasePacketCb)                 │
  │      ...                                                                │
  │  endclass                                                               │
  └─────────────────────────────────────────────────────────────────────────┘

  Callback Execution (in run_phase):
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  virtual task drive_packet(CpmPacketTxn txn);                            │
  │      `uvm_do_callbacks(CpmPacketDriver, CpmBasePacketCb, pre_drive(txn)) │
  │      // ... drive packet to DUT ...                                      │
  │      `uvm_do_callbacks(CpmPacketDriver, CpmBasePacketCb, post_drive(txn))│
  │  endtask                                                                 │
  └──────────────────────────────────────────────────────────────────────────┘

  Available Callbacks:
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  CpmBasePacketCb    : pre_drive(), post_drive()                         │
  │  CpmBaseRegCb       : pre_drive(), post_drive()                         │
  │  CpmBaseMonitorCb   : pre_monitor_input(), post_monitor_input(),        │
  │                       pre_monitor_output(), post_monitor_output()       │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## Coverage Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Coverage Collection Flow                            │
└─────────────────────────────────────────────────────────────────────────────┘

  CpmPacketMonitor.m_ap_input
           │
           │  write(txn)
           ▼
  CpmPacketCoverage (uvm_subscriber)
           │
           │  write(CpmPacketTxn t)
           ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  // Get mode from transaction (captured at input acceptance)            │
  │  cpm_mode_e mode = t.m_mode_at_accept;                                  │
  │                                                                         │
  │  // Sample covergroup                                                   │
  │  cg_packet.sample(mode, t.m_opcode, drop_event, stall_event);           │
  └─────────────────────────────────────────────────────────────────────────┘

  Coverage Targets Achieved:
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Metric              │ Result    │ Target  │ Status                     │
  │──────────────────────┼───────────┼─────────┼────────────────────────────│
  │  MODE                │ 100.00%   │ 100%    │ ✅ MET                    │
  │  OPCODE              │ 100.00%   │ 90%     │ ✅ MET                    │
  │  MODE × OPCODE       │ 100.00%   │ 80%     │ ✅ MET                    │
  │  DROP bin            │ 50%       │ Hit once│ ✅ MET                    │
  │  STALL bin           │ 50%       │ Hit once│ ✅ MET                    │
  │  Register ADDR       │ 100%      │ 100%    │ ✅ MET                    │
  │  Register OP         │ 100%      │ 100%    │ ✅ MET                    │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## Register Map

| Address | Name         | Fields                       | Access |
|---------|--------------|------------------------------|--------|
| 0x00    | CTRL         | ENABLE[0], SOFT_RST[1]       | RW     |
| 0x04    | MODE         | MODE[1:0]                    | RW     |
| 0x08    | PARAMS       | MASK[15:0], ADD_CONST[31:16] | RW     |
| 0x0C    | DROP_CFG     | DROP_EN[0], DROP_OPCODE[7:4] | RW     |
| 0x10    | STATUS       | BUSY[0]                      | RO     |
| 0x14    | COUNT_IN     | COUNT[31:0]                  | RO     |
| 0x18    | COUNT_OUT    | COUNT[31:0]                  | RO     |
| 0x1C    | DROPPED_COUNT| COUNT[31:0]                  | RO     |

---

## Test Suite

| Test Name          | Purpose                                      | Status |
|--------------------|----------------------------------------------|--------|
| CpmSmokeTest       | Basic functionality, quick verification      | ✅ PASS |
| CpmMainTest        | Full feature: RAL, virtual seq, factory, CB  | ✅ PASS |
| CpmRalResetTest    | Verify all register reset values via RAL     | ✅ PASS |

---

## Key Design Decisions

1. **Direct Virtual Interface Distribution**: Virtual interfaces are set directly in `uvm_config_db` using standard UVM approach - each interface type is registered separately (`stream_if`, `reg_if`). Components retrieve their interfaces directly via `config_db::get()`.

2. **Mode Tracking via RAL Mirror**: Monitor reads mode from `m_reg_model.m_mode.m_mode.get_mirrored_value()` instead of relying on manual updates.

3. **Reference Model Reads from RAL**: The reference model (`CpmRefModel`) reads mask, add_const, drop_en, and drop_opcode from the RAL model's mirrored values to ensure accurate predictions.

4. **ID+OPCODE Packet Matching**: Scoreboard matches packets by ID+OPCODE combination to handle reordering caused by different mode latencies (PASS=0, XOR=1, ADD=2, ROT=1 cycles).

5. **Coverage Traffic Sequence**: `CpmCoverageTrafficSeq` explicitly generates all 16 opcodes to guarantee 100% cross coverage when run in each mode.

6. **Robust Reset Wait**: All drivers/monitors use clocked reset wait (`do @(posedge clk) while (rst);`) to ensure proper synchronization.

7. **SVA Drop Awareness**: The bounded liveness SVA assertion uses shadow registers to track DROP_CFG and automatically disables when packets are intentionally dropped.

---

2## Complete Hierarchy & Connection Map

This section documents every component and connection in the verification environment.

### Top-Level Instantiation (tb_top.sv)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    tb_top (Module)                                          │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                             │
│  CLOCK/RESET GENERATION                                                                     │
│  ├── clk        : logic, 100MHz (#5 toggle)                                                │
│  └── rst        : logic, active-high synchronous, deasserts after 10 cycles                │
│                                                                                             │
│  INTERFACES                                                                                 │
│  ├── stream_if  : CpmStreamIf(.clk(clk), .rst(rst))                                        │
│  │     ├── in_valid, in_ready, in_id[3:0], in_opcode[3:0], in_payload[15:0]                │
│  │     ├── out_valid, out_ready, out_id[3:0], out_opcode[3:0], out_payload[15:0]           │
│  │     ├── drop_en_shadow, drop_opcode_shadow[3:0]  (for SVA drop awareness)               │
│  │     └── SVA: p_input_stability, p_output_stability, p_bounded_liveness                  │
│  │                                                                                         │
│  └── reg_if     : CpmRegIf(.clk(clk), .rst(rst))                                           │
│        └── req, gnt, write_en, addr[7:0], wdata[31:0], rdata[31:0]                         │
│                                                                                             │
│  DUT INSTANTIATION                                                                          │
│  └── cpm dut                                                                               │
│        ├── .clk(clk), .rst(rst)                                                            │
│        ├── .in_valid(stream_if.in_valid)    ◄── driven by CpmPacketDriver                  │
│        ├── .in_ready(stream_if.in_ready)    ──► read by CpmPacketMonitor                   │
│        ├── .in_id(stream_if.in_id)          ◄── driven by CpmPacketDriver                  │
│        ├── .in_opcode(stream_if.in_opcode)  ◄── driven by CpmPacketDriver                  │
│        ├── .in_payload(stream_if.in_payload)◄── driven by CpmPacketDriver                  │
│        ├── .out_valid(stream_if.out_valid)  ──► read by CpmPacketMonitor                   │
│        ├── .out_ready(stream_if.out_ready)  ◄── driven by tb_top (backpressure sim)        │
│        ├── .out_id(stream_if.out_id)        ──► read by CpmPacketMonitor                   │
│        ├── .out_opcode(stream_if.out_opcode)──► read by CpmPacketMonitor                   │
│        ├── .out_payload(stream_if.out_payload)─► read by CpmPacketMonitor                  │
│        ├── .req(reg_if.req)                 ◄── driven by CpmRegDriver                     │
│        ├── .gnt(reg_if.gnt)                 ──► read by CpmRegMonitor                      │
│        ├── .write_en(reg_if.write_en)       ◄── driven by CpmRegDriver                     │
│        ├── .addr(reg_if.addr)               ◄── driven by CpmRegDriver                     │
│        ├── .wdata(reg_if.wdata)             ◄── driven by CpmRegDriver                     │
│        └── .rdata(reg_if.rdata)             ──► read by CpmRegMonitor                      │
│                                                                                             │
│  CONFIG_DB SETUP                                                                            │
│  └── uvm_config_db#(virtual CpmStreamIf)::set(null, "*", "stream_if", stream_if)           │
│  └── uvm_config_db#(virtual CpmRegIf)::set(null, "*", "reg_if", reg_if)                    │
│                                                                                             │
│  DROP SHADOW LOGIC (for SVA)                                                                │
│  └── always_ff: on write to ADDR_DROP_CFG (0x0C)                                           │
│        stream_if.drop_en_shadow     <= reg_if.wdata[0]                                     │
│        stream_if.drop_opcode_shadow <= reg_if.wdata[7:4]                                   │
│                                                                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

### UVM Component Hierarchy (Containment Tree)

```
uvm_test_top
└── CpmBaseTest / CpmMainTest / CpmSmokeTest / CpmRalResetTest
    │
    ├── m_env_cfg         : CpmEnvConfig (configuration object)
    │   ├── m_stream_cfg  : CpmStreamAgentConfig
    │   └── m_reg_cfg     : CpmRegAgentConfig
    │
    └── m_env             : CpmEnv
        │
        ├── m_packet_agent        : CpmPacketAgent
        │   ├── m_sequencer       : CpmPacketSequencer (uvm_sequencer#(CpmPacketTxn))
        │   ├── m_driver          : CpmPacketDriver (uvm_driver#(CpmPacketTxn))
        │   └── m_monitor         : CpmPacketMonitor (uvm_monitor)
        │
        ├── m_reg_agent           : CpmRegAgent
        │   ├── m_sequencer       : CpmRegSequencer (uvm_sequencer#(CpmRegTxn))
        │   ├── m_driver          : CpmRegDriver (uvm_driver#(CpmRegTxn))
        │   └── m_monitor         : CpmRegMonitor (uvm_monitor)
        │
        ├── m_scoreboard          : CpmScoreboard (uvm_scoreboard)
        │   └── m_export_output   : CpmScoreboardOutputImp (uvm_subscriber)
        │
        ├── m_ref_model           : CpmRefModel (uvm_component)
        │
        ├── m_packet_cov          : CpmPacketCoverage (uvm_subscriber#(CpmPacketTxn))
        │
        ├── m_reg_cov             : CpmRegCoverage (uvm_subscriber#(CpmRegTxn))
        │
        ├── m_reg_model           : CpmRegModel (uvm_reg_block)
        │   ├── m_ctrl            : CpmRegCtrl (uvm_reg)
        │   │   ├── m_enable      : uvm_reg_field [0:0]
        │   │   └── m_soft_rst    : uvm_reg_field [1:1]
        │   ├── m_mode            : CpmRegMode (uvm_reg)
        │   │   └── m_mode        : uvm_reg_field [1:0]
        │   ├── m_params          : CpmRegParams (uvm_reg)
        │   │   ├── m_mask        : uvm_reg_field [15:0]
        │   │   └── m_add_const   : uvm_reg_field [31:16]
        │   ├── m_drop_cfg        : CpmRegDropCfg (uvm_reg)
        │   │   ├── m_drop_en     : uvm_reg_field [0:0]
        │   │   └── m_drop_opcode : uvm_reg_field [7:4]
        │   ├── m_status          : CpmRegStatus (uvm_reg)
        │   │   └── m_busy        : uvm_reg_field [0:0]
        │   ├── m_count_in        : CpmRegCountIn (uvm_reg)
        │   │   └── m_count_in    : uvm_reg_field [31:0]
        │   ├── m_count_out       : CpmRegCountOut (uvm_reg)
        │   │   └── m_count_out   : uvm_reg_field [31:0]
        │   └── m_dropped_count   : CpmRegDroppedCount (uvm_reg)
        │       └── m_dropped_count : uvm_reg_field [31:0]
        │
        ├── m_reg_adapter         : CpmRegAdapter (uvm_reg_adapter)
        │
        └── m_reg_predictor       : CpmRegPredictor (uvm_reg_predictor#(CpmRegTxn))
```

### Complete Connection Table

#### Virtual Interface Connections

| Component | VIF Handle | Retrieved Via | Interface Type |
|-----------|------------|---------------|----------------|
| CpmPacketDriver | m_vif | `config_db::get(this, "", "stream_if", m_vif)` | virtual CpmStreamIf |
| CpmPacketMonitor | m_vif | `config_db::get(this, "", "stream_if", m_vif)` | virtual CpmStreamIf |
| CpmRegDriver | m_vif | `config_db::get(this, "", "reg_if", m_vif)` | virtual CpmRegIf |
| CpmRegMonitor | m_vif | `config_db::get(this, "", "reg_if", m_vif)` | virtual CpmRegIf |
| CpmPacketCoverage | m_vif | `config_db::get(this, "", "stream_if", m_vif)` | virtual CpmStreamIf |

#### TLM Analysis Port Connections

| Source | Port | Direction | Destination | Port/Export |
|--------|------|-----------|-------------|-------------|
| CpmPacketMonitor | m_ap_input | ──► | CpmScoreboard | m_export_input (uvm_analysis_imp) |
| CpmPacketMonitor | m_ap_input | ──► | CpmPacketCoverage | analysis_export |
| CpmPacketMonitor | m_ap_output | ──► | CpmScoreboardOutputImp | analysis_export |
| CpmRegMonitor | m_ap | ──► | CpmRegPredictor | bus_in |
| CpmRegMonitor | m_ap | ──► | CpmRegCoverage | analysis_export |

#### Sequencer-Driver Connections

| Agent | Sequencer | Connection | Driver |
|-------|-----------|------------|--------|
| CpmPacketAgent | m_sequencer.seq_item_export | ◄── | m_driver.seq_item_port |
| CpmRegAgent | m_sequencer.seq_item_export | ◄── | m_driver.seq_item_port |

#### RAL Connections

| Source | Handle/Method | Direction | Destination | Handle |
|--------|---------------|-----------|-------------|--------|
| CpmEnv | m_reg_model.default_map.set_sequencer() | ──► | CpmRegAgent | m_sequencer |
| CpmEnv | m_reg_model.default_map.set_sequencer() | ──► | CpmRegAdapter | (adapter arg) |
| CpmEnv | m_reg_predictor.map | ◄── | CpmRegModel | default_map |
| CpmEnv | m_reg_predictor.adapter | ◄── | CpmRegAdapter | (instance) |
| CpmEnv | m_scoreboard.m_reg_model | ◄── | CpmRegModel | (instance) |
| CpmEnv | m_ref_model.m_reg_model | ◄── | CpmRegModel | (instance) |
| CpmEnv | m_packet_agent.m_monitor.m_reg_model | ◄── | CpmRegModel | (instance) |

#### Reference Model Connections

| Source | Handle | Direction | Destination | Handle |
|--------|--------|-----------|-------------|--------|
| CpmEnv | m_scoreboard.m_ref_model | ◄── | CpmRefModel | (instance) |
| CpmEnv | m_packet_agent.m_monitor.m_ref_model | ◄── | CpmRefModel | (instance) |

#### Virtual Sequence Connections (set in test run_phase)

| Virtual Sequence | Handle | Direction | Connected To |
|------------------|--------|-----------|--------------|
| CpmTopVirtualSeq | m_packet_seqr | ◄── | m_env.m_packet_agent.m_sequencer |
| CpmTopVirtualSeq | m_reg_seqr | ◄── | m_env.m_reg_agent.m_sequencer |
| CpmTopVirtualSeq | m_reg_model | ◄── | m_env.m_reg_model |
| CpmTopVirtualSeq | m_scoreboard | ◄── | m_env.m_scoreboard |

#### Callback Registrations

| Component | Callback Base Class | Macro | Concrete Callback | Registered In |
|-----------|---------------------|-------|-------------------|---------------|
| CpmPacketDriver | CpmBasePacketCb | `uvm_register_cb` | CpmPacketStatsCb | CpmMainTest.connect_phase |
| CpmRegDriver | CpmBaseRegCb | `uvm_register_cb` | (none currently) | - |
| CpmPacketMonitor | CpmBaseMonitorCb | `uvm_register_cb` | (none currently) | - |

### Data Flow Diagram

```
                                    ┌─────────────────────────────────────┐
                                    │           CpmTopVirtualSeq          │
                                    │  ┌─────────────────────────────────┐│
                                    │  │ 1. do_reset()                   ││
                                    │  │ 2. do_configure()               ││
                                    │  │ 3. do_traffic()                 ││
                                    │  │ 4. do_reconfigure()             ││
                                    │  │ 5. do_stress()                  ││
                                    │  │ 6. do_drop()                    ││
                                    │  │ 7. do_readback()                ││
                                    │  │ 8. check_counter_invariant()    ││
                                    │  └─────────────────────────────────┘│
                                    └───────────────┬─────────────────────┘
                                                    │ starts sequences on
                          ┌─────────────────────────┼─────────────────────────┐
                          │                         │                         │
                          ▼                         ▼                         │
              ┌───────────────────┐     ┌───────────────────┐                 │
              │ CpmPacketSequencer│     │ CpmRegSequencer   │                 │
              │                   │     │                   │                 │
              │ Sequences:        │     │ Sequences:        │                 │
              │ • CpmBaseTrafficSeq│    │ • CpmConfigSeq    │                 │
              │ • CpmStressSeq    │     │ • uvm_reg_hw_reset│                 │
              │ • CpmDropSeq      │     │                   │                 │
              │ • CpmCoverageSeq  │     └─────────┬─────────┘                 │
              └─────────┬─────────┘               │                           │
                        │                         │                           │
                        │ seq_item_port           │ seq_item_port             │
                        ▼                         ▼                           │
              ┌───────────────────┐     ┌───────────────────┐                 │
              │ CpmPacketDriver   │     │ CpmRegDriver      │                 │
              │                   │     │                   │                 │
              │ Callbacks:        │     │ Callbacks:        │                 │
              │ • pre_drive()     │     │ • pre_drive()     │                 │
              │ • post_drive()    │     │ • post_drive()    │                 │
              │                   │     │                   │                 │
              │ Drives: in_valid, │     │ Drives: req,      │                 │
              │ in_id, in_opcode, │     │ write_en, addr,   │                 │
              │ in_payload        │     │ wdata             │                 │
              └─────────┬─────────┘     └─────────┬─────────┘                 │
                        │                         │                           │
                        │ via m_vif               │ via m_vif                 │
                        ▼                         ▼                           │
┌─────────────────────────────────────────────────────────────────────────────┴───┐
│                                    DUT (cpm)                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │ Registers:                      │ Pipeline:                                 │ │
│  │ • CTRL (0x00)                   │ • s0 (slot 0) - output candidate          │ │
│  │ • MODE (0x04)                   │ • s1 (slot 1) - waiting                   │ │
│  │ • PARAMS (0x08)                 │                                           │ │
│  │ • DROP_CFG (0x0C)               │ Transform Functions:                      │ │
│  │ • STATUS (0x10)                 │ • PASS: payload_out = payload_in          │ │
│  │ • COUNT_IN (0x14)               │ • XOR:  payload_out = payload_in ^ MASK   │ │
│  │ • COUNT_OUT (0x18)              │ • ADD:  payload_out = payload_in + CONST  │ │
│  │ • DROPPED_COUNT (0x1C)          │ • ROT:  payload_out = rol16(payload_in,4) │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
                        │                         │
                        │ via m_vif               │ via m_vif
                        ▼                         ▼
              ┌───────────────────┐     ┌───────────────────┐
              │ CpmPacketMonitor  │     │ CpmRegMonitor     │
              │                   │     │                   │
              │ Monitors:         │     │ Monitors:         │
              │ • in_fire         │     │ • req & gnt       │
              │ • out_fire        │     │ • addr, wdata     │
              │                   │     │ • rdata           │
              │ Sets in txn:      │     │                   │
              │ • m_mode_at_accept│     │ Creates CpmRegTxn │
              │ • m_mask_at_accept│     │ • m_addr          │
              │ • m_add_const_at_ │     │ • m_wdata/m_rdata │
              │   accept          │     │ • m_write_en      │
              │                   │     │                   │
              │ Analysis Ports:   │     │ Analysis Port:    │
              │ • m_ap_input ─────┼──┐  │ • m_ap ───────────┼──┬──────────┐
              │ • m_ap_output ────┼──┼──│───────────────────│──│──────────│──┐
              └───────────────────┘  │  └───────────────────┘  │          │  │
                                     │                         │          │  │
           ┌─────────────────────────┘                         │          │  │
           │                                                   │          │  │
           │  ┌────────────────────────────────────────────────┘          │  │
           │  │                                                           │  │
           ▼  ▼                                                           │  │
  ┌────────────────────┐                                                  │  │
  │ CpmPacketCoverage  │                                                  │  │
  │                    │                                                  │  │
  │ Covergroups:       │                                                  │  │
  │ • cg_packet        │                                                  │  │
  │   - cp_mode        │                                                  │  │
  │   - cp_opcode      │                                                  │  │
  │   - cp_mode_opcode │                                                  │  │
  │   - cp_drop        │                                                  │  │
  │   - cp_stall       │                                                  │  │
  └────────────────────┘                                                  │  │
                                                                          │  │
           ┌──────────────────────────────────────────────────────────────┘  │
           │                                                                 │
           ▼                                                                 │
  ┌────────────────────┐     ┌────────────────────┐                          │
  │ CpmRegPredictor    │     │ CpmRegCoverage     │◄─────────────────────────┘
  │                    │     │                    │
  │ • bus_in ◄── m_ap  │     │ Covergroups:       │
  │ • map ──► RAL      │     │ • cg_register      │
  │ • adapter          │     │   - cp_addr        │
  │                    │     │   - cp_op          │
  │ Auto-updates RAL   │     │   - cp_addr_op     │
  │ mirrored values    │     │                    │
  └─────────┬──────────┘     └────────────────────┘
            │
            │ updates
            ▼
  ┌────────────────────────────────────────────────────────────────────────────┐
  │                              CpmRegModel (RAL)                              │
  │                                                                            │
  │  ┌──────────┬──────────┬──────────┬──────────┬──────────┬────────────────┐ │
  │  │ m_ctrl   │ m_mode   │ m_params │m_drop_cfg│ m_status │ m_count_*      │ │
  │  │ ENABLE   │ MODE[1:0]│ MASK     │ DROP_EN  │ BUSY     │ COUNT_IN       │ │
  │  │ SOFT_RST │          │ ADD_CONST│DROP_OPCODE         │ COUNT_OUT      │ │
  │  │          │          │          │          │          │ DROPPED_COUNT  │ │
  │  └──────────┴──────────┴──────────┴──────────┴──────────┴────────────────┘ │
  │                                                                            │
  │  default_map.set_sequencer(m_reg_agent.m_sequencer, m_reg_adapter)         │
  └────────────────────────────────────────────────────────────────────────────┘
            │
            │ provides mirrored values to
            ▼
  ┌────────────────────┐                              ┌────────────────────────┐
  │ CpmRefModel        │──────────────────────────────│ CpmScoreboard          │
  │                    │        m_ref_model           │                        │
  │ • predict_output() │◄─────────────────────────────│ • m_export_input       │
  │   - Uses m_mode_at │                              │   (input packets)      │
  │     accept from txn│                              │ • m_export_output      │
  │   - Uses m_mask_at │                              │   (output packets)     │
  │     accept from txn│                              │                        │
  │   - Uses m_add_    │                              │ • m_expected_queue[]   │
  │     const_at_accept│                              │ • compare_packets()    │
  │     from txn       │                              │ • report_mismatch()    │
  │                    │        m_reg_model           │                        │
  │ • m_reg_model ─────┼──────────────────────────────│ • check_counter_       │
  │   (for drop_en,    │                              │   invariant()          │
  │    drop_opcode)    │                              │                        │
  └────────────────────┘                              └────────────────────────┘
```

### Sequence Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Sequence Relationships                               │
└─────────────────────────────────────────────────────────────────────────────┘

  CpmTopVirtualSeq (orchestrates all)
  │
  ├── Runs on m_reg_seqr (CpmRegSequencer):
  │   │
  │   ├── uvm_reg_hw_reset_seq     (RAL built-in reset sequence)
  │   │
  │   └── CpmConfigSeq             (custom RAL config sequence)
  │       ├── Writes: m_ctrl.m_enable
  │       ├── Writes: m_mode.m_mode
  │       ├── Writes: m_params.m_mask
  │       ├── Writes: m_params.m_add_const
  │       └── Writes: m_drop_cfg.m_drop_en, m_drop_cfg.m_drop_opcode
  │
  └── Runs on m_packet_seqr (CpmPacketSequencer):
      │
      ├── CpmBaseTrafficSeq        (random constrained packets)
      │   └── Creates: CpmPacketTxn with random m_id, m_opcode, m_payload
      │
      ├── CpmStressSeq             (burst traffic with backpressure)
      │   ├── m_num_packets = 1000
      │   ├── m_burst_size = 10
      │   └── Creates bursts of CpmPacketTxn
      │
      ├── CpmDropSeq               (targeted drop testing)
      │   ├── m_drop_opcode = configured opcode
      │   └── Creates: CpmPacketTxn with specific opcode
      │
      └── CpmCoverageTrafficSeq    (coverage-directed)
          └── Creates: CpmPacketTxn with all 16 opcodes sequentially
```

### Transaction Fields

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CpmPacketTxn Fields                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ RANDOMIZED FIELDS:                                                          │
│   • m_id              : rand bit [3:0]    - Packet identifier               │
│   • m_opcode          : rand bit [3:0]    - Operation code                  │
│   • m_payload         : rand bit [15:0]   - Data payload                    │
│                                                                             │
│ METADATA FIELDS (set by monitor/scoreboard):                                │
│   • m_timestamp           : time          - Acceptance timestamp            │
│   • m_expected_payload    : bit [15:0]    - Scoreboard expected result      │
│   • m_mode_at_accept      : cpm_mode_e    - MODE at input acceptance        │
│   • m_mask_at_accept      : bit [15:0]    - MASK at input acceptance        │
│   • m_add_const_at_accept : bit [15:0]    - ADD_CONST at input acceptance   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                            CpmRegTxn Fields                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ RANDOMIZED FIELDS:                                                          │
│   • m_addr            : rand bit [7:0]    - Register address                │
│   • m_wdata           : rand bit [31:0]   - Write data                      │
│   • m_write_en        : rand bit          - Write enable (1=write, 0=read)  │
│                                                                             │
│ RESPONSE FIELDS (set by monitor):                                           │
│   • m_rdata           : bit [31:0]        - Read data                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

*Last Updated: 2026-02-07*
