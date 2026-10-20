#!/usr/bin/env bash
# preflight.sh — read-only check sebelum install SekaiPop di CachyOS.
#
#   bash scripts/preflight.sh
#
# TIDAK mengubah apa pun. Tidak pakai sudo. Tidak install paket.
# Hanya membaca kondisi sistem dan melaporkan apa yang kurang.
#
# Exit 0 = semua prasyarat wajib terpenuhi.
# Exit 1 = ada yang wajib dan belum beres.

set -u

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B=$'\e[1m'; D=$'\e[2m'; Z=$'\e[0m'
    OK=$'\e[38;5;114m'; BAD=$'\e[38;5;203m'; WARN=$'\e[38;5;221m'; HD=$'\e[38;5;80m'
else
    B=; D=; Z=; OK=; BAD=; WARN=; HD=
fi

FAIL=0; WARNING=0

hr() {
    local i s=""
    for ((i = 0; i < 60; i++)); do s+="─"; done
    printf '%s\n' "$s"
}
step() { printf '\n%s%s%s\n' "$HD$B" "$1" "$Z"; hr; }
pass() { printf '  %s✔%s %s\n' "$OK" "$Z" "$1"; }
fail() { printf '  %s✘%s %s\n' "$BAD" "$Z" "$1"; FAIL=$((FAIL + 1)); }
warn() { printf '  %s!%s %s\n' "$WARN" "$Z" "$1"; WARNING=$((WARNING + 1)); }
note() { printf '    %s%s%s\n' "$D" "$1" "$Z"; }
have() { command -v "$1" >/dev/null 2>&1; }
pkg() { pacman -Q "$1" >/dev/null 2>&1; }

printf '\n%sSekaiPop preflight%s  %s(read-only, tidak mengubah apa pun)%s\n' "$B" "$Z" "$D" "$Z"
printf '%s%s%s\n' "$D" "$(date '+%Y-%m-%d %H:%M:%S')" "$Z"

# ---------------------------------------------------------------- 1. distro
step "1. Sistem"

if have pacman; then
    pass "pacman tersedia"
else
    fail "pacman tidak ada — ini bukan sistem Arch-based"
fi

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    pass "distro: ${PRETTY_NAME:-unknown}"
    case "${ID:-}${ID_LIKE:-}" in
        *arch*|*cachyos*) ;;
        *) warn "bukan Arch/CachyOS (ID=${ID:-?}) — belum diuji" ;;
    esac
else
    warn "/etc/os-release tidak terbaca"
fi

if [ -d /sys/firmware/efi ]; then
    pass "boot mode: UEFI"
else
    warn "boot mode: BIOS/Legacy — UEFI sangat disarankan"
fi

# arsitektur CPU vs repo CachyOS
ARCH_LEVEL=""
if [ -r /lib/ld-linux-x86-64.so.2 ] && have /lib/ld-linux-x86-64.so.2; then
    if /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v4'; then
        ARCH_LEVEL="x86-64-v4"
    elif /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v3'; then
        ARCH_LEVEL="x86-64-v3"
    else
        ARCH_LEVEL="x86-64 (base)"
    fi
fi
[ -n "$ARCH_LEVEL" ] && pass "dukungan CPU: $ARCH_LEVEL"

# ---------------------------------------------------------------- 2. GPU
step "2. GPU"

GPU_AMD=0; GPU_NVIDIA=0
if have lspci; then
    if lspci -nn 2>/dev/null | grep -Eiq 'vga|3d|display'; then
        lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | while IFS= read -r l; do
            printf '    %s%s%s\n' "$D" "$l" "$Z"
        done
        lspci -nn 2>/dev/null | grep -Eiq '\[1002:' && GPU_AMD=1
        lspci -nn 2>/dev/null | grep -Eiq '\[10de:' && GPU_NVIDIA=1
    else
        fail "tidak ada GPU terdeteksi oleh lspci"
    fi
else
    warn "lspci tidak ada (pciutils belum terpasang)"
fi

if [ "$GPU_AMD" = 1 ]; then pass "GPU AMD terdeteksi"; else warn "GPU AMD tidak terdeteksi"; fi

if [ "$GPU_NVIDIA" = 1 ]; then
    pass "GPU NVIDIA terdeteksi (hybrid graphics)"
    if have nvidia-smi; then
        if nvidia-smi >/dev/null 2>&1; then
            NV=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)
            pass "driver NVIDIA aktif: $NV"
        else
            fail "nvidia-smi gagal — driver NVIDIA belum benar"
            note "lihat docs/02-driver-gpu.md §2.5"
        fi
    else
        fail "GPU NVIDIA ada tapi nvidia-utils belum terpasang"
        note "sudo chwd -a    (atau: sudo pacman -S nvidia-open-dkms nvidia-utils)"
    fi

    if have lsmod && lsmod | grep -q '^nvidia_drm'; then
        pass "modul nvidia_drm termuat"
    else
        fail "modul nvidia_drm tidak termuat"
        note "cek: dkms status   lalu: sudo dkms autoinstall"
    fi
else
    pass "tidak ada GPU NVIDIA (tidak perlu driver proprietary)"
fi

# env yang memaksa NVIDIA jadi primary — penyebab layar hitam
FORCED=""
[ -n "${GBM_BACKEND:-}" ] && FORCED="$FORCED GBM_BACKEND=$GBM_BACKEND"
[ -n "${__GLX_VENDOR_LIBRARY_NAME:-}" ] && FORCED="$FORCED __GLX_VENDOR_LIBRARY_NAME=$__GLX_VENDOR_LIBRARY_NAME"
if [ -n "$FORCED" ]; then
    warn "env memaksa renderer:$FORCED"
    note "di laptop hybrid ini biasanya bikin layar hitam. lihat docs/02-driver-gpu.md §2.4"
else
    pass "tidak ada env yang memaksa renderer GPU"
fi

# ---------------------------------------------------------------- 3. Hyprland
step "3. Hyprland"

if have Hyprland; then
    HV=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [ -n "$HV" ]; then
        if [ "$(printf '%s\n0.55\n' "$HV" | sort -V | head -1)" = "0.55" ]; then
            pass "Hyprland $HV (butuh 0.55+ untuk config Lua)"
        else
            fail "Hyprland $HV terlalu tua — butuh 0.55+ untuk config Lua"
            note "sudo pacman -Syu hyprland"
        fi
    else
        warn "Hyprland terpasang tapi versi tidak terbaca"
    fi
else
    fail "Hyprland belum terpasang"
    note "sudo pacman -S --needed hyprland"
fi

# config lama yang akan dipindah installer
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
if [ -d "$CFG/hypr" ]; then
    N=$(find "$CFG/hypr" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)
    if [ "$N" -gt 0 ]; then
        warn "$CFG/hypr sudah ada isinya ($N item)"
        note "installer akan memindahkannya ke hypr.sekaipop-backup-<waktu>"
        note "pakai --hypr merge kalau config ini mau dipertahankan"
        if [ -f "$CFG/hypr/config/autostart.lua" ] && grep -qs 'noctalia' "$CFG/hypr/config/autostart.lua" 2>/dev/null; then
            warn "terdeteksi dots CachyOS (Noctalia)"
            note "hapus baris noctalia di autostart.lua, atau pakai CachyOS 'No Desktop'"
        fi
    fi
else
    pass "belum ada config Hyprland (installer akan membuat baru)"
fi

# ---------------------------------------------------------------- 4. Qt & Quickshell
step "4. Qt dan Quickshell"

QTV=""
for q in qmake6 qmake-qt6 qtpaths6; do
    if have "$q"; then
        QTV=$("$q" -query QT_VERSION 2>/dev/null || "$q" --qt-query QT_VERSION 2>/dev/null)
        [ -n "$QTV" ] && break
    fi
done

if [ -n "$QTV" ]; then
    if [ "$(printf '%s\n6.7.0\n' "$QTV" | sort -V | head -1)" = "6.7.0" ]; then
        pass "Qt $QTV (butuh 6.7+)"
        if [ "$(printf '%s\n6.12.0\n' "$QTV" | sort -V | head -1)" = "6.12.0" ]; then
            pass "Qt 6.12+ — shader tidak perlu di-rebuild"
        else
            warn "Qt < 6.12 — shader perlu di-rebuild sekali"
            note "bash ~/.config/quickshell/sekaipop/shaders/compile-shaders.sh"
        fi
    else
        fail "Qt $QTV terlalu tua (butuh 6.7+)"
    fi
else
    warn "versi Qt tidak terdeteksi (qmake6/qtpaths6 tidak ada)"
fi

if have qs || have quickshell; then
    QSV=$({ qs --version 2>/dev/null || quickshell --version 2>/dev/null; } | head -1)
    pass "Quickshell: ${QSV:-terpasang}"
else
    fail "Quickshell belum terpasang"
    note "sudo pacman -S --needed quickshell"
fi

# ---------------------------------------------------------------- 5. paket inti
step "5. Paket inti SekaiPop"

CORE_MISSING=""
for p in hyprland qt6-base qt6-declarative qt6-svg qt6-wayland qt6-shadertools \
         pipewire wireplumber networkmanager bluez upower \
         jq curl git wl-clipboard; do
    if ! pkg "$p"; then CORE_MISSING="$CORE_MISSING $p"; fi
done

if [ -z "$CORE_MISSING" ]; then
    pass "semua paket inti terpasang"
else
    fail "paket inti kurang:$CORE_MISSING"
    note "sudo pacman -S --needed$CORE_MISSING"
fi

# ---------------------------------------------------------------- 6. service
step "6. Service"

for s in NetworkManager bluetooth upower power-profiles-daemon; do
    if systemctl is-enabled "$s" >/dev/null 2>&1; then
        if systemctl is-active "$s" >/dev/null 2>&1; then
            pass "$s aktif"
        else
            warn "$s enabled tapi tidak aktif"
        fi
    elif pkg "$s" >/dev/null 2>&1; then
        warn "$s terpasang tapi belum enabled"
        note "sudo systemctl enable --now $s"
    else
        warn "$s belum terpasang"
    fi
done

for s in pipewire pipewire-pulse wireplumber; do
    if systemctl --user is-active "$s" >/dev/null 2>&1; then
        pass "$s (user) aktif"
    else
        warn "$s (user) tidak aktif"
        note "systemctl --user enable --now $s"
    fi
done

# ---------------------------------------------------------------- 7. ruang disk
step "7. Ruang disk"

ROOT_AVAIL=$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9')
if [ -n "$ROOT_AVAIL" ]; then
    if [ "$ROOT_AVAIL" -ge 20 ]; then
        pass "/ tersisa ${ROOT_AVAIL}G"
    elif [ "$ROOT_AVAIL" -ge 12 ]; then
        warn "/ hanya ${ROOT_AVAIL}G — mepet untuk paket penuh"
        note "pertimbangkan --core-only"
    else
        fail "/ hanya ${ROOT_AVAIL}G — tidak cukup"
    fi
fi

if mountpoint -q /boot 2>/dev/null; then
    BOOT_AVAIL=$(df -BG --output=avail /boot 2>/dev/null | tail -1 | tr -dc '0-9')
    BOOT_FS=$(findmnt -no FSTYPE /boot 2>/dev/null)
    BOOT_SIZE=$(df -BG --output=size /boot 2>/dev/null | tail -1 | tr -dc '0-9')
    if [ -n "$BOOT_AVAIL" ]; then
        if [ "$BOOT_AVAIL" -ge 2 ]; then
            pass "/boot tersisa ${BOOT_AVAIL}G (${BOOT_FS:-?})"
        else
            fail "/boot hanya ${BOOT_AVAIL}G — update kernel bisa gagal"
            note "lihat docs/04-troubleshooting.md §4.2"
        fi
    fi
    # /boot harus FAT32 kalau pakai Limine
    if [ -n "$BOOT_FS" ] && [ "$BOOT_FS" != "vfat" ] && [ "$BOOT_FS" != "msdos" ]; then
        warn "/boot bukan FAT32 ($BOOT_FS) — Limine butuh FAT12/16/32"
    fi
    if [ -n "$BOOT_SIZE" ] && [ "$BOOT_SIZE" -lt 2 ]; then
        warn "/boot hanya ${BOOT_SIZE}G — CachyOS minta minimal 4G untuk Limine"
        note "kalau ini ESP Windows 260MB, kernel tidak akan muat"
    fi
else
    warn "/boot bukan mount point terpisah"
    note "layout dual-boot seharusnya punya /boot FAT32 4G sendiri"
fi

# dual boot: pastikan Windows masih terdeteksi
step "7b. Dual boot"

if have lsblk; then
    WIN_PARTS=$(lsblk -no FSTYPE 2>/dev/null | grep -c '^ntfs$')
    if [ "$WIN_PARTS" -gt 0 ]; then
        pass "partisi NTFS terdeteksi ($WIN_PARTS) — Windows kemungkinan masih ada"
    else
        warn "tidak ada partisi NTFS — Windows mungkin sudah terhapus"
    fi

    # ESP terpisah untuk Linux?
    VFAT_COUNT=$(lsblk -no FSTYPE 2>/dev/null | grep -c '^vfat$')
    if [ "$VFAT_COUNT" -ge 2 ]; then
        pass "ada $VFAT_COUNT partisi FAT32 (ESP Windows + ESP Linux) — layout benar"
    elif [ "$VFAT_COUNT" -eq 1 ]; then
        warn "hanya 1 partisi FAT32 — kemungkinan /boot menumpang di ESP Windows"
        note "ESP Windows 260MB tidak cukup untuk kernel + driver DKMS"
    fi
else
    warn "lsblk tidak ada, tidak bisa cek partisi"
fi

if have efibootmgr; then
    if efibootmgr >/dev/null 2>&1; then
        if efibootmgr 2>/dev/null | grep -qi 'limine\|cachyos'; then
            pass "entri boot Limine/CachyOS terdaftar di NVRAM"
        else
            warn "entri Limine tidak ditemukan di NVRAM"
            note "sudo efibootmgr --create --disk /dev/nvme0n1 --part 6 --label Limine --loader '\\EFI\\limine\\limine_x64.efi'"
        fi
        if efibootmgr 2>/dev/null | grep -qi 'windows'; then
            pass "entri boot Windows terdaftar"
        else
            warn "entri Windows tidak terlihat — coba: sudo limine-scan"
        fi
    else
        warn "efibootmgr gagal (mungkin bukan UEFI, atau butuh root)"
    fi
else
    warn "efibootmgr tidak ada — tidak bisa cek NVRAM"
    note "sudo pacman -S --needed efibootmgr"
fi

# ---------------------------------------------------------------- 8. sesi
step "8. Sesi"

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    pass "sedang di dalam sesi Hyprland"
    if have hyprctl && hyprctl version >/dev/null 2>&1; then
        MON=$(hyprctl monitors -j 2>/dev/null | grep -c '"name"')
        pass "monitor terdeteksi: $MON"
    fi
else
    pass "tidak di dalam Hyprland (normal kalau baru login TTY)"
fi

if [ -n "${UWSM_SESSION_ID:-}" ] || [ -n "${UWSM_WAIT_SOCK_DIR:-}" ]; then
    warn "sepertinya sesi uwsm — SekaiPop minta sesi plain Hyprland"
    note "login ke entri 'Hyprland', bukan 'Hyprland (uwsm)'"
else
    pass "bukan sesi uwsm"
fi

if have paru || have yay; then
    pass "AUR helper tersedia: $(have paru && echo paru || echo yay)"
else
    warn "tidak ada AUR helper — installer bisa membangun yay-bin sendiri"
    note "atau: sudo pacman -S --needed paru"
fi

# ---------------------------------------------------------------- hasil
printf '\n'; hr
if [ "$FAIL" -eq 0 ] && [ "$WARNING" -eq 0 ]; then
    printf '  %s%sSIAP%s — semua prasyarat wajib terpenuhi\n' "$OK$B" "" "$Z"
    printf '\n  %sLangkah berikutnya:%s\n' "$B" "$Z"
    printf '    cd ~/SekaiPop && ./install.sh --dry-run\n\n'
    exit 0
elif [ "$FAIL" -eq 0 ]; then
    printf '  %s%sSIAP (dengan %d peringatan)%s\n' "$WARN$B" "" "$WARNING" "$Z"
    printf '    %sPeringatan tidak memblokir, tapi baca satu per satu.%s\n\n' "$D" "$Z"
    exit 0
else
    printf '  %s%sBELUM SIAP%s — %d masalah wajib, %d peringatan\n' "$BAD$B" "" "$Z" "$FAIL" "$WARNING"
    printf '    %sPerbaiki yang ditandai ✘ dulu. Lihat docs/02-driver-gpu.md%s\n\n' "$D" "$Z"
    exit 1
fi
