# ============================================================================
# Assertion Report Generation Script for QuestaSim
# ============================================================================
# Usage: vsim -c -do assertion_report.do
# This script generates a detailed assertion report from the UCDB file
# ============================================================================

# Set paths
set PROJECT_ROOT [file normalize [file join [pwd] ".." ".."]]
set COVERAGE_DIR "$PROJECT_ROOT/coverage"
set UCDB_FILE "$COVERAGE_DIR/CpmMainTest.ucdb"
set REPORT_DIR "$COVERAGE_DIR/assertion_report"
set REPORT_TXT "$REPORT_DIR/assertion_report.txt"
set REPORT_HTML "$REPORT_DIR/html"

# Create report directory
file mkdir $REPORT_DIR

puts "============================================================================"
puts "                    ASSERTION REPORT GENERATOR"
puts "============================================================================"
puts "UCDB File: $UCDB_FILE"
puts "Report Dir: $REPORT_DIR"
puts "============================================================================"

# Check if UCDB file exists
if {![file exists $UCDB_FILE]} {
    puts "ERROR: UCDB file not found: $UCDB_FILE"
    puts "Please run CpmMainTest first with coverage enabled."
    quit -f
}

# Generate assertion text report
puts "\n--- Generating Text Assertion Report ---"
vcover report -assert -details -output $REPORT_TXT $UCDB_FILE

# Generate assertion HTML report
puts "\n--- Generating HTML Assertion Report ---"
vcover report -assert -html -htmldir $REPORT_HTML $UCDB_FILE

# Display summary
puts "\n============================================================================"
puts "                    ASSERTION REPORT SUMMARY"
puts "============================================================================"

# Also display assertion statistics in console
vcover report -assert $UCDB_FILE

puts "============================================================================"
puts "Reports Generated:"
puts "  Text Report: $REPORT_TXT"
puts "  HTML Report: $REPORT_HTML/index.html"
puts "============================================================================"

quit -f
