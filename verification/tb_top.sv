/**
 * @file tb_top.sv
 * @brief CPM Testbench Top Module
 * 
 * Top-level testbench module.
 * Instantiates DUT, interfaces, and connects to UVM environment.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

`timescale 1ns/1ps

// Include UVM macros
`include "uvm_macros.svh"

// Import UVM package and CPM test package
import uvm_pkg::*;
import CpmTestPkg::*;

module tb_top;

    // ============================================================================
    // Clock and Reset
    // ============================================================================
    logic clk;
    logic rst;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Reset generation
    initial begin
        rst = 1;  // Active-high synchronous reset
        repeat(10) @(posedge clk);
        rst = 0;
        `uvm_info("TB_TOP", "[TB_TOP] Reset deasserted at time %0t", UVM_MEDIUM);
    end

    // ============================================================================
    // Interfaces
    // ============================================================================
    CpmStreamIf stream_if(.clk(clk), .rst(rst));
    CpmRegIf    reg_if(.clk(clk), .rst(rst));
    
    // ============================================================================
    // Drop Configuration Shadow for SVA
    // Observe register bus writes to DROP_CFG (0x0C) and update stream_if shadow
    // This allows the SVA to know when packets will be dropped
    // ============================================================================
    localparam logic [7:0] ADDR_DROP_CFG = 8'h0C;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            stream_if.drop_en_shadow <= 1'b0;
            stream_if.drop_opcode_shadow <= 4'h0;
        end else if (reg_if.req && reg_if.gnt && reg_if.write_en && reg_if.addr == ADDR_DROP_CFG) begin
            // Capture DROP_CFG write: bit[0] = drop_en, bits[7:4] = drop_opcode
            stream_if.drop_en_shadow <= reg_if.wdata[0];
            stream_if.drop_opcode_shadow <= reg_if.wdata[7:4];
        end
    end

    // ============================================================================
    // Default Signal Drivers
    // out_ready must be driven (DUT output backpressure)
    // ============================================================================
    initial begin
        stream_if.out_ready = 1'b1;  // Initially ready
        stream_if.in_valid = 1'b0;   // No input initially
        stream_if.in_id = 4'h0;
        stream_if.in_opcode = 4'h0;
        stream_if.in_payload = 16'h0;
        reg_if.req = 1'b0;
        reg_if.write_en = 1'b0;
        reg_if.addr = 8'h0;
        reg_if.wdata = 32'h0;
    end
    
    // ============================================================================
    // Backpressure Simulation
    // Randomly deassert out_ready to test DUT backpressure handling
    // This improves code coverage by exercising the stall paths
    // ============================================================================
    initial begin
        int backpressure_cycles;
        // Wait for reset to complete
        @(negedge rst);
        repeat(5) @(posedge clk);
        
        // Randomly toggle out_ready to create backpressure
        forever begin
            // Stay ready for random number of cycles (10-50)
            backpressure_cycles = $urandom_range(10, 50);
            repeat(backpressure_cycles) @(posedge clk);
            
            // Create backpressure for random number of cycles (1-5)
            backpressure_cycles = $urandom_range(1, 5);
            stream_if.out_ready = 1'b0;
            repeat(backpressure_cycles) @(posedge clk);
            stream_if.out_ready = 1'b1;
        end
    end

    // ============================================================================
    // DUT Instantiation
    // ============================================================================
    cpm dut (
        .clk(clk),
        .rst(rst),
        // Stream input
        .in_valid(stream_if.in_valid),
        .in_ready(stream_if.in_ready),
        .in_id(stream_if.in_id),
        .in_opcode(stream_if.in_opcode),
        .in_payload(stream_if.in_payload),
        // Stream output
        .out_valid(stream_if.out_valid),
        .out_ready(stream_if.out_ready),
        .out_id(stream_if.out_id),
        .out_opcode(stream_if.out_opcode),
        .out_payload(stream_if.out_payload),
        // Register bus
        .req(reg_if.req),
        .gnt(reg_if.gnt),
        .write_en(reg_if.write_en),
        .addr(reg_if.addr),
        .wdata(reg_if.wdata),
        .rdata(reg_if.rdata)
    );


    // ============================================================================
    // UVM Test
    // ============================================================================
    initial begin
        `uvm_info("TB_TOP", "[TB_TOP] Starting UVM testbench at time %0t", UVM_MEDIUM);
        
        // Set the interfaces in the config_db
        uvm_config_db#(virtual CpmStreamIf)::set(null, "*", "stream_if", stream_if);
        uvm_config_db#(virtual CpmRegIf)::set(null, "*", "reg_if", reg_if);
        
        `uvm_info("TB_TOP", "[TB_TOP] About to call run_test() at time %0t", UVM_MEDIUM);
        
        // Run test (UVM will handle timing)
        run_test();
        
        `uvm_info("TB_TOP", "[TB_TOP] run_test() returned at time %0t", UVM_MEDIUM);
        #100;
        $finish;
    end

endmodule : tb_top
