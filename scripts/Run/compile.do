# QuestaSim Compile Script for CPM Verification
# Usage: vsim -c -do compile.do
# Note: Run this script from the scripts/Run directory
# It will change to project root (../../) before compiling

# Set working directory to project root
cd ../..

# Create work library in sim/ folder
vlib sim/work
vmap work sim/work

# Compile parameters package
vlog -sv -work work +incdir+verification/pkg verification/pkg/CpmParamsPkg.sv

# Compile interfaces
vlog -sv -work work +incdir+verification/interfaces verification/interfaces/CpmStreamIf.sv
vlog -sv -work work +incdir+verification/interfaces verification/interfaces/CpmRegIf.sv

# Compile DUT with CODE COVERAGE enabled
# +cover=bcesft enables: branch, condition, expression, statement, fsm, toggle
vlog -sv -work work +cover=bcesft +incdir+cpm_design cpm_design/cpm_rtl.sv

# Compile test package (includes all components)
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmTestPkg.sv

# Compile testbench top
vlog -sv -work work +incdir+verification verification/tb_top.sv

quit -force
