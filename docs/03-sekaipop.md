# 03 — Install SekaiPop

Prasyarat: [02-driver-gpu.md](02-driver-gpu.md) sudah selesai dan **Hyprland polos
sudah bisa start**. Kalau belum, balik dulu ke sana.

---

## 3.1 Kenapa setup kita justru menghindari masalah terbesar

README SekaiPop menyuruh login ke **"plain Hyprland session, not uwsm"**. Itu
sulit kalau kamu pakai display manager yang menawarkan dua entri sesi.

Kita tidak punya display manager. CachyOS "No Desktop" tidak memasang greeter.
Artinya kamu login ke TTY lalu menjalankan `Hyprland` langsung — dan itu **secara
definisi** sesi plain Hyprland, bukan uwsm. Masalahnya hilang dengan sendirinya.

> Kalau nanti kamu memasang display manager (SDDM, greetd, Noctalia greeter),
> **ingat aturan ini**: pilih entri `Hyprland`, jangan `Hyprland (uwsm)`.

---

## 3.2 Clone — jangan `curl | bash`

```bash
cd ~
git clone https://github.com/ivyxynn/SekaiPop.git
cd SekaiPop
```

> Pakai fork kamu (`ivyxynn/SekaiPop`) supaya kalau nanti kamu mau mengubah
> sesuatu, perubahannya tersimpan di repo sendiri. Untuk mengikuti update dari
> upstream, lihat 3.8.

Baca dulu yang akan dijalankan. Minimal lihat bahwa dia memindahkan config:

```bash
less install.sh          # tekan q untuk keluar
grep -n "hypr.sekaipop-backup" install.sh
```

---

## 3.3 Dry run — wajib

```bash
./install.sh --dry-run
```

Ini mencetak semua yang akan dilakukan dan **tidak mengubah apa pun**. Baca
output-nya. Yang perlu kamu perhatikan:

- Baris `Hyprland config mode:` — harus `full` (kita memang mau full, karena
  config kita masih kosong/default)
- Daftar paket yang akan dipasang dari repo vs AUR
- Apakah dia menemukan `~/.config/hypr` yang sudah ada

Kalau output-nya menyebut akan memindahkan config yang **kamu anggap penting**,
berhenti dan pikir ulang.

---

## 3.4 Putuskan: `full` atau `merge`

| Mode | Yang dilakukan | Pakai kalau |
|---|---|---|
| `--hypr full` | Memindahkan `~/.config/hypr` ke backup, ganti dengan config SekaiPop | Config Hyprland-mu masih default/kosong |
| `--hypr merge` | Config-mu tetap, hanya menambah `sekaipop_session.lua` | Kamu sudah punya config Hyprland yang kamu rawat |

**Untuk setup ini: `full`.** Kamu baru install Hyprland minimal di langkah 2.6,
jadi tidak ada yang berharga untuk dipertahankan.

Yang tetap diselamatkan installer walaupun mode `full`:

- `monitors.lua` — punyamu dipakai kalau ada
- `workspaces.lua`
- `sekaipop_overrides.lua`
- folder `custom/`

Dan config lamamu **tidak dihapus**, hanya dipindah ke
`~/.config/hypr.sekaipop-backup-<tanggal>`.

---

## 3.5 Jalankan installer

```bash
./install.sh --hypr full
```

Dia akan bertanya beberapa hal. Jawaban yang disarankan:

| Pertanyaan | Jawab | Alasan |
|---|---|---|
| Run a full system update first? | **n** | Kamu sudah `-Syu` di langkah 1.5 |
| Build yay-bin from AUR? | **y** | Kalau kamu belum punya `paru`/`yay` |
| Replace Hyprland config? | **y** | Config-mu masih default |
| Reload and start the shell now? | **n** | Kamu di TTY, belum ada Hyprland jalan |

Prosesnya bisa 10–30 menit tergantung kecepatan internet dan berapa paket AUR
yang harus dikompilasi.

### Yang sedang terjadi

1. **Dependencies** — paket repo + AUR, font Google Sans Flex, service systemd,
   menambahkan kamu ke grup `video`
2. **Shell** — disalin ke `~/.config/quickshell/sekaipop`
3. **Hyprland** — config Lua lengkap + `monitors.lua` yang dibuat untuk layar
   yang terdeteksi saat itu

### Kalau ada yang gagal

Installer mencetak ringkasan di akhir. Kalau ada baris merah:

```bash
# Lihat apa yang kurang
./check-deps.sh
```

Jangan panik kalau beberapa paket AUR gagal — sebagian besar **opsional**
(`mpvpaper`, `cloudflare-warp-bin`). Yang wajib hanya yang ada di daftar CORE.

---

## 3.6 Verifikasi sebelum start

```bash
# Semua dependensi inti ada?
./check-deps.sh --core
```

Harus berakhir dengan **`core missing: 0`**.

Cek juga:

```bash
# Shell terpasang?
ls ~/.config/quickshell/sekaipop/VERSION && cat ~/.config/quickshell/sekaipop/VERSION

# Config Hyprland terpasang?
ls ~/.config/hypr/hyprland.lua
ls ~/.config/hypr/monitors.lua

# Qt versi berapa (6.12 = shader tidak perlu di-rebuild)
qmake6 -query QT_VERSION 2>/dev/null || qtpaths6 --qt-query QT_VERSION 2>/dev/null

# Quickshell ada?
qs --version 2>/dev/null || quickshell --version 2>/dev/null
```

---

## 3.7 Start pertama

Karena tidak ada display manager, jalankan dari TTY:

```bash
Hyprland
```

Kalau berhasil, kamu akan melihat desktop SekaiPop: bar, widget, dan semuanya.

**Kalau layar hitam tapi ada kursor**, jangan panik. Coba `Ctrl+Alt+F2` untuk
masuk TTY lain, lalu:

```bash
# Error config Hyprland
cat ~/.cache/sekaipop/hypr-errors.log

# Error shell
qs -c sekaipop log 2>&1 | tail -40

# Error Hyprland
journalctl -xe | grep -i -E 'hyprland|quickshell|qs' | tail -30
```

Detail penanganannya di [04-troubleshooting.md](04-troubleshooting.md).

### Keybind penting setelah masuk

| Tombol | Fungsi |
|---|---|
| `Super` (tap) | App launcher |
| `Super + /` | Cheat sheet semua keybind |
| `Super + N` | Quick panel |
| `Super + I` | Settings |
| `Super + Return` | Terminal (kitty) |
| `Super + L` | Lock |
| `Ctrl + Super + R` | Restart shell |
| `Super + Shift + E` | Edit desktop |

---

## 3.8 Supaya tidak perlu ketik `Hyprland` tiap boot

Tiga pilihan, dari paling sederhana:

### Opsi A — autologin TTY + start otomatis (paling ringan)

Buat systemd user service yang menjalankan Hyprland saat login di tty1.

Edit `~/.bash_profile`:

```bash
nano ~/.bash_profile
```

Tambahkan di akhir:

```bash
# Start Hyprland otomatis di tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
```

Simpan. Sekarang login di tty1 langsung masuk Hyprland.

### Opsi B — display manager (SDDM)

```bash
sudo pacman -S --needed sddm
sudo systemctl enable sddm
```

Saat login, **pilih entri `Hyprland`**, bukan `Hyprland (uwsm)`.

### Opsi C — uwsm

Jangan, kecuali kamu tahu apa yang kamu lakukan. `sekaipop_session.lua` menulis
`hl.env()` di config Hyprland, sementara panduan uwsm menyarankan env var di
`~/.config/uwsm/env`. Bisa jalan, tapi kamu menambah satu lapisan yang bisa
salah.

---

## 3.9 Update SekaiPop nanti

```bash
cd ~/SekaiPop
git pull
./install.sh
```

Settings dan state kamu disimpan di `~/.local/state/sekaipop`, jadi tidak hilang.
Config di `~/.config/hypr/custom/` juga tidak pernah ditimpa.

### Mengambil update dari upstream asli

Fork kamu tidak otomatis mengikuti `Blapples/SekaiPop`. Untuk sinkron:

```bash
cd ~/SekaiPop
git remote add upstream https://github.com/Blapples/SekaiPop.git 2>/dev/null
git fetch upstream
git merge upstream/main
```

Kalau ada konflik, selesaikan lalu `git commit`.

---

## 3.10 Kalau mau balik

```bash
cd ~/SekaiPop
./install.sh --restore
```

Ini mengembalikan config Hyprland yang di-backup installer terakhir.

Untuk menghapus shell-nya saja:

```bash
rm -rf ~/.config/quickshell/sekaipop
```

---

## Checklist

- [ ] `./check-deps.sh --core` → `core missing: 0`
- [ ] `~/.config/hypr/hyprland.lua` ada
- [ ] `~/.config/quickshell/sekaipop/VERSION` ada
- [ ] `Hyprland` berhasil start dan desktop SekaiPop muncul
- [ ] `Super + /` membuka cheat sheet
- [ ] Sudah memilih cara autostart (3.8)

Kalau semua tercentang: selesai. Kalau ada yang gagal:
[04-troubleshooting.md](04-troubleshooting.md).
