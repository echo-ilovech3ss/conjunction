#!/usr/bin/env python3
"""Phase 4B Production Controls Acceptance Verification inside QEMU (WSL2)."""

import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time

WORK_DIR = Path('/root/phase4b-vm')
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
    local_tmp = Path('/tmp/guest_exec_p4b.sh')
    local_tmp.write_text(script_content)
    scp_to_guest(str(local_tmp), '/tmp/guest_exec_p4b.sh')
    run_ssh('chmod 755 /tmp/guest_exec_p4b.sh')
    if as_user:
        return run_ssh(f"su - {as_user} -c 'bash /tmp/guest_exec_p4b.sh'", timeout=timeout)
    else:
        return run_ssh('bash /tmp/guest_exec_p4b.sh', timeout=timeout)


def parse_png_dimensions(data: bytes):
    if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    width, height = struct.unpack('>II', data[16:24])
    return width, height


def main():
    print("=== Conjunction Phase 4B Production Controls QEMU System Verification ===", flush=True)

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
    print("\n[STEP 1/8] Setting up unprivileged user conjunction-test and directories...", flush=True)
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
    print("  User conjunction-test ready.", flush=True)

    # 5. Provision gallery binary and full QML payload (Design + Controls)
    print("\n[STEP 2/8] Provisioning conjunction-design-gallery and Conjunction.Controls module...", flush=True)
    scp_to_guest(str(GALLERY_BIN), '/usr/local/bin/conjunction-design-gallery')
    run_ssh('chmod +x /usr/local/bin/conjunction-design-gallery')

    tmp_archive = Path('/tmp/conjunction-p4b-payload.tar.gz')
    subprocess.run([
        'tar', '-czf', str(tmp_archive),
        '-C', str(DESIGN_SRC.parent),
        'conjunction-design'
    ], check=True)
    scp_to_guest(str(tmp_archive), '/tmp/conjunction-p4b-payload.tar.gz')

    extract_script = r'''#!/bin/bash
set -euo pipefail
tar -xzf /tmp/conjunction-p4b-payload.tar.gz -C /tmp/
mkdir -p /usr/share/conjunction/qml
cp -r /tmp/conjunction-design/qml/* /usr/share/conjunction/qml/
mkdir -p /usr/share/conjunction/gallery
cp -r /tmp/conjunction-design/gallery/* /usr/share/conjunction/gallery/
chmod -R a+rX /usr/share/conjunction
'''
    res = run_guest_script(extract_script)
    if res.returncode != 0:
        raise RuntimeError(f"Payload extraction failed: {res.stderr}")
    print("  Conjunction.Controls and gallery deployed to /usr/share/conjunction.", flush=True)

    # 6. Execute Visual Screenshot Tests
    print("\n[STEP 3/8] Rendering offscreen control scenes under conjunction-test...", flush=True)
    tests = [
        ("light", "Light Controls Scene", ["--theme", "light", "--scene", "controls_buttons", "--screenshot", "/tmp/screenshot-controls-light.png"]),
        ("dark", "Dark Controls Scene", ["--theme", "dark", "--scene", "controls_buttons", "--screenshot", "/tmp/screenshot-controls-dark.png"]),
        ("desktop_reference", "Integrated DesktopReference Scene", ["--theme", "light", "--scene", "desktop_reference", "--screenshot", "/tmp/screenshot-desktop-reference.png"]),
        ("dialogs", "Modal Dialogs & Sheets Scene", ["--theme", "light", "--scene", "controls_dialogs", "--screenshot", "/tmp/screenshot-dialogs.png"]),
        ("150scale", "150% Scale DesktopReference Scene", ["--theme", "light", "--scale", "1.5", "--scene", "desktop_reference", "--screenshot", "/tmp/screenshot-controls-150scale.png"]),
        ("200scale", "200% Scale DesktopReference Scene", ["--theme", "light", "--scale", "2.0", "--scene", "desktop_reference", "--screenshot", "/tmp/screenshot-controls-200scale.png"]),
        ("rtl", "RTL Mirrored DesktopReference Scene", ["--theme", "light", "--rtl", "--scene", "desktop_reference", "--screenshot", "/tmp/screenshot-controls-rtl.png"]),
        ("reduced_motion", "Reduced Motion Controls Scene", ["--theme", "light", "--reduced-motion", "--scene", "controls_progress_slider", "--screenshot", "/tmp/screenshot-reduced-motion.png"]),
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

    # 7. Execute End-to-End Keyboard Workflow Test
    print("\n[STEP 4/8] Running end-to-end keyboard-only workflow test...", flush=True)
    kb_cmd = '''export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
export QT_QPA_PLATFORM=offscreen
/usr/local/bin/conjunction-design-gallery --keyboard-test
'''
    res = run_guest_script(kb_cmd, as_user='conjunction-test', timeout=30)
    if res.returncode != 0:
        raise RuntimeError(f"Keyboard workflow failed: {res.stderr}")
    print("  Keyboard-only workflow verified (Search, Segmented, Sidebar, Menu, Dialog):\n" + res.stderr.strip())

    # 8. Execute Dynamic Theme Switch Stress Test
    print("\n[STEP 5/8] Running dynamic theme switch stress test (50 cycles)...", flush=True)
    stress_cmd = '''export XDG_RUNTIME_DIR=/tmp/runtime-conjunction-test
export QT_QPA_PLATFORM=offscreen
/usr/local/bin/conjunction-design-gallery --stress-test-themes 50
'''
    res = run_guest_script(stress_cmd, as_user='conjunction-test', timeout=60)
    if res.returncode != 0:
        raise RuntimeError(f"Theme stress test failed: {res.stderr}")
    print("  Dynamic theme switching stability verified:\n" + res.stderr.strip())

    # 9. Verify and retrieve screenshots
    print("\n[STEP 6/8] Validating and retrieving rendered screenshots...", flush=True)
    expected_files = [
        "screenshot-controls-light.png",
        "screenshot-controls-dark.png",
        "screenshot-desktop-reference.png",
        "screenshot-dialogs.png",
        "screenshot-controls-150scale.png",
        "screenshot-controls-200scale.png",
        "screenshot-controls-rtl.png",
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
    print("\n[STEP 7/8] Stopping QEMU VM cleanly...", flush=True)
    subprocess.run([
        sys.executable, '/root/scripts/vm_test.py', 'stop',
        '--dir', str(WORK_DIR)
    ], check=True)

    print("\n=======================================================================", flush=True)
    print("PHASE 4B ACCEPTANCE VERIFICATION PASSED: PRODUCTION CONTROLS VERIFIED!", flush=True)
    print("=======================================================================", flush=True)


if __name__ == '__main__':
    main()
