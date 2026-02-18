#!/usr/bin/env python3
"""
CPM Test Runner GUI - 2026 Premium Edition
A beautiful, modern graphical interface for running UVM verification tests.

Author: Assaf Afriat
Date: 2026-02-01
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import subprocess
import threading
import os
import sys
import time
from pathlib import Path
from datetime import datetime
import queue


class PremiumTestRunner:
    # Font sizes - easily adjustable
    FONT_TITLE = 36
    FONT_SUBTITLE = 16
    FONT_CARD_HEADER = 20
    FONT_LABEL = 16
    FONT_INPUT = 16
    FONT_CHECKBOX = 18
    FONT_BUTTON_LARGE = 20
    FONT_BUTTON_MEDIUM = 16
    FONT_BUTTON_SMALL = 14
    FONT_CONSOLE = 13
    FONT_STAT_VALUE = 32
    FONT_STAT_LABEL = 14
    FONT_STATUS = 16
    FONT_THEME = 24
    
    def __init__(self, root):
        self.root = root
        self.root.title("CPM Verification Suite")
        
        # Try to maximize
        try:
            self.root.state('zoomed')
        except:
            self.root.geometry("1920x1080")
        
        self.root.minsize(1600, 1000)
        
        # Get project root
        self.project_root = Path(__file__).parent.parent
        self.run_script = self.project_root / "scripts" / "Run" / "run.py"
        
        # Theme state
        self.dark_mode = tk.BooleanVar(value=True)
        
        # Theme colors - matching modern coverage report
        self.themes = {
            'dark': {
                'bg_primary': '#0f0f14',      # Dark navy background
                'bg_secondary': '#16161d',    # Slightly lighter
                'bg_card': '#1a1a24',         # Card background
                'bg_input': '#1e1e28',        # Input fields
                'bg_hover': '#2a2a38',        # Hover state
                'text_primary': '#f0f0f5',    # Bright white text
                'text_secondary': '#a0a0b0',  # Muted text
                'text_muted': '#6a6a7a',      # Very muted
                'accent': '#818cf8',          # Indigo accent
                'accent_hover': '#60a5fa',    # Blue hover
                'accent_blue': '#60a5fa',     # Blue
                'accent_indigo': '#818cf8',   # Indigo
                'success': '#34d399',         # Emerald green
                'warning': '#fbbf24',         # Amber yellow
                'error': '#f87171',           # Coral red
                'info': '#60a5fa',            # Sky blue
                'border': '#2a2a38',          # Border color
                'console_bg': '#0f0f14',      # Console background
                'console_fg': '#f0f0f5',      # Console text
            },
            'light': {
                'bg_primary': '#fafbfc',      # Off-white background
                'bg_secondary': '#ffffff',    # Pure white
                'bg_card': '#ffffff',         # White cards
                'bg_input': '#f3f4f6',        # Light gray inputs
                'bg_hover': '#e5e7eb',        # Hover state
                'text_primary': '#111827',    # Near black text
                'text_secondary': '#6b7280',  # Gray text
                'text_muted': '#9ca3af',      # Light gray
                'accent': '#6366f1',          # Indigo accent
                'accent_hover': '#3b82f6',    # Blue hover
                'accent_blue': '#3b82f6',     # Blue
                'accent_indigo': '#6366f1',   # Indigo
                'success': '#10b981',         # Emerald green
                'warning': '#f59e0b',         # Amber yellow
                'error': '#ef4444',           # Red
                'info': '#3b82f6',            # Blue
                'border': '#e5e7eb',          # Border color
                'console_bg': '#1e1e28',      # Console stays dark
                'console_fg': '#f0f0f5',      # Console text
            }
        }
        
        # Variables
        self.test_var = tk.StringVar(value="CpmSmokeTest")
        self.timeout_var = tk.StringVar(value="120")
        self.seed_var = tk.StringVar(value="random")
        self.coverage_var = tk.BooleanVar(value=True)
        self.gui_mode_var = tk.BooleanVar(value=False)
        self.modern_report_var = tk.BooleanVar(value=False)
        
        self.running = False
        self.process = None
        self.output_queue = queue.Queue()
        self.start_time = None
        
        # Configure combobox style for large fonts
        self.setup_styles()
        
        # Create UI
        self.create_ui()
        self.apply_theme()
        
    def setup_styles(self):
        """Setup ttk styles for large fonts."""
        style = ttk.Style()
        
        # Configure combobox with large font
        style.configure('Large.TCombobox', 
                       font=('Segoe UI', self.FONT_INPUT))
        
        # Configure the dropdown list font
        self.root.option_add('*TCombobox*Listbox.font', 
                            ('Segoe UI', self.FONT_INPUT))
        self.root.option_add('*TCombobox*Listbox.selectBackground', '#8b5cf6')
        self.root.option_add('*TCombobox*Listbox.selectForeground', 'white')
        
    def create_ui(self):
        """Create the main UI layout."""
        # Main container
        self.main_frame = tk.Frame(self.root)
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Header bar
        self.create_header()
        
        # Content area with padding
        self.content_frame = tk.Frame(self.main_frame)
        self.content_frame.pack(fill=tk.BOTH, expand=True, padx=50, pady=40)
        
        # Left panel (controls) - fixed width
        self.create_control_panel()
        
        # Right panel (output) - expands
        self.create_output_panel()
        
        # Status bar
        self.create_status_bar()
        
    def create_header(self):
        """Create modern header."""
        self.header_frame = tk.Frame(self.main_frame, height=250)
        self.header_frame.pack(fill=tk.X)
        self.header_frame.pack_propagate(False)
        
        # Inner container - use grid for precise positioning
        header_inner = tk.Frame(self.header_frame)
        header_inner.pack(fill=tk.BOTH, expand=True, padx=60, pady=25)
        header_inner.grid_columnconfigure(0, weight=0)  # Left - fixed
        header_inner.grid_columnconfigure(1, weight=1)  # Center - expand
        header_inner.grid_columnconfigure(2, weight=0)  # Right - fixed
        header_inner.grid_rowconfigure(0, weight=1)
        
        # Left: CPM title
        left_frame = tk.Frame(header_inner)
        left_frame.grid(row=0, column=0, sticky='w')
        
        # Title section - CPM as text matching title style
        title_frame = tk.Frame(left_frame)
        title_frame.pack(side=tk.LEFT, fill=tk.Y, pady=5)
        
        # CPM text styled like the title
        self.cpm_label = tk.Label(title_frame, text="CPM",
                                  font=("Segoe UI", self.FONT_TITLE, "bold"))
        self.cpm_label.pack(side=tk.LEFT)
        
        # Separator
        self.sep_label = tk.Label(title_frame, text="  ",
                                  font=("Segoe UI", self.FONT_TITLE))
        self.sep_label.pack(side=tk.LEFT)
        
        self.title_label = tk.Label(title_frame, text="Verification Suite",
                                    font=("Segoe UI", self.FONT_TITLE, "bold"))
        self.title_label.pack(side=tk.LEFT)
        
        # Center: Subtitle (centered between title and stats)
        self.center_frame = tk.Frame(header_inner)
        self.center_frame.grid(row=0, column=1, sticky='nsew')
        
        self.subtitle_label = tk.Label(self.center_frame, 
                                       text="UVM Test Runner  •  2026 Premium Edition",
                                       font=("Segoe UI", self.FONT_SUBTITLE))
        self.subtitle_label.place(relx=0.5, rely=0.5, anchor=tk.CENTER)
        
        # Right: Theme toggle and stats
        right_frame = tk.Frame(header_inner)
        right_frame.grid(row=0, column=2, sticky='e')
        
        # Theme toggle - centered in container
        self.toggle_container = tk.Frame(right_frame)
        self.toggle_container.pack(side=tk.RIGHT, padx=(40, 0), fill=tk.Y)
        
        # Use pack with expand to center vertically
        spacer_top = tk.Frame(self.toggle_container)
        spacer_top.pack(side=tk.TOP, expand=True, fill=tk.Y)
        
        self.theme_btn = tk.Button(self.toggle_container, text="🌙",
                                   font=("Segoe UI", self.FONT_THEME),
                                   bd=0, padx=25, pady=25,
                                   cursor="hand2",
                                   command=self.toggle_theme)
        self.theme_btn.pack(side=tk.TOP)
        
        spacer_bottom = tk.Frame(self.toggle_container)
        spacer_bottom.pack(side=tk.TOP, expand=True, fill=tk.Y)
        
        # Stats
        self.stats_frame = tk.Frame(right_frame)
        self.stats_frame.pack(side=tk.RIGHT, pady=5)
        
        self.stat_widgets = []
        self.create_stat_badge(self.stats_frame, "3", "Tests", "#818cf8")    # Indigo
        self.create_stat_badge(self.stats_frame, "100%", "Pass", "#34d399")  # Emerald
        self.create_stat_badge(self.stats_frame, "100%", "Coverage", "#60a5fa")  # Blue
        
    def create_stat_badge(self, parent, value, label, color):
        """Create a stat badge."""
        badge = tk.Frame(parent, padx=30, pady=25)
        badge.pack(side=tk.LEFT, padx=15)
        
        val_label = tk.Label(badge, text=value, 
                            font=("Segoe UI", self.FONT_STAT_VALUE, "bold"), fg=color)
        val_label.pack()
        
        lbl_label = tk.Label(badge, text=label.upper(), 
                            font=("Segoe UI", self.FONT_STAT_LABEL, "bold"))
        lbl_label.pack(pady=(8, 10))
        
        self.stat_widgets.append((badge, val_label, lbl_label, color))
        
    def create_control_panel(self):
        """Create the left control panel with scroll support."""
        # Outer frame with fixed width
        self.control_outer = tk.Frame(self.content_frame, width=700)
        self.control_outer.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 60))
        self.control_outer.pack_propagate(False)
        
        # Canvas for scrolling (no visible scrollbar - use mouse wheel)
        self.control_canvas = tk.Canvas(self.control_outer, highlightthickness=0, bd=0)
        self.control_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Inner frame for content
        self.control_frame = tk.Frame(self.control_canvas, width=680)
        self.control_window = self.control_canvas.create_window((0, 0), window=self.control_frame, 
                                                                  anchor=tk.NW, width=680)
        
        # Bind scroll events
        self.control_frame.bind('<Configure>', self._on_control_configure)
        self.control_canvas.bind_all('<MouseWheel>', self._on_mousewheel)
        
        # === Test Configuration Card ===
        self.config_card = self.create_card(self.control_frame, "Test Configuration", "⚙️")
        
        # Test dropdown
        self.create_label(self.config_card, "Select Test")
        
        tests = ["CpmSmokeTest", "CpmMainTest", "CpmRalResetTest"]
        self.test_combo = ttk.Combobox(self.config_card, textvariable=self.test_var,
                                       values=tests, state="readonly", 
                                       font=("Segoe UI", self.FONT_INPUT),
                                       style='Large.TCombobox')
        self.test_combo.pack(fill=tk.X, ipady=15, pady=(0, 30))
        
        # Timeout
        self.create_label(self.config_card, "Timeout (seconds)")
        
        self.timeout_entry = tk.Entry(self.config_card, textvariable=self.timeout_var,
                                      font=("Segoe UI", self.FONT_INPUT), bd=0,
                                      highlightthickness=3)
        self.timeout_entry.pack(fill=tk.X, ipady=18, pady=(0, 30))
        
        # Seed
        self.create_label(self.config_card, "Seed (or 'random')")
        
        self.seed_entry = tk.Entry(self.config_card, textvariable=self.seed_var,
                                   font=("Segoe UI", self.FONT_INPUT), bd=0,
                                   highlightthickness=3)
        self.seed_entry.pack(fill=tk.X, ipady=18)
        
        # === Options Card ===
        self.options_card = self.create_card(self.control_frame, "Options", "🎛️")
        
        # Custom large checkboxes
        self.check_widgets = []
        
        self.coverage_check_frame = self.create_custom_checkbox(
            self.options_card, "Generate Coverage Report", self.coverage_var)
        self.coverage_check_frame.pack(anchor=tk.W, pady=12, fill=tk.X)
        
        self.modern_check_frame = self.create_custom_checkbox(
            self.options_card, "Modern HTML Report", self.modern_report_var)
        self.modern_check_frame.pack(anchor=tk.W, pady=12, fill=tk.X)
        
        self.gui_check_frame = self.create_custom_checkbox(
            self.options_card, "GUI Mode (QuestaSim)", self.gui_mode_var)
        self.gui_check_frame.pack(anchor=tk.W, pady=12, fill=tk.X)
        
        # === Action Buttons ===
        self.btn_frame = tk.Frame(self.control_frame)
        self.btn_frame.pack(fill=tk.X, pady=(40, 0))
        
        self.run_btn = tk.Button(self.btn_frame,
                                 text="▶   RUN TEST",
                                 font=("Segoe UI", self.FONT_BUTTON_LARGE, "bold"),
                                 bd=0, pady=28,
                                 cursor="hand2",
                                 command=self.run_test)
        self.run_btn.pack(fill=tk.X, pady=(0, 18))
        
        self.stop_btn = tk.Button(self.btn_frame,
                                  text="■   STOP",
                                  font=("Segoe UI", self.FONT_BUTTON_MEDIUM, "bold"),
                                  bd=0, pady=24,
                                  state=tk.DISABLED,
                                  cursor="hand2",
                                  command=self.stop_test)
        self.stop_btn.pack(fill=tk.X)
        
        # === Quick Actions Card ===
        self.actions_card = self.create_card(self.control_frame, "Quick Actions", "⚡")
        
        actions = [
            ("📂   Open Logs Folder", self.open_logs),
            ("📊   Coverage Report", self.open_coverage),
            ("🎯   Project Demo", self.open_docs),
        ]
        
        for text, cmd in actions:
            btn = tk.Button(self.actions_card, text=text,
                           font=("Segoe UI", self.FONT_BUTTON_SMALL),
                           bd=0, pady=18,
                           cursor="hand2",
                           anchor=tk.W, padx=30,
                           command=cmd)
            btn.pack(fill=tk.X, pady=6)
            
    def create_label(self, parent, text):
        """Create a styled label."""
        label = tk.Label(parent, text=text, 
                        font=("Segoe UI", self.FONT_LABEL, "bold"))
        label.pack(anchor=tk.W, pady=(0, 12))
        return label
        
    def create_custom_checkbox(self, parent, text, variable):
        """Create a custom large checkbox."""
        frame = tk.Frame(parent, cursor="hand2")
        
        # Large checkbox indicator using a label
        indicator = tk.Label(frame, text="☐", font=("Segoe UI", 22),
                            cursor="hand2")
        indicator.pack(side=tk.LEFT, padx=(0, 15))
        
        # Text label
        text_label = tk.Label(frame, text=text, 
                             font=("Segoe UI", self.FONT_CHECKBOX),
                             cursor="hand2")
        text_label.pack(side=tk.LEFT)
        
        # Store references
        frame.indicator = indicator
        frame.text_label = text_label
        frame.variable = variable
        
        # Update function
        def update_indicator(*args):
            if variable.get():
                indicator.configure(text="☑")
            else:
                indicator.configure(text="☐")
        
        # Toggle function
        def toggle(event=None):
            variable.set(not variable.get())
            update_indicator()
        
        # Bind clicks
        frame.bind("<Button-1>", toggle)
        indicator.bind("<Button-1>", toggle)
        text_label.bind("<Button-1>", toggle)
        
        # Initial state
        update_indicator()
        
        # Track variable changes
        variable.trace_add("write", update_indicator)
        
        # Store for theming
        self.check_widgets.append(frame)
        
        return frame
            
    def create_card(self, parent, title, icon=""):
        """Create a card with title."""
        card = tk.Frame(parent, pady=35, padx=35)
        card.pack(fill=tk.X, pady=(0, 30))
        
        # Header with icon
        header = tk.Frame(card)
        header.pack(fill=tk.X, pady=(0, 25))
        
        title_text = f"{icon}   {title}" if icon else title
        title_label = tk.Label(header, text=title_text,
                               font=("Segoe UI", self.FONT_CARD_HEADER, "bold"))
        title_label.pack(anchor=tk.W)
        
        return card
        
    def create_output_panel(self):
        """Create the output/console panel."""
        self.output_frame = tk.Frame(self.content_frame)
        self.output_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Console card
        self.console_card = tk.Frame(self.output_frame, pady=35, padx=35)
        self.console_card.pack(fill=tk.BOTH, expand=True)
        
        # Header
        header = tk.Frame(self.console_card)
        header.pack(fill=tk.X, pady=(0, 30))
        
        title_label = tk.Label(header, text="💻   Console Output",
                              font=("Segoe UI", self.FONT_CARD_HEADER, "bold"))
        title_label.pack(side=tk.LEFT)
        
        self.clear_btn = tk.Button(header, text="Clear",
                                   font=("Segoe UI", self.FONT_BUTTON_SMALL),
                                   bd=0, padx=30, pady=12,
                                   cursor="hand2",
                                   command=self.clear_output)
        self.clear_btn.pack(side=tk.RIGHT)
        
        # Console
        console_container = tk.Frame(self.console_card)
        console_container.pack(fill=tk.BOTH, expand=True)
        
        self.console = scrolledtext.ScrolledText(
            console_container,
            font=("Consolas", self.FONT_CONSOLE),
            wrap=tk.WORD,
            state=tk.DISABLED,
            bd=0,
            padx=30,
            pady=30
        )
        self.console.pack(fill=tk.BOTH, expand=True)
        
        # Configure tags - matching modern report colors
        self.console.tag_configure("info", foreground="#60a5fa")     # Blue
        self.console.tag_configure("success", foreground="#34d399")  # Emerald
        self.console.tag_configure("error", foreground="#f87171")    # Coral red
        self.console.tag_configure("warning", foreground="#fbbf24") # Amber
        self.console.tag_configure("header", foreground="#818cf8",  # Indigo
                                  font=("Consolas", self.FONT_CONSOLE, "bold"))
        
    def create_status_bar(self):
        """Create the status bar."""
        self.status_frame = tk.Frame(self.main_frame, height=120)
        self.status_frame.pack(fill=tk.X)
        self.status_frame.pack_propagate(False)
        
        inner = tk.Frame(self.status_frame)
        inner.pack(fill=tk.BOTH, expand=True, padx=60)
        
        # Left side: Status
        left = tk.Frame(inner)
        left.pack(side=tk.LEFT, fill=tk.Y)
        
        self.status_dot = tk.Label(left, text="●", font=("Segoe UI", 22))
        self.status_dot.pack(side=tk.LEFT, pady=30)
        
        self.status_label = tk.Label(left, text="Ready to run",
                                     font=("Segoe UI", self.FONT_STATUS))
        self.status_label.pack(side=tk.LEFT, padx=(25, 0), pady=30)
        
        # Right side: Timer
        self.time_label = tk.Label(inner, text="",
                                   font=("Segoe UI", self.FONT_STATUS, "bold"))
        self.time_label.pack(side=tk.RIGHT, pady=30)
        
    def apply_theme(self):
        """Apply current theme colors."""
        theme = 'dark' if self.dark_mode.get() else 'light'
        c = self.themes[theme]
        
        try:
            # Update theme button icon
            self.theme_btn.configure(text="☀️" if self.dark_mode.get() else "🌙")
        
            # Root and main frames
            self.root.configure(bg=c['bg_primary'])
            self.main_frame.configure(bg=c['bg_primary'])
            self.header_frame.configure(bg=c['bg_secondary'])
            self.content_frame.configure(bg=c['bg_primary'])
            self.control_outer.configure(bg=c['bg_primary'])
            self.control_canvas.configure(bg=c['bg_primary'])
            self.control_frame.configure(bg=c['bg_primary'])
            self.output_frame.configure(bg=c['bg_primary'])
            self.status_frame.configure(bg=c['bg_secondary'])
            
            # Header widgets
            for widget in self.header_frame.winfo_children():
                self._apply_bg_recursive(widget, c['bg_secondary'])
                
            # CPM and title text - accent color for CPM
            self.cpm_label.configure(bg=c['bg_secondary'], fg=c['accent'])
            self.sep_label.configure(bg=c['bg_secondary'], fg=c['text_primary'])
            self.title_label.configure(bg=c['bg_secondary'], fg=c['text_primary'])
            self.center_frame.configure(bg=c['bg_secondary'])
            self.subtitle_label.configure(bg=c['bg_secondary'], fg=c['text_muted'])
            
            # Theme toggle container and button (including spacers)
            self.toggle_container.configure(bg=c['bg_secondary'])
            for child in self.toggle_container.winfo_children():
                try:
                    child.configure(bg=c['bg_secondary'])
                except:
                    pass
            self.theme_btn.configure(bg=c['bg_card'], fg=c['text_primary'],
                                    activebackground=c['bg_hover'])
            
            # Stat badges - ensure labels are visible
            self.stats_frame.configure(bg=c['bg_secondary'])
            for badge, val_lbl, lbl_lbl, color in self.stat_widgets:
                badge.configure(bg=c['bg_secondary'])
                val_lbl.configure(bg=c['bg_secondary'], fg=color)
                # Use white for dark mode, black for light mode  
                if self.dark_mode:
                    lbl_lbl.configure(bg=c['bg_secondary'], fg='#ffffff')
                else:
                    lbl_lbl.configure(bg='#ffffff', fg='#000000')
            
            # Cards - set ALL label colors to bright text
            for card in [self.config_card, self.options_card, self.actions_card]:
                card.configure(bg=c['bg_card'])
                self._apply_card_theme(card, c)
                        
            self.console_card.configure(bg=c['bg_card'])
            self._apply_card_theme(self.console_card, c)
            
            # Input fields
            self.timeout_entry.configure(bg=c['bg_input'], fg=c['text_primary'],
                                         insertbackground=c['text_primary'],
                                         highlightbackground=c['border'],
                                         highlightcolor=c['accent'])
            self.seed_entry.configure(bg=c['bg_input'], fg=c['text_primary'],
                                      insertbackground=c['text_primary'],
                                      highlightbackground=c['border'],
                                      highlightcolor=c['accent'])
            
            # Combobox colors
            style = ttk.Style()
            style.map('Large.TCombobox', 
                     fieldbackground=[('readonly', c['bg_input'])],
                     selectbackground=[('readonly', c['accent'])],
                     selectforeground=[('readonly', 'white')])
            
            # Update listbox colors
            self.root.option_add('*TCombobox*Listbox.background', c['bg_input'])
            self.root.option_add('*TCombobox*Listbox.foreground', c['text_primary'])
            
            # Custom checkboxes
            for check_frame in self.check_widgets:
                check_frame.configure(bg=c['bg_card'])
                check_frame.indicator.configure(bg=c['bg_card'], fg=c['accent'])
                check_frame.text_label.configure(bg=c['bg_card'], fg=c['text_primary'])
            
            # Run button
            self.run_btn.configure(bg=c['accent'], fg='white',
                                  activebackground=c['accent_hover'],
                                  activeforeground='white')
            
            # Stop button
            self.stop_btn.configure(bg=c['bg_input'], fg=c['text_muted'],
                                   activebackground=c['bg_hover'],
                                   disabledforeground=c['text_muted'])
            
            # Quick action buttons
            for child in self.actions_card.winfo_children():
                if isinstance(child, tk.Button):
                    child.configure(bg=c['bg_input'], fg=c['text_primary'],
                                   activebackground=c['bg_hover'])
            
            # Clear button
            self.clear_btn.configure(bg=c['bg_input'], fg=c['text_primary'],
                                    activebackground=c['bg_hover'])
            
            # Console
            self.console.configure(bg=c['console_bg'], fg=c['console_fg'],
                                  insertbackground=c['console_fg'])
            
            # Status bar
            for widget in self.status_frame.winfo_children():
                self._apply_bg_recursive(widget, c['bg_secondary'])
            self.status_label.configure(fg=c['text_secondary'])
            self.time_label.configure(fg=c['accent'])
            self._update_status_dot()
            
            # Button frame in control panel
            self.btn_frame.configure(bg=c['bg_primary'])
            
            # FINAL: Force stat label colors (must be last to avoid overrides)
            stat_labels = ["TESTS", "PASS", "COVERAGE"]
            for i, (badge, val_lbl, lbl_lbl, color) in enumerate(self.stat_widgets):
                # Background matches header, text color contrasts
                lbl_lbl.configure(text=stat_labels[i], 
                                 bg=c['bg_secondary'],
                                 fg='#ffffff' if self.dark_mode else '#111827',
                                 font=("Segoe UI", self.FONT_STAT_LABEL, "bold"))
                    
        except Exception as e:
            print(f"Theme error: {e}")
        
    def _apply_bg_recursive(self, widget, bg_color):
        """Apply background color recursively."""
        try:
            widget.configure(bg=bg_color)
        except:
            pass
        for child in widget.winfo_children():
            self._apply_bg_recursive(child, bg_color)
            
    def _apply_card_theme(self, card, colors):
        """Apply theme to a card and all its children."""
        card.configure(bg=colors['bg_card'])
        for child in card.winfo_children():
            try:
                child.configure(bg=colors['bg_card'])
            except:
                pass
            # Set label text to bright color
            if isinstance(child, tk.Label):
                child.configure(fg=colors['text_primary'], bg=colors['bg_card'])
            # Recurse into frames
            if isinstance(child, tk.Frame):
                self._apply_card_theme(child, colors)
                
    def _on_control_configure(self, event):
        """Update scroll region when control frame changes size."""
        self.control_canvas.configure(scrollregion=self.control_canvas.bbox("all"))
        
    def _on_mousewheel(self, event):
        """Handle mouse wheel scrolling."""
        # Only scroll if mouse is over control panel
        x, y = self.root.winfo_pointerxy()
        widget = self.root.winfo_containing(x, y)
        if widget:
            # Check if widget is in control panel hierarchy
            parent = widget
            while parent:
                if parent == self.control_outer:
                    self.control_canvas.yview_scroll(int(-1*(event.delta/120)), "units")
                    break
                try:
                    parent = parent.master
                except:
                    break
            
    def _update_status_dot(self):
        """Update status dot color."""
        c = self.themes['dark' if self.dark_mode.get() else 'light']
        color = c['warning'] if self.running else c['success']
        self.status_dot.configure(fg=color)
        
    def toggle_theme(self):
        """Toggle between light and dark theme."""
        self.dark_mode.set(not self.dark_mode.get())
        self.apply_theme()
        
    def log(self, message, tag=None):
        """Log a message to the console."""
        try:
            self.console.configure(state=tk.NORMAL)
            if tag:
                self.console.insert(tk.END, message + "\n", tag)
            else:
                self.console.insert(tk.END, message + "\n")
            self.console.see(tk.END)
            self.console.configure(state=tk.DISABLED)
        except tk.TclError:
            pass
            
    def clear_output(self):
        """Clear the console output."""
        self.console.configure(state=tk.NORMAL)
        self.console.delete(1.0, tk.END)
        self.console.configure(state=tk.DISABLED)
        
    def set_status(self, status):
        """Update status bar."""
        self.status_label.configure(text=status)
        self._update_status_dot()
        
    def run_test(self):
        """Run the selected test."""
        if self.running:
            return
            
        self.running = True
        c = self.themes['dark' if self.dark_mode.get() else 'light']
        
        self.run_btn.configure(state=tk.DISABLED, bg=c['text_muted'])
        self.stop_btn.configure(state=tk.NORMAL, bg=c['error'], fg='white')
        
        # Get settings
        test_name = self.test_var.get()
        timeout = self.timeout_var.get()
        seed = self.seed_var.get()
        
        # Build command
        cmd = ["python", str(self.run_script), "--test", test_name]
        
        if timeout and timeout.isdigit():
            cmd.extend(["--timeout", timeout])
            
        if seed and seed != "random" and seed.isdigit():
            cmd.extend(["--seed", seed])
            
        if self.coverage_var.get():
            cmd.append("--coverage-report")
            
        if self.modern_report_var.get():
            cmd.append("--modern-report")
            
        if self.gui_mode_var.get():
            cmd.append("--gui")
        
        self.clear_output()
        self.log("━" * 60, "header")
        self.log(f"   CPM VERIFICATION SUITE  ─  {test_name}", "header")
        self.log("━" * 60, "header")
        self.log("")
        self.log(f"   Command:  {' '.join(cmd)}", "info")
        self.log(f"   Started:  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "info")
        self.log("")
        
        self.set_status(f"Running {test_name}...")
        self.start_time = datetime.now()
        
        # Clear queue
        while not self.output_queue.empty():
            try:
                self.output_queue.get_nowait()
            except queue.Empty:
                break
        
        # Run in thread
        thread = threading.Thread(target=self.execute_test, args=(cmd,))
        thread.daemon = True
        thread.start()
        
        # Start polling
        self.root.after(50, self.poll_output)
        self.update_timer()
        
    def execute_test(self, cmd):
        """Execute the test command."""
        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=str(self.project_root),
                text=True,
                bufsize=1,
                encoding='utf-8',
                errors='replace'  # Handle QuestaSim's special characters
            )
            
            for line in iter(self.process.stdout.readline, ''):
                if not self.running:
                    break
                self.output_queue.put(('line', line.rstrip()))
                time.sleep(0.001)
                
            self.process.wait()
            
            if self.running:
                success = self.process.returncode == 0
                self.output_queue.put(('done', success))
                    
        except Exception as e:
            self.output_queue.put(('error', str(e)))
    
    def poll_output(self):
        """Poll output queue."""
        try:
            while True:
                try:
                    msg_type, data = self.output_queue.get_nowait()
                    if msg_type == 'line':
                        self.process_line(data)
                    elif msg_type == 'done':
                        self.test_complete(data)
                        return
                    elif msg_type == 'error':
                        self.log(f"   Error: {data}", "error")
                        self.test_complete(False)
                        return
                except queue.Empty:
                    break
        except Exception:
            pass
        
        if self.running:
            self.root.after(50, self.poll_output)
            
    def process_line(self, line):
        """Process output line with coloring."""
        if not self.running:
            return
        try:
            lower = line.lower()
            if "error" in lower or "fatal" in lower:
                self.log(f"   {line}", "error")
            elif "warning" in lower:
                self.log(f"   {line}", "warning")
            elif "pass" in lower or "success" in lower or "complete" in lower:
                self.log(f"   {line}", "success")
            elif "info" in lower or "---" in line or "===" in line:
                self.log(f"   {line}", "info")
            else:
                self.log(f"   {line}")
        except Exception:
            pass
            
    def test_complete(self, success):
        """Handle test completion."""
        self.running = False
        self.process = None
        c = self.themes['dark' if self.dark_mode.get() else 'light']
        
        try:
            elapsed = datetime.now() - self.start_time
            elapsed_str = f"{elapsed.seconds}s"
            
            self.log("")
            if success:
                self.log("━" * 60, "success")
                self.log(f"   ✓  TEST COMPLETED SUCCESSFULLY  ({elapsed_str})", "success")
                self.log("━" * 60, "success")
                self.set_status(f"Completed successfully  •  {elapsed_str}")
            else:
                self.log("━" * 60, "error")
                self.log(f"   ✗  TEST FAILED  ({elapsed_str})", "error")
                self.log("━" * 60, "error")
                self.set_status(f"Failed  •  {elapsed_str}")
                
            self.run_btn.configure(state=tk.NORMAL, bg=c['accent'])
            self.stop_btn.configure(state=tk.DISABLED, bg=c['bg_input'], fg=c['text_muted'])
        except Exception:
            pass
            
    def stop_test(self):
        """Stop running test."""
        if self.process:
            self.running = False
            self.process.terminate()
            self.log("\n   ─── Test stopped by user ───", "warning")
            self.set_status("Stopped")
            
        c = self.themes['dark' if self.dark_mode.get() else 'light']
        self.run_btn.configure(state=tk.NORMAL, bg=c['accent'])
        self.stop_btn.configure(state=tk.DISABLED, bg=c['bg_input'], fg=c['text_muted'])
        
    def update_timer(self):
        """Update elapsed time."""
        if self.running and self.start_time:
            elapsed = datetime.now() - self.start_time
            mins = elapsed.seconds // 60
            secs = elapsed.seconds % 60
            if mins > 0:
                self.time_label.configure(text=f"⏱  {mins}m {secs}s")
            else:
                self.time_label.configure(text=f"⏱  {secs}s")
            self.root.after(1000, self.update_timer)
        else:
            self.time_label.configure(text="")
            
    def open_logs(self):
        """Open logs folder."""
        logs_path = self.project_root / "logs"
        logs_path.mkdir(exist_ok=True)
        os.startfile(str(logs_path))
        
    def open_coverage(self):
        """Open coverage report."""
        report_path = self.project_root / "deliverables" / "modern_report.html"
        if report_path.exists():
            os.startfile(str(report_path))
        else:
            messagebox.showinfo("Coverage Report", 
                              "No coverage report found.\n\nRun a test with 'Modern HTML Report' enabled.")
            
    def open_docs(self):
        """Open documentation."""
        docs_path = self.project_root / "deliverables" / "project_demo.html"
        if docs_path.exists():
            os.startfile(str(docs_path))
        else:
            messagebox.showinfo("Documentation", "Documentation not found.\n\nExpected: docs/project_demo.html")


def main():
    root = tk.Tk()
    
    # DPI awareness on Windows
    try:
        from ctypes import windll
        windll.shcore.SetProcessDpiAwareness(2)
    except:
        pass
    
    app = PremiumTestRunner(root)
    root.mainloop()


if __name__ == "__main__":
    main()
