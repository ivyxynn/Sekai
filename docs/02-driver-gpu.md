# 02 — Driver GPU hybrid (AMD + NVIDIA)

**Halaman ini wajib.** Ini sumber kegagalan paling sering di setup seperti punya
kamu, dan gejalanya menipu: layar hitam atau shell tidak muncul, yang terlihat
seperti "SekaiPop rusak" padahal driver-nya belum benar.

Laptop ini punya dua GPU:

- **AMD Radeon** (iGPU, menempel di Ryzen 5 7535HS) — yang dipakai sehari-hari
- **NVIDIA RTX 2050** (dGPU) — dipakai saat diminta, misalnya gaming

Di Wayland/Hyprland, **iGPU AMD yang menggambar desktop**. NVIDIA hanya dipakai
kalau aplikasi memintanya. Artinya: kalau AMD-nya bermasalah, seluruh desktop
rusak. Kalau NVIDIA-nya bermasalah, hanya aplikasi tertentu yang rusak.

---

## 2.1 Jangan pakai installer SekaiPop untuk ini

Installer SekaiPop **secara eksplisit tidak menyentuh driver GPU**. Di
`install-deps.sh` ada logikanya:

```bash
nvidia) warn "NVIDIA detected: install your NVIDIA driver yourself
               (e.g. nvidia-open + nvidia-utils). This script never touches it." ;;
```

Kalau kamu mengandalkan installer itu, driver akan tetap belum terpasang dan
kamu akan bingung kenapa layarnya hitam. Urutannya: **driver dulu, SekaiPop
belakangan.**

---

## 2.2 Driver AMD — hampir selalu sudah benar

Mesa (driver open-source AMD) biasanya sudah terpasang di CachyOS minimal. Cek:

```bash
pacman -Q mesa libva-mesa-driver vulkan-radeon
```

Kalau ada yang `was not found`:

```bash
sudo pacman -S --needed mesa libva-mesa-driver vulkan-radeon libva-utils
```

Verifikasi:

```bash
vainfo
```

Harus muncul driver `radeonsi`. Kalau `vainfo` error "can't connect to X server",
itu normal di TTY — abaikan, yang penting paketnya ada.

---

## 2.3 Driver NVIDIA — pakai `chwd`, jangan manual

CachyOS punya alat deteksi hardware sendiri bernama **chwd**. Ini lebih aman
daripada menebak nama paket, karena dia tahu kombinasi kernel + driver yang benar
untuk CachyOS.

### Cek dulu apa yang terdeteksi

```bash
chwd --list
```

Kamu akan melihat profil untuk GPU yang terdeteksi. Untuk RTX 2050 (Turing),
biasanya muncul profil **NVIDIA Open** atau **NVIDIA proprietary**.

### Pasang

```bash
sudo chwd -a
```

Ini memasang profil yang cocok secara otomatis.

Kalau `chwd` tidak ada:

```bash
sudo pacman -S --needed chwd
```

### Kalau mau manual (tanpa chwd)

Untuk RTX 2050, driver yang tepat adalah **nvidia-open** (Turing ke atas
didukung driver open kernel module resmi NVIDIA):

```bash
# Cek kernel yang kamu pakai
uname -r

# Untuk kernel CachyOS, paketnya biasanya sudah disiapkan khusus:
sudo pacman -S --needed nvidia-open-dkms nvidia-utils nvidia-settings
```

> **Kenapa `-dkms`?** Karena CachyOS sering update kernel. Dengan DKMS, modul
> NVIDIA dikompilasi ulang otomatis setiap kernel berubah. Tanpa DKMS, update
> kernel bisa membuat NVIDIA mati sampai kamu install ulang driver secara manual.

> **Kalau ragu antara `nvidia` dan `nvidia-open`:** RTX 2050 adalah Turing.
> NVIDIA merilis open kernel module untuk Turing ke atas. `chwd` akan memilih yang
> benar; kalau manual, `nvidia-open-dkms` adalah pilihan yang tepat.

---

## 2.4 Konfigurasi hybrid graphics

Ini bagian yang sering terlewat dan bikin layar hitam.

### Pastikan iGPU yang jadi default

Di laptop hybrid, desktop harus digambar oleh **AMD**, bukan NVIDIA. Kalau NVIDIA
yang mencoba jadi primary tanpa konfigurasi yang benar, hasilnya layar hitam.

Cek environment yang ada:

```bash
cat /etc/environment 2>/dev/null
ls /etc/environment.d/ 2>/dev/null
```

**Jangan** menambahkan `__GLX_VENDOR_LIBRARY_NAME=nvidia` atau
`GBM_BACKEND=nvidia-drm` secara global. Itu memaksa NVIDIA jadi renderer utama
dan di laptop hybrid hampir selalu berakhir layar hitam.

Kalau ada file di `/etc/environment.d/` yang memaksa NVIDIA, komentari dulu:

```bash
sudo nano /etc/environment.d/99-nvidia.conf
# beri tanda # di depan baris GBM_BACKEND / __GLX_VENDOR_LIBRARY_NAME
```

### Mode hybrid vs discrete

Beberapa laptop ASUS bisa beralih mode GPU di BIOS (**MUX switch**):

| Mode | Arti | Untuk kita |
|---|---|---|
| **Hybrid / Optimus** | iGPU menggambar, dGPU on-demand | **Pilih ini** |
| **Discrete / dGPU only** | NVIDIA menggambar semuanya | Hindari di awal |

Kalau di BIOS ada opsi itu, set ke **Hybrid**. Mode discrete punya konsumsi daya
lebih tinggi dan lebih sering bermasalah di Wayland.

---

## 2.5 Reboot dan verifikasi

```bash
sudo reboot
```

Setelah login TTY, cek:

```bash
# Modul NVIDIA termuat?
lsmod | grep nvidia

# Driver versi berapa?
nvidia-smi

# Apakah GPU terdeteksi?
nvidia-smi -L
```

Yang harus muncul:

- `lsmod` menampilkan `nvidia`, `nvidia_modeset`, `nvidia_drm`
- `nvidia-smi` menampilkan tabel dengan RTX 2050 dan versi driver
- `nvidia-smi -L` menampilkan `GPU 0: NVIDIA GeForce RTX 2050`

### Kalau `nvidia-smi` error

| Error | Arti | Perbaikan |
|---|---|---|
| `command not found` | Paket belum terpasang | `sudo pacman -S nvidia-utils` |
| `NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver` | Modul tidak termuat | Cek `dmesg \| grep -i nvidia`, kemungkinan DKMS gagal build |
| `No devices were found` | GPU dinonaktifkan di BIOS, atau mode MUX salah | Cek BIOS, set ke Hybrid |

Cek log build DKMS kalau modul tidak termuat:

```bash
dkms status
sudo dkms autoinstall
```

---

## 2.6 Verifikasi Wayland siap

Sebelum install desktop, pastikan compositor bisa start. Cara termudah: install
Hyprland minimal dan coba jalankan.

```bash
sudo pacman -S --needed hyprland
```

Lalu dari TTY:

```bash
Hyprland
```

Yang diharapkan: layar berubah jadi desktop Hyprland kosong (hanya wallpaper
polos atau hitam, tanpa bar). Kalau **ini berhasil**, driver kamu sudah benar dan
kamu siap lanjut.

Keluar dengan `SUPER + M` atau dari TTY lain tekan `Ctrl+Alt+F2` lalu `pkill Hyprland`.

### Kalau layar hitam / crash

Baca error-nya dari TTY lain (`Ctrl+Alt+F2`):

```bash
cat ~/.local/share/hyprland/hyprland.log | tail -50
# atau
journalctl -xe | grep -i -E 'hyprland|drm|nvidia|amdgpu' | tail -30
```

Penyebab paling umum, berurutan:

1. **NVIDIA dipaksa jadi primary** → hapus env var di 2.4
2. **Modul NVIDIA tidak termuat** → `dkms status`, lihat 2.5
3. **Firmware AMD hilang** → `sudo pacman -S linux-firmware`
4. **MUX switch di mode Discrete** → ubah ke Hybrid di BIOS

> **Jangan lanjut ke SekaiPop sebelum `Hyprland` polos berhasil start.** Kalau
> Hyprland kosong saja gagal, SekaiPop pasti juga gagal, dan kamu akan mendebug
> dua lapisan sekaligus — jauh lebih sulit.

---

## 2.7 Yang tidak perlu kamu lakukan

- **Jangan install `optimus-manager` atau `envycontrol`** di awal. Alat itu
  mengubah cara GPU di-bind dan sering bentrok dengan setup Wayland modern.
  Cukup `chwd` / paket NVIDIA standar.
- **Jangan install driver dari website NVIDIA.** Selalu lewat pacman.
- **Jangan set `nvidia_drm.modeset=1` manual** kalau `chwd` sudah menanganinya.
  Cek dulu: `cat /proc/cmdline`. Kalau sudah ada, jangan duplikasi.

---

## Checklist

- [ ] `vainfo` menampilkan `radeonsi`
- [ ] `lsmod | grep nvidia` menampilkan modul
- [ ] `nvidia-smi` jalan dan melihat RTX 2050
- [ ] Tidak ada env var yang memaksa NVIDIA jadi primary
- [ ] BIOS dalam mode Hybrid (kalau ada opsi MUX)
- [ ] `Hyprland` polos berhasil start dan bisa keluar dengan bersih

Kalau semua tercentang, lanjut ke [03-sekaipop.md](03-sekaipop.md).
