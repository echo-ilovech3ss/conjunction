<#
.SYNOPSIS
    Launches Conjunction OS in a native GUI window via QEMU and WSLg.

.DESCRIPTION
    Allows switching easily between booting the Live ISO and booting the installed system.

.PARAMETER Mode
    "Installed" (default) - Boots the installed Conjunction OS standalone from the virtual disk.
    "Live" - Boots the Conjunction OS live installer ISO with the virtual disk attached.

.PARAMETER MemoryMB
    Memory to allocate in MB (default: 4096).

.PARAMETER Cores
    CPU cores to allocate (default: 4).

.EXAMPLE
    .\run-conjunction.ps1
    # Boots the installed system standalone.

.EXAMPLE
    .\run-conjunction.ps1 -Mode Live
    # Boots the live ISO to test the desktop environment or installer.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Installed", "Live")]
    [string]$Mode = "Installed",

    [Parameter()]
    [int]$MemoryMB = 4096,

    [Parameter()]
    [int]$Cores = 4
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Conjunction OS Virtual Machine Launcher" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Mode:    $Mode" -ForegroundColor Green
Write-Host " Memory:  $MemoryMB MB" -ForegroundColor Gray
Write-Host " Cores:   $Cores" -ForegroundColor Gray
Write-Host ""

if ($Mode -eq "Live") {
    Write-Host "Booting from LIVE ISO..." -ForegroundColor Yellow
    Write-Host "- Auto-login will load the KDE Plasma live desktop."
    Write-Host "- Virtual disk /dev/vda is attached for installation."
    $BootArgs = "-boot d -cdrom /root/conjunction-build/out/conjunction-20260911-x86_64.iso"
} else {
    Write-Host "Booting from INSTALLED DISK (no ISO attached)..." -ForegroundColor Green
    Write-Host "- User:     vmtest"
    Write-Host "- Password: ConjunctionVM42"
    $BootArgs = "-boot c"
}

Write-Host "`nLaunching native QEMU GUI window on your desktop (close the window to stop)...`n" -ForegroundColor Yellow

$QemuCmd = @"
qemu-system-x86_64 \
  -m $MemoryMB \
  -smp $Cores \
  -enable-kvm -cpu host \
  -vga virtio \
  -display gtk,show-cursor=on \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=/root/test-vm/OVMF_VARS.fd \
  -drive file=/root/test-vm/disk.qcow2,format=qcow2,if=virtio \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  $BootArgs
"@

wsl.exe -u root -- bash -c $QemuCmd
