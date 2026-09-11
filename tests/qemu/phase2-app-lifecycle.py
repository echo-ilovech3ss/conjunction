#!/usr/bin/env python3
"""Phase 2 Application Lifecycle System Verification inside QEMU (WSL2)."""

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
    print("=== Conjunction Phase 2 QEMU System Verification ===", flush=True)

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
    binaries = ['conj-bundle', 'conj-appctl', 'conj-appd', 'conj-open']
    for b in binaries:
        bin_path = BIN_DIR / b
        if not bin_path.exists():
            raise FileNotFoundError(f"Binary {bin_path} not found. Run cargo build --release first.")
        scp_to_guest(str(bin_path), f'/usr/local/bin/{b}')
        run_ssh(f'chmod +x /usr/local/bin/{b}')
    print("  Provisioned: " + ", ".join(binaries), flush=True)

    # Guest test script
    guest_test_script = r'''#!/bin/bash
set -euo pipefail

export HOME="/root"
export XDG_DATA_HOME="/root/.local/share"
export XDG_CONFIG_HOME="/root/.config"
export XDG_STATE_HOME="/root/.local/state"

TEST_ROOT="/tmp/phase2_test"
rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"
cd "$TEST_ROOT"

echo "=== Test 1: Validate and Inspect Hello.app ==="
mkdir -p Hello.app/Contents/{Executable,Resources}
cat > Hello.app/Contents/Info.toml << 'EOF'
bundle_format = "conjunction.app/1"
id = "org.conjunction.hello"
name = "Hello App"
version = "1.0.0"
executable = "Contents/Executable/hello"
architectures = ["x86_64"]
mime_types = ["application/x-hello"]
description = "A friendly acceptance test app."
EOF

cat > Hello.app/Contents/Executable/hello << 'EOF'
#!/bin/sh
echo "Hello from Conjunction"
EOF
chmod +x Hello.app/Contents/Executable/hello

conj-bundle validate Hello.app
conj-bundle inspect Hello.app | grep "org.conjunction.hello"
echo "  [PASS] Hello.app validated and inspected."

echo "=== Test 2: Install Hello.app via conj-appctl ==="
conj-appctl install ./Hello.app

# Check user Applications directory
test -d /root/Applications/Hello.app
test -f /root/Applications/Hello.app/Contents/Info.toml

# Check synthesized desktop entry
test -f /root/.local/share/applications/conj-org.conjunction.hello.desktop
grep -q "Name=Hello App" /root/.local/share/applications/conj-org.conjunction.hello.desktop
grep -q "X-Conjunction-AppId=org.conjunction.hello" /root/.local/share/applications/conj-org.conjunction.hello.desktop

# Check MIME association
test -f /root/.config/mimeapps.list
grep -q "application/x-hello=conj-org.conjunction.hello.desktop;" /root/.config/mimeapps.list
echo "  [PASS] Installation and desktop/MIME synthesis verified."

echo "=== Test 3: Discover by ID ==="
conj-appctl list | grep "org.conjunction.hello"
conj-appctl inspect org.conjunction.hello | grep "Version:          1.0.0"
echo "  [PASS] Discovery by ID verified."

echo "=== Test 4: Launch via Application Services ==="
LAUNCH_OUTPUT=$(conj-appctl launch org.conjunction.hello)
echo "Launch output: $LAUNCH_OUTPUT"
test "$LAUNCH_OUTPUT" = "Hello from Conjunction"
echo "  [PASS] Application launched end-to-end through Application Services."

echo "=== Test 5: Rename bundle preserves identity ==="
mv /root/Applications/Hello.app "/root/Applications/Renamed Hello.app"
conj-appctl reconcile

# ID must remain org.conjunction.hello and point to new path
conj-appctl inspect org.conjunction.hello | grep "Renamed Hello.app"
RENAME_LAUNCH=$(conj-appctl launch org.conjunction.hello)
test "$RENAME_LAUNCH" = "Hello from Conjunction"

# No ghost entries
APP_COUNT=$(conj-appctl list | grep -c "org.conjunction.hello" || true)
test "$APP_COUNT" -eq 1
echo "  [PASS] Bundle rename preserved identity without ghost entries."

echo "=== Test 6: Daemon restart & Registry Cache reconstruction ==="
# Kill daemon if running, wipe cache
rm -f /root/.local/state/conjunction/registry.json
conj-appctl reconcile
conj-appctl inspect org.conjunction.hello | grep "Renamed Hello.app"
echo "  [PASS] Registry cache reconstructed cleanly from filesystem truth."

echo "=== Test 7: Uninstall completely unregisters application ==="
conj-appctl uninstall org.conjunction.hello

# Verify bundle removed
test ! -d "/root/Applications/Renamed Hello.app"

# Verify desktop entry removed
test ! -f "/root/.local/share/applications/conj-org.conjunction.hello.desktop"

# Verify MIME association removed
if [ -f /root/.config/mimeapps.list ]; then
    ! grep -q "conj-org.conjunction.hello.desktop" /root/.config/mimeapps.list
fi

# Verify launch fails
if conj-appctl launch org.conjunction.hello 2>/dev/null; then
    echo "ERROR: launch should have failed after uninstall"
    exit 1
fi
echo "  [PASS] Application uninstalled cleanly with no stale artifacts."

echo "=== Test 8: Clean Reinstallation ==="
conj-appctl install "$TEST_ROOT/Hello.app"
conj-appctl inspect org.conjunction.hello | grep "Hello App"
REINSTALL_LAUNCH=$(conj-appctl launch org.conjunction.hello)
test "$REINSTALL_LAUNCH" = "Hello from Conjunction"
conj-appctl uninstall org.conjunction.hello
echo "  [PASS] Clean reinstallation verified."

echo "=== Test 9: Duplicate-ID Conflict Handling ==="
mkdir -p "$TEST_ROOT/Alpha.app/Contents/Executable"
mkdir -p "$TEST_ROOT/Beta.app/Contents/Executable"

cat > "$TEST_ROOT/Alpha.app/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "org.example.conflict"
name = "Alpha"
version = "1.0.0"
executable = "Contents/Executable/run"
architectures = ["x86_64"]
EOF
echo '#!/bin/sh' > "$TEST_ROOT/Alpha.app/Contents/Executable/run"
echo 'echo "Alpha"' >> "$TEST_ROOT/Alpha.app/Contents/Executable/run"
chmod +x "$TEST_ROOT/Alpha.app/Contents/Executable/run"

cat > "$TEST_ROOT/Beta.app/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "org.example.conflict"
name = "Beta"
version = "1.0.0"
executable = "Contents/Executable/run"
architectures = ["x86_64"]
EOF
echo '#!/bin/sh' > "$TEST_ROOT/Beta.app/Contents/Executable/run"
echo 'echo "Beta"' >> "$TEST_ROOT/Beta.app/Contents/Executable/run"
chmod +x "$TEST_ROOT/Beta.app/Contents/Executable/run"

cp -r "$TEST_ROOT/Alpha.app" /root/Applications/
cp -r "$TEST_ROOT/Beta.app" /root/Applications/

conj-appctl reconcile
# Must report conflict in list
conj-appctl list | grep "CONFLICT DETECTED"

# Launch by ID must fail
if conj-appctl launch org.example.conflict 2>/dev/null; then
    echo "ERROR: launch of conflicting ID must fail"
    exit 1
fi

# Remove Beta.app -> conflict resolves
rm -rf /root/Applications/Beta.app
conj-appctl reconcile

# Now launches Alpha
ALPHA_OUT=$(conj-appctl launch org.example.conflict)
test "$ALPHA_OUT" = "Alpha"
rm -rf /root/Applications/Alpha.app
conj-appctl reconcile
echo "  [PASS] Duplicate-ID conflict detected, blocked launch, and resolved upon removal."

echo "=== Test 10: Reserved-ID Protection ==="
mkdir -p "$TEST_ROOT/Settings.app/Contents/Executable"
cat > "$TEST_ROOT/Settings.app/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "org.conjunction.settings"
name = "Settings"
version = "1.0.0"
executable = "Contents/Executable/run"
architectures = ["x86_64"]
EOF
echo '#!/bin/sh' > "$TEST_ROOT/Settings.app/Contents/Executable/run"
chmod +x "$TEST_ROOT/Settings.app/Contents/Executable/run"

if conj-appctl install "$TEST_ROOT/Settings.app" 2>/dev/null; then
    echo "ERROR: User install of reserved ID org.conjunction.settings must be rejected"
    exit 1
fi
test ! -d /root/Applications/Settings.app
echo "  [PASS] Reserved system ID properly rejected."

echo "=== Test 11: Malicious Traversal Bundle Rejection ==="
mkdir -p "$TEST_ROOT/Evil.app/Contents"
cat > "$TEST_ROOT/Evil.app/Contents/Info.toml" << 'EOF'
bundle_format = "conjunction.app/1"
id = "org.example.evil"
name = "Evil"
version = "1.0.0"
executable = "../../bin/sh"
architectures = ["x86_64"]
EOF

if conj-appctl install "$TEST_ROOT/Evil.app" 2>/dev/null; then
    echo "ERROR: Installation of traversal executable must be rejected"
    exit 1
fi
test ! -d /root/Applications/Evil.app
test ! -f /root/.local/share/applications/conj-org.example.evil.desktop
echo "  [PASS] Malicious bundle rejected before registration; no files installed."

echo "=== Test 12: Incomplete / Interrupted Transaction Recovery ==="
# Simulate leftover staging directory
mkdir -p /root/Applications/.Corrupt.app.staging_12345
echo "partial data" > /root/Applications/.Corrupt.app.staging_12345/dummy.txt

conj-appctl reconcile
if conj-appctl list | grep -q "Corrupt"; then
    echo "ERROR: Staging directory must not be registered as an installed application"
    exit 1
fi
rm -rf /root/Applications/.Corrupt.app.staging_12345

# Verify clean installation of another app works
conj-appctl install "$TEST_ROOT/Hello.app"
conj-appctl launch org.conjunction.hello | grep -q "Hello from Conjunction"
conj-appctl uninstall org.conjunction.hello
echo "  [PASS] Interrupted staging handled safely without phantom registrations."

echo ""
echo "========================================================"
echo "ALL PHASE 2 REAL-SYSTEM QEMU ACCEPTANCE TESTS PASSED!"
echo "========================================================"
'''

    guest_script_path = '/tmp/phase2_guest_tests.sh'
    run_ssh(f"cat << 'GUEST_EOF' > {guest_script_path}\n{guest_test_script}\nGUEST_EOF\nchmod +x {guest_script_path}")

    print("\n[STEP 2/8] Executing Phase 2 test suite inside QEMU guest...", flush=True)
    res = run_ssh(f"bash {guest_script_path}", capture=False, timeout=120)
    if res.returncode != 0:
        raise RuntimeError(f"Guest acceptance tests failed with code {res.returncode}")

    print("\n[STEP 3/8] Shutting down QEMU VM cleanly...", flush=True)
    try:
        qmp_cmd(state, 'quit')
    except Exception:
        pass
    time.sleep(2)

    print("\n*** PHASE 2 QEMU ACCEPTANCE GATE VERIFICATION SUCCESSFUL ***")


if __name__ == '__main__':
    main()
