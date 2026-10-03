#!/usr/bin/env bash
set -euo pipefail

ROOT="${CONJUNCTION_CHROOT_ROOT:-/root/conjunction-build/arch-chroot/root.x86_64}"
WINDOWS_SRC="${CONJUNCTION_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

mountpoint -q "$ROOT/proc" || mount -t proc proc "$ROOT/proc"
mountpoint -q "$ROOT/sys" || mount -t sysfs sys "$ROOT/sys"
mountpoint -q "$ROOT/dev" || mount --bind /dev "$ROOT/dev"
mountpoint -q "$ROOT/dev/pts" || mount -t devpts devpts "$ROOT/dev/pts"
mountpoint -q "$ROOT/run" || mount -t tmpfs tmpfs "$ROOT/run"
mountpoint -q "$ROOT/tmp" || mount -t tmpfs tmpfs "$ROOT/tmp"

# Bind mount conjunction repo
mkdir -p "$ROOT/conjunction-repo"
mountpoint -q "$ROOT/conjunction-repo" || mount --bind "$WINDOWS_SRC" "$ROOT/conjunction-repo"

# Symlinks for bash
mkdir -p "$ROOT/dev"
ln -sf /proc/self/fd "$ROOT/dev/fd" 2>/dev/null || true
ln -sf /proc/self/fd/0 "$ROOT/dev/stdin" 2>/dev/null || true
ln -sf /proc/self/fd/1 "$ROOT/dev/stdout" 2>/dev/null || true
ln -sf /proc/self/fd/2 "$ROOT/dev/stderr" 2>/dev/null || true

cp -f /etc/resolv.conf "$ROOT/etc/resolv.conf" 2>/dev/null || true

chroot "$ROOT" /bin/bash -c "$@"
