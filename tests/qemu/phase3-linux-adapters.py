#!/usr/bin/env python3
"""Phase 3 Linux Application Adapters Acceptance Verification inside QEMU (WSL2)."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

WORK_DIR = Path('/root/phase3-vm')
ISO_PATH = Path('/root/conjunction-build/out/conjunction-20260911-x86_64.iso')
BIN_DIR = Path('/tmp/wsl-target/release')
SSH_PORT = 2222
PASSWORD = 'conjunction'


def run_ssh(cmd, capture=True, timeout=60):
    ssh_cmd = [
        'sshpass', '-p', PASSWORD,
        'ssh', '-p', str(SSH_PORT),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'ConnectTimeout=5',
        '-o', 'LogLevel=ERROR',
        'root@127.0.0.1', cmd
    ]
    if capture:
        return subprocess.run(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
    return subprocess.run(ssh_cmd, timeout=timeout)


def scp_to_guest(src_path, dst_path):
    scp_cmd = [
        'sshpass', '-p', PASSWORD,
        'scp', '-P', str(SSH_PORT),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'LogLevel=ERROR',
        str(src_path), f'root@127.0.0.1:{dst_path}'
    ]
    subprocess.run(scp_cmd, check=True)


def run_guest_script(script_content, as_user=None, timeout=120):
    local_tmp = Path('/tmp/guest_exec.sh')
    local_tmp.write_text(script_content)
    scp_to_guest(str(local_tmp), '/tmp/guest_exec.sh')
    run_ssh('chmod 755 /tmp/guest_exec.sh')
    if as_user:
        return run_ssh(f"su - {as_user} -c 'bash /tmp/guest_exec.sh'", timeout=timeout)
    else:
        return run_ssh('bash /tmp/guest_exec.sh', timeout=timeout)


def qmp_cmd(state, command, arguments=None):
    import socket
    with socket.socket(socket.AF_UNIX) as sock:
        sock.settimeout(10)
        sock.connect(state["socket"])
        stream = sock.makefile("rwb")
        stream.readline()
        for request in [{"execute": "qmp_capabilities"},
                        {"execute": command, "arguments": arguments or {}}]:
            stream.write(json.dumps(request).encode() + b"\n")
            stream.flush()
            while True:
                result = json.loads(stream.readline())
                if "error" in result:
                    raise RuntimeError(result["error"])
                if "return" in result:
                    break
        return result["return"]


def main():
    print("=== Conjunction Phase 3 Linux Adapters QEMU System Verification ===", flush=True)

    # 1. Kill stale QEMU instances
    subprocess.run(['pkill', '-9', '-f', 'qemu-system-x86_64'], stderr=subprocess.DEVNULL)
    time.sleep(1)

    if WORK_DIR.exists():
        shutil.rmtree(WORK_DIR, ignore_errors=True)
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    # 2. Boot QEMU with Live ISO
    print(f"Booting QEMU VM from live ISO: {ISO_PATH} ...", flush=True)
    subprocess.run([
        sys.executable, '/root/scripts/vm_test.py', 'start',
        '--dir', str(WORK_DIR),
        '--iso', str(ISO_PATH),
        '--firmware', 'uefi',
        '--port', str(SSH_PORT)
    ], check=True)

    state = json.loads((WORK_DIR / 'vm.json').read_text())

    # 3. Wait for SSH in guest
    print("Waiting for QEMU guest SSH daemon to respond...", flush=True)
    ssh_ready = False
    deadline = time.monotonic() + 180
    attempt = 0
    while time.monotonic() < deadline:
        attempt += 1
        try:
            res = run_ssh('uname -a; whoami', capture=True, timeout=5)
            if res.returncode == 0 and 'root' in res.stdout:
                print(f"Guest SSH connected successfully after {attempt*3}s:\n  {res.stdout.strip()}", flush=True)
                ssh_ready = True
                break
        except Exception:
            pass
        time.sleep(3)

    if not ssh_ready:
        raise RuntimeError("Timeout waiting for guest SSH")

    # 4. Provision compiled Conjunction binaries
    print("\n[STEP 1/8] Provisioning Conjunction binaries to guest /usr/local/bin...", flush=True)
    binaries = ['conj-bundle', 'conj-appctl', 'conj-appd', 'conj-open', 'conj-sysd']
    for b in binaries:
        bin_path = BIN_DIR / b
        if not bin_path.exists():
            raise FileNotFoundError(f"Binary {bin_path} not found. Run cargo build --release first.")
        scp_to_guest(str(bin_path), f'/usr/local/bin/{b}')
        run_ssh(f'chmod +x /usr/local/bin/{b}')
    print("  Provisioned: " + ", ".join(binaries), flush=True)

    # 5. Provision environment, system packages, and conj-sysd daemon
    print("\n[STEP 2/8] Setting up guest environment: conj-sysd service & deterministic test packages...", flush=True)
    setup_script = r'''#!/bin/bash
set -euo pipefail

# Create unprivileged test user if not existing
if ! id -u conjunction-test &>/dev/null; then
    useradd -m -s /bin/bash conjunction-test
fi

USER_UID=$(id -u conjunction-test)
mkdir -p "/tmp/conjunction-run-$USER_UID"
chown -R conjunction-test:conjunction-test "/tmp/conjunction-run-$USER_UID"
chmod 700 "/tmp/conjunction-run-$USER_UID"

cat >> /home/conjunction-test/.bashrc << EOF
export XDG_RUNTIME_DIR="/tmp/conjunction-run-$USER_UID"
EOF
cat >> /home/conjunction-test/.profile << EOF
export XDG_RUNTIME_DIR="/tmp/conjunction-run-$USER_UID"
EOF
chown conjunction-test:conjunction-test /home/conjunction-test/.bashrc /home/conjunction-test/.profile

# Ensure /run/conjunction directory exists and permissions are 755
mkdir -p /run/conjunction
chmod 755 /run/conjunction

# Start conj-sysd privileged service in background with detached fds
pkill -9 -f conj-sysd 2>/dev/null || true
rm -f /run/conjunction/sysd.sock
nohup /usr/local/bin/conj-sysd </dev/null >/tmp/conj-sysd.log 2>&1 &
sleep 1

# Verify socket is created and accessible
test -S /run/conjunction/sysd.sock
echo "conj-sysd started and listening at /run/conjunction/sysd.sock"

# Build deterministic test packages in /tmp/packages
PKG_DIR="/tmp/packages"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"

# Package 1: conjunction-phase3-demo (Single app package)
DEMO_BUILD="$PKG_DIR/demo_pkg"
mkdir -p "$DEMO_BUILD/pkg/usr/bin" "$DEMO_BUILD/pkg/usr/share/applications"

cat > "$DEMO_BUILD/pkg/.PKGINFO" << 'EOF'
pkgname = conjunction-phase3-demo
pkgver = 1.0.0-1
pkgdesc = Conjunction Phase 3 Single-App Demo
url = https://conjunction.org
builddate = 1710000000
packager = Conjunction <packager@conjunction.org>
size = 2048
arch = any
EOF

cat > "$DEMO_BUILD/pkg/usr/bin/conjunction-phase3-demo" << 'EOF'
#!/bin/sh
echo "Conjunction Phase 3 Demo Executed: $@"
EOF
chmod 755 "$DEMO_BUILD/pkg/usr/bin/conjunction-phase3-demo"

cat > "$DEMO_BUILD/pkg/usr/share/applications/conjunction-phase3-demo.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Phase3 Demo
Exec=conjunction-phase3-demo %U
Icon=utilities-terminal
Categories=Utility;
EOF
chmod 644 "$DEMO_BUILD/pkg/usr/share/applications/conjunction-phase3-demo.desktop"

(cd "$DEMO_BUILD/pkg" && tar -c --zstd -f "$PKG_DIR/conjunction-phase3-demo-1.0.0-1-any.pkg.tar.zst" .PKGINFO usr/)

# Package 2: conjunction-phase3-suite (Multi-app package)
SUITE_BUILD="$PKG_DIR/suite_pkg"
mkdir -p "$SUITE_BUILD/pkg/usr/bin" "$SUITE_BUILD/pkg/usr/share/applications"

cat > "$SUITE_BUILD/pkg/.PKGINFO" << 'EOF'
pkgname = conjunction-phase3-suite
pkgver = 2.0.0-1
pkgdesc = Conjunction Phase 3 Multi-App Suite
url = https://conjunction.org
builddate = 1710000000
packager = Conjunction <packager@conjunction.org>
size = 4096
arch = any
EOF

cat > "$SUITE_BUILD/pkg/usr/bin/suite-alpha" << 'EOF'
#!/bin/sh
echo "Suite Alpha Executed: $@"
EOF
chmod 755 "$SUITE_BUILD/pkg/usr/bin/suite-alpha"

cat > "$SUITE_BUILD/pkg/usr/share/applications/conjunction-suite-alpha.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Suite Alpha
Exec=suite-alpha %U
Icon=utilities-terminal
Categories=Utility;
EOF
chmod 644 "$SUITE_BUILD/pkg/usr/share/applications/conjunction-suite-alpha.desktop"

cat > "$SUITE_BUILD/pkg/usr/bin/suite-beta" << 'EOF'
#!/bin/sh
echo "Suite Beta Executed: $@"
EOF
chmod 755 "$SUITE_BUILD/pkg/usr/bin/suite-beta"

cat > "$SUITE_BUILD/pkg/usr/share/applications/conjunction-suite-beta.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Suite Beta
Exec=suite-beta %U
Icon=utilities-terminal
Categories=Utility;
EOF
chmod 644 "$SUITE_BUILD/pkg/usr/share/applications/conjunction-suite-beta.desktop"

(cd "$SUITE_BUILD/pkg" && tar -c --zstd -f "$PKG_DIR/conjunction-phase3-suite-2.0.0-1-any.pkg.tar.zst" .PKGINFO usr/)

# Initial install of Package 1 via pacman
pacman -U --noconfirm "$PKG_DIR/conjunction-phase3-demo-1.0.0-1-any.pkg.tar.zst"

# Verify pacman ownership
pacman -Qo /usr/share/applications/conjunction-phase3-demo.desktop
'''
    res = run_guest_script(setup_script)
    if res.returncode != 0:
        raise RuntimeError(f"System setup failed:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
    print("  conj-sysd started and conjunction-phase3-demo installed via pacman.", flush=True)

    # 6. User Verification: Start conj-appd, discover, inspect, launch, and uninstall pacman package
    print("\n[STEP 3/8] Unprivileged user: discovering, inspecting, launching, and uninstallation via conj-sysd...", flush=True)
    part1_script = r'''#!/bin/bash
set -euo pipefail

export HOME="/home/conjunction-test"
export USER="conjunction-test"
export LOGNAME="conjunction-test"
export XDG_RUNTIME_DIR="/tmp/conjunction-run-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Clean any existing daemon
pkill -9 -f conj-appd 2>/dev/null || true
sleep 1

# Start conj-appd detached
nohup conj-appd </dev/null >/tmp/conj-appd.log 2>&1 &
APPD_PID=$!

# Wait for conj-appd to be ready (up to 10s)
READY=0
for i in $(seq 1 20); do
    if conj-appctl ping 2>/dev/null; then
        READY=1
        break
    fi
    sleep 0.5
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: conj-appd failed to become ready! Log:"
    cat /tmp/conj-appd.log || true
    exit 1
fi
echo "  [PASS] conj-appd started and responsive."

# Test 1: In-place Pacman Application Discovery
LIST_OUT=$(conj-appctl list)
echo "$LIST_OUT"
echo "$LIST_OUT" | grep -E "conjunction-phase3-demo.*\[system\].*\[pacman\]"
echo "  [PASS] Pacman app discovered with [pacman] backend without .app wrapper."

# Verify no fake .app wrappers exist
test ! -e "/home/conjunction-test/Applications/conjunction-phase3-demo.app"
test ! -e "/Applications/conjunction-phase3-demo.app"
echo "  [PASS] Verified zero filesystem duplication or fake .app wrappers."

# Test 2: Inspect Pacman Application Metadata
INSPECT_OUT=$(conj-appctl inspect conjunction-phase3-demo)
echo "$INSPECT_OUT"
echo "$INSPECT_OUT" | grep -q "Backend:          pacman"
echo "$INSPECT_OUT" | grep -q "Scope:            system"
echo "$INSPECT_OUT" | grep -q "Package:          conjunction-phase3-demo 1.0.0-1"
echo "$INSPECT_OUT" | grep -q "Bundle Path:      /usr/share/applications/conjunction-phase3-demo.desktop"
echo "  [PASS] Inspect accurately exposes pacman package metadata."

# Test 3: Launch Pacman Application (conj-appctl & conj-open)
APPCTL_RUN=$(conj-appctl launch conjunction-phase3-demo appctl_arg1 appctl_arg2)
test "$APPCTL_RUN" = "Conjunction Phase 3 Demo Executed: appctl_arg1 appctl_arg2"

OPEN_RUN=$(conj-open conjunction-phase3-demo open_arg)
test "$OPEN_RUN" = "Conjunction Phase 3 Demo Executed: open_arg"
echo "  [PASS] Direct launch through Application Services verified."

# Test 4: Conjunction-Initiated Pacman Uninstallation
# Note: conjunction-test has NO sudo privileges. conj-appd uses conj-sysd socket!
conj-appctl uninstall conjunction-phase3-demo

# Verify registry has automatically deregistered the app
! conj-appctl list | grep -q "conjunction-phase3-demo"
echo "  [PASS] Package deregistered in registry upon uninstallation."
'''
    res = run_guest_script(part1_script, as_user='conjunction-test')
    if res.returncode != 0:
        raise RuntimeError(f"User part 1 failed:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
    print("  User part 1 passed.", flush=True)

    # 7. Root Verification: Verify conj-sysd removed the pacman package from the system
    print("\n[STEP 4/8] Root verification: pacman database and filesystem state...", flush=True)
    check_pacman = run_ssh('pacman -Q conjunction-phase3-demo')
    if check_pacman.returncode == 0:
        raise RuntimeError("ERROR: Package conjunction-phase3-demo is still installed according to pacman!")
    check_files = run_ssh('test ! -f /usr/share/applications/conjunction-phase3-demo.desktop && test ! -f /usr/bin/conjunction-phase3-demo')
    if check_files.returncode != 0:
        raise RuntimeError("ERROR: Files from conjunction-phase3-demo still exist on filesystem!")
    print("  [PASS] Pacman package and files confirmed removed by conj-sysd.", flush=True)

    # 8. External Pacman Reinstall & Automatic Discovery Test
    print("\n[STEP 5/8] External pacman reinstall & remove lifecycle...", flush=True)
    # Root reinstalls package outside Conjunction
    res = run_ssh('pacman -U --noconfirm /tmp/packages/conjunction-phase3-demo-1.0.0-1-any.pkg.tar.zst')
    if res.returncode != 0:
        raise RuntimeError(f"External reinstall failed: {res.stderr}")

    # User reconciles and verifies rediscovery
    res = run_ssh("su - conjunction-test -c 'export XDG_RUNTIME_DIR=/tmp/conjunction-run-$(id -u); conj-appctl reconcile && conj-appctl list | grep conjunction-phase3-demo'")
    if res.returncode != 0:
        raise RuntimeError("ERROR: conjunction-phase3-demo was not rediscovered after external pacman install!")
    print("  [PASS] External package install automatically rediscovered.", flush=True)

    # Root removes package outside Conjunction
    res = run_ssh('pacman -R --noconfirm conjunction-phase3-demo')
    if res.returncode != 0:
        raise RuntimeError(f"External removal failed: {res.stderr}")

    # User reconciles and verifies automatic deregistration
    res = run_ssh("su - conjunction-test -c 'export XDG_RUNTIME_DIR=/tmp/conjunction-run-$(id -u); conj-appctl reconcile && conj-appctl list | grep conjunction-phase3-demo'")
    if res.returncode == 0:
        raise RuntimeError("ERROR: conjunction-phase3-demo was not removed after external pacman -R!")
    print("  [PASS] External package removal automatically deregistered without ghosts.", flush=True)

    # 9. Multi-Application Package Ownership & Safe Removal Test
    print("\n[STEP 6/8] Multi-application package confirmation & removal...", flush=True)
    # Root installs multi-app package
    res = run_ssh('pacman -U --noconfirm /tmp/packages/conjunction-phase3-suite-2.0.0-1-any.pkg.tar.zst')
    if res.returncode != 0:
        raise RuntimeError(f"Suite install failed: {res.stderr}")

    part2_script = r'''#!/bin/bash
set -euo pipefail

export HOME="/home/conjunction-test"
export USER="conjunction-test"
export LOGNAME="conjunction-test"
export XDG_RUNTIME_DIR="/tmp/conjunction-run-$(id -u)"

conj-appctl reconcile

# Verify both apps discovered
LIST_OUT=$(conj-appctl list)
echo "$LIST_OUT" | grep -q "conjunction-suite-alpha"
echo "$LIST_OUT" | grep -q "conjunction-suite-beta"

# Verify sibling relationships
ALPHA_INSPECT=$(conj-appctl inspect conjunction-suite-alpha)
echo "$ALPHA_INSPECT" | grep -q "Sibling Apps:     conjunction-suite-beta"

BETA_INSPECT=$(conj-appctl inspect conjunction-suite-beta)
echo "$BETA_INSPECT" | grep -q "Sibling Apps:     conjunction-suite-alpha"

# Attempt uninstallation without confirmation flag (MUST fail)
if conj-appctl uninstall conjunction-suite-alpha 2>/tmp/uninst_alpha.err; then
    echo "ERROR: Uninstalling multi-app package without --yes should have failed!"
    exit 1
fi
grep -i -E "also provides other applications|Use --yes to confirm" /tmp/uninst_alpha.err
echo "  [PASS] Unconfirmed removal rejected; sibling applications protected."

# Now confirm with --yes
conj-appctl uninstall --yes conjunction-suite-alpha

# Both apps must now be gone from registry
! conj-appctl list | grep -q "conjunction-suite-alpha"
! conj-appctl list | grep -q "conjunction-suite-beta"
echo "  [PASS] Multi-app package removed completely upon explicit confirmation."
'''
    res = run_guest_script(part2_script, as_user='conjunction-test')
    if res.returncode != 0:
        raise RuntimeError(f"Multi-app test failed:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")

    # Root confirms package was removed
    check_suite = run_ssh('pacman -Q conjunction-phase3-suite')
    if check_suite.returncode == 0:
        raise RuntimeError("ERROR: Package conjunction-phase3-suite still installed after --yes removal!")
    print("  [PASS] Multi-app package confirmed uninstalled from pacman by conj-sysd.", flush=True)

    # 10. Unowned Desktop Entry, Hostile Exec Security, and Native .app Regression Test
    print("\n[STEP 7/8] Unowned desktop entry, hostile Exec injection security, and native .app regression...", flush=True)
    part3_script = r'''#!/bin/bash
set -euo pipefail

export HOME="/home/conjunction-test"
export USER="conjunction-test"
export LOGNAME="conjunction-test"
export XDG_RUNTIME_DIR="/tmp/conjunction-run-$(id -u)"

USER_APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$USER_APPS_DIR"

# Test A: Unowned Desktop Entry
cat > "$USER_APPS_DIR/standalone-calc.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Standalone Calc
Exec=echo Standalone Calc Executed: %U
Icon=accessories-calculator
Terminal=false
EOF

conj-appctl reconcile
CALC_INSPECT=$(conj-appctl inspect standalone-calc)
echo "$CALC_INSPECT" | grep -q "Backend:          desktop-entry"
echo "$CALC_INSPECT" | grep -q "Scope:            user"

CALC_OUT=$(conj-appctl launch standalone-calc arg123)
test "$CALC_OUT" = "Standalone Calc Executed: arg123"

# Uninstall unowned user desktop entry
conj-appctl uninstall standalone-calc
test ! -f "$USER_APPS_DIR/standalone-calc.desktop"
! conj-appctl list | grep -q "standalone-calc"
echo "  [PASS] Unowned Desktop Entry discovered, launched, and uninstalled cleanly."

# Test B: Hostile Exec Security Verification (No Shell Execution)
cat > "$USER_APPS_DIR/hostile-exec.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Hostile Exec Test
Exec=echo Hostile ; touch /tmp/pwned_marker | cat $(touch /tmp/pwned_subst) `touch /tmp/pwned_backtick`
Icon=utilities-terminal
EOF

conj-appctl reconcile
rm -f /tmp/pwned_marker /tmp/pwned_subst /tmp/pwned_backtick

HOSTILE_OUT=$(conj-appctl launch hostile-exec)
echo "Hostile launch output: $HOSTILE_OUT"

# Verify that NO shell executed the injection payload
test ! -f /tmp/pwned_marker
test ! -f /tmp/pwned_subst
test ! -f /tmp/pwned_backtick
echo "  [PASS] Hostile Exec injection successfully defeated (no shell invoked)."

conj-appctl uninstall hostile-exec

# Test C: Native .app Bundle Regression Test
TEST_SRC="/tmp/conjunction-native-test"
rm -rf "$TEST_SRC"
mkdir -p "$TEST_SRC/NativeHello.app/Contents/Executable"
cat > "$TEST_SRC/NativeHello.app/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "dev.conjunction.test.hello"
name = "Native Hello"
version = "1.0.0"
executable = "Contents/Executable/run"
architectures = ["x86_64"]
EOF
cat > "$TEST_SRC/NativeHello.app/Contents/Executable/run" << 'EOF'
#!/bin/sh
echo "Hello from Native Bundle"
EOF
chmod +x "$TEST_SRC/NativeHello.app/Contents/Executable/run"

conj-appctl install "$TEST_SRC/NativeHello.app"
NATIVE_INSPECT=$(conj-appctl inspect dev.conjunction.test.hello)
echo "$NATIVE_INSPECT" | grep -q "Backend:          native"
test "$(conj-appctl launch dev.conjunction.test.hello)" = "Hello from Native Bundle"
test "$(conj-open dev.conjunction.test.hello)" = "Hello from Native Bundle"

conj-appctl uninstall dev.conjunction.test.hello
! conj-appctl list | grep -q "dev.conjunction.test.hello"
echo "  [PASS] Native Conjunction .app bundle lifecycle completely intact."
'''
    res = run_guest_script(part3_script, as_user='conjunction-test')
    if res.returncode != 0:
        raise RuntimeError(f"Part 3 tests failed:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
    print("  Part 3 tests passed.", flush=True)

    # 11. Ownership Audit: Ensure no root-owned files exist in user home directory
    print("\n[STEP 8/8] User ownership audit...", flush=True)
    res = run_ssh("find /home/conjunction-test -user root")
    if res.stdout.strip():
        raise RuntimeError(f"ERROR: Found root-owned files in user home:\n{res.stdout}")
    print("  [PASS] Ownership audit passed: zero root-owned files in user home.", flush=True)

    # 12. Clean Shutdown
    print("\nShutting down QEMU VM cleanly...", flush=True)
    try:
        qmp_cmd(state, 'quit')
    except Exception:
        pass
    time.sleep(2)

    print("\n========================================================")
    print("ALL PHASE 3 REAL-SYSTEM ACCEPTANCE TESTS PASSED!")
    print("========================================================")


if __name__ == '__main__':
    main()
