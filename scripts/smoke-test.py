#!/usr/bin/env python3
"""Boot an ISO under BIOS and UEFI and require a real Plasma/welcome readiness signal."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from vm_test import qmp

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("iso", type=Path)
parser.add_argument("--timeout", type=int, default=300)
parser.add_argument("--firmware", choices=["bios", "uefi", "both"], default="both")
args = parser.parse_args()
runner = Path(__file__).with_name("vm_test.py")
for mode in (["bios", "uefi"] if args.firmware == "both" else [args.firmware]):
    directory = Path(tempfile.mkdtemp(prefix=f"conjunction-smoke-{mode}-"))
    print(f"Booting {mode}; logs: {directory}", flush=True)
    subprocess.run([sys.executable, str(runner), "start", "--dir", str(directory),
                    "--iso", str(args.iso.resolve()), "--firmware", mode, "--port", "0"], check=True)
    state = json.loads((directory / "vm.json").read_text())
    try:
        deadline = time.monotonic() + args.timeout
        ready = False
        while time.monotonic() < deadline:
            if "SMOKE_TEST_OK: boot=1 sddm=1 networkmanager=1 plasma=1 welcome=1" in (directory / "live.log").read_text(errors="replace"):
                ready = True
                break
            if qmp(state, "query-status")["status"] != "running":
                break
            time.sleep(2)
        qmp(state, "screendump", {"filename": str(directory / "screen.ppm")})
        if not ready:
            raise RuntimeError(f"{mode} desktop failed to become ready; inspect {directory}")
        print(f"PASS: {mode} live desktop and welcome window", flush=True)
    finally:
        try:
            qmp(state, "quit")
        except OSError:
            pass
