#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/conjunction-build/arch-chroot/root.x86_64"
VERSION="3.4.2"
TARBALL="calamares-${VERSION}.tar.gz"
HOST_TARBALL="/root/${TARBALL}"
URL="https://codeberg.org/Calamares/calamares/releases/download/v${VERSION}/${TARBALL}"
SHA256="733bbbb00dc9f84874bd5c22960952f317ea2537565431179fa2152b2fbfdccc"

if [[ ! -f "$HOST_TARBALL" ]]; then
    echo "==> Downloading Calamares to $HOST_TARBALL..."
    wget -O "$HOST_TARBALL" "$URL" || curl -k -L -o "$HOST_TARBALL" "$URL"
fi

echo "${SHA256}  ${HOST_TARBALL}" | sha256sum -c -

# Ensure chroot mounts
mountpoint -q "$ROOT/proc" || mount -t proc proc "$ROOT/proc"
mountpoint -q "$ROOT/sys" || mount -t sysfs sys "$ROOT/sys"
mountpoint -q "$ROOT/dev" || mount --bind /dev "$ROOT/dev"
mountpoint -q "$ROOT/dev/pts" || mount -t devpts devpts "$ROOT/dev/pts"
mountpoint -q "$ROOT/run" || mount -t tmpfs tmpfs "$ROOT/run"
mountpoint -q "$ROOT/tmp" || mount -t tmpfs tmpfs "$ROOT/tmp"
cp -f /etc/resolv.conf "$ROOT/etc/resolv.conf" 2>/dev/null || true

# Copy downloaded tarball into chroot
mkdir -p "$ROOT/var/tmp/calamares-build"
cp "$HOST_TARBALL" "$ROOT/var/tmp/calamares-build/"

chroot "$ROOT" /bin/bash -c '
set -euo pipefail

VERSION="3.4.2"
TARBALL="calamares-${VERSION}.tar.gz"
WORK_DIR="/var/tmp/calamares-build"
cd "$WORK_DIR"

echo "==> Extracting Calamares..."
rm -rf "calamares-${VERSION}"
tar -xzf "$TARBALL"
cd "calamares-${VERSION}"

echo "==> Configuring with CMake and Qt 6..."
_skip_modules="dracut dracutlukscfg dummycpp dummyprocess dummypython dummypythonqt initramfs initramfscfg interactiveterminal packagechooser packagechooserq services-openrc"

cmake -B build -S . -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DWITH_QT6=ON \
    -DINSTALL_CONFIG=ON \
    -DSKIP_MODULES="${_skip_modules}" \
    -DBUILD_TESTING=OFF \
    -DKDE_INSTALL_BINDIR=/usr/bin \
    -DKDE_INSTALL_SBINDIR=/usr/sbin \
    -DKDE_INSTALL_LIBDIR=/usr/lib \
    -DKDE_INSTALL_LIBEXECDIR=/usr/libexec \
    -DKDE_INSTALL_INCLUDEDIR=/usr/include \
    -DKDE_INSTALL_LOCALSTATEDIR=/var \
    -DKDE_INSTALL_SHAREDSTATEDIR=/usr/share \
    -DKDE_INSTALL_DATAROOTDIR=/usr/share \
    -DKDE_INSTALL_DATADIR=/usr/share \
    -DKDE_INSTALL_LOCALEDIR=/usr/share/locale \
    -DKDE_INSTALL_MANDIR=/usr/share/man \
    -DKDE_INSTALL_INFODIR=/usr/share/info \
    -DKDE_INSTALL_SYSCONFDIR=/etc \
    -Wno-dev

echo "==> Compiling Calamares with Ninja..."
cmake --build build -j$(nproc)

echo "==> Installing Calamares to chroot /usr..."
cmake --install build

echo "==> Verifying Calamares binary..."
/usr/bin/calamares --version
'
