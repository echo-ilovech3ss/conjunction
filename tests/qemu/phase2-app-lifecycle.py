#!/usr/bin/env python3
"""Phase 2.2 Application Services Correctness & Hardening Verification inside QEMU (WSL2)."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

WORK_DIR = Path('/root/phase2-vm')
ISO_PATH = Path('/root/conjunction-build/out/conjunction-20260911-x86_64.iso')
BIN_DIR = Path('/tmp/wsl-target/release')
SSH_PORT = 2222
PASSWORD = 'conjunction'


def run_ssh(cmd, capture=True, timeout=30):
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
    print("=== Conjunction Phase 2.2 QEMU System Verification ===", flush=True)

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
    print("\n[STEP 1/4] Provisioning Conjunction binaries to guest /usr/local/bin...", flush=True)
    binaries = ['conj-bundle', 'conj-appctl', 'conj-appd', 'conj-open']
    for b in binaries:
        bin_path = BIN_DIR / b
        if not bin_path.exists():
            raise FileNotFoundError(f"Binary {bin_path} not found. Run cargo build --release first.")
        scp_to_guest(str(bin_path), f'/usr/local/bin/{b}')
        run_ssh(f'chmod +x /usr/local/bin/{b}')
    print("  Provisioned: " + ", ".join(binaries), flush=True)

    # 5. Provision non-root user and system applications directory
    print("\n[STEP 2/4] Setting up guest environment: non-root user & system applications...", flush=True)
    setup_script = r'''#!/bin/bash
set -euo pipefail
# Create unprivileged test user if not existing
if ! id -u conjunction-test &>/dev/null; then
    useradd -m -s /bin/bash conjunction-test
fi

# Ensure /opt/conjunction/Applications exists, owned by root (read-only to ordinary users)
mkdir -p /opt/conjunction/Applications
chown -R root:root /opt/conjunction
chmod 755 /opt/conjunction /opt/conjunction/Applications

# Install system bundle fixture: SystemSettings.app (legitimate system app)
SYS_APP="/opt/conjunction/Applications/SystemSettings.app"
rm -rf "$SYS_APP"
mkdir -p "$SYS_APP"/Contents/{Executable,Resources}
cat > "$SYS_APP/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "org.conjunction.settings"
name = "System Settings"
version = "1.0.0"
executable = "Contents/Executable/settings"
architectures = ["x86_64"]
description = "Conjunction System Settings."
EOF

cat > "$SYS_APP/Contents/Executable/settings" << 'EOF'
#!/bin/sh
echo "Conjunction System Settings Opened"
EOF
chmod +x "$SYS_APP/Contents/Executable/settings"
chown -R root:root "$SYS_APP"

# Pre-seed non-root user's mimeapps.list with an unrelated association
USER_CONFIG="/home/conjunction-test/.config"
mkdir -p "$USER_CONFIG"
cat > "$USER_CONFIG/mimeapps.list" << 'EOF'
[Added Associations]
text/plain=unrelated-editor.desktop;
EOF
chown -R conjunction-test:conjunction-test /home/conjunction-test

# Ensure root /Applications does NOT exist
rm -rf /Applications
'''
    res = run_ssh(setup_script)
    if res.returncode != 0:
        raise RuntimeError(f"System setup failed: {res.stderr}")
    print("  Created user conjunction-test, /opt/conjunction/Applications/SystemSettings.app, and pre-seeded mimeapps.list", flush=True)

    # 6. Guest non-root verification script
    guest_test_script = r'''#!/bin/bash
set -euo pipefail

export HOME="/home/conjunction-test"
export USER="conjunction-test"
export LOGNAME="conjunction-test"
export XDG_RUNTIME_DIR="/tmp/conjunction-run-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

APPD_PID=""
cleanup() {
    if [ -n "$APPD_PID" ]; then
        kill -9 "$APPD_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "=== Pre-check: Verify User & Privileges ==="
test "$(whoami)" = "conjunction-test"
test "$HOME" = "/home/conjunction-test"
echo "  [PASS] Running as unprivileged user: $(whoami) (UID $(id -u))"

echo "=== Test 1: Start conj-appd daemon & Verify Session IPC ==="
conj-appd &
APPD_PID=$!
sleep 1

# Check daemon ping over IPC
PING_RESP=$(conj-appctl ping)
test "$PING_RESP" = "pong"
echo "  [PASS] conj-appd running (PID $APPD_PID), IPC ping verified: $PING_RESP"

echo "=== Test 2: Daemon Single-Instance Protection ==="
# Attempt to start a second conj-appd instance for the same user
if conj-appd 2>/tmp/second_daemon.err; then
    echo "ERROR: Second conj-appd instance should have been rejected!"
    exit 1
fi
grep -i -E "already running" /tmp/second_daemon.err
echo "  [PASS] Second conj-appd instance rejected cleanly."

# Verify first daemon is still responsive and socket was not stolen
test "$(conj-appctl ping)" = "pong"
echo "  [PASS] Primary daemon retained socket ownership and remains responsive."

echo "=== Test 3: Validate and Install dev.conjunction.test.hello ==="
TEST_SRC="/tmp/conjunction-build-test"
rm -rf "$TEST_SRC"
mkdir -p "$TEST_SRC/Hello.app/Contents/Executable" "$TEST_SRC/Hello.app/Contents/Resources"
cd "$TEST_SRC"

cat > Hello.app/Contents/Info.toml << 'EOF'
bundle_format = "conjunction.app/1"
id = "dev.conjunction.test.hello"
name = "Hello App"
version = "1.0.0"
executable = "Contents/Executable/hello"
architectures = ["x86_64"]
mime_types = ["application/x-hello"]
description = "A friendly acceptance test app with unreserved ID."
EOF

cat > Hello.app/Contents/Executable/hello << 'EOF'
#!/bin/sh
echo "Hello from Conjunction"
EOF
chmod +x Hello.app/Contents/Executable/hello

conj-bundle validate Hello.app
conj-bundle inspect Hello.app | grep "dev.conjunction.test.hello"
echo "  [PASS] Hello.app validated with unreserved ID."

# Install via conj-appctl IPC
conj-appctl install "$TEST_SRC/Hello.app"

# Verify installed to non-root user Applications ($HOME/Applications)
test -d "$HOME/Applications/Hello.app"
test -f "$HOME/Applications/Hello.app/Contents/Info.toml"
test ! -e "/Applications/Hello.app"

# Verify desktop entry generated
DESKTOP_FILE="$HOME/.local/share/applications/conj-dev.conjunction.test.hello.desktop"
test -f "$DESKTOP_FILE"
grep -q "Name=Hello App" "$DESKTOP_FILE"
grep -q "X-Conjunction-AppId=dev.conjunction.test.hello" "$DESKTOP_FILE"

# Verify MIME association added AND pre-existing unrelated association preserved
MIME_FILE="$HOME/.config/mimeapps.list"
test -f "$MIME_FILE"
grep -q "text/plain=unrelated-editor.desktop;" "$MIME_FILE"
grep -q "application/x-hello=conj-dev.conjunction.test.hello.desktop;" "$MIME_FILE"
echo "  [PASS] dev.conjunction.test.hello installed successfully; MIME preserved."

echo "=== Test 4: Reserved Namespace Protection (org.conjunction.fake) ==="
# Attempt to install bundle with reserved org.conjunction.* ID as unprivileged user
mkdir -p "$TEST_SRC/Fake.app/Contents/Executable"
cat > "$TEST_SRC/Fake.app/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "org.conjunction.fake"
name = "Fake App"
version = "1.0.0"
executable = "Contents/Executable/run"
architectures = ["x86_64"]
mime_types = ["application/x-fake"]
EOF
cat > "$TEST_SRC/Fake.app/Contents/Executable/run" << 'EOF'
#!/bin/sh
echo "Fake"
EOF
chmod +x "$TEST_SRC/Fake.app/Contents/Executable/run"

if conj-appctl install "$TEST_SRC/Fake.app" 2>/dev/null; then
    echo "ERROR: User install of reserved ID org.conjunction.fake should have been rejected!"
    exit 1
fi

# Verify no bundle, no desktop entry, no MIME residue
test ! -d "$HOME/Applications/Fake.app"
test ! -f "$HOME/.local/share/applications/conj-org.conjunction.fake.desktop"
! grep -q "org.conjunction.fake" "$MIME_FILE"
! grep -q "application/x-fake" "$MIME_FILE"
! conj-appctl list | grep -q "org.conjunction.fake"
echo "  [PASS] org.conjunction.fake rejected with no bundle, registry, desktop, or MIME residue."

echo "=== Test 5: Discover applications (User + System scopes) ==="
LIST_OUT=$(conj-appctl list)
echo "$LIST_OUT"
echo "$LIST_OUT" | grep -q "dev.conjunction.test.hello"
echo "$LIST_OUT" | grep -q "org.conjunction.settings"

USER_INSPECT=$(conj-appctl inspect dev.conjunction.test.hello)
echo "$USER_INSPECT" | grep -q "Scope:            user"
echo "$USER_INSPECT" | grep -q "Version:          1.0.0"

SYS_INSPECT=$(conj-appctl inspect org.conjunction.settings)
echo "$SYS_INSPECT" | grep -q "Scope:            system"
echo "$SYS_INSPECT" | grep -q "/opt/conjunction/Applications/SystemSettings.app"
echo "  [PASS] System fixture org.conjunction.settings remains discoverable and unaffected."

echo "=== Test 6: Launch applications via conj-appctl and conj-open ==="
APPCTL_OUT=$(conj-appctl launch dev.conjunction.test.hello)
test "$APPCTL_OUT" = "Hello from Conjunction"

OPEN_OUT=$(conj-open dev.conjunction.test.hello)
test "$OPEN_OUT" = "Hello from Conjunction"

SYS_OUT=$(conj-appctl launch org.conjunction.settings)
test "$SYS_OUT" = "Conjunction System Settings Opened"
echo "  [PASS] Launches verified through Application Services."

echo "=== Test 7: Rename bundle preserves identity ==="
mv "$HOME/Applications/Hello.app" "$HOME/Applications/Renamed Hello.app"
conj-appctl reconcile

# Bundle identity points to renamed path
RENAME_INSPECT=$(conj-appctl inspect dev.conjunction.test.hello)
echo "$RENAME_INSPECT" | grep -q "Renamed Hello.app"

# Launch still succeeds
RENAME_LAUNCH=$(conj-appctl launch dev.conjunction.test.hello)
test "$RENAME_LAUNCH" = "Hello from Conjunction"

# Exactly one entry exists in registry (no ghosts)
HELLO_COUNT=$(conj-appctl list | grep -c "dev.conjunction.test.hello" || true)
test "$HELLO_COUNT" -eq 1
echo "  [PASS] Bundle rename preserved identity without ghost entries."

echo "=== Test 8: Single-Writer Architecture (--standalone mutation rejection) ==="
# Mutating operations in standalone mode MUST be rejected to protect single-writer model
if conj-appctl --standalone install "$TEST_SRC/Hello.app" 2>/tmp/sa_install.err; then
    echo "ERROR: conj-appctl --standalone install must be rejected!"
    exit 1
fi
grep -i -E "cannot be performed in standalone mode|conj-appd.*required" /tmp/sa_install.err

if conj-appctl --standalone uninstall dev.conjunction.test.hello 2>/tmp/sa_uninst.err; then
    echo "ERROR: conj-appctl --standalone uninstall must be rejected!"
    exit 1
fi
grep -i -E "cannot be performed in standalone mode|conj-appd.*required" /tmp/sa_uninst.err

if conj-appctl --standalone reconcile 2>/tmp/sa_rec.err; then
    echo "ERROR: conj-appctl --standalone reconcile must be rejected!"
    exit 1
fi
grep -i -E "cannot be performed in standalone mode|conj-appd.*required" /tmp/sa_rec.err

# But read-only diagnostic operations in standalone mode MUST succeed
conj-appctl --standalone list | grep -q "dev.conjunction.test.hello"
conj-appctl --standalone inspect dev.conjunction.test.hello | grep -q "dev.conjunction.test.hello"
test "$(conj-appctl --standalone ping)" = "pong (standalone)"
echo "  [PASS] Standalone mode correctly forbids mutations and allows safe read-only queries."

echo "=== Test 9: Daemon failure & Stale Socket Restart Recovery ==="
# Kill conj-appd
kill -9 "$APPD_PID"
wait "$APPD_PID" 2>/dev/null || true
APPD_PID=""

# conj-appctl must fail cleanly when daemon is unreachable
if conj-appctl list 2>/tmp/appctl_err; then
    echo "ERROR: conj-appctl list should have failed when conj-appd is not running!"
    exit 1
fi
grep -i -E "cannot connect|is conj-appd running|Connection refused" /tmp/appctl_err
echo "  Clean connection failure verified when daemon is absent."

# Restart conj-appd (must safely clean up stale socket file and bind new listener)
conj-appd &
APPD_PID=$!
sleep 1

# conj-appctl connects and works again
test "$(conj-appctl ping)" = "pong"
RESTART_LAUNCH=$(conj-appctl launch dev.conjunction.test.hello)
test "$RESTART_LAUNCH" = "Hello from Conjunction"
echo "  [PASS] Stale socket cleanly recovered and new daemon resumed Application Services."

echo "=== Test 10: Privilege Boundary & Path Traversal Rejection ==="
# 1. Non-root user cannot write to system /opt/conjunction/Applications
if touch /opt/conjunction/Applications/malicious.txt 2>/dev/null; then
    echo "ERROR: Unprivileged user should not be able to write to /opt/conjunction/Applications!"
    exit 1
fi

# 2. Path traversal executable rejected
mkdir -p "$TEST_SRC/Evil.app/Contents"
cat > "$TEST_SRC/Evil.app/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "com.example.evil"
name = "Evil"
version = "1.0.0"
executable = "../../bin/sh"
architectures = ["x86_64"]
EOF

if conj-appctl install "$TEST_SRC/Evil.app" 2>/dev/null; then
    echo "ERROR: Bundle with path traversal executable should have been rejected!"
    exit 1
fi
test ! -d "$HOME/Applications/Evil.app"
test ! -f "$HOME/.local/share/applications/conj-com.example.evil.desktop"
echo "  [PASS] System root write protection and path traversal rejection verified."

echo "=== Test 11: Clean Uninstallation & MIME Preservation ==="
conj-appctl uninstall dev.conjunction.test.hello

# Verify bundle removed
test ! -d "$HOME/Applications/Renamed Hello.app"

# Verify desktop file removed
test ! -f "$HOME/.local/share/applications/conj-dev.conjunction.test.hello.desktop"

# Verify Hello association removed BUT unrelated association strictly preserved
test -f "$MIME_FILE"
! grep -q "application/x-hello" "$MIME_FILE"
grep -q "text/plain=unrelated-editor.desktop;" "$MIME_FILE"

# Launch should now fail
if conj-appctl launch dev.conjunction.test.hello 2>/dev/null; then
    echo "ERROR: launch should have failed after uninstall"
    exit 1
fi
echo "  [PASS] Application uninstalled cleanly; unrelated MIME associations remained intact."

echo "=== Test 12: Ownership Audit (No root-owned user files) ==="
ROOT_OWNED=$(find /home/conjunction-test -user root 2>/dev/null || true)
if [ -n "$ROOT_OWNED" ]; then
    echo "ERROR: Found root-owned files in user home directory:"
    echo "$ROOT_OWNED"
    exit 1
fi
echo "  [PASS] Ownership audit passed: no root-owned files in user home."

echo ""
echo "========================================================"
echo "ALL PHASE 2.2 REAL-SYSTEM HARDENING TESTS PASSED!"
echo "========================================================"
'''

    # Write test script to guest
    guest_script_path = '/home/conjunction-test/phase2_2_tests.sh'
    run_ssh(f"cat << 'GUEST_EOF' > {guest_script_path}\n{guest_test_script}\nGUEST_EOF\nchmod +x {guest_script_path}\nchown conjunction-test:conjunction-test {guest_script_path}")

    # Run tests as unprivileged user conjunction-test
    print("\n[STEP 3/4] Executing Phase 2.2 hardening tests inside QEMU guest as conjunction-test...", flush=True)
    res = run_ssh(f"su - conjunction-test -c 'bash {guest_script_path}'", capture=False, timeout=120)
    if res.returncode != 0:
        raise RuntimeError(f"Guest acceptance tests failed with code {res.returncode}")

    print("\n[STEP 4/4] Shutting down QEMU VM cleanly...", flush=True)
    try:
        qmp_cmd(state, 'quit')
    except Exception:
        pass
    time.sleep(2)

    print("\n*** PHASE 2.2 REAL-SYSTEM HARDENING GATE VERIFICATION SUCCESSFUL ***")


if __name__ == '__main__':
    main()
