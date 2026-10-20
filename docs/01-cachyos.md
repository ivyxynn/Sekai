# 01 — Install CachyOS

Tujuan halaman ini: CachyOS terpasang, bisa boot, bisa login ke TTY, **belum ada
desktop apa pun**. Itu memang yang kita mau.

---

## Kenapa "No Desktop", bukan Hyprland edition

Ini keputusan paling penting di seluruh runbook, jadi alasannya lengkap.

CachyOS punya opsi **Hyprland** di installer. Itu bukan Hyprland kosong — itu
Hyprland **plus dots CachyOS bernama Noctalia**. Kalau kamu pilih itu:

| Yang terjadi | Akibat |
|---|---|
| `~/.config/hypr/config/*.lua` terisi dots CachyOS | SekaiPop `--hypr full` akan **memindahkan seluruh folder ini** |
| `autostart.lua` menjalankan `noctalia` | Dua shell jalan bersamaan, saling tabrakan layer |
| Sesi login default = **Hyprland (UWSM)** | SekaiPop butuh sesi plain Hyprland, bukan uwsm |
| `~/.config/uwsm/env` dipakai untuk env var | `sekaipop_session.lua` justru menulis `hl.env()` di config Hyprland |

Semua itu bisa dibereskan satu per satu, tapi kamu akan menghabiskan waktu
mendebug konflik yang tidak perlu. Mulai dari kosong jauh lebih cepat.

SekaiPop sendiri didesain untuk ini — `install.sh`-nya menulis di komentarnya:
*"turns a minimal Hyprland system into the complete desktop"*.

> **Kalau kamu tetap mau Hyprland edition** karena ingin ada desktop cadangan:
> pilih itu, lalu **wajib** pakai `--hypr merge` (bukan `full`), dan hapus baris
> `hl.exec_cmd("noctalia")` dari `~/.config/hypr/config/autostart.lua` sebelum
> login. Detailnya di [03-sekaipop.md](03-sekaipop.md).

---

## 1.1 Boot dari USB

1. Colok USB, restart laptop
2. Tekan **Esc** berulang saat logo ASUS untuk membuka boot menu
   (atau **F8**; kalau tidak muncul, masuk BIOS dengan **F2** → Boot → pilih USB)
3. Pilih USB-nya. Kalau ada dua entri, pilih yang **UEFI**
4. Tunggu sampai desktop live muncul

Di desktop live ada tombol **Launch Installer**. Klik itu.

---

## 1.2 Wizard installer

Ikuti urutan Calamares. Yang penting hanya beberapa layar:

### Language & Region
Pilih English (US) untuk bahasa installer. Untuk region, pilih **Asia/Jakarta**
kalau kamu mau zona waktu WIB.

### Keyboard
`us` — default. Kalau keyboard laptop kamu layout Indonesia, tetap pilih `us`
kecuali kamu yakin butuh yang lain.

### Partisi — **bagian paling berbahaya**

Pilih **Manual partitioning**.

> **Jangan pilih "Erase disk".** Di mesin ini hanya ada satu disk berisi Windows.
> Erase disk akan menghapus Windows beserta semua data.

Yang harus dibuat:

| Ukuran | Filesystem | Mount point | Flag |
|---|---|---|---|
| 4096 MiB | FAT32 | `/boot` | `boot` |
| sisa unallocated | btrfs (atau ext4) | `/` | — |

**Jangan sentuh** partisi yang sudah ada:

- `System` / EFI 300 MB — punya Windows, jangan diformat
- `Reserved` / MSR 16 MB
- `C:` 475 GB — Windows
- `Recovery` ×2

Cara aman: klik **unallocated space** → **Create** → isi seperti tabel di atas.
Jangan pernah klik **Delete** pada partisi yang sudah ada.

> **Soal `/boot` terpisah 4 GB.** Ini rekomendasi CachyOS dan masuk akal di
> laptop hybrid: kernel + initramfs + microcode + driver NVIDIA DKMS bisa cepat
> membesar. Kalau `/boot` terlalu kecil, update kernel akan gagal dan sistem
> tidak bisa boot. 4 GB memberi ruang lega.

### Desktop Environment — **pilih "No Desktop"**

Ini intinya. Di daftar desktop, scroll ke paling atas dan pilih **No Desktop**.

Deskripsinya sendiri bilang: *"your system will start up in text-only mode and you
can install a desktop environment later"* — persis yang kita mau.

### Packages
Biarkan default. Jangan centang apa pun yang tidak kamu paham.

### Users
- Nama lengkap, username (huruf kecil, tanpa spasi)
- **Password wajib diisi** — akun tanpa password akan menyulitkan `sudo`
- Centang **"Log in automatically"**? **Jangan.** Kalau shell rusak, kamu butuh
  TTY untuk memperbaikinya.
- **"Use the same password for the administrator account"** — biarkan tercentang

### Bootloader
Pilih **Limine** (default CachyOS) atau **systemd-boot**. Keduanya bisa
mendeteksi Windows.

> Kalau setelah install Windows tidak muncul di menu boot, dari CachyOS jalankan
> `sudo limine-scan` (untuk Limine) atau `sudo bootctl list` untuk memeriksa.

### Review
Baca ringkasannya. Pastikan:
- Tidak ada partisi Windows yang ditandai akan diformat
- Desktop = No Desktop
- Bootloader terpasang ke disk yang benar

Baru klik **Install Now**.

---

## 1.3 Boot pertama

Setelah selesai, lepas USB, restart.

Kamu akan melihat menu boot dengan pilihan CachyOS dan Windows. Pilih CachyOS.

Yang muncul adalah **login TTY** — layar hitam dengan teks. Ini **normal dan
benar**. Tidak ada desktop karena kita memang tidak memasangnya.

Login dengan username dan password yang kamu buat tadi.

---

## 1.4 Verifikasi dasar

Sebelum lanjut, pastikan sistemnya sehat:

```bash
# Distro apa ini
cat /etc/os-release | head -3

# Kernel
uname -r

# Arsitektur CPU (penting untuk repo CachyOS)
/lib/ld-linux-x86-64.so.2 --help | grep -A5 "Subdirectories of glibc-hwcaps"

# Internet
ping -c 3 archlinux.org

# Disk
lsblk -f
df -h /
```

Yang harus kamu lihat:

- `NAME="CachyOS Linux"` (atau serupa)
- Kernel `linux-cachyos` sesuatu
- CPU mendukung `x86-64-v3` (Ryzen 5 7535HS = Zen 3+ → **v3, bukan v4**)
- Ping berhasil

> **Kenapa arsitektur penting.** CachyOS punya repo terpisah per level CPU. Kalau
> `pacman.conf` menunjuk ke repo v4 padahal CPU-mu v3, paket akan gagal install
> dengan error "invalid or corrupted package". Ini biasanya sudah benar otomatis,
> tapi bagus untuk dicek.

---

## 1.5 Update sistem penuh

Sebelum install apa pun:

```bash
sudo pacman -Syu
```

Kalau ada pertanyaan konfirmasi, jawab `y`. Kalau muncul konflik paket, **berhenti
dan baca** — jangan paksa dengan `--overwrite`.

Setelah selesai, reboot:

```bash
sudo reboot
```

Login lagi setelah reboot.

---

## 1.6 Pasang alat dasar

CachyOS minimal biasanya sudah punya ini, tapi pastikan:

```bash
sudo pacman -S --needed base-devel git curl wget nano sudo
```

- `base-devel` — wajib untuk build paket AUR
- `git` — SekaiPop di-clone dari GitHub
- `nano` — editor sederhana untuk memperbaiki config kalau ada yang rusak

Cek AUR helper:

```bash
command -v paru yay
```

CachyOS versi baru **tidak lagi** memasang `paru` secara default (dihapus dari
installer). Kalau kosong, install nanti — installer SekaiPop bisa membangun
`yay-bin` sendiri, tapi lebih rapi kalau kamu siapkan sekarang:

```bash
sudo pacman -S --needed paru
```

Kalau `paru` tidak ada di repo, lewati saja — installer SekaiPop akan menanganinya.

---

## 1.7 Cek hardware dikenali

```bash
# GPU
lspci -nn | grep -Ei 'vga|3d|display'

# Cari dua entri: AMD (1002:...) dan NVIDIA (10de:...)
```

Di laptop ini kamu harus melihat **dua** GPU:

```
AMD Radeon Graphics [1002:...]
NVIDIA GeForce RTX 2050 [10de:...]
```

Kalau hanya satu yang muncul, atau tidak ada sama sekali, **jangan lanjut** —
perbaiki dulu di [02-driver-gpu.md](02-driver-gpu.md).

---

## Checklist

- [ ] CachyOS boot ke TTY, bisa login
- [ ] Windows masih ada di menu boot
- [ ] `sudo pacman -Syu` selesai tanpa error
- [ ] Sudah reboot setelah update
- [ ] `lspci` menunjukkan **dua** GPU (AMD + NVIDIA)
- [ ] Internet jalan
- [ ] `base-devel` dan `git` terpasang

Lanjut ke [02-driver-gpu.md](02-driver-gpu.md) — **jangan lewati ini.**
