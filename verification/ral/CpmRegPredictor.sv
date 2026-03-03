/**
 * @file CpmRegPredictor.sv
 * @brief CPM RAL Predictor
 * 
 * RAL predictor for automatic register model updates.
 * MANDATORY: uvm_reg_predictor for automatic prediction.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmRegPredictor extends uvm_reg_predictor #(CpmRegTxn);

    `uvm_component_utils(CpmRegPredictor)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmRegPredictor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ============================================================================
    // write
    // Called when monitor observes a register transaction
    // The base class uvm_reg_predictor::write() handles the conversion
    // using the adapter and calls predict() internally
    // ============================================================================
    virtual function void write(CpmRegTxn tr);
        // Base class write() will:
        // 1. Call adapter.bus2reg(tr, rw) to convert transaction
        // 2. Call predict(rw) to update the register model
        // We just need to ensure adapter is set (checked in base class)
        super.write(tr);
    endfunction

endclass : CpmRegPredictor
