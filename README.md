# SekaiLinux

Catatan setup: CachyOS + desktop SekaiPop, di **ASUS TUF Gaming A15 FA506NF**
(AMD Ryzen 5 7535HS, Radeon iGPU + NVIDIA RTX 2050, 16 GB RAM, 1 SSD 477 GB).

Repo ini bukan distro dan bukan kode. Ini **runbook**: urutan langkah yang sudah
diverifikasi, supaya kalau ada yang rusak kamu tahu harus balik ke mana.

---

## Baca dulu: ini bukan distro

| | Apa itu | Dipasang bagaimana |
|---|---|---|
| **CachyOS** | Distro Arch-based. Ini OS-nya. | Di-install ke disk, jadi sistem utama |
| **SekaiPop** | Desktop shell (Quickshell + Hyprland). Bukan distro, tidak punya kernel atau ISO. | Di-install **di atas** CachyOS |

SekaiPop di repo aslinya menyebut CachyOS sebagai target resmi, jadi kombinasi ini
didukung. Yang tidak didukung: mengharapkan SekaiPop jadi OS yang bisa di-install
sendiri.

---

## Kondisi mesin saat runbook ini ditulis

Sudah dicek langsung dari Windows:

| Item | Nilai | Arti |
|---|---|---|
| Disk | 1× SAMSUNG MZVL8512HELU, 477 GB, NVMe SSD, GPT | **Satu-satunya disk.** Windows pakai semua |
| Partisi | EFI **260 MB**, MSR 16 MB, C: 475 GB, Recovery 1 GB + 200 MB | Skema standar Windows 11 |
| Free space C: | **50.6 GB** | Bisa jadi ~87 GB setelah dibersihkan (§0.5b) |
| ESP Windows | **260 MB** | **Terlalu kecil** — lihat poin 2 |
| RAM | 16 GB (2×8 GB DDR5 5600) | Slot penuh, tidak bisa upgrade tanpa buang |
| GPU | AMD Radeon iGPU + NVIDIA RTX 2050 | **Hybrid graphics — ini risiko utama** |
| Model | ASUS TUF Gaming A15 FA506NF | Laptop, bukan desktop |

Konsekuensi yang harus kamu terima sebelum mulai:

1. **Hybrid graphics adalah sumber masalah paling sering**, bukan installer-nya.
   SekaiPop secara eksplisit *tidak menyentuh* driver GPU. Kalau driver belum benar,
   yang rusak adalah Hyprland, dan kamu akan salah menyalahkan SekaiPop.
2. **ESP Windows cuma 260 MB, CachyOS butuh `/boot` 4 GB.** FAT32 tidak bisa
   di-resize in-place. Solusinya: buat `/boot` sendiri sebagai ESP kedua, jangan
   sentuh ESP Windows. Ini juga mencegah Windows Update merusak bootloader Linux.
   Detail di [01-cachyos.md §1.1](docs/01-cachyos.md#11-masalah-utama-esp-260-mb).
3. **50.6 GB free space itu mepet — tapi bisa dibebaskan.** Hasil scan rekursif:
   `Documents` 25.8 GB (didominasi `Plant Ai EVe` 14.9 GB), `Downloads` 17.1 GB,
   `Videos` 6.8 GB. Sekitar **36 GB aman dibebaskan**, jadi free space bisa naik
   ke **~87 GB**. Caranya di
   [00-persiapan.md §0.5b](docs/00-persiapan.md#05b-membersihkan-windows-kalau-shrink-kurang).
4. **Laptop ini punya satu slot M.2** menurut spesifikasi seri FA506. Jadi "beli SSD
   kedua" bukan opsi simpel — cek dulu fisiknya sebelum berasumsi.

---

## Urutan yang harus diikuti

Jangan lompat. Nomor 2 dan 3 adalah tempat 90% kegagalan terjadi.

| # | Langkah | File | Kalau dilewati |
|---|---|---|---|
| 1 | Siapkan Windows (BitLocker, Fast Startup, backup) | [docs/00-persiapan.md](docs/00-persiapan.md) | Kehilangan data / Windows tidak bisa boot |
| 2 | **Dual boot**: partisi + install CachyOS (No Desktop) | [docs/01-cachyos.md](docs/01-cachyos.md) | Windows tertimpa / ESP penuh, sistem tidak bisa boot |
| 3 | Driver GPU hybrid (AMD + NVIDIA) | [docs/02-driver-gpu.md](docs/02-driver-gpu.md) | Layar hitam, Hyprland crash, shell tidak muncul |
| 4 | Install SekaiPop | [docs/03-sekaipop.md](docs/03-sekaipop.md) | — |
| 5 | Kalau ada yang rusak | [docs/04-troubleshooting.md](docs/04-troubleshooting.md) | Panik tanpa jalan pulang |

Setelah selesai, tiap kali nyalakan laptop kamu akan lihat menu **Limine** dengan
pilihan CachyOS dan Windows 11.

---

## Aturan yang tidak boleh dilanggar

1. **Jangan `curl | bash`.** Clone dulu, baca, baru jalankan. Installer SekaiPop
   memindahkan seluruh `~/.config/hypr` kamu.
2. **Selalu `--dry-run` dulu.** Dia mencetak semua yang akan diubah dan tidak
   menyentuh apa pun.
3. **Jangan pakai `--hypr full`** di mesin yang sudah punya config Hyprland.
4. **Jangan install driver NVIDIA sebelum baca [docs/02-driver-gpu.md](docs/02-driver-gpu.md).**
   Urutan pemasangannya penting di laptop hybrid.
5. **Siapkan USB live second** (CachyOS atau Arch) sebelum mulai. Kalau boot rusak,
   ini satu-satunya cara masuk kembali tanpa install ulang.

---

## Script

`scripts/preflight.sh` — read-only. Dijalankan **di CachyOS setelah install**,
sebelum menyentuh SekaiPop. Dia memeriksa semua prasyarat dan melaporkan mana yang
kurang, tanpa mengubah apa pun.

```bash
bash scripts/preflight.sh
```

---

## Sumber yang dipakai

Semua klaim di repo ini dicek ke sumber primer, bukan tebakan:

- [SekaiPop README](https://github.com/Blapples/SekaiPop) — requirements, opsi installer, peringatan
- [CachyOS: Preparation steps](https://wiki.cachyos.org/installation/installation_prepare/) — requirement sistem, cara bikin USB
- [CachyOS: Installation](https://wiki.cachyos.org/installation/installation_on_root/) — partisi, dual-boot
- [CachyOS: Desktop Environments](https://wiki.cachyos.org/installation/desktop_environments/) — Hyprland edition = Noctalia
- [CachyOS: chwd](https://wiki.cachyos.org/features/chwd/chwd/) — deteksi hardware & driver
- [CachyOS calamares packagechooser](https://github.com/CachyOS/cachyos-calamares/blob/cachyos/src/modules/packagechooser/packagechooser_desktop.conf) — opsi "No Desktop" memang ada
- [Hyprland: Start](https://wiki.hypr.land/Configuring/Start/) — config Lua sejak 0.55
- [Hyprland: Systemd startup](https://wiki.hypr.land/Useful-Utilities/Systemd-start/) — soal uwsm
- [Arch package DB](https://archlinux.org/packages/) — versi hyprland 0.56.2, quickshell 0.3.2, qt6-base 6.12.0

---

## Lisensi & kredit

Runbook ini tulisan sendiri, bebas kamu pakai. SekaiPop sendiri **GPL-3.0** dan
sebagian besar kodenya ditulis dengan bantuan AI oleh author aslinya — lihat
peringatan di README mereka sebelum menganggapnya stabil.
