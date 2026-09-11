#!/usr/bin/env python3
"""Control disposable QEMU VMs for live and installed boot checks (Linux/WSL)."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time


def qmp(state, command, arguments=None):
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


def key(state, keys):
    qmp(state, "human-monitor-command", {"command-line": "sendkey " + keys})
    time.sleep(0.06)


def type_text(state, text):
    mapping = {" ": "spc", "\n": "ret", "/": "slash", ".": "dot",
               "-": "minus", "_": "shift-minus", ":": "shift-semicolon",
               ";": "semicolon", "=": "equal", "+": "shift-equal",
               "'": "apostrophe", '"': "shift-apostrophe", "|": "shift-backslash",
               ">": "shift-dot", "<": "shift-comma", "&": "shift-7",
               "!": "shift-1", "(": "shift-9", ")": "shift-0",
               "$": "shift-4", "~": "shift-grave", ",": "comma", "@": "shift-2"}
    for char in text:
        code = mapping.get(char)
        if code is None:
            if char.isascii() and char.isalnum():
                code = "shift-" + char.lower() if char.isupper() else char
            else:
                raise ValueError(f"Unsupported keyboard character: {char!r}")
        key(state, code)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["start", "status", "key", "type", "screenshot", "stop", "ssh", "authorize"])
    parser.add_argument("--dir", type=Path, required=True)
    parser.add_argument("--iso", type=Path)
    parser.add_argument("--firmware", choices=["uefi", "bios"], default="uefi")
    parser.add_argument("--disk-boot", action="store_true")
    parser.add_argument("--port", type=int, default=2222)
    parser.add_argument("text", nargs="?")
    args = parser.parse_args()
    directory = args.dir.resolve()
    state_file = directory / "vm.json"
    if args.action == "start":
        directory.mkdir(parents=True, exist_ok=True)
        if state_file.exists():
            previous = json.loads(state_file.read_text())
            try:
                qmp(previous, "query-status")
            except (OSError, RuntimeError):
                pass
            else:
                raise RuntimeError("VM is already running; stop it first")
        disk = directory / "disk.qcow2"
        if not disk.exists():
            if args.disk_boot:
                raise RuntimeError("No installed disk exists")
            subprocess.run(["qemu-img", "create", "-f", "qcow2", str(disk), "40G"], check=True)
        socket_dir = tempfile.mkdtemp(prefix="conjunction-vm-")
        state = {"socket": socket_dir + "/qmp.sock", "port": args.port}
        cmd = ["qemu-system-x86_64", "-m", "4096", "-smp", "2", "-display", "none",
               "-vga", "virtio", "-no-reboot", "-daemonize",
               "-qmp", "unix:" + state["socket"] + ",server=on,wait=off",
               "-serial", "file:" + str(directory / ("installed.log" if args.disk_boot else "live.log")),
               "-drive", f"file={disk},format=qcow2,if=virtio",
               "-netdev", "user,id=net0" + (f",hostfwd=tcp:127.0.0.1:{args.port}-:22" if args.port else ""),
               "-device", "virtio-net-pci,netdev=net0"]
        if os.access("/dev/kvm", os.R_OK | os.W_OK):
            cmd += ["-enable-kvm", "-cpu", "host"]
        if args.firmware == "uefi":
            firmware_pairs = [
                (os.environ.get("OVMF_CODE", ""), os.environ.get("OVMF_VARS", "")),
                ("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd"),
                ("/usr/share/edk2/x64/OVMF_CODE.4m.fd", "/usr/share/edk2/x64/OVMF_VARS.4m.fd"),
            ]
            pair = next(((Path(code), Path(variables)) for code, variables in firmware_pairs
                         if code and variables and Path(code).is_file() and Path(variables).is_file()), None)
            if pair is None:
                raise RuntimeError("Install OVMF firmware or set OVMF_CODE and OVMF_VARS")
            firmware, variables_template = pair
            variables = directory / "OVMF_VARS.fd"
            if not variables.exists():
                shutil.copyfile(variables_template, variables)
            cmd += ["-drive", f"if=pflash,format=raw,readonly=on,file={firmware}",
                    "-drive", f"if=pflash,format=raw,file={variables}"]
        if not args.disk_boot:
            if not args.iso or not args.iso.is_file():
                raise RuntimeError("A live ISO is required")
            cmd += ["-boot", "d", "-cdrom", str(args.iso.resolve())]
        else:
            cmd += ["-boot", "c"]
        subprocess.run(cmd, check=True)
        state_file.write_text(json.dumps(state, indent=2))
        print("Started", "installed disk without ISO" if args.disk_boot else "live ISO", directory)
        return
    state = json.loads(state_file.read_text())
    if args.action == "status":
        print(qmp(state, "query-status"))
    elif args.action == "key":
        key(state, args.text)
    elif args.action == "type":
        type_text(state, args.text)
    elif args.action == "screenshot":
        target = directory / (args.text or "screen.ppm")
        qmp(state, "screendump", {"filename": str(target)})
        print(target)
    elif args.action == "stop":
        qmp(state, "quit")
    elif args.action == "authorize":
        # Run only at the live VM's root console. The key remains in its RAM overlay.
        identity = directory / "test-key"
        if not identity.exists():
            subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(identity)], check=True)
        pubkey = " ".join(Path(str(identity) + ".pub").read_text().split()[:2])
        type_text(state, f"mkdir -p /root/.ssh; echo '{pubkey}' > /root/.ssh/authorized_keys; systemctl start sshd\n")
    elif args.action == "ssh":
        subprocess.run(["ssh", "-i", str(directory / "test-key"), "-p", str(state["port"]),
                        "-o", "StrictHostKeyChecking=accept-new", "-o", "IdentitiesOnly=yes",
                        "-o", "UserKnownHostsFile=" + str(directory / "known_hosts"),
                        "root@127.0.0.1", args.text], check=True)


if __name__ == "__main__":
    main()
