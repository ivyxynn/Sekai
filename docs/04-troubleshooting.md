# 04 — Troubleshooting & recovery

Urutannya: **kenali dulu lapisan mana yang rusak**, baru perbaiki. Sebagian besar
waktu terbuang karena mendebug lapisan yang salah.

---

## Peta lapisan

```
┌─────────────────────────────────────┐
│ 4. Shell SekaiPop (Quickshell/QML)  │  ← bar, widget, panel
├─────────────────────────────────────┤
│ 3. Hyprland (compositor)            │  ← window manager, config Lua
├─────────────────────────────────────┤
│ 2. Driver GPU (AMD + NVIDIA)        │  ← mesa, nvidia, DRM
├─────────────────────────────────────┤
│ 1. Kernel + firmware + CachyOS      │  ← boot, modul, filesystem
└─────────────────────────────────────┘
```

Gejala yang **sama** bisa berasal dari lapisan berbeda. Layar hitam bisa berarti
kernel panic, driver gagal, Hyprland crash, atau shell crash. Cara membedakannya:
lihat apakah kamu masih bisa pindah TTY.

---

## 4.1 Triage cepat

| Gejala | Lapisan | Mulai dari |
|---|---|---|
| Tidak bisa boot sama sekali, tidak ada menu | 1 | [4.2](#42-tidak-bisa-boot) |
| Windows hilang dari menu Limine | boot | [4.2](#windows-hilang-dari-menu-limine) |
| Langsung masuk Windows, menu Limine tidak muncul | boot | [4.2](#laptop-langsung-masuk-windows-menu-limine-tidak-muncul) |
| Boot sampai TTY, tapi `Hyprland` langsung mati | 2–3 | [4.3](#43-hyprland-gagal-start) |
| Hyprland jalan, layar hitam + kursor | 3–4 | [4.4](#44-layar-hitam-tapi-ada-kursor) |
| Desktop muncul, tapi tidak ada bar/widget | 4 | [4.5](#45-shell-tidak-muncul) |
| Shell muncul lalu hilang sendiri | 4 | [4.6](#46-shell-crash-berulang) |
| Desktop jalan, tapi lambat / patah-patah | 2 | [4.7](#47-performa-buruk) |
| Tidak ada suara | 1 | [4.8](#48-tidak-ada-suara) |
| Wi-Fi/Bluetooth mati | 1 | [4.9](#49-wifi--bluetooth) |

**Pintu darurat**: `Ctrl + Alt + F2` (atau F3–F6) dari mana saja untuk masuk TTY.
Ini hampir selalu berhasil walaupun desktop rusak total. Kalau TTY juga tidak
bisa, masalahnya di lapisan 1.

---

## 4.2 Tidak bisa boot

### Masuk lewat USB live

Boot USB CachyOS, pilih **live session** (jangan installer), buka terminal.

```bash
# Lihat partisi — catat nomornya
lsblk -f
```

Layout hasil runbook ini:

```
nvme0n1p1  vfat   260M            ← ESP Windows, JANGAN di-mount ke /mnt/boot
nvme0n1p3  ntfs   475G            ← Windows C:
nvme0n1p6  vfat     4G            ← /boot Linux  (ESP kedua)
nvme0n1p7  btrfs  ~45G            ← / Linux
```

```bash
# Root
sudo mount /dev/nvme0n1p7 /mnt

# /boot — ini ESP Linux, BUKAN partisi Windows
sudo mount /dev/nvme0n1p6 /mnt/boot

# Masuk
sudo arch-chroot /mnt
```

> **Jangan mount `nvme0n1p1` ke `/mnt/boot`.** Itu ESP Windows. Kalau kamu mount
> di sana lalu menjalankan `limine-update` atau `mkinitcpio`, kamu menulis
> kernel Linux ke partisi boot Windows. Kerusakan yang dihasilkan tidak langsung
> terlihat, tapi bisa membuat Windows gagal boot.

Sekarang kamu di sistem asli. Perbaiki dari sini.

### Bootloader rusak

```bash
# Limine — regenerasi entri
sudo limine-update

# Cari Windows kalau entri-nya hilang
sudo limine-scan

# systemd-boot
sudo bootctl install
sudo bootctl update
```

### Windows hilang dari menu Limine

Ini kejadian paling umum setelah Windows Update besar.

```bash
sudo limine-scan
```

Kalau tidak membantu, cek Windows Boot Manager masih ada:

```bash
sudo mkdir -p /mnt/winboot
sudo mount /dev/nvme0n1p1 /mnt/winboot
ls /mnt/winboot/EFI/Microsoft/Boot/bootmgfw.efi
sudo umount /mnt/winboot
```

- File **ada** → Windows sehat, tinggal daftarkan ulang entrinya
- File **tidak ada** → Windows-nya bermasalah, perbaiki dari sisi Windows
  (bootrec / startup repair), bukan dari CachyOS

### Laptop langsung masuk Windows, menu Limine tidak muncul

Windows Update mengubah urutan boot di NVRAM.

```bash
efibootmgr
```

Cari entri `Limine` / `CachyOS`, catat nomornya, lalu taruh paling depan:

```bash
sudo efibootmgr -o 0001,0000
```

Kalau entri Limine **hilang sama sekali** dari daftar:

```bash
# Cari file EFI-nya dulu
sudo find /boot -name '*.efi'

# Daftarkan ulang (sesuaikan nomor partisi /boot kamu)
sudo efibootmgr --create --disk /dev/nvme0n1 --part 6 \
  --label "Limine" --loader '\EFI\limine\limine_x64.efi'
```

### Kernel hilang atau rusak

```bash
# Lihat kernel yang terpasang
pacman -Q | grep linux

# Reinstall
sudo pacman -S linux-cachyos linux-cachyos-headers
sudo mkinitcpio -P
```

### `/boot` penuh — penyebab update gagal yang sering terlewat

```bash
df -h /boot
```

Kalau penuh, hapus kernel lama:

```bash
# Lihat semua kernel
ls /boot/vmlinuz-*

# Hapus paket kernel lama (JANGAN yang sedang dipakai)
pacman -Q | grep linux-cachyos
sudo pacman -Rns linux-cachyos-lts  # contoh, sesuaikan
```

Ini alasan kenapa runbook ini menyarankan `/boot` 4 GB, bukan 512 MB.

---

## 4.3 Hyprland gagal start

Jalankan dari TTY dan baca error-nya langsung:

```bash
Hyprland 2>&1 | tee /tmp/hypr-start.log
```

### Error yang umum

| Pesan | Penyebab | Perbaikan |
|---|---|---|
| `Couldn't find config file` | `~/.config/hypr/hyprland.lua` tidak ada | Reinstall SekaiPop atau copy manual |
| `error: ... module 'X' not found` | Config butuh file yang tidak ada | Lihat `~/.cache/sekaipop/hypr-errors.log` |
| `Failed to open DRM device` | Driver GPU belum benar | Balik ke [02-driver-gpu.md](02-driver-gpu.md) |
| `GLES: Failed to create EGL context` | Mesa/NVIDIA salah | `sudo pacman -S mesa`, cek env var NVIDIA |
| `no monitors found` | Layar tidak terdeteksi | Cek `monitors.lua`, atau hapus sementara |

### Cek error config tanpa menjalankan Hyprland

```bash
cat ~/.cache/sekaipop/hypr-errors.log
```

Config SekaiPop memuat tiap file secara terpisah, jadi satu file rusak tidak
mematikan semuanya. Log ini mencatat file mana yang gagal.

### Mulai dengan config minimal

Kalau curiga config-nya:

```bash
mv ~/.config/hypr ~/.config/hypr.broken
mkdir -p ~/.config/hypr
echo 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' > ~/.config/hypr/hyprland.lua
Hyprland
```

Kalau ini berhasil, masalahnya di config SekaiPop, bukan di sistem. Kembalikan
bertahap:

```bash
rm -rf ~/.config/hypr
mv ~/.config/hypr.broken ~/.config/hypr
```

---

## 4.4 Layar hitam tapi ada kursor

Ini tanda **Hyprland jalan tapi shell tidak menggambar apa pun**, atau semua
window transparan.

### Cek dari TTY lain

```bash
# Hyprland hidup?
hyprctl version

# Monitor terdeteksi?
hyprctl monitors

# Shell jalan?
pgrep -a qs

# Error shell
qs -c sekaipop log 2>&1 | tail -50
```

### Kalau shell tidak jalan

```bash
qs -c sekaipop
```

Perhatikan error yang muncul. Yang paling umum:

**a. Ikon hilang**

```bash
sudo pacman -S --needed ttf-material-symbols-variable
fc-cache -f
```

**b. Shader tidak bisa digambar** (Qt < 6.12)

```bash
qmake6 -query QT_VERSION
bash ~/.config/quickshell/sekaipop/shaders/compile-shaders.sh
```

Butuh `qt6-shadertools`:

```bash
sudo pacman -S --needed qt6-shadertools
```

**c. Modul QML kurang**

```bash
./check-deps.sh
```

Dia mencantumkan modul QML mana yang hilang beserta paket yang menyediakannya.

### Kalau shell jalan tapi tetap hitam

Kemungkinan besar NVIDIA yang menggambar, bukan AMD. Cek:

```bash
echo $GBM_BACKEND
echo $__GLX_VENDOR_LIBRARY_NAME
cat /proc/cmdline
```

Kalau ada yang menunjuk NVIDIA, hapus (lihat [02-driver-gpu.md §2.4](02-driver-gpu.md#24-konfigurasi-hybrid-graphics)).

---

## 4.5 Shell tidak muncul

Desktop Hyprland ada (bisa buka terminal dengan `Super + Return`), tapi tidak ada
bar atau widget.

```bash
# Jalankan manual dan lihat output
qs -c sekaipop
```

### Kalau terminal juga tidak bisa dibuka

Berarti keybind tidak termuat. Cek:

```bash
hyprctl configerrors
```

Atau cek apakah `kitty` terpasang:

```bash
pacman -Q kitty
```

### Kalau `qs` tidak ada

```bash
pacman -Q quickshell quickshell-git
sudo pacman -S --needed quickshell
```

---

## 4.6 Shell crash berulang

Issue tracker SekaiPop punya laporan **"Frequent Random Crashes"** (#7) yang masih
terbuka. Jadi kalau kamu mengalami crash acak, itu bukan salah setup kamu.

### Kumpulkan bukti dulu

```bash
# Log shell
qs -c sekaipop log 2>&1 | tail -100 > /tmp/qs-crash.log

# Log sistem
journalctl --user -u quickshell -n 100 > /tmp/qs-journal.log
journalctl -b -p err > /tmp/system-errors.log
```

### Mitigasi

1. **Kurangi beban.** Matikan widget yang tidak dipakai lewat
   `Super + Shift + E` (Edit Desktop) → klik kanan widget → remove.
2. **Matikan video wallpaper** kalau ada — `mpvpaper` paling berat.
3. **Matikan cava visualizer** sementara.
4. **Cek memori** — 16 GB harusnya cukup, tapi cek apakah ada kebocoran:
   ```bash
   free -h
   watch -n 5 'free -h'
   ```

### Restart shell tanpa logout

```bash
Ctrl + Super + R
```

Atau:

```bash
pkill qs && qs -c sekaipop &
```

---

## 4.7 Performa buruk

Di laptop hybrid, penyebab paling umum: **desktop digambar oleh NVIDIA**, bukan AMD.

```bash
# Cek GPU mana yang dipakai
glxinfo | grep "OpenGL renderer"
# atau
hyprctl systeminfo | grep -i gpu
```

Harusnya `AMD Radeon`. Kalau `NVIDIA`, lihat [02-driver-gpu.md §2.4](02-driver-gpu.md).

### Penyebab lain

| Gejala | Cek | Perbaikan |
|---|---|---|
| Panas & fan kencang | `sensors` | Pasang `power-profiles-daemon`, set balanced |
| Battery cepat habis | `powertop` | Sama |
| Animasi patah | `hyprctl systeminfo` | Turunkan refresh rate di `monitors.lua` |
| Disk lambat | `systemd-analyze blame` | — |

```bash
sudo pacman -S --needed power-profiles-daemon lm_sensors
sudo systemctl enable --now power-profiles-daemon
powerprofilesctl set balanced
```

---

## 4.8 Tidak ada suara

```bash
# Status
systemctl --user status pipewire pipewire-pulse wireplumber

# Kalau mati
systemctl --user enable --now pipewire pipewire-pulse wireplumber

# Cek device
wpctl status

# Volume & mute
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%
```

Kalau `wpctl status` kosong, cek:

```bash
lspci | grep -i audio
pacman -Q sof-firmware alsa-ucm-conf
```

Laptop AMD modern sering butuh `sof-firmware`:

```bash
sudo pacman -S --needed sof-firmware alsa-ucm-conf
sudo reboot
```

---

## 4.9 Wi-Fi / Bluetooth

```bash
# Wi-Fi
nmcli device status
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"

# Bluetooth
systemctl status bluetooth
bluetoothctl
```

Kalau Wi-Fi mati total:

```bash
rfkill list
sudo rfkill unblock all
```

Cek driver:

```bash
lspci -k | grep -A3 -i network
```

---

## 4.10 Kembali ke kondisi aman

Kalau sudah terlalu banyak yang diubah dan kamu mau mulai bersih:

### Level 1 — reset config Hyprland saja

```bash
cd ~/SekaiPop
./install.sh --restore
```

### Level 2 — hapus SekaiPop, sisakan CachyOS

```bash
rm -rf ~/.config/quickshell/sekaipop
mv ~/.config/hypr ~/.config/hypr.sekaipop-old
```

Sekarang kamu punya Hyprland minimal lagi. Tidak ada paket yang dihapus.

### Level 3 — install ulang CachyOS

Kalau sistemnya sudah tidak bisa diselamatkan. Windows tetap aman selama kamu
**tidak** memilih "Erase disk" dan tidak menyentuh partisinya.

Saat install ulang, hapus dulu partisi `/boot` dan `/` yang lama (p6 dan p7) di
Calamares, biarkan jadi unallocated, lalu buat ulang. **Jangan** sentuh p1–p5.

### Level 4 — hapus CachyOS, kembalikan ke Windows saja

Kalau kamu memutuskan berhenti:

1. Boot USB CachyOS live
2. Hapus partisi p6 (`/boot`) dan p7 (`/`)
3. Jangan sentuh p1–p5
4. Boot Windows → `diskmgmt.msc` → klik kanan **C:** → **Extend Volume**
5. Hapus entri boot Limine:
   ```bash
   efibootmgr              # cari nomor entri Limine
   sudo efibootmgr -b 0001 -B
   ```

Windows kembali seperti semula. Data Windows tidak pernah tersentuh selama kamu
tidak memformat p3.

---

## 4.11 Yang tidak boleh dilakukan saat panik

| Jangan | Kenapa |
|---|---|
| `rm -rf ~/.config` | Menghapus semua config, termasuk yang masih bagus |
| `pacman -Rdd` untuk memaksa hapus | Merusak dependency, sistem bisa tidak boot |
| `pacman -Syu --overwrite '*'` | Menimpa file milik paket lain, kerusakan tidak terlihat sampai nanti |
| Format partisi "biar bersih" | Windows ikut hilang |
| Install driver NVIDIA versi lain saat sistem masih rusak | Menambah variabel, bukan mengurangi |
| Hapus kernel yang sedang dipakai | Tidak bisa boot |

**Aturan**: satu perubahan, satu tes. Kalau tidak membantu, kembalikan dulu sebelum
mencoba hal lain.

---

## Melaporkan bug ke SekaiPop

Kalau masalahnya memang di shell, laporkan ke
[github.com/Blapples/SekaiPop/issues](https://github.com/Blapples/SekaiPop/issues)
dengan:

```bash
# Kumpulkan info
qs -c sekaipop log > qs-log.txt 2>&1
hyprctl version > env.txt
hyprctl systeminfo >> env.txt
cat ~/.config/quickshell/sekaipop/VERSION >> env.txt
qmake6 -query QT_VERSION >> env.txt
cat ~/.cache/sekaipop/hypr-errors.log >> env.txt
```

Lampirkan `qs-log.txt` dan `env.txt`. Sebutkan GPU kamu (AMD iGPU + RTX 2050) dan
bahwa kamu pakai sesi plain Hyprland, bukan uwsm — itu informasi yang sering
diminta maintainer.
