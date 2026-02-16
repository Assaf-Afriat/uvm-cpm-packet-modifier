/**
 * @file CpmBaseMonitorCb.sv
 * @brief CPM Base Monitor Callback
 * 
 * Base callback class for packet monitor.
 * 
 * @author Assaf Afriat
 * @date 2026-01-31
 */

class CpmBaseMonitorCb extends uvm_callback;

    `uvm_object_utils(CpmBaseMonitorCb)

    // ============================================================================
    // Constructor
    // ============================================================================
    function new(string name = "CpmBaseMonitorCb");
        super.new(name);
    endfunction

    // ============================================================================
    // Monitor Callback Methods
    // ============================================================================
    virtual task pre_monitor_input();
        // Override in derived classes
    endtask

    virtual task post_monitor_input(CpmPacketTxn txn);
        // Override in derived classes
    endtask

    virtual task pre_monitor_output();
        // Override in derived classes
    endtask

    virtual task post_monitor_output(CpmPacketTxn txn);
        // Override in derived classes
    endtask

endclass : CpmBaseMonitorCb
