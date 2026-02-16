/**
 * @file CpmBaseRegCb.sv
 * @brief CPM Base Register Callback
 * 
 * Base callback class for register driver.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmBaseRegCb extends uvm_callback;

    `uvm_object_utils(CpmBaseRegCb)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmBaseRegCb");
        super.new(name);
    endfunction

    // ============================================================================
    // Callback Methods
    // ============================================================================
    virtual task pre_drive(CpmRegDriver driver, CpmRegTxn txn);
        // Override in derived classes
    endtask

    virtual task post_drive(CpmRegDriver driver, CpmRegTxn txn);
        // Override in derived classes
    endtask

endclass : CpmBaseRegCb
