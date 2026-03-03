# Elaborate the top module
# Set working directory to project root
cd ../..

# Elaborate the top module with CODE COVERAGE enabled
# +cover=bcesft enables: branch, condition, expression, statement, fsm, toggle
vopt +acc=npr +cover=bcesft -o tb_top_opt work.tb_top
quit -force
