import os
import sys
import argparse
import signal
import time
from pathlib import Path

# --- Constants for Compilation/Elaboration ---
CMD_COMPILE = "vsim -c -do compile.do"
CMD_ELABORATE = "vsim -c -do elaborate.do"

def run_command(command, step_name, cwd=None):
    """Runs a shell command and exits if it fails."""
    print(f"\n--- INFO: Starting Step: {step_name} ---")
    print(f"Executing: {command}")
    
    if cwd:
        print(f"Working directory: {cwd}")
    
    return_code = os.system(command) 
    
    if return_code != 0:
        print(f"\n--- ERROR: Step '{step_name}' failed! ---")
        sys.exit(1)

# --- Main Script Execution Block ---
try:
    parser = argparse.ArgumentParser(description="Run QuestaSim simulation for CPM Verification")
    parser.add_argument('--gui', action='store_true', help="Run simulation in GUI mode.")
    parser.add_argument('--seed', type=int, default=1, help="Set the random number seed.")
    parser.add_argument('--test', type=str, default='CpmSmokeTest', help="UVM Test name.")
    parser.add_argument('--timeout', type=int, default=300, help="Simulation timeout in seconds.")
    parser.add_argument('--no-compile', action='store_true', help="Skip compilation and elaboration.")
    parser.add_argument('--clean', action='store_true', help="Clean work directory before compilation.")
    parser.add_argument('--coverage-report', action='store_true', help="Generate code coverage report after simulation.")
    parser.add_argument('--modern-report', action='store_true', help="Generate modern HTML coverage report.")
    
    args = parser.parse_args()

    # Get the Run directory (where this script is located)
    run_dir = Path(__file__).parent.resolve()
    project_root = run_dir.parent.parent.resolve()
    
    # Change to Run directory
    os.chdir(run_dir)
    
    # --- 1. Clean up ---
    if args.clean:
        print("\n--- INFO: Cleaning up previous run files... ---")
        logs_clean = project_root / "logs"
        sim_dir = project_root / "sim"
        if os.name == 'nt':
            os.system(f'del /f /q "{logs_clean}\\*.log" "{logs_clean}\\*.wlf" 2>nul')
            os.system(f'rmdir /s /q "{sim_dir}\\work" "{sim_dir}\\tb_top_opt" 2>nul')
        else:
            os.system(f'rm -rf "{logs_clean}"/*.log "{logs_clean}"/*.wlf')
            os.system(f'rm -rf "{sim_dir}/work" "{sim_dir}/tb_top_opt"')
    
    # --- 2. Run Compile and Elaborate ---
    if not args.no_compile:
        run_command(CMD_COMPILE, "Compile", cwd=str(run_dir))
        run_command(CMD_ELABORATE, "Elaborate", cwd=str(run_dir))

    # --- 3. Build the Simulate Command ---
    # Create logs and coverage folders if they don't exist
    logs_dir = project_root / "logs"
    logs_dir.mkdir(exist_ok=True)
    coverage_dir = project_root / "coverage"
    coverage_dir.mkdir(exist_ok=True)
    
    log_file = logs_dir / f"{args.test}.log"
    wlf_file = logs_dir / f"{args.test}.wlf"
    ucdb_file = coverage_dir / f"{args.test}.ucdb"
    
    # Build simulation command with test name
    # Note: vsim must be run from project root to find work library
    # Add UVM_DEBUG verbosity to catch crashes early
    # -coverage enables code coverage collection
    cmd = ( f"vsim -coverage tb_top_opt +UVM_TESTNAME={args.test} +UVM_VERBOSITY=UVM_DEBUG -voptargs=+acc -sv_seed {args.seed} ")
    
    if args.gui:
        print("INFO: GUI mode detected. Opening GUI...")
        cmd += ' -gui'
        cmd += ' -do "add wave -r /*; run -all"' 
    else: 
        print("INFO: Batch mode detected. Running...")
        cmd += ' -c'
        # Use relative paths from project_root for -do commands (avoids Windows path escaping issues)
        rel_log = log_file.relative_to(project_root).as_posix()
        rel_wlf = wlf_file.relative_to(project_root).as_posix()
        rel_ucdb = ucdb_file.relative_to(project_root).as_posix()
        cmd += f' -logfile {rel_log} -wlf {rel_wlf}'
        # Save coverage data to UCDB file after simulation
        cmd += f' -do "coverage save -onexit {rel_ucdb}; run -all; quit -f"' 
    
    # Run the final command from project root
    print(f"\n--- INFO: Starting Simulation ---")
    print(f"Test: {args.test}")
    print(f"Seed: {args.seed}")
    print(f"Timeout: {args.timeout}s")
    print(f"Command: {cmd}")
    print(f"Working directory: {project_root}")
    
    # Handle timeout and interrupts
    def signal_handler(sig, frame):
        print("\n--- INFO: Interrupt received, cleaning up... ---")
        if os.name == 'nt':
            os.system("taskkill /F /IM vsim.exe 2>nul")
        else:
            os.system("pkill -9 vsim")
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Change to project root before running vsim
    os.chdir(project_root)
    
    start_time = time.time()
    return_code = os.system(cmd)
    elapsed_time = time.time() - start_time
    
    if elapsed_time > args.timeout:
        print(f"\n--- WARNING: Simulation exceeded timeout ({args.timeout}s) ---")
        if os.name == 'nt':
            os.system("taskkill /F /IM vsim.exe 2>nul")
        else:
            os.system("pkill -9 vsim")
        sys.exit(1)
    
    if return_code != 0:
        print(f"\n--- ERROR: Simulation failed! ---")
        sys.exit(1)
    
    print(f"\n--- INFO: Simulation completed ---")
    print(f"Log file: {log_file}")
    print(f"Waveform: {wlf_file}")
    print(f"Coverage: {ucdb_file}")
    print(f"Elapsed time: {elapsed_time:.2f}s")
    
    # --- 4. Generate Coverage Report (if requested) ---
    if args.coverage_report:
        print(f"\n--- INFO: Generating Coverage Report ---")
        report_txt = coverage_dir / f"{args.test}_coverage.txt"
        report_html = coverage_dir / "html"
        
        # Generate text summary report
        os.system(f'vcover report -details -output "{report_txt}" "{ucdb_file}"')
        
        # Generate HTML report (more detailed)
        os.system(f'vcover report -html -htmldir "{report_html}" "{ucdb_file}"')
        
        print(f"Text report: {report_txt}")
        print(f"HTML report: {report_html}/index.html")
    
    # --- 5. Generate Modern Report (if requested) ---
    if args.modern_report or args.coverage_report:
        print(f"\n--- INFO: Generating Modern Coverage Report ---")
        modern_script = run_dir.parent / "generate_coverage_report.py"
        if modern_script.exists():
            os.chdir(project_root)
            os.system(f'python "{modern_script}"')
            modern_report = coverage_dir / "modern_report.html"
            print(f"Modern report: {modern_report}")
        else:
            print(f"Modern report script not found: {modern_script}")
    
    print(f"\n--- INFO: All steps completed ---")

except KeyboardInterrupt:
    print("\n--- INFO: Interrupted by user ---")
    if os.name == 'nt':
        os.system("taskkill /F /IM vsim.exe 2>nul")
    else:
        os.system("pkill -9 vsim")
    sys.exit(0)
except Exception as e:
    print(f"\n--- FATAL ERROR: {e} ---")
    import traceback
    traceback.print_exc()
    sys.exit(1)
