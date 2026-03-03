# QuestaSim Compile Script for CPM Verification
# Usage: vsim -c -do compile.do
# Note: Run this script from the scripts/Run directory
# It will change to project root (../../) before compiling

# Set working directory to project root
cd ../..

# Create work library in sim/ folder
vlib sim/work
vmap work sim/work

# Compile interfaces first (no package dependencies)
vlog -sv -work work +incdir+verification/interfaces verification/interfaces/CpmStreamIf.sv
vlog -sv -work work +incdir+verification/interfaces verification/interfaces/CpmRegIf.sv

# Compile DUT with CODE COVERAGE enabled
# +cover=bcesft enables: branch, condition, expression, statement, fsm, toggle
vlog -sv -work work +cover=bcesft +incdir+cpm_design cpm_design/cpm_rtl.sv

# Compile packages in dependency order
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmParamsPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmTransactionsPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmConfigPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmRalPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmPacketAgentPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmRegAgentPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmScoreboardPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmCoveragePkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmEnvPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmSequencesPkg.sv
vlog -sv -work work +incdir+verification/pkg +incdir+verification verification/pkg/CpmTestsPkg.sv

# Compile testbench top
vlog -sv -work work +incdir+verification verification/tb_top.sv

quit -force
