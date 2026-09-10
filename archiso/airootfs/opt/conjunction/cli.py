#!/usr/bin/env python3
"""
cj - Conjunction OS Command-Line Utility

A simplified interface for system management, abstracting Linux complexity
behind macOS-like simple commands. Built for the Conjunction OS ecosystem.

Commands:
    update   - Full system update (pacman, Flatpak, Wine, AUR)
    install  - Install apps from package names or .exe/.msi paths
    optimize - System performance tuning (GPU, CPU, memory)
    status   - Display system information and health
    apps     - Manage installed sandboxed applications
"""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import textwrap
import threading
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional, Any

try:
    from engine import ConjunctionAPI, get_user_home, redact_sensitive_info
except ImportError:
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    from engine import ConjunctionAPI, get_user_home, redact_sensitive_info

VERSION = "1.0.0"
PROGRAM_NAME = "cj"
PROGRAM_DESCRIPTION = "Conjunction OS - Simplified system management"

# ANSI color codes for terminal output
class Colors:
    """ANSI escape codes for colored terminal output."""
    RESET = "\033[0m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    BOLD = "\033[1m"
    DIM = "\033[2m"


def _colored(text: str, color: str) -> str:
    """Wrap text in ANSI color codes for terminal output.
    
    Args:
        text: The text to colorize.
        color: One of Colors class attributes (e.g., Colors.GREEN).
    
    Returns:
        Color-wrapped text string, or plain text if no TTY.
    """
    if not sys.stdout.isatty():
        return text
    return f"{color}{text}{Colors.RESET}"


def _confirm(message: str) -> bool:
    """Prompt user for Y/N confirmation.
    
    Args:
        message: The confirmation prompt message.
    
    Returns:
        True if user confirms, False otherwise.
    """
    try:
        response = input(f"{message} [y/N]: ").strip().lower()
        return response in ("y", "yes")
    except (EOFError, KeyboardInterrupt):
        print()
        return False


class Spinner:
    """Animated terminal spinner for long-running operations.
    
    Usage:
        with Spinner("Updating packages..."):
            long_running_operation()
    """
    
    FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    INTERVAL = 0.08
    
    def __init__(self, message: str = "", color: str = Colors.CYAN):
        """Initialize the spinner.
        
        Args:
            message: Text to display beside the spinner.
            color: ANSI color code for the spinner animation.
        """
        self.message = message
        self.color = color
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None
    
    def _animate(self) -> None:
        """Run the spinner animation in a background thread."""
        idx = 0
        while not self._stop_event.is_set():
            frame = self.FRAMES[idx % len(self.FRAMES)]
            sys.stdout.write(f"\r{self.color}{frame}{Colors.RESET} {self.message}  ")
            sys.stdout.flush()
            idx += 1
            self._stop_event.wait(self.INTERVAL)
        # Clear the spinner line
        sys.stdout.write("\r" + " " * (len(self.message) + 10) + "\r")
        sys.stdout.flush()
    
    def __enter__(self) -> "Spinner":
        """Start the spinner animation."""
        if sys.stdout.isatty():
            self._thread = threading.Thread(target=self._animate, daemon=True)
            self._thread.start()
        return self
    
    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        """Stop the spinner animation."""
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=1.0)


@dataclass
class CommandResult:
    """Result of a shell command execution."""
    returncode: int
    stdout: str
    stderr: str
    success: bool = field(init=False)
    
    def __post_init__(self) -> None:
        """Derive success flag from return code."""
        self.success = self.returncode == 0


class ConjunctionCLI:
    """Main CLI class for Conjunction OS system management.
    
    Provides commands for system updates, application installation,
    performance optimization, and system status reporting.
    """
    
    SNAPSHOTS_DIR = "/etc/snapper/configs"
    WINE_PREFIX = str(get_user_home() / ".conjunction" / "prefixes")
    APPS_DIR = str(get_user_home() / ".conjunction" / "apps")
    DESKTOP_DIR = get_user_home() / ".local" / "share" / "applications"
    ICONS_DIR = get_user_home() / ".local" / "share" / "icons"
    
    def __init__(self, args: argparse.Namespace, session_id: str) -> None:
        """Initialize the CLI with parsed arguments.
        
        Args:
            args: Parsed argparse namespace.
            session_id: UUID session correlation ID.
        """
        self.args = args
        self.verbose = getattr(args, "verbose", False)
        self.quiet = getattr(args, "quiet", False)
        self.dry_run = getattr(args, "dry_run", False)
        self.session_id = session_id
        self.api = ConjunctionAPI(session_id=session_id)
    
    # ------------------------------------------------------------------ #
    #  Helper Utilities                                                    #
    # ------------------------------------------------------------------ #
    
    def _log(self, message: str, color: str = Colors.RESET) -> None:
        """Print a colored message to stdout (unless quiet).
        
        Args:
            message: The message to print.
            color: ANSI color code to apply.
        """
        if not self.quiet:
            print(_colored(message, color))
    
    def _info(self, message: str) -> None:
        """Print an informational message (blue)."""
        self._log(message, Colors.BLUE)
    
    def _success(self, message: str) -> None:
        """Print a success message (green)."""
        self._log(f"✓ {message}", Colors.GREEN)
    
    def _warning(self, message: str) -> None:
        """Print a warning message (yellow)."""
        self._log(f"⚠ {message}", Colors.YELLOW)
    
    def _error(self, message: str) -> None:
        """Print an error message (red)."""
        self._log(f"✗ {message}", Colors.RED)
    
    def _verbose(self, message: str) -> None:
        """Print a debug message only in verbose mode."""
        if self.verbose:
            self._log(f"  {Colors.DIM}{message}{Colors.RESET}")
    
    def _run_command(
        self,
        cmd: list[str] | str,
        sudo: bool = False,
        timeout: int = 300,
        capture: bool = True,
    ) -> CommandResult:
        """Execute a shell command with optional sudo and timeout.
        
        Args:
            cmd: Command as a list of args or a string (shell=True).
            sudo: Whether to prepend sudo to the command.
            timeout: Maximum execution time in seconds.
            capture: Whether to capture stdout/stderr.
        
        Returns:
            CommandResult with returncode, stdout, stderr, and success flag.
        """
        if isinstance(cmd, str):
            cmd_list = cmd.split()
        else:
            cmd_list = list(cmd)
        
        if sudo:
            cmd_list = ["sudo"] + cmd_list
        
        cmd_str = " ".join(cmd_list)
        self._verbose(f"Running: {cmd_str}")
        
        if self.dry_run:
            self._info(f"[dry-run] {cmd_str}")
            return CommandResult(returncode=0, stdout="", stderr="")
        
        try:
            result = subprocess.run(
                cmd_list,
                capture_output=capture,
                text=True,
                timeout=timeout,
                check=False,
            )
            return CommandResult(
                returncode=result.returncode,
                stdout=result.stdout or "",
                stderr=result.stderr or "",
            )
        except subprocess.TimeoutExpired:
            self._error(f"Command timed out after {timeout}s: {cmd_str}")
            return CommandResult(
                returncode=-1,
                stdout="",
                stderr=f"Command timed out after {timeout}s",
            )
        except FileNotFoundError:
            self._error(f"Command not found: {cmd_list[0]}")
            return CommandResult(
                returncode=-1,
                stdout="",
                stderr=f"Command not found: {cmd_list[0]}",
            )
        except PermissionError:
            self._error("Permission denied. Try running with sudo.")
            return CommandResult(
                returncode=-1,
                stdout="",
                stderr="Permission denied",
            )
            
    def _run_as_user(
        self,
        cmd: list[str] | str,
        timeout: int = 300,
        capture: bool = True,
    ) -> CommandResult:
        """Run a command as the original logged-in user if running under sudo."""
        if isinstance(cmd, str):
            cmd_list = cmd.split()
        else:
            cmd_list = list(cmd)
            
        sudo_user = os.environ.get("SUDO_USER")
        if sudo_user and hasattr(os, "getuid") and os.getuid() == 0:
            cmd_list = ["sudo", "-u", sudo_user] + cmd_list
            
        return self._run_command(cmd_list, sudo=False, timeout=timeout, capture=capture)
    
    def _check_dependencies(self) -> bool:
        """Verify that required system tools are installed.
        
        Returns:
            True if all critical dependencies are available.
        """
        required = ["pacman", "flatpak"]
        optional = ["yay", "snapper", "cpupower", "nvidia-settings"]
        
        missing_required = []
        missing_optional = []
        
        for cmd in required:
            if not shutil.which(cmd):
                missing_required.append(cmd)
        
        for cmd in optional:
            if not shutil.which(cmd):
                missing_optional.append(cmd)
        
        if missing_required:
            self._error(f"Missing required tools: {', '.join(missing_required)}")
            return False
        
        if missing_optional and self.verbose:
            self._warning(f"Optional tools not found: {', '.join(missing_optional)}")
        
        return True
    
    def _is_exe_or_msi(self, path: str) -> bool:
        """Check if a path points to a .exe or .msi file.
        
        Args:
            path: The file path to check.
        
        Returns:
            True if the path is a Windows executable or installer.
        """
        lower = path.lower()
        return lower.endswith(".exe") or lower.endswith(".msi")
    
    def _get_app_disk_size(self, app_path: str) -> str:
        """Calculate the disk usage of an application directory.
        
        Args:
            app_path: Path to the application directory.
        
        Returns:
            Human-readable size string (e.g., "1.2G", "450M").
        """
        if self.dry_run:
            return "N/A (dry-run)"
        
        try:
            result = subprocess.run(
                ["du", "-sh", app_path],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode == 0:
                return result.stdout.split()[0]
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        return "unknown"
    
    # ------------------------------------------------------------------ #
    #  Commands                                                            #
    # ------------------------------------------------------------------ #
    
    def cmd_update(self) -> int:
        """Execute a full system update across all package managers."""
        self._info("═══════════════════════════════════════")
        self._info(" Conjunction OS — System Update")
        self._info("═══════════════════════════════════════")
        print()
        
        if not self._check_dependencies():
            return 1

        def log_callback(msg, step=None):
            if step == 1:
                if "created" in msg.lower():
                    self._success(msg)
                elif "failed" in msg.lower() or "warning" in msg.lower():
                    self._warning(msg)
                else:
                    self._info(msg)
            elif step == 2:
                if "updated successfully" in msg.lower():
                    self._success(msg)
                elif "failed" in msg.lower():
                    self._error(msg)
                else:
                    self._info(msg)
            elif step == 3:
                if "updated" in msg.lower():
                    self._success(msg)
                else:
                    self._warning(msg)
            elif step == 4:
                if "updated" in msg.lower() and "wine prefix" not in msg.lower():
                    self._success(msg)
                else:
                    self._info(msg)
            elif step == 5:
                if "updated" in msg.lower():
                    self._success(msg)
                else:
                    self._warning(msg)
            else:
                self._info(msg)

        if self.dry_run:
            self._info("[dry-run] Would execute full system update (pacman, flatpak, wineboot, yay)")
            return 0

        with Spinner("Updating system..."):
            report = self.api.update(log_cb=log_callback)
            
        print()
        if report.get("success"):
            self._success("Update Complete!")
            return 0
        else:
            self._error("Update failed")
            return 1

    def cmd_install(self, app_name_or_path: str) -> int:
        """Install an application from a package name or .exe/.msi path."""
        self._info("═══════════════════════════════════════")
        self._info(f" Conjunction OS — Installing: {app_name_or_path}")
        self._info("═══════════════════════════════════════")
        print()
        
        force = getattr(self.args, "force", False)
        
        if self._is_exe_or_msi(app_name_or_path):
            if not os.path.isfile(app_name_or_path):
                self._error(f"File not found: {app_name_or_path}")
                return 1
            installer_path = os.path.abspath(app_name_or_path)
            if self.dry_run:
                self._info(f"[dry-run] Would install Windows app from {installer_path}")
                return 0
            try:
                with Spinner(f"Installing {Path(installer_path).name} via ConjunctionRunner..."):
                    metadata = self.api.install(installer_path)
                self._success(f"Successfully installed '{metadata['name']}'")
                if metadata.get("desktop_entry"):
                    self._info(f"Created desktop entry: {metadata['desktop_entry']}")
                return 0
            except Exception as exc:
                self._error(f"Installation failed: {exc}")
                return 1
        else:
            package_name = app_name_or_path
            self._info("Searching Flatpak repositories...")
            if self.dry_run:
                self._info(f"[dry-run] Would search and install '{package_name}' from Flatpak")
            else:
                with Spinner(f"Looking for {package_name} in Flatpak..."):
                    flatpak_match = self.api.search_flatpak(package_name)
                if flatpak_match:
                    self._info(f"Found in Flatpak as {flatpak_match}")
                    with Spinner(f"Installing {flatpak_match} from Flatpak..."):
                        success = self.api.install_flatpak(flatpak_match, force)
                    if success:
                        self._success(f"Installed {flatpak_match} from Flatpak")
                        return 0
                    self._warning("Flatpak installation failed, trying next source...")
                    
            self._info("Searching pacman repositories...")
            if self.dry_run:
                self._info(f"[dry-run] Would search and install '{package_name}' from pacman")
            else:
                found = self.api.search_pacman(package_name)
                if found:
                    self._info(f"Found {package_name} in official repositories")
                    with Spinner(f"Installing {package_name} from pacman..."):
                        success = self.api.install_pacman(package_name, force)
                    if success:
                        self._success(f"Installed {package_name} from pacman")
                        return 0
                    self._warning("pacman installation failed, trying AUR...")
                    
            self._info("Searching AUR...")
            if self.dry_run:
                self._info(f"[dry-run] Would search and install '{package_name}' from AUR")
            else:
                found = self.api.search_aur(package_name)
                if found:
                    self._info(f"Found {package_name} in AUR")
                    with Spinner(f"Building and installing {package_name} from AUR..."):
                        success = self.api.install_aur(package_name)
                    if success:
                        self._success(f"Installed {package_name} from AUR")
                        return 0
                        
            self._error(f"Package '{package_name}' not found in any repository")
            return 1

    def cmd_optimize(self) -> int:
        """Optimize system performance settings."""
        self._info("═══════════════════════════════════════")
        self._info(" Conjunction OS — Performance Optimization")
        self._info("═══════════════════════════════════════")
        print()
        
        gpu_only = getattr(self.args, "gpu_only", False)
        cpu_only = getattr(self.args, "cpu_only", False)
        memory_only = getattr(self.args, "memory_only", False)
        
        self._info("── Current System Stats ──")
        self._show_system_stats()
        print()
        
        def log_cb(msg):
            if "flushed" in msg.lower() or "set to" in msg.lower() or "optimized" in msg.lower() or "enabled" in msg.lower():
                self._success(msg)
            elif "failed" in msg.lower() or "could not" in msg.lower():
                self._warning(msg)
            else:
                self._info(msg)
                
        self.api.optimize(gpu_only=gpu_only, cpu_only=cpu_only, memory_only=memory_only, dry_run=self.dry_run, log_cb=log_cb)
        print()
        
        self._info("── Updated System Stats ──")
        self._show_system_stats()
        print()
        
        self._success("Optimization complete!")
        return 0

    def _show_system_stats(self) -> None:
        """Display current system statistics."""
        try:
            mem_result = self._run_command(["free", "-h"], timeout=5)
            if mem_result.success:
                for line in mem_result.stdout.strip().split("\n"):
                    self._info(f"  {line}")
        except Exception:
            pass
        try:
            load_result = self._run_command(["uptime"], timeout=5)
            if load_result.success:
                self._info(f"  {load_result.stdout.strip()}")
        except Exception:
            pass

    def cmd_status(self) -> int:
        """Display comprehensive system information and health status."""
        logo = r"""
  ____ ___  _   _    _ _   _ _   _  ____ _____ ___ ___  _   _    ___  ____  
 / ___/ _ \| \ | |  | | | | | \ | |/ ___|_   _|_ _/ _ \| \ | |  / _ \/ ___| 
| |  | | | |  \| |  | | | | |  \| | |     | |  | | | | |  \| | | | | \___ \ 
| |__| |_| | |\  |__| | |_| | |\  | |___  | |  | | |_| | |\  | | |_| |___) |
 \____\___/|_| \_(_)___\___/|_| \_|\____| |_| |___\___/|_| \_|  \___/|____/ 
"""
        print(_colored(logo, Colors.CYAN))
        self._info("═══════════════════════════════════════")
        self._info(" Conjunction OS — System Status")
        self._info("═══════════════════════════════════════")
        print()
        
        status = self.api.get_status()
        self._info(f"Kernel:        {status['kernel']}")
        self._info(f"Desktop:       {status['desktop']}")
        self._info(f"GPU Driver:    {status['gpu_driver']}")
        self._info(f"Wine:          {status['wine_version']}")
        self._info(f"Sandboxed:     {status['sandbox_count']} apps")
        self._info(f"Last Update:   {status['last_update']}")
        self._info(f"Snapshots:     {status['snapshot_count']}")
        self._info(f"Uptime:        {status['uptime']}")
        self._info(f"Wine Prefix:   {status['prefix_size']}")
        
        print()
        return 0

    def cmd_apps(self) -> int:
        """List installed sandboxed applications with details."""
        remove_app = getattr(self.args, "remove", None)
        
        if remove_app:
            return self._remove_app(remove_app)
        
        self._info("═══════════════════════════════════════")
        self._info(" Conjunction OS — Installed Apps")
        self._info("═══════════════════════════════════════")
        print()
        
        try:
            apps = self.api.list_apps()
            if not apps:
                self._warning("No applications installed yet")
                self._info("Install apps with: cj install <name_or_path>")
                return 0
                
            for app in apps:
                self._info(f"  {_colored(app['name'], Colors.BOLD)}")
                self._info(f"    GPU Passthrough: {app.get('gpu_vendor', 'unknown')}")
                self._info(f"    Installed:       {app.get('installed_at', 'unknown')[:10]}")
                if app.get("desktop_entry"):
                    self._info(f"    Desktop Entry:   {app['desktop_entry']}")
                print()
        except Exception as exc:
            self._error(f"Failed to list applications: {exc}")
            return 1
        
        return 0

    def _remove_app(self, app_name: str) -> int:
        """Remove a sandboxed application.
        
        Args:
            app_name: Name of the application to remove.
        
        Returns:
            0 on success, 1 on failure.
        """
        # Confirm removal
        if not self.dry_run:
            if not _confirm(f"Remove '{app_name}' and all its data?"):
                self._info("Aborted.")
                return 0
        
        self._info(f"Removing {app_name}...")
        
        try:
            runner = ConjunctionRunner()
            if self.dry_run:
                self._info(f"[dry-run] ConjunctionRunner().remove('{app_name}')")
                return 0
            runner.remove(app_name)
            self._success(f"Removed '{app_name}' successfully")
            return 0
        except Exception as exc:
            self._error(f"Failed to remove application: {exc}")
            return 1

    def cmd_export(self) -> int:
        """Export an application prefix to a .tar.zst package."""
        app_name = self.args.app_name
        output_path = self.args.output_path
        self._info("═══════════════════════════════════════")
        self._info(f" Conjunction OS — Export App: {app_name}")
        self._info("═══════════════════════════════════════")
        print()
        try:
            if self.dry_run:
                self._info(f"[dry-run] Would export app '{app_name}' to '{output_path}'")
                return 0
            with Spinner(f"Exporting application '{app_name}' to '{output_path}'..."):
                self.api.export_app(app_name, Path(output_path))
            self._success(f"Application '{app_name}' exported successfully.")
            return 0
        except Exception as exc:
            self._error(f"Failed to export application: {exc}")
            return 1

    def cmd_import(self) -> int:
        """Import an application prefix from a .tar.zst package."""
        input_path = self.args.input_path
        override_name = getattr(self.args, "override_app_name", None)
        self._info("═══════════════════════════════════════")
        self._info(f" Conjunction OS — Import App")
        self._info("═══════════════════════════════════════")
        print()
        try:
            if self.dry_run:
                self._info(f"[dry-run] Would import app from '{input_path}' with override_name={override_name}")
                return 0
            with Spinner(f"Importing application from '{input_path}'..."):
                metadata = self.api.import_app(Path(input_path), override_name)
            self._success(f"Application '{metadata['name']}' imported successfully.")
            return 0
        except Exception as exc:
            self._error(f"Failed to import application: {exc}")
            return 1

    def cmd_doctor(self) -> int:
        """Run system health checks and diagnostics."""
        self._info("═══════════════════════════════════════")
        self._info(" Conjunction OS — Doctor Health Check")
        self._info("═══════════════════════════════════════")
        print()
        if self.dry_run:
            self._info("[dry-run] Would run system health checks")
            return 0

        with Spinner("Running system diagnostics..."):
            report = self.api.doctor()
            
        critical_issues = []
        warnings = []
        
        for category, checks in report.items():
            self._info(f"── {category} ──")
            for check in checks:
                status = check["status"]
                name = check["name"]
                message = check["message"]
                
                if status == "OK":
                    self._success(f"{name}: {message}")
                elif status == "WARN":
                    self._warning(f"{name}: {message}")
                    warnings.append(f"{category} - {name}: {message}")
                else:
                    self._error(f"{name}: {message}")
                    critical_issues.append(f"{category} - {name}: {message}")
            print()
            
        if critical_issues:
            self._error(f"Doctor found {len(critical_issues)} critical issue(s):")
            for issue in critical_issues:
                self._error(f"  - {issue}")
            return 1
            
        if warnings:
            self._warning(f"Doctor found {len(warnings)} warning(s). Please review them.")
        else:
            self._success("System is healthy! No critical issues found.")
        return 0

    def cmd_bug_report(self) -> int:
        """Generate a system bug report tarball."""
        output_path = getattr(self.args, "output_path", None)
        self._info("═══════════════════════════════════════")
        self._info(" Conjunction OS — Bug Report")
        self._info("═══════════════════════════════════════")
        print()
        try:
            if self.dry_run:
                self._info(f"[dry-run] Would generate bug report")
                return 0
            with Spinner("Generating redacted bug report (.tar.zst)..."):
                report_path = self.api.bug_report(output_path, dry_run=self.dry_run)
            self._success(f"Bug report successfully generated: {report_path}")
            return 0
        except Exception as exc:
            self._error(f"Failed to generate bug report: {exc}")
            return 1

    def cmd_rollback(self) -> int:
        """Rollback snapper snapshot or prefix snapshot."""
        target = self.args.target
        snapshot_id = self.args.snapshot_id
        
        self._info("═══════════════════════════════════════")
        self._info(f" Conjunction OS — Rollback Target: {target} to {snapshot_id}")
        self._info("═══════════════════════════════════════")
        print()
        
        preview = self.api.get_rollback_preview(target, snapshot_id)
        if not preview:
            self._error(f"No snapshot found or metadata unavailable for target '{target}' and snapshot '{snapshot_id}'.")
            return 1
            
        self._info("── Rollback Preview Metadata ──")
        for k, v in preview.items():
            self._info(f"  {k:20}: {v}")
        print()
        
        if not self.dry_run:
            if not _confirm("Are you sure you want to perform this rollback? This action cannot be undone."):
                self._info("Rollback aborted.")
                return 0
                
        with Spinner(f"Rolling back '{target}' to '{snapshot_id}'..."):
            success = self.api.rollback(target, snapshot_id, dry_run=self.dry_run)
            
        if success:
            self._success(f"Successfully rolled back '{target}' to '{snapshot_id}'.")
            return 0
        else:
            self._error("Rollback failed.")
            return 1

    def cmd_repair(self) -> int:
        """Repair application prefix components."""
        app_name = self.args.app_name
        self._info("═══════════════════════════════════════")
        self._info(f" Conjunction OS — Repair App: {app_name}")
        self._info("═══════════════════════════════════════")
        print()
        try:
            if self.dry_run:
                self._info(f"[dry-run] Would repair application '{app_name}'")
                return 0
                
            def log_cb(msg):
                self._info(f"  {msg}")
                
            with Spinner(f"Repairing application '{app_name}'..."):
                success = self.api.repair_prefix(app_name, dry_run=self.dry_run, log_cb=log_cb)
                
            if success:
                self._success(f"Application '{app_name}' repaired successfully.")
                return 0
            else:
                self._error(f"Repairing application '{app_name}' failed.")
                return 1
        except Exception as exc:
            self._error(f"Failed to repair application: {exc}")
            return 1

    def cmd_cleanup(self) -> int:
        """Cleanup expired cache, log, and export files."""
        days = getattr(self.args, "days", 7)
        self._info("═══════════════════════════════════════")
        self._info(f" Conjunction OS — System Cleanup (Older than {days} days)")
        self._info("═══════════════════════════════════════")
        print()
        try:
            with Spinner("Scanning and cleaning system files..."):
                deleted = self.api.cleanup_system(days=days)
            
            total_deleted = sum(len(files) for files in deleted.values())
            if total_deleted > 0:
                for cat, files in deleted.items():
                    if files:
                        self._info(f"  Deleted {len(files)} {cat} files:")
                        for f in files:
                            print(f"    - {f}")
                self._success(f"Successfully cleaned {total_deleted} expired file(s).")
            else:
                self._info("  No expired files found to clean.")
            return 0
        except Exception as exc:
            self._error(f"Failed to run system cleanup: {exc}")
            return 1

    # ------------------------------------------------------------------ #
    #  Dispatch                                                            #
    # ------------------------------------------------------------------ #

    def run(self) -> int:
        """Dispatch to the appropriate command handler.
        
        Returns:
            Exit code from the executed command.
        """
        command = self.args.command
        
        if command == "update":
            return self.cmd_update()
        elif command == "install":
            return self.cmd_install(self.args.app_name_or_path)
        elif command == "optimize":
            return self.cmd_optimize()
        elif command == "status":
            return self.cmd_status()
        elif command == "apps":
            return self.cmd_apps()
        elif command == "doctor":
            return self.cmd_doctor()
        elif command == "rollback":
            return self.cmd_rollback()
        elif command == "export":
            return self.cmd_export()
        elif command == "import":
            return self.cmd_import()
        elif command == "bug-report":
            return self.cmd_bug_report()
        elif command == "repair":
            return self.cmd_repair()
        elif command == "cleanup":
            return self.cmd_cleanup()
        else:
            self._error(f"Unknown command: {command}")
            return 1


def build_parser() -> argparse.ArgumentParser:
    """Construct the argument parser with all subcommands and flags.
    
    Returns:
        Configured ArgumentParser instance.
    """
    parser = argparse.ArgumentParser(
        prog=PROGRAM_NAME,
        description=PROGRAM_DESCRIPTION,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              cj update                    Full system update
              cj install firefox           Install Firefox (Flatpak/pacman/AUR)
              cj install game.exe          Install Windows game via Wine
              cj optimize                  Full performance tuning
              cj status                    Show system information
              cj apps                      List installed apps
              cj apps --remove game        Remove an installed app
              cj doctor                    Diagnose system health
              cj rollback system 42        Roll back snapper snapshot
              cj export app prefix.tar.zst Package prefix
        """),
    )
    
    parser.add_argument(
        "--version",
        action="version",
        version=f"{PROGRAM_NAME} {VERSION}",
    )
    
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        default=False,
        help="Enable verbose output with detailed information",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        default=False,
        help="Suppress non-essential output",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Show commands without executing them",
    )
    
    subparsers = parser.add_subparsers(
        dest="command",
        help="Available commands",
        metavar="COMMAND",
    )
    
    # -- update --
    subparsers.add_parser(
        "update",
        help="Update system packages, Flatpak, Wine, and AUR",
        description="Perform a full system update across all package managers",
    )
    
    # -- install --
    install_parser = subparsers.add_parser(
        "install",
        help="Install an application from a name or .exe/.msi path",
        description="Install apps via Flatpak, pacman, AUR, or Wine",
    )
    install_parser.add_argument(
        "app_name_or_path",
        help="Package name (e.g., firefox) or path to .exe/.msi",
    )
    install_parser.add_argument(
        "--force",
        action="store_true",
        default=False,
        help="Force reinstall even if already installed",
    )
    install_parser.add_argument(
        "--sandbox",
        action="store_true",
        default=False,
        help="Install Windows apps in an isolated Wine prefix",
    )
    
    # -- optimize --
    optimize_parser = subparsers.add_parser(
        "optimize",
        help="Tune system for maximum performance",
        description="Optimize GPU, CPU, and memory settings",
    )
    optimize_parser.add_argument(
        "--gpu-only",
        action="store_true",
        default=False,
        help="Only optimize GPU settings",
    )
    optimize_parser.add_argument(
        "--cpu-only",
        action="store_true",
        default=False,
        help="Only optimize CPU settings",
    )
    optimize_parser.add_argument(
        "--memory-only",
        action="store_true",
        default=False,
        help="Only optimize memory settings",
    )
    
    # -- status --
    subparsers.add_parser(
        "status",
        help="Display system information and health",
        description="Show kernel, GPU, Wine, snapshots, and app status",
    )
    
    # -- apps --
    apps_parser = subparsers.add_parser(
        "apps",
        help="List or manage installed sandboxed applications",
        description="View and manage your installed applications",
    )
    apps_parser.add_argument(
        "--remove",
        metavar="APP",
        help="Remove the specified application",
    )
    
    # -- doctor --
    subparsers.add_parser(
        "doctor",
        help="System components health diagnostic report",
        description="Check status of Wine, GPU, Vulkan, OpenGL, Audio, flatpak, disk space, networks, Btrfs",
    )
    
    # -- rollback --
    rollback_parser = subparsers.add_parser(
        "rollback",
        help="Rollback system snapper snapshot or prefix snapshot",
        description="Rollback snapper snapshot or prefix snapshot with metadata preview",
    )
    rollback_parser.add_argument(
        "target",
        help="Target for rollback: 'system' or the app name"
    )
    rollback_parser.add_argument(
        "snapshot_id",
        help="Snapper snapshot ID or tag/pristine for prefix"
    )
    
    # -- export --
    export_parser = subparsers.add_parser(
        "export",
        help="Export application prefix to .tar.zst package",
        description="Compress prefix directory and metadata to a .tar.zst package",
    )
    export_parser.add_argument(
        "app_name",
        help="Name of the app to export"
    )
    export_parser.add_argument(
        "output_path",
        help="Path to save the exported .tar.zst package"
    )
    
    # -- import --
    import_parser = subparsers.add_parser(
        "import",
        help="Import application prefix from .tar.zst package",
        description="Restore app prefix and metadata from a .tar.zst package",
    )
    import_parser.add_argument(
        "input_path",
        help="Path to the .tar.zst package"
    )
    import_parser.add_argument(
        "--name",
        dest="override_app_name",
        default=None,
        help="Override the app name on import"
    )
    
    # -- bug-report --
    bug_parser = subparsers.add_parser(
        "bug-report",
        help="Generate a zipped diagnostic bug report",
        description="Package redacted logs, tracebacks, and diagnostics into conjunction-report.tar.zst",
    )
    bug_parser.add_argument(
        "--output",
        dest="output_path",
        default=None,
        help="Custom output path for the report"
    )
    
    # -- repair --
    repair_parser = subparsers.add_parser(
        "repair",
        help="Repair application prefix components",
        description="Safe prefix repairs (registry refresh, permissions check, metadata restore)",
    )
    repair_parser.add_argument(
        "app_name",
        help="Name of the app/prefix to repair"
    )

    # -- cleanup --
    cleanup_parser = subparsers.add_parser(
        "cleanup",
        help="Cleanup expired cache, log, and export files",
        description="Delete expired logs, crash reports, cache entries, and incomplete exports automatically",
    )
    cleanup_parser.add_argument(
        "--days",
        type=int,
        default=7,
        help="Age threshold in days (files older than this will be deleted, default 7)"
    )
    
    return parser


def dump_crash_report(exc: Exception, command_args: list[str], session_id: str) -> Path:
    import traceback
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    crash_dir = get_user_home() / ".conjunction" / "crash-reports"
    crash_dir.mkdir(parents=True, exist_ok=True)
    crash_file = crash_dir / f"crash-{timestamp}.json"
    
    tb_str = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    
    diagnostics = {
        "os": platform.platform(),
        "python_version": platform.python_version(),
        "cli_version": VERSION,
        "command": " ".join(command_args),
        "env": {k: os.environ.get(k, "") for k in ["LANG", "SHELL", "TERM", "USER", "HOME", "XDG_CURRENT_DESKTOP"]}
    }
    
    report_data = {
        "timestamp": datetime.now().isoformat(),
        "session_id": session_id,
        "exception_type": type(exc).__name__,
        "exception_message": str(exc),
        "traceback": tb_str,
        "diagnostics": diagnostics
    }
    
    report_str = json.dumps(report_data, indent=2)
    redacted_report_str = redact_sensitive_info(report_str)
    
    crash_file.write_text(redacted_report_str, encoding="utf-8")
    return crash_file


def main() -> int:
    """Entry point for the cj CLI utility.
    
    Returns:
        Exit code (0 for success, non-zero for failure).
    """
    if hasattr(sys.stdout, 'reconfigure'):
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except Exception:
            pass
    if hasattr(sys.stderr, 'reconfigure'):
        try:
            sys.stderr.reconfigure(encoding='utf-8')
        except Exception:
            pass

    session_id = str(uuid.uuid4())
    import logging
    logging.session_id = session_id

    parser = build_parser()
    args = parser.parse_args()
    
    if args.command is None:
        parser.print_help()
        return 0
    
    cli = ConjunctionCLI(args, session_id)
    
    try:
        return cli.run()
    except KeyboardInterrupt:
        print()
        cli._warning("Interrupted by user")
        return 130
    except Exception as exc:
        try:
            crash_file = dump_crash_report(exc, sys.argv, session_id)
            cli._error(f"Unexpected error: {exc}")
            cli._error(f"Crash report written to: {crash_file}")
        except Exception as inner_exc:
            cli._error(f"Unexpected error: {exc} (failed to write crash report: {inner_exc})")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
