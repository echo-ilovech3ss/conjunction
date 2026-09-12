#!/usr/bin/env python3
"""Phase 4A Visual Verification inside QEMU (WSL2)."""

import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time

WORK_DIR = Path('/root/phase4a-vm')
ISO_PATH = Path('/root/conjunction-build/out/conjunction-20260911-x86_64.iso')
GALLERY_BIN_CANDIDATES = [
    Path('/tmp/wsl-target/release/conjunction-design-gallery'),
    Path('/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs/tmp/conjunction-design-gallery'),
]
GALLERY_BIN = next((p for p in GALLERY_BIN_CANDIDATES if p.exists()), GALLERY_BIN_CANDIDATES[0])
DESIGN_SRC = Path('/mnt/c/Users/Way4U/Coding-projects/conjunction/conjunction-design')
OUT_SCREENSHOTS = Path('/mnt/c/Users/Way4U/Coding-projects/conjunction/docs/design/screenshots')
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


def scp_from_guest(src_path, dst_path):
    scp_cmd = [
        'sshpass', '-p', PASSWORD,
        'scp', '-P', str(SSH_PORT),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'LogLevel=ERROR',
        f'root@127.0.0.1:{src_path}', str(dst_path)
    ]
    subprocess.run(scp_cmd, check=True)


def run_guest_script(script_content, as_user=None, timeout=120):
    local_tmp = Path('/tmp/guest_exec_p4a.sh')
    local_tmp.write_text(script_content)
    scp_to_guest(str(local_tmp), '/tmp/guest_exec_p4a.sh')
    run_ssh('chmod 755 /tmp/guest_exec_p4a.sh')
    if as_user:
        return run_ssh(f"su - {as_user} -c 'bash /tmp/guest_exec_p4a.sh'", timeout=timeout)
    else:
        return run_ssh('bash /tmp/guest_exec_p4a.sh', timeout=timeout)


def parse_png_dimensions(data: bytes):
    if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    width, height = struct.unpack('>II', data[16:24])
    return width, height


def main():
    print("=== Conjunction Phase 4A Visual Foundation & Theme Engine QEMU Verification ===", flush=True)

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

    # 4. Provision unprivileged user & system directories
    print("\n[STEP 1/7] Setting up unprivileged user conjunction-test and directories...", flush=True)
    setup_script = r'''#!/bin/bash
set -euo pipefail
if ! id -u conjunction-test &>/dev/null; then
    useradd -m -s /bin/bash conjunction-test
fi
mkdir -p /usr/share/conjunction/qml
mkdir -p /usr/share/conjunction/gallery
mkdir -p /tmp/runtime-conjunction-test
chown -R conjunction-test:conjunction-test /tmp/runtime-conjunction-test
chmod 700 /tmp/runtime-conjunction-test
'''
    res = run_guest_script(setup_script)
    if res.returncode != 0:
        raise RuntimeError(f"User setup failed: {res.stderr}")
    print("  User conjunction-test created and ready.", flush=True)

    # 5. Provision binary and design files
    print("\n[STEP 2/7] Provisioning design gallery binary and QML module...", flush=True)
    if not GALLERY_BIN.exists():
        raise FileNotFoundError(f"Binary {GALLERY_BIN} not found. Build it first.")

    scp_to_guest(str(GALLERY_BIN), '/usr/local/bin/conjunction-design-gallery')
    run_ssh('chmod +x /usr/local/bin/conjunction-design-gallery')

    # Copy QML design module and gallery files
    tmp_archive = Path('/tmp/conjunction-design-payload.tar.gz')
    subprocess.run([
        'tar', '-czf', str(tmp_archive),
        '-C', str(DESIGN_SRC.parent),
        'conjunction-design'
    ], check=True)
    scp_to_guest(str(tmp_archive), '/tmp/conjunction-design-payload.tar.gz')

    extract_script = r'''#!/bin/bash
set -euo pipefail
tar -xzf /tmp/conjunction-design-payload.tar.gz -C /tmp/
mkdir -p /usr/share/conjunction/qml
cp -r /tmp/conjunction-design/qml/* /usr/share/conjunction/qml/
mkdir -p /usr/share/conjunction/gallery
cp -r /tmp/conjunction-design/gallery/* /usr/share/conjunction/gallery/
chmod -R a+rX /usr/share/conjunction
'''
    res = run_guest_script(extract_script)
    if res.returncode != 0:
        raise RuntimeError(f"Payload extraction failed: {res.stderr}")
    print("  QML design tokens and gallery successfully installed to /usr/share/conjunction.", flush=True)

    # 6. Execute Visual Screenshot Tests as unprivileged user
    print("\n[STEP 3/7] Rendering offscreen visual scenes under conjunction-test...", flush=True)
    tests = [
        ("light", "Light Theme Benchmark", ["--theme", "light", "--scene", "benchmark", "--screenshot", "/tmp/screenshot-light.png"]),
        ("dark", "Dark Theme Benchmark", ["--theme", "dark", "--scene", "benchmark", "--screenshot", "/tmp/screenshot-dark.png"]),
        ("rtl", "Right-to-Left Layout Benchmark", ["--theme", "light", "--rtl", "--scene", "benchmark", "--screenshot", "/tmp/screenshot-rtl.png"]),
        ("150scale", "150% Scale Benchmark", ["--theme", "light", "--scale", "1.5", "--scene", "benchmark", "--screenshot", "/tmp/screenshot-150scale.png"]),
        ("reduced_motion", "Reduced Motion Benchmark", ["--theme", "light", "--reduced-motion", "--scene", "benchmark", "--screenshot", "/tmp/screenshot-reduced-motion.png"]),
    ]

    for test_key, test_desc, test_args in tests:
        print(f"  Rendering {test_desc}...", flush=True)
        args_str = " ".join(test_args)
        cmd = f'''export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
export QT_QPA_PLATFORM=offscreen
/usr/local/bin/conjunction-design-gallery {args_str}
'''
        res = run_guest_script(cmd, as_user='conjunction-test', timeout=30)
        if res.returncode != 0:
            raise RuntimeError(f"Rendering failed for {test_desc}: stdout=" + str(res.stdout) + ", stderr=" + str(res.stderr))
        print(f"    -> Rendered successfully. Output: " + (res.stderr.strip() or res.stdout.strip()))

    # 7. Execute Interactive Focus Navigation Test
    print("\n[STEP 4/7] Running keyboard focus cycling test (no pointer input)...", flush=True)
    focus_cmd = '''export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
export QT_QPA_PLATFORM=offscreen
/usr/local/bin/conjunction-design-gallery --focus-test
'''
    res = run_guest_script(focus_cmd, as_user='conjunction-test', timeout=30)
    if res.returncode != 0:
        raise RuntimeError(f"Focus test failed: {res.stderr}")
    print(f"  Keyboard focus navigation verified: " + res.stderr.strip())

    # 8. Execute Theme Switch Stress Test
    print("\n[STEP 5/7] Running dynamic theme switch stress test (50 cycles)...", flush=True)
    stress_cmd = '''export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
export QT_QPA_PLATFORM=offscreen
/usr/local/bin/conjunction-design-gallery --stress-test-themes 50
'''
    res = run_guest_script(stress_cmd, as_user='conjunction-test', timeout=60)
    if res.returncode != 0:
        raise RuntimeError(f"Theme stress test failed: {res.stderr}")

    # 9. Verify and retrieve screenshots
    print("\n[STEP 6/7] Validating and retrieving rendered screenshots...", flush=True)
    expected_files = [
        "screenshot-light.png",
        "screenshot-dark.png",
        "screenshot-rtl.png",
        "screenshot-150scale.png",
        "screenshot-reduced-motion.png"
    ]

    for fname in expected_files:
        guest_path = f"/tmp/{fname}"
        host_path = OUT_SCREENSHOTS / fname
        scp_from_guest(guest_path, str(host_path))

        with open(host_path, 'rb') as f:
            data = f.read()

        dims = parse_png_dimensions(data)
        if not dims:
            raise ValueError(f"File {fname} is not a valid PNG")
        width, height = dims
        print(f"  Verified {fname}: {width}x{height} px, {len(data)} bytes -> saved to {host_path}", flush=True)

        if len(data) < 5000:
            raise ValueError(f"Rendered image {fname} is suspiciously small: {len(data)} bytes")

    # 10. Clean VM shutdown
    print("\n[STEP 7/7] Stopping QEMU VM cleanly...", flush=True)
    subprocess.run([
        sys.executable, '/root/scripts/vm_test.py', 'stop',
        '--dir', str(WORK_DIR)
    ], check=True)

    print("\n=======================================================================", flush=True)
    print("PHASE 4A ACCEPTANCE VERIFICATION PASSED: REAL QEMU RENDERING CONFIRMED!", flush=True)
    print("=======================================================================", flush=True)


if __name__ == '__main__':
    main()
