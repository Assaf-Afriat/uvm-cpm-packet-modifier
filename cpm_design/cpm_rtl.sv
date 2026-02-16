// ============================================================
// CPM (Configurable Packet Modifier)
// Spec alignment: CPM v1.0
// - Single-beat packets: id[3:0], opcode[3:0], payload[15:0]
// - Ready/valid in/out, strict ordering
// - Backpressure with depth-2 internal buffer
// - Deterministic mode-dependent latency: PASS=0, XOR=1, ADD=2, ROT=1
// - DROP behavior based on DROP_CFG
// - Counters: COUNT_IN, COUNT_OUT, DROPPED_COUNT
// - CTRL.ENABLE, CTRL.SOFT_RST (self-clearing)
// - STATUS.BUSY: pending accepted packets not yet output or dropped
// - Simple reg bus: req/gnt handshake, single-cycle grant
// ============================================================

module cpm (
  input  logic        clk,
  input  logic        rst,

  // Stream input
  input  logic        in_valid,
  output logic        in_ready,
  input  logic [3:0]  in_id,
  input  logic [3:0]  in_opcode,
  input  logic [15:0] in_payload,

  // Stream output
  output logic        out_valid,
  input  logic        out_ready,
  output logic [3:0]  out_id,
  output logic [3:0]  out_opcode,
  output logic [15:0] out_payload,

  // Register bus
  input  logic        req,
  output logic        gnt,
  input  logic        write_en,
  input  logic [7:0]  addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata
);

  // ----------------------------
  // Register addresses (byte)
  // ----------------------------
  localparam logic [7:0] ADDR_CTRL         = 8'h00;
  localparam logic [7:0] ADDR_MODE         = 8'h04;
  localparam logic [7:0] ADDR_PARAMS       = 8'h08;
  localparam logic [7:0] ADDR_DROP_CFG     = 8'h0C;
  localparam logic [7:0] ADDR_STATUS       = 8'h10;
  localparam logic [7:0] ADDR_COUNT_IN     = 8'h14;
  localparam logic [7:0] ADDR_COUNT_OUT    = 8'h18;
  localparam logic [7:0] ADDR_DROPPED_CNT  = 8'h1C;

  // ----------------------------
  // Control regs
  // ----------------------------
  logic        ctrl_enable;      // CTRL.ENABLE bit0
  logic        ctrl_soft_rst;    // CTRL.SOFT_RST bit1 (self-clearing)

  logic [1:0]  reg_mode;        // MODE[1:0]
  logic [15:0] reg_mask;        // PARAMS[15:0]
  logic [15:0] reg_add_const;   // PARAMS[31:16]

  logic        drop_en;          // DROP_CFG bit0
  logic [3:0]  drop_opcode;      // DROP_CFG[7:4]

  // Status / counters
  logic        status_busy;
  logic [31:0] count_in;
  logic [31:0] count_out;
  logic [31:0] dropped_count;

  // ----------------------------
  // Reg bus handshake
  // (protocol verification is out-of-scope; this is functional)
  // ----------------------------
  assign gnt = req; // single-cycle grant

  // Read mux (combinational)
  always_comb begin
    unique case (addr)
      ADDR_CTRL:        rdata = {30'b0, ctrl_soft_rst, ctrl_enable};
      ADDR_MODE:        rdata = {30'b0, reg_mode};
      ADDR_PARAMS:      rdata = {reg_add_const, reg_mask};
      ADDR_DROP_CFG:    rdata = {24'b0, drop_opcode, 3'b0, drop_en};
      ADDR_STATUS:      rdata = {31'b0, status_busy};
      ADDR_COUNT_IN:    rdata = count_in;
      ADDR_COUNT_OUT:   rdata = count_out;
      ADDR_DROPPED_CNT: rdata = dropped_count;
      default:          rdata = 32'h0;
    endcase
  end

  // Soft reset pulse detection from bus write
  logic soft_rst_pulse;

  // Synchronous register writes
  always_ff @(posedge clk) begin
    if (rst) begin
      ctrl_enable    <= 1'b0;
      ctrl_soft_rst  <= 1'b0;
      reg_mode       <= 2'b00;
      reg_mask       <= 16'h0000;
      reg_add_const  <= 16'h0000;
      drop_en        <= 1'b0;
      drop_opcode    <= 4'h0;
    end else begin
      // default: self-clear ctrl_soft_rst
      ctrl_soft_rst <= 1'b0;

      if (req && gnt && write_en) begin
        unique case (addr)
          ADDR_CTRL: begin
            ctrl_enable   <= wdata[0];
            if (wdata[1]) ctrl_soft_rst <= 1'b1; // becomes 1 for one cycle
          end
          ADDR_MODE: begin
            reg_mode <= wdata[1:0];
          end
          ADDR_PARAMS: begin
            reg_mask      <= wdata[15:0];
            reg_add_const <= wdata[31:16];
          end
          ADDR_DROP_CFG: begin
            drop_en     <= wdata[0];
            drop_opcode <= wdata[7:4];
          end
          default: /* RO / unused */ ;
        endcase
      end
    end
  end

  assign soft_rst_pulse = ctrl_soft_rst; // asserted for one cycle

  // ----------------------------
  // Internal buffer (depth 2)
  // Each entry stores:
  // - id/opcode/payload_out (already transformed)
  // - countdown latency until eligible for output (0..2)
  // ----------------------------
  typedef struct packed {
    logic        v;
    logic [3:0]  id;
    logic [3:0]  opcode;
    logic [15:0] payload;
    logic [1:0]  cd;     // countdown cycles remaining
  } slot_t;

  slot_t s0, s1;

  // Helper: fixed rotation amount for ROT mode
  // (Spec references ROT_AMT; not exposed in regs in v1.1. Keep constant.)
  localparam int ROT_AMT = 4;

  function automatic logic [15:0] rol16(input logic [15:0] x, input int sh);
    logic [15:0] y;
    begin
      y = (x << sh) | (x >> (16 - sh));
      return y;
    end
  endfunction

  // Compute transform + base latency from sampled config at accept time
  function automatic void compute_expected(
    input  logic [1:0]  mode,
    input  logic [15:0] mask,
    input  logic [15:0] addc,
    input  logic [15:0] inpay,
    output logic [15:0] outpay,
    output logic [1:0]  base_lat
  );
    begin
      unique case (mode)
        2'd0: begin // PASS
          outpay   = inpay;
          base_lat = 2'd0;
        end
        2'd1: begin // XOR
          outpay   = inpay ^ mask;
          base_lat = 2'd1;
        end
        2'd2: begin // ADD
          outpay   = inpay + addc;
          base_lat = 2'd2;
        end
        default: begin // ROT
          outpay   = rol16(inpay, ROT_AMT);
          base_lat = 2'd1;
        end
      endcase
    end
  endfunction

  // ----------------------------
  // Streaming control signals
  // ----------------------------
  wire buffer_full  = s0.v && s1.v;
  wire buffer_empty = !s0.v;

  // When disabled, do not accept or produce output
  // Also: do not present out_valid when disabled (flush behavior)
  assign in_ready  = ctrl_enable && !buffer_full;

  // Output valid only when enabled, slot0 valid, and countdown==0
  assign out_valid = ctrl_enable && s0.v && (s0.cd == 2'd0);

  assign out_id      = s0.id;
  assign out_opcode  = s0.opcode;
  assign out_payload = s0.payload;

  wire in_fire  = ctrl_enable && in_valid && in_ready;
  wire out_fire = out_valid && out_ready;

  // Busy definition per spec v1.1: accepted not yet output or dropped.
  // Since drop doesn't enter buffer, busy means buffer not empty.
  assign status_busy = ctrl_enable && (s0.v || s1.v);

  // ----------------------------
  // Main datapath/control sequential logic
  // ----------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      s0 <= '{default:'0};
      s1 <= '{default:'0};
      count_in      <= 32'd0;
      count_out     <= 32'd0;
      dropped_count <= 32'd0;
    end else begin
      // Soft reset: clear counters and internal state (and stay enabled/disabled as configured)
      if (soft_rst_pulse) begin
        s0 <= '{default:'0};
        s1 <= '{default:'0};
        count_in      <= 32'd0;
        count_out     <= 32'd0;
        dropped_count <= 32'd0;
      end

      // If disabled: flush pipeline to avoid output while disabled (implementation choice)
      if (!ctrl_enable) begin
        s0.v <= 1'b0;
        s1.v <= 1'b0;
      end else begin
        // 1) Countdown decrement each cycle for valid entries
        if (s0.v && s0.cd != 0) s0.cd <= s0.cd - 2'd1;
        if (s1.v && s1.cd != 0) s1.cd <= s1.cd - 2'd1;

        // 2) Output pop on out_fire (only possible when s0.cd==0)
        if (out_fire) begin
          // pop s0, shift s1->s0
          s0 <= s1;
          s1 <= '{default:'0};
        end

        // 3) Input accept (may happen same cycle as out_fire; shifting already handled)
        if (in_fire) begin
          count_in <= count_in + 32'd1;

          // Drop check at accept time
          if (drop_en && (in_opcode == drop_opcode)) begin
            dropped_count <= dropped_count + 32'd1;
            // no enqueue
          end else begin
            logic [15:0] tx_payload;
            logic [1:0]  tx_lat;
            compute_expected(reg_mode, reg_mask, reg_add_const, in_payload, tx_payload, tx_lat);

            // enqueue into first free slot (depth-2)
            if (!s0.v) begin
              s0.v       <= 1'b1;
              s0.id      <= in_id;
              s0.opcode  <= in_opcode;
              s0.payload <= tx_payload;
              s0.cd      <= tx_lat;
            end else if (!s1.v) begin
              s1.v       <= 1'b1;
              s1.id      <= in_id;
              s1.opcode  <= in_opcode;
              s1.payload <= tx_payload;
              s1.cd      <= tx_lat;
            end
            // else: should not happen because in_ready would be 0
          end
        end

        // 4) Count output on out_fire
        if (out_fire) begin
          count_out <= count_out + 32'd1;
        end
      end
    end
  end

endmodule
