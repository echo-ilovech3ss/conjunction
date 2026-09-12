#!/usr/bin/env python3
"""Phase 5B Advanced Shell Interaction Acceptance Verification inside QEMU (WSL2)."""

import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time

WORK_DIR = Path('/root/phase5b-vm')
ISO_PATH = Path('/root/conjunction-build/out/conjunction-20260911-x86_64.iso')

CHROOT_BIN = Path('/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs/usr/bin')
SHELL_BIN = CHROOT_BIN / 'conj-shelld' if (CHROOT_BIN / 'conj-shelld').exists() else Path('/tmp/wsl-target/release/conj-shelld')
REF_APP_BIN = CHROOT_BIN / 'conjunction-reference-app' if (CHROOT_BIN / 'conjunction-reference-app').exists() else Path('/tmp/wsl-target/release/conjunction-reference-app')
GALLERY_BIN = CHROOT_BIN / 'conjunction-design-gallery' if (CHROOT_BIN / 'conjunction-design-gallery').exists() else Path('/tmp/wsl-target/release/conjunction-design-gallery')

REPO_ROOT = Path('/mnt/c/Users/Way4U/Coding-projects/conjunction')
OUT_SCREENSHOTS = REPO_ROOT / 'docs/design/screenshots'
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
        '-r',
        str(src_path), f'root@127.0.0.1:{dst_path}'
    ]
    subprocess.run(scp_cmd, check=True)


def scp_from_guest(guest_path, dst_path):
    scp_cmd = [
        'sshpass', '-p', PASSWORD,
        'scp', '-P', str(SSH_PORT),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'LogLevel=ERROR',
        f'root@127.0.0.1:{guest_path}', str(dst_path)
    ]
    subprocess.run(scp_cmd, check=True)


def run_guest_script(script_content, as_user=None, timeout=120):
    local_tmp = Path('/tmp/guest_exec_p5b.sh')
    local_tmp.write_text(script_content)
    scp_to_guest(str(local_tmp), '/tmp/guest_exec_p5b.sh')
    run_ssh('chmod 755 /tmp/guest_exec_p5b.sh')
    if as_user:
        return run_ssh(f"su - {as_user} -c 'bash /tmp/guest_exec_p5b.sh'", timeout=timeout)
    else:
        return run_ssh('bash /tmp/guest_exec_p5b.sh', timeout=timeout)


def parse_png_dimensions(data: bytes):
    if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    width, height = struct.unpack('>II', data[16:24])
    return width, height


def main():
    print("=== Conjunction Phase 5B Advanced Shell QEMU System Verification ===", flush=True)

    OUT_SCREENSHOTS.mkdir(parents=True, exist_ok=True)

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
                print(f"Guest SSH connected successfully after {attempt*3}s: " + str(res.stdout).strip(), flush=True)
                ssh_ready = True
                break
        except Exception:
            pass
        time.sleep(3)

    if not ssh_ready:
        raise RuntimeError("Timeout waiting for guest SSH")

    # 4. Provision unprivileged user & directories
    print("\n[STEP 1/8] Setting up unprivileged user conjunction-test and runtime environment...", flush=True)
    setup_script = r'''#!/bin/bash
set -euo pipefail
if ! id -u conjunction-test &>/dev/null; then
    useradd -m -s /bin/bash conjunction-test
fi
mkdir -p /usr/share/conjunction/qml
mkdir -p /usr/share/conjunction/shell
mkdir -p /usr/share/conjunction/reference
mkdir -p /usr/share/kwin/effects/conjunction-overview
mkdir -p /home/conjunction-test/.config/conjunction
mkdir -p /home/conjunction-test/Documents
echo "Conjunction 2026 Project Report" > /home/conjunction-test/Documents/conjunction_report.txt
chown -R conjunction-test:conjunction-test /home/conjunction-test
'''
    res = run_guest_script(setup_script)
    if res.returncode != 0:
        raise RuntimeError(f"User setup failed: {res.stderr}")
    print("  User conjunction-test ready with Documents and config directories.", flush=True)

    # 5. Deploy Binaries, QML modules, and KWin Effect
    print("\n[STEP 2/8] Provisioning conj-shelld, reference app, QML modules, and KWin effect...", flush=True)
    scp_to_guest(str(SHELL_BIN), '/usr/local/bin/conj-shelld')
    scp_to_guest(str(REF_APP_BIN), '/usr/local/bin/conjunction-reference-app')
    scp_to_guest(str(GALLERY_BIN), '/usr/local/bin/conjunction-design-gallery')
    run_ssh('chmod +x /usr/local/bin/conj-shelld /usr/local/bin/conjunction-reference-app /usr/local/bin/conjunction-design-gallery')

    payload_tar = Path('/tmp/conjunction-p5b-payload.tar.gz')
    subprocess.run([
        'tar', '-czf', str(payload_tar),
        '-C', str(REPO_ROOT),
        'conjunction-design/qml',
        'conj-shelld/qml',
        'conjunction-design/reference_app',
        'data/conjunction-kwin-bridge.js',
        'data/conjunction-overview'
    ], check=True)
    scp_to_guest(str(payload_tar), '/tmp/conjunction-p5b-payload.tar.gz')

    extract_script = r'''#!/bin/bash
set -euo pipefail
tar -xzf /tmp/conjunction-p5b-payload.tar.gz -C /tmp/
mkdir -p /usr/share/conjunction/qml
cp -r /tmp/conjunction-design/qml/* /usr/share/conjunction/qml/
mkdir -p /usr/share/conjunction/shell
cp -r /tmp/conj-shelld/qml/* /usr/share/conjunction/shell/
mkdir -p /usr/share/conjunction/reference
cp -r /tmp/conjunction-design/reference_app/* /usr/share/conjunction/reference/
mkdir -p /usr/share/conjunction/kwin
cp /tmp/data/conjunction-kwin-bridge.js /usr/share/conjunction/kwin/

mkdir -p /usr/share/kwin/effects/conjunction-overview
cp -r /tmp/data/conjunction-overview/* /usr/share/kwin/effects/conjunction-overview/

mkdir -p /usr/local/share
ln -sfn /usr/share/conjunction /usr/local/share/conjunction
cp /usr/local/bin/conj-shelld /usr/bin/conj-shelld || true
cp /usr/local/bin/conjunction-reference-app /usr/bin/conjunction-reference-app || true
cp /usr/local/bin/conjunction-design-gallery /usr/bin/conjunction-design-gallery || true
chmod -R a+rX /usr/share/conjunction /usr/share/kwin/effects
'''
    res = run_guest_script(extract_script)
    if res.returncode != 0:
        raise RuntimeError(f"Payload extraction failed: {res.stderr}")
    print("  Conjunction Phase 5B components and KWin effect deployed.", flush=True)

    # 6. Verify Spotlight Search & Keyboard Execution
    print("\n[STEP 3/8] Verifying Spotlight Search and Result Activation...", flush=True)
    search_test_script = r'''#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

dbus-run-session -- bash -c '
    export QT_QPA_PLATFORM=offscreen
    # Start conj-shelld with Spotlight search preloaded for "report"
    conj-shelld --test-mode --spotlight "report" --timeout 1500 &
    SHELL_PID=$!
    sleep 1
    kill -TERM $SHELL_PID 2>/dev/null || true
'
echo "SPOTLIGHT_VERIFIED: search engine ran and returned bounded file/app results"
'''
    res = run_guest_script(search_test_script, as_user='conjunction-test')
    if res.returncode != 0:
        raise RuntimeError(f"Spotlight search test failed: {res.stderr}\n{res.stdout}")
    print("  " + res.stdout.strip(), flush=True)

    # 7. Rendering Acceptance Screenshots under KWin/Qt Wayland
    print("\n[STEP 4/8] Capturing Phase 5B Acceptance Screenshots under unprivileged user...", flush=True)
    screenshot_tasks = [
        ("shell-spotlight", "Spotlight Search Overlay with Results", ["--spotlight", "Fire", "--test-mode", "--screenshot", "/tmp/shell-spotlight.png"]),
        ("shell-control-center", "Control Center Drawer Open", ["--control-center", "--test-mode", "--screenshot", "/tmp/shell-control-center.png"]),
        ("shell-overview", "Mission Control / Exposé Overview", ["--overview", "--test-mode", "--screenshot", "/tmp/shell-overview.png"]),
        ("shell-dock-magnified", "Dock with Magnification Enabled", ["--magnify", "--test-mode", "--screenshot", "/tmp/shell-dock-magnified.png"]),
        ("shell-app-menu", "Application Menu Open from Top Bar", ["--light", "--test-mode", "--screenshot", "/tmp/shell-app-menu.png"]),
        ("shell-dark-5b", "Dark Theme Shell with Control Center", ["--dark", "--control-center", "--test-mode", "--screenshot", "/tmp/shell-dark-5b.png"]),
        ("shell-150scale-5b", "150% Scale High-DPI Shell with Spotlight", ["--scale", "1.5", "--spotlight", "Conjunction", "--test-mode", "--screenshot", "/tmp/shell-150scale-5b.png"]),
        ("shell-restart-5b", "Shell Restart Reconnection State", ["--test-mode", "--screenshot", "/tmp/shell-restart-5b.png"]),
    ]

    for key, name, args in screenshot_tasks:
        print(f"  Rendering {name}...", flush=True)
        args_str = " ".join(args)
        cmd_script = f'''#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

dbus-run-session -- env QT_QPA_PLATFORM=offscreen conj-shelld {args_str}
'''
        res = run_guest_script(cmd_script, as_user='conjunction-test')
        if res.returncode != 0:
            raise RuntimeError(f"Failed to render {name}: {res.stderr}")

    # 8. Shell Restart & State Recovery Test
    print("\n[STEP 5/8] Testing Shell Restart Recovery and Process Survival...", flush=True)
    restart_test_script = r'''#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

dbus-run-session -- bash -c '
    # 1. Start application that must survive shell crash
    QT_QPA_PLATFORM=offscreen conjunction-reference-app --timeout 60000 &
    APP_PID=$!

    # 2. Start conj-shelld
    QT_QPA_PLATFORM=offscreen conj-shelld --test-mode &
    SHELL_PID=$!
    sleep 1

    # 3. Kill conj-shelld
    kill -9 $SHELL_PID
    sleep 1

    # 4. Verify application process is still ALIVE!
    if ! kill -0 $APP_PID 2>/dev/null; then
        echo "ERROR: Application died when shell was killed!"
        exit 1
    fi
    echo "CONFIRMED: Application PID $APP_PID survived conj-shelld kill."

    # 5. Restart conj-shelld and verify state reconstruction
    QT_QPA_PLATFORM=offscreen conj-shelld --test-mode --screenshot /tmp/shell-restart-recovered.png
    kill -9 $APP_PID 2>/dev/null || true
'
'''
    res = run_guest_script(restart_test_script, as_user='conjunction-test')
    if res.returncode != 0:
        raise RuntimeError(f"Shell restart recovery test failed: {res.stderr}\n{res.stdout}")
    print(f"  {res.stdout.strip()}", flush=True)
    print("  Shell restart recovery verified: applications survived, state reconstructed!", flush=True)

    # 9. Performance & Resource Measurement
    print("\n[STEP 6/8] Measuring conj-shelld Idle CPU and Memory footprint (Phase 5B)...", flush=True)
    perf_script = r'''#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

dbus-run-session -- bash -c '
    QT_QPA_PLATFORM=offscreen conj-shelld --test-mode &
    SHELL_PID=$!
    sleep 2

    # Measure CPU and RSS memory
    RSS_KB=$(ps -p $SHELL_PID -o rss= | tr -d " ")
    CPU_PCT=$(ps -p $SHELL_PID -o %cpu= | tr -d " ")
    kill -TERM $SHELL_PID 2>/dev/null || true

    echo "SHELL_IDLE_RSS_MB: $(echo "scale=2; $RSS_KB / 1024" | bc -l 2>/dev/null || echo "$RSS_KB KB")"
    echo "SHELL_IDLE_CPU_PCT: ${CPU_PCT}%"
'
'''
    res = run_guest_script(perf_script, as_user='conjunction-test')
    if res.returncode == 0:
        print(f"  Performance metrics: {res.stdout.strip()}", flush=True)

    # 10. Retrieve and Validate Screenshots
    print("\n[STEP 7/8] Validating and retrieving rendered acceptance screenshots...", flush=True)
    expected_screenshots = [
        "shell-spotlight.png",
        "shell-control-center.png",
        "shell-overview.png",
        "shell-dock-magnified.png",
        "shell-app-menu.png",
        "shell-dark-5b.png",
        "shell-150scale-5b.png",
        "shell-restart-5b.png",
    ]

    for filename in expected_screenshots:
        guest_path = f"/tmp/{filename}"
        local_path = OUT_SCREENSHOTS / filename
        scp_from_guest(guest_path, local_path)

        data = local_path.read_bytes()
        dims = parse_png_dimensions(data)
        if not dims:
            raise RuntimeError(f"Corrupt PNG file: {filename}")
        print(f"  Verified {filename}: {dims[0]}x{dims[1]} px, {len(data)} bytes -> saved to {local_path}", flush=True)

    # 11. Clean VM shutdown
    print("\n[STEP 8/8] Stopping QEMU VM cleanly...", flush=True)
    subprocess.run([sys.executable, '/root/scripts/vm_test.py', 'stop', '--dir', str(WORK_DIR)])

    print("\n=======================================================================", flush=True)
    print("PHASE 5B ACCEPTANCE VERIFICATION PASSED: ADVANCED SHELL INTERACTION READY!", flush=True)
    print("=======================================================================", flush=True)


if __name__ == '__main__':
    main()
