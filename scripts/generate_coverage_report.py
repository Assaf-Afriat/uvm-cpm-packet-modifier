#!/usr/bin/env python3
"""
Modern Coverage Report Generator - Light Theme
Generates a comprehensive, 2026-style HTML coverage report from QuestaSim UCDB data.

Author: Assaf Afriat
Date: 2026-02-01
"""

import os
import re
import subprocess
from pathlib import Path
from datetime import datetime

def run_vcover(args):
    """Run vcover command and return output."""
    result = subprocess.run(['vcover'] + args, capture_output=True, text=True)
    return result.stdout

def get_coverage_summary(ucdb_path):
    """Extract overall coverage summary."""
    output = run_vcover(['report', '-summary', str(ucdb_path)])
    
    data = {
        'assertions': {'covered': 0, 'total': 0, 'pct': 0},
        'branches': {'covered': 0, 'total': 0, 'pct': 0},
        'conditions': {'covered': 0, 'total': 0, 'pct': 0},
        'expressions': {'covered': 0, 'total': 0, 'pct': 0},
        'statements': {'covered': 0, 'total': 0, 'pct': 0},
        'toggles': {'covered': 0, 'total': 0, 'pct': 0},
        'covergroups': {'pct': 0},
        'total': 0
    }
    
    for line in output.split('\n'):
        for metric in ['Assertions', 'Branches', 'Conditions', 'Expressions', 'Statements', 'Toggles']:
            if metric in line and 'totals' not in line.lower():
                nums = re.findall(r'(\d+)', line)
                pct_match = re.search(r'(\d+\.\d+)%', line)
                if len(nums) >= 2 and pct_match:
                    key = metric.lower()
                    data[key] = {
                        'total': int(nums[0]),
                        'covered': int(nums[1]),
                        'pct': float(pct_match.group(1))
                    }
        if 'Covergroups' in line:
            pct_match = re.search(r'(\d+\.\d+)%', line)
            if pct_match:
                data['covergroups']['pct'] = float(pct_match.group(1))
        if 'Total coverage' in line:
            pct_match = re.search(r'(\d+\.\d+)%', line)
            if pct_match:
                data['total'] = float(pct_match.group(1))
    
    return data

def get_dut_coverage(ucdb_path):
    """Extract DUT-specific coverage."""
    output = run_vcover(['report', '-summary', '-du=cpm', str(ucdb_path)])
    
    data = {
        'branches': {'covered': 0, 'total': 0, 'pct': 0},
        'conditions': {'covered': 0, 'total': 0, 'pct': 0},
        'expressions': {'covered': 0, 'total': 0, 'pct': 0},
        'statements': {'covered': 0, 'total': 0, 'pct': 0},
        'toggles': {'covered': 0, 'total': 0, 'pct': 0},
        'total': 0
    }
    
    for line in output.split('\n'):
        for metric in ['Branches', 'Conditions', 'Expressions', 'Statements', 'Toggles']:
            if metric in line and 'totals' not in line.lower():
                nums = re.findall(r'(\d+)', line)
                pct_match = re.search(r'(\d+\.\d+)%', line)
                if len(nums) >= 2 and pct_match:
                    key = metric.lower()
                    data[key] = {
                        'total': int(nums[0]),
                        'covered': int(nums[1]),
                        'pct': float(pct_match.group(1))
                    }
        if 'Total Coverage By Design Unit' in line:
            pct_match = re.search(r'(\d+\.\d+)%', line)
            if pct_match:
                data['total'] = float(pct_match.group(1))
    
    return data

def get_uncovered_items(ucdb_path):
    """Extract uncovered items for detailed view."""
    output = run_vcover(['report', '-zeros', '-details', '-du=cpm', str(ucdb_path)])
    
    uncovered = {
        'branches': [],
        'conditions': [],
        'statements': [],
        'toggles': []
    }
    
    current_section = None
    current_file = None
    
    for line in output.split('\n'):
        if 'Branch Coverage' in line:
            current_section = 'branches'
        elif 'Condition Coverage' in line:
            current_section = 'conditions'
        elif 'Statement Coverage' in line:
            current_section = 'statements'
        elif 'Toggle Coverage' in line:
            current_section = 'toggles'
        elif 'File ' in line:
            file_match = re.search(r'File\s+(.+)', line)
            if file_match:
                current_file = file_match.group(1).strip()
        elif '***0***' in line and current_section:
            line_match = re.search(r'(\d+)', line)
            if line_match and current_file:
                uncovered[current_section].append({
                    'file': current_file,
                    'line': line_match.group(1),
                    'detail': line.strip()
                })
    
    return uncovered

def get_functional_coverage(ucdb_path):
    """Extract functional coverage details."""
    output = run_vcover(['report', '-cvg', '-details', str(ucdb_path)])
    
    # Use dict to deduplicate covergroups by full path
    covergroups_dict = {}
    current_cg = None
    current_cp = None
    
    skip_until_next_cg = False
    
    for line in output.split('\n'):
        # Match covergroup definition (TYPE line)
        if 'TYPE' in line and 'cg_' in line:
            # Extract full path to use as unique key
            path_match = re.search(r'TYPE\s+(\S+)', line)
            name_match = re.search(r'(cg_\w+)', line)
            pct_match = re.search(r'(\d+\.\d+)%', line)
            if name_match and path_match:
                full_path = path_match.group(1)
                # Skip if we already have this covergroup
                if full_path in covergroups_dict:
                    current_cg = None
                    current_cp = None
                    skip_until_next_cg = True
                    continue
                
                skip_until_next_cg = False
                current_cg = {
                    'name': name_match.group(1),
                    'pct': float(pct_match.group(1)) if pct_match else 0,
                    'coverpoints': []
                }
                covergroups_dict[full_path] = current_cg
                current_cp = None
        
        # Skip all content until we hit a new covergroup
        if skip_until_next_cg:
            continue
        
        # Match coverpoint (starts with "Coverpoint cp_")
        elif current_cg and line.strip().startswith('Coverpoint cp_'):
            name_match = re.search(r'Coverpoint\s+(cp_\w+)', line)
            pct_match = re.search(r'(\d+\.\d+)%', line)
            status = 'Covered' if 'Covered' in line else 'Uncovered'
            if name_match:
                current_cp = {
                    'name': name_match.group(1),
                    'pct': float(pct_match.group(1)) if pct_match else 0,
                    'status': status,
                    'bins': []
                }
                current_cg['coverpoints'].append(current_cp)
        
        # Match cross coverage
        elif current_cg and line.strip().startswith('Cross cp_'):
            name_match = re.search(r'Cross\s+(cp_\w+)', line)
            pct_match = re.search(r'(\d+\.\d+)%', line)
            status = 'Covered' if 'Covered' in line else 'Uncovered'
            if name_match:
                current_cp = {
                    'name': name_match.group(1),
                    'pct': float(pct_match.group(1)) if pct_match else 0,
                    'status': status,
                    'bins': [],
                    'is_cross': True
                }
                current_cg['coverpoints'].append(current_cp)
        
        # Match individual bins
        elif current_cp and line.strip().startswith('bin '):
            bin_match = re.search(r'bin\s+(\S+)\s+(\d+)', line)
            if bin_match:
                hits = int(bin_match.group(2))
                status = 'ZERO' if hits == 0 else 'Covered'
                current_cp['bins'].append({
                    'name': bin_match.group(1),
                    'hits': hits,
                    'status': status
                })
    
    # Return unique covergroups as list
    return list(covergroups_dict.values())

def generate_html_report(overall, dut, uncovered, func_cov, output_path, test_name="All Tests"):
    """Generate a comprehensive light-theme HTML report."""
    
    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CPM Coverage Report | 2026</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg-primary: #0f0f14;
            --bg-secondary: #16161d;
            --bg-tertiary: #1e1e28;
            --bg-card: #1a1a24;
            --border-color: #2a2a38;
            --border-strong: #3a3a4a;
            --text-primary: #f0f0f5;
            --text-secondary: #a0a0b0;
            --text-tertiary: #6a6a7a;
            --accent-blue: #60a5fa;
            --accent-indigo: #818cf8;
            --accent-green: #34d399;
            --accent-emerald: #10b981;
            --accent-yellow: #fbbf24;
            --accent-orange: #fb923c;
            --accent-red: #f87171;
            --gradient-primary: linear-gradient(135deg, #60a5fa 0%, #818cf8 100%);
            --gradient-success: linear-gradient(135deg, #34d399 0%, #10b981 100%);
            --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.3);
            --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.4), 0 2px 4px -1px rgba(0, 0, 0, 0.3);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.5), 0 4px 6px -2px rgba(0, 0, 0, 0.4);
            --badge-excellent-bg: rgba(52, 211, 153, 0.2);
            --badge-excellent-color: #34d399;
            --badge-good-bg: rgba(251, 191, 36, 0.2);
            --badge-good-color: #fbbf24;
            --badge-poor-bg: rgba(248, 113, 113, 0.2);
            --badge-poor-color: #f87171;
        }}
        
        [data-theme="light"] {{
            --bg-primary: #fafbfc;
            --bg-secondary: #ffffff;
            --bg-tertiary: #f3f4f6;
            --bg-card: #ffffff;
            --border-color: #e5e7eb;
            --border-strong: #d1d5db;
            --text-primary: #111827;
            --text-secondary: #6b7280;
            --text-tertiary: #9ca3af;
            --accent-blue: #3b82f6;
            --accent-indigo: #6366f1;
            --accent-green: #10b981;
            --accent-emerald: #059669;
            --accent-yellow: #f59e0b;
            --accent-orange: #f97316;
            --accent-red: #ef4444;
            --gradient-primary: linear-gradient(135deg, #3b82f6 0%, #6366f1 100%);
            --gradient-success: linear-gradient(135deg, #10b981 0%, #059669 100%);
            --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
            --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
            --badge-excellent-bg: #dcfce7;
            --badge-excellent-color: #166534;
            --badge-good-bg: #fef3c7;
            --badge-good-color: #92400e;
            --badge-poor-bg: #fee2e2;
            --badge-poor-color: #991b1b;
        }}
        
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        
        body {{
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            min-height: 100vh;
            line-height: 1.6;
        }}
        
        .container {{ max-width: 1400px; margin: 0 auto; padding: 32px 24px; }}
        
        /* Header */
        header {{
            background: var(--bg-secondary);
            border-bottom: 1px solid var(--border-color);
            padding: 24px 0;
            margin-bottom: 32px;
        }}
        
        .header-content {{
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        
        .logo-section {{ display: flex; align-items: center; gap: 16px; }}
        
        .logo-icon {{
            width: 48px;
            height: 48px;
            background: var(--gradient-primary);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 700;
            font-size: 18px;
        }}
        
        .logo-text h1 {{
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--text-primary);
        }}
        
        .logo-text p {{
            font-size: 0.875rem;
            color: var(--text-secondary);
        }}
        
        .header-meta {{
            text-align: right;
        }}
        
        .timestamp {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.75rem;
            color: var(--text-tertiary);
            background: var(--bg-tertiary);
            padding: 6px 12px;
            border-radius: 6px;
        }}
        
        /* Score Hero */
        .score-hero {{
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 24px;
            margin-bottom: 32px;
        }}
        
        .score-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 32px;
            box-shadow: var(--shadow-sm);
        }}
        
        .score-card.featured {{
            background: var(--gradient-success);
            color: white;
            border: none;
        }}
        
        .score-label {{
            font-size: 0.875rem;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            opacity: 0.8;
            margin-bottom: 8px;
        }}
        
        .score-value {{
            font-size: 3.5rem;
            font-weight: 700;
            line-height: 1;
        }}
        
        .score-unit {{
            font-size: 1.5rem;
            opacity: 0.7;
        }}
        
        .score-detail {{
            margin-top: 12px;
            font-size: 0.875rem;
            opacity: 0.8;
        }}
        
        /* Section */
        .section {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            margin-bottom: 24px;
            box-shadow: var(--shadow-sm);
            overflow: hidden;
        }}
        
        .section-header {{
            padding: 20px 24px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: var(--bg-tertiary);
        }}
        
        .section-title {{
            font-size: 1rem;
            font-weight: 600;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 10px;
        }}
        
        .section-icon {{
            width: 32px;
            height: 32px;
            background: var(--gradient-primary);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 14px;
        }}
        
        .section-body {{ padding: 24px; }}
        
        /* Metrics Grid */
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
        }}
        
        .metric-item {{
            background: var(--bg-tertiary);
            border-radius: 12px;
            padding: 20px;
            transition: all 0.2s ease;
        }}
        
        .metric-item:hover {{
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }}
        
        .metric-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }}
        
        .metric-name {{
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-secondary);
        }}
        
        .metric-badge {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.65rem;
            padding: 3px 8px;
            border-radius: 4px;
            font-weight: 600;
        }}
        
        .badge-excellent {{ background: var(--badge-excellent-bg); color: var(--badge-excellent-color); }}
        .badge-good {{ background: var(--badge-good-bg); color: var(--badge-good-color); }}
        .badge-poor {{ background: var(--badge-poor-bg); color: var(--badge-poor-color); }}
        
        .metric-value {{
            font-size: 1.75rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 4px;
        }}
        
        .metric-detail {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.75rem;
            color: var(--text-tertiary);
        }}
        
        .progress-bar {{
            height: 6px;
            background: var(--border-color);
            border-radius: 3px;
            margin-top: 12px;
            overflow: hidden;
        }}
        
        .progress-fill {{
            height: 100%;
            border-radius: 3px;
            transition: width 0.8s cubic-bezier(0.4, 0, 0.2, 1);
        }}
        
        .fill-excellent {{ background: var(--accent-green); }}
        .fill-good {{ background: var(--accent-yellow); }}
        .fill-poor {{ background: var(--accent-red); }}
        
        /* Table */
        .data-table {{
            width: 100%;
            border-collapse: collapse;
        }}
        
        .data-table th {{
            text-align: left;
            padding: 12px 16px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-secondary);
            background: var(--bg-tertiary);
            border-bottom: 1px solid var(--border-color);
        }}
        
        .data-table td {{
            padding: 12px 16px;
            font-size: 0.875rem;
            border-bottom: 1px solid var(--border-color);
        }}
        
        .data-table tr:last-child td {{
            border-bottom: none;
        }}
        
        .data-table tr:hover {{
            background: var(--bg-tertiary);
        }}
        
        .data-table .file-path {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.8rem;
            color: var(--accent-blue);
        }}
        
        .data-table .line-num {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.8rem;
            background: var(--bg-tertiary);
            padding: 2px 8px;
            border-radius: 4px;
        }}
        
        .data-table .status-hit {{
            color: var(--accent-green);
            font-weight: 600;
        }}
        
        .data-table .status-miss {{
            color: var(--accent-red);
            font-weight: 600;
        }}
        
        /* Two Column Layout */
        .two-column {{
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 24px;
        }}
        
        @media (max-width: 900px) {{
            .two-column {{ grid-template-columns: 1fr; }}
            .score-hero {{ grid-template-columns: 1fr; }}
        }}
        
        /* Info List */
        .info-list {{
            list-style: none;
        }}
        
        .info-list li {{
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid var(--border-color);
            font-size: 0.875rem;
        }}
        
        .info-list li:last-child {{ border-bottom: none; }}
        
        .info-list .label {{ color: var(--text-secondary); }}
        
        .info-list .value {{
            font-family: 'JetBrains Mono', monospace;
            font-weight: 500;
        }}
        
        /* Empty State */
        .empty-state {{
            text-align: center;
            padding: 40px;
            color: var(--text-tertiary);
        }}
        
        .empty-state-icon {{
            font-size: 2rem;
            margin-bottom: 12px;
        }}
        
        /* Footer */
        footer {{
            text-align: center;
            padding: 32px 0;
            color: var(--text-tertiary);
            font-size: 0.875rem;
        }}
        
        .footer-brand {{
            font-weight: 600;
            background: var(--gradient-primary);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}
        
        /* Tabs */
        .tabs {{
            display: flex;
            gap: 8px;
            padding: 16px 24px;
            border-bottom: 1px solid var(--border-color);
            background: var(--bg-card);
        }}
        
        .tab {{
            padding: 8px 16px;
            font-size: 0.875rem;
            font-weight: 500;
            color: var(--text-secondary);
            border-radius: 6px;
            cursor: pointer;
            transition: all 0.2s;
        }}
        
        .tab:hover {{ background: var(--bg-tertiary); }}
        
        .tab.active {{
            background: var(--gradient-primary);
            color: white;
        }}
        
        /* Functional Coverage */
        .covergroup-card {{
            border: 1px solid var(--border-color);
            border-radius: 12px;
            margin-bottom: 20px;
            overflow: hidden;
        }}
        
        .covergroup-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 16px 20px;
            background: linear-gradient(135deg, #7c3aed 0%, #a855f7 100%);
            color: white;
        }}
        
        .covergroup-name {{
            font-family: 'JetBrains Mono', monospace;
            font-weight: 600;
            font-size: 0.95rem;
        }}
        
        .covergroup-pct {{
            font-size: 1.25rem;
            font-weight: 700;
        }}
        
        .coverpoints-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 12px;
            padding: 16px;
            background: var(--bg-tertiary);
        }}
        
        .coverpoint-item {{
            background: var(--bg-card);
            border-radius: 10px;
            padding: 14px;
            border: 2px solid transparent;
            transition: all 0.2s ease;
        }}
        
        .coverpoint-item:hover {{
            transform: translateY(-2px);
            box-shadow: var(--shadow-md);
        }}
        
        .coverpoint-item.cp-covered {{
            border-color: var(--accent-green);
        }}
        
        .coverpoint-item.cp-partial {{
            border-color: var(--accent-yellow);
        }}
        
        .coverpoint-item.cp-uncovered {{
            border-color: var(--accent-red);
        }}
        
        .cp-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }}
        
        .cp-type {{
            font-size: 0.65rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-tertiary);
            background: var(--bg-tertiary);
            padding: 2px 6px;
            border-radius: 4px;
        }}
        
        .cp-status-icon {{
            width: 20px;
            height: 20px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            font-weight: 700;
        }}
        
        .cp-covered .cp-status-icon {{
            background: rgba(52, 211, 153, 0.2);
            color: #34d399;
        }}
        
        .cp-partial .cp-status-icon {{
            background: rgba(251, 191, 36, 0.2);
            color: #fbbf24;
        }}
        
        .cp-uncovered .cp-status-icon {{
            background: rgba(248, 113, 113, 0.2);
            color: #f87171;
        }}
        
        .cp-name {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.8rem;
            font-weight: 500;
            color: var(--text-primary);
            margin-bottom: 6px;
            word-break: break-word;
        }}
        
        .cp-value {{
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 4px;
        }}
        
        .cp-bar {{
            height: 4px;
            background: var(--border-color);
            border-radius: 2px;
            overflow: hidden;
            margin-bottom: 8px;
        }}
        
        .cp-bar-fill {{
            height: 100%;
            border-radius: 2px;
            transition: width 0.6s ease;
        }}
        
        .cp-covered .cp-bar-fill {{ background: var(--accent-green); }}
        .cp-partial .cp-bar-fill {{ background: var(--accent-yellow); }}
        .cp-uncovered .cp-bar-fill {{ background: var(--accent-red); }}
        
        .cp-bins {{
            font-size: 0.7rem;
            color: var(--text-secondary);
        }}
        
        .bins-missing {{
            font-size: 0.65rem;
            color: var(--accent-red);
            margin-top: 4px;
            font-weight: 500;
        }}
        
        /* Theme Toggle */
        .theme-toggle {{
            display: flex;
            align-items: center;
            gap: 10px;
            cursor: pointer;
            padding: 8px 14px;
            border-radius: 50px;
            background: var(--bg-tertiary);
            border: 1px solid var(--border-color);
            transition: all 0.3s ease;
        }}
        
        .theme-toggle:hover {{
            border-color: var(--accent-blue);
            box-shadow: 0 0 12px rgba(96, 165, 250, 0.3);
        }}
        
        .theme-toggle-track {{
            width: 44px;
            height: 24px;
            background: var(--border-strong);
            border-radius: 12px;
            position: relative;
            transition: all 0.3s ease;
        }}
        
        .theme-toggle-thumb {{
            width: 20px;
            height: 20px;
            background: var(--text-primary);
            border-radius: 50%;
            position: absolute;
            top: 2px;
            left: 2px;
            transition: all 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 10px;
        }}
        
        [data-theme="light"] .theme-toggle-thumb {{
            left: 22px;
        }}
        
        .theme-toggle-label {{
            font-size: 0.75rem;
            font-weight: 500;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
    </style>
</head>
<body>
    <header>
        <div class="header-content">
            <div class="logo-section">
                <div class="logo-icon">CPM</div>
                <div class="logo-text">
                    <h1>Coverage Report</h1>
                    <p>Configurable Packet Modifier Verification</p>
                </div>
            </div>
            <div class="header-meta" style="display: flex; align-items: center; gap: 16px;">
                <div class="theme-toggle" onclick="toggleTheme()">
                    <div class="theme-toggle-track">
                        <div class="theme-toggle-thumb" id="toggleThumb">&#9790;</div>
                    </div>
                    <span class="theme-toggle-label" id="themeLabel">Dark</span>
                </div>
                <div class="timestamp">{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</div>
            </div>
        </div>
    </header>
    
    <div class="container">
        <!-- Score Hero -->
        <div class="score-hero">
            <div class="score-card featured">
                <div class="score-label">DUT Coverage (cpm)</div>
                <div class="score-value">{dut['total']:.1f}<span class="score-unit">%</span></div>
                <div class="score-detail">Design Under Test - All Metrics Combined</div>
            </div>
            <div class="score-card">
                <div class="score-label">Overall Coverage</div>
                <div class="score-value" style="color: var(--accent-blue);">{overall['total']:.1f}<span class="score-unit">%</span></div>
                <div class="score-detail">Including Testbench Components</div>
            </div>
        </div>
        
        <!-- DUT Code Coverage -->
        <div class="section">
            <div class="section-header">
                <div class="section-title">
                    <div class="section-icon">D</div>
                    DUT Code Coverage (cpm_rtl.sv)
                </div>
            </div>
            <div class="section-body">
                <div class="metrics-grid">
                    {generate_metric_html("Statements", dut['statements'])}
                    {generate_metric_html("Branches", dut['branches'])}
                    {generate_metric_html("Expressions", dut['expressions'])}
                    {generate_metric_html("Conditions", dut['conditions'])}
                    {generate_metric_html("Toggles", dut['toggles'])}
                </div>
            </div>
        </div>
        
        <!-- Overall Coverage -->
        <div class="section">
            <div class="section-header">
                <div class="section-title">
                    <div class="section-icon">O</div>
                    Overall Coverage (All Design Units)
                </div>
            </div>
            <div class="section-body">
                <div class="metrics-grid">
                    {generate_metric_html("Assertions", overall['assertions'])}
                    {generate_metric_html("Statements", overall['statements'])}
                    {generate_metric_html("Branches", overall['branches'])}
                    {generate_metric_html("Expressions", overall['expressions'])}
                    {generate_metric_html("Conditions", overall['conditions'])}
                    {generate_metric_html("Toggles", overall['toggles'])}
                </div>
            </div>
        </div>
        
        <div class="two-column">
            <!-- Uncovered Branches -->
            <div class="section">
                <div class="section-header">
                    <div class="section-title">
                        <div class="section-icon" style="background: linear-gradient(135deg, #f59e0b, #f97316);">!</div>
                        Uncovered Branches ({len(uncovered['branches'])})
                    </div>
                </div>
                <div class="section-body" style="padding: 0;">
                    {generate_uncovered_table(uncovered['branches'])}
                </div>
            </div>
            
            <!-- Uncovered Conditions -->
            <div class="section">
                <div class="section-header">
                    <div class="section-title">
                        <div class="section-icon" style="background: linear-gradient(135deg, #f59e0b, #f97316);">!</div>
                        Uncovered Conditions ({len(uncovered['conditions'])})
                    </div>
                </div>
                <div class="section-body" style="padding: 0;">
                    {generate_uncovered_table(uncovered['conditions'])}
                </div>
            </div>
        </div>
        
        <!-- Functional Coverage -->
        <div class="section">
            <div class="section-header">
                <div class="section-title">
                    <div class="section-icon" style="background: linear-gradient(135deg, #8b5cf6, #a855f7);">F</div>
                    Functional Coverage ({overall['covergroups']['pct']:.1f}%)
                </div>
            </div>
            <div class="section-body">
                {generate_functional_coverage_html(func_cov)}
            </div>
        </div>
        
        <!-- Test Information -->
        <div class="two-column">
            <div class="section">
                <div class="section-header">
                    <div class="section-title">
                        <div class="section-icon" style="background: linear-gradient(135deg, #06b6d4, #0891b2);">i</div>
                        Test Information
                    </div>
                </div>
                <div class="section-body">
                    <ul class="info-list">
                        <li>
                            <span class="label">Test Suite</span>
                            <span class="value">{test_name}</span>
                        </li>
                        <li>
                            <span class="label">DUT Module</span>
                            <span class="value">cpm (cpm_rtl.sv)</span>
                        </li>
                        <li>
                            <span class="label">Simulator</span>
                            <span class="value">QuestaSim 2025.1</span>
                        </li>
                        <li>
                            <span class="label">Report Generated</span>
                            <span class="value">{datetime.now().strftime("%Y-%m-%d %H:%M")}</span>
                        </li>
                    </ul>
                </div>
            </div>
            
            <div class="section">
                <div class="section-header">
                    <div class="section-title">
                        <div class="section-icon" style="background: linear-gradient(135deg, #10b981, #059669);">T</div>
                        Coverage Targets
                    </div>
                </div>
                <div class="section-body">
                    <ul class="info-list">
                        <li>
                            <span class="label">Statements &gt;95%</span>
                            <span class="value {'status-hit' if dut['statements']['pct'] >= 95 else 'status-miss'}">{dut['statements']['pct']:.1f}% {'PASS' if dut['statements']['pct'] >= 95 else 'FAIL'}</span>
                        </li>
                        <li>
                            <span class="label">Branches &gt;90%</span>
                            <span class="value {'status-hit' if dut['branches']['pct'] >= 90 else 'status-miss'}">{dut['branches']['pct']:.1f}% {'PASS' if dut['branches']['pct'] >= 90 else 'FAIL'}</span>
                        </li>
                        <li>
                            <span class="label">Expressions &gt;90%</span>
                            <span class="value {'status-hit' if dut['expressions']['pct'] >= 90 else 'status-miss'}">{dut['expressions']['pct']:.1f}% {'PASS' if dut['expressions']['pct'] >= 90 else 'FAIL'}</span>
                        </li>
                        <li>
                            <span class="label">Conditions &gt;80%</span>
                            <span class="value {'status-hit' if dut['conditions']['pct'] >= 80 else 'status-miss'}">{dut['conditions']['pct']:.1f}% {'PASS' if dut['conditions']['pct'] >= 80 else 'FAIL'}</span>
                        </li>
                    </ul>
                </div>
            </div>
        </div>
    </div>
    
    <footer>
        <p>Generated by <span class="footer-brand">CPM Verification Suite</span> | Assaf Afriat 2026</p>
    </footer>
    
    <script>
        function toggleTheme() {{
            const html = document.documentElement;
            const thumb = document.getElementById('toggleThumb');
            const label = document.getElementById('themeLabel');
            
            if (html.getAttribute('data-theme') === 'light') {{
                html.removeAttribute('data-theme');
                thumb.innerHTML = '&#9790;';  // Moon
                label.textContent = 'Dark';
                localStorage.setItem('theme', 'dark');
            }} else {{
                html.setAttribute('data-theme', 'light');
                thumb.innerHTML = '&#9728;';  // Sun
                label.textContent = 'Light';
                localStorage.setItem('theme', 'light');
            }}
        }}
        
        // Load saved theme preference
        (function() {{
            const savedTheme = localStorage.getItem('theme');
            const thumb = document.getElementById('toggleThumb');
            const label = document.getElementById('themeLabel');
            
            if (savedTheme === 'light') {{
                document.documentElement.setAttribute('data-theme', 'light');
                thumb.innerHTML = '&#9728;';  // Sun
                label.textContent = 'Light';
            }}
        }})();
    </script>
</body>
</html>
'''
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html)
    
    print(f"[+] Modern coverage report generated: {output_path}")

def generate_metric_html(name, data):
    """Generate a metric item HTML."""
    pct = data.get('pct', 0)
    covered = data.get('covered', 0)
    total = data.get('total', 0)
    
    return f'''
                    <div class="metric-item">
                        <div class="metric-header">
                            <span class="metric-name">{name}</span>
                            {get_badge_html(pct)}
                        </div>
                        <div class="metric-value">{pct:.1f}%</div>
                        <div class="metric-detail">{covered} / {total} bins</div>
                        <div class="progress-bar">
                            <div class="progress-fill {get_fill_class(pct)}" style="width: {pct}%;"></div>
                        </div>
                    </div>'''

def get_badge_html(pct):
    """Get the badge HTML based on percentage."""
    if pct >= 95:
        return '<span class="metric-badge badge-excellent">EXCELLENT</span>'
    elif pct >= 80:
        return '<span class="metric-badge badge-good">GOOD</span>'
    else:
        return '<span class="metric-badge badge-poor">NEEDS WORK</span>'

def get_fill_class(pct):
    """Get the fill class based on percentage."""
    if pct >= 95:
        return 'fill-excellent'
    elif pct >= 80:
        return 'fill-good'
    else:
        return 'fill-poor'

def generate_functional_coverage_html(func_cov):
    """Generate detailed functional coverage HTML."""
    if not func_cov:
        return '''<div class="empty-state">
            <div class="empty-state-icon">?</div>
            <p>No functional coverage data found</p>
        </div>'''
    
    html = ''
    
    for cg in func_cov:
        cg_html = f'''
                <div class="covergroup-card">
                    <div class="covergroup-header">
                        <div class="covergroup-name">{cg['name']}</div>
                        <div class="covergroup-pct">{cg['pct']:.1f}%</div>
                    </div>
                    <div class="coverpoints-grid">'''
        
        for cp in cg.get('coverpoints', []):
            is_cross = cp.get('is_cross', False)
            icon = 'X' if is_cross else 'C'
            type_label = 'Cross' if is_cross else 'Coverpoint'
            
            # Determine status class
            if cp['pct'] >= 100:
                status_class = 'cp-covered'
                status_icon = '&#10003;'
            elif cp['pct'] >= 50:
                status_class = 'cp-partial'
                status_icon = '~'
            else:
                status_class = 'cp-uncovered'
                status_icon = '!'
            
            # Build bins info
            bins_html = ''
            zero_bins = [b for b in cp.get('bins', []) if b['status'] == 'ZERO']
            covered_bins = [b for b in cp.get('bins', []) if b['status'] == 'Covered']
            
            if zero_bins:
                bins_html += f'<div class="bins-missing">{len(zero_bins)} bins missing</div>'
            
            cg_html += f'''
                        <div class="coverpoint-item {status_class}">
                            <div class="cp-header">
                                <span class="cp-type">{type_label}</span>
                                <span class="cp-status-icon">{status_icon}</span>
                            </div>
                            <div class="cp-name">{cp['name']}</div>
                            <div class="cp-value">{cp['pct']:.0f}%</div>
                            <div class="cp-bar">
                                <div class="cp-bar-fill" style="width: {cp['pct']}%;"></div>
                            </div>
                            <div class="cp-bins">{len(covered_bins)}/{len(covered_bins) + len(zero_bins)} bins</div>
                            {bins_html}
                        </div>'''
        
        cg_html += '''
                    </div>
                </div>'''
        html += cg_html
    
    return html

def generate_uncovered_table(items):
    """Generate a table of uncovered items."""
    if not items:
        return '''<div class="empty-state">
            <div class="empty-state-icon">:)</div>
            <p>All items covered!</p>
        </div>'''
    
    rows = ''
    for item in items[:10]:  # Limit to 10 items
        rows += f'''
                        <tr>
                            <td class="file-path">{item.get('file', 'N/A')}</td>
                            <td><span class="line-num">Line {item.get('line', '?')}</span></td>
                            <td class="status-miss">NOT HIT</td>
                        </tr>'''
    
    if len(items) > 10:
        rows += f'''
                        <tr>
                            <td colspan="3" style="text-align: center; color: var(--text-tertiary);">
                                ... and {len(items) - 10} more items
                            </td>
                        </tr>'''
    
    return f'''
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>File</th>
                                <th>Location</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>{rows}
                        </tbody>
                    </table>'''

def main():
    project_root = Path(__file__).parent.parent
    coverage_dir = project_root / "coverage"
    
    # Use merged UCDB if available
    ucdb_path = coverage_dir / "merged.ucdb"
    if not ucdb_path.exists():
        ucdb_path = coverage_dir / "CpmMainTest.ucdb"
    
    if not ucdb_path.exists():
        print("[!] No coverage database found. Run tests with --coverage-report first.")
        return
    
    print(f"[*] Reading coverage data from: {ucdb_path}")
    
    overall = get_coverage_summary(ucdb_path)
    dut = get_dut_coverage(ucdb_path)
    uncovered = get_uncovered_items(ucdb_path)
    func_cov = get_functional_coverage(ucdb_path)
    
    output_path = coverage_dir / "modern_report.html"
    generate_html_report(overall, dut, uncovered, func_cov, output_path, "Merged Tests")
    
    print(f"\n[+] Open in browser: {output_path}")

if __name__ == "__main__":
    main()
