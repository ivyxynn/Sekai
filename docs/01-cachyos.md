# 01 — Install CachyOS (dual boot dengan Windows 11)

Target halaman ini: CachyOS terpasang **berdampingan** dengan Windows 11, Windows
tetap utuh dan bisa di-boot, dan CachyOS login ke TTY tanpa desktop.

---

## 1.0 Kondisi disk kamu (dicek langsung)

Ini bukan asumsi. Dibaca dari Windows sebelum runbook ditulis:

```
Disk 0: SAMSUNG MZVL8512HELU  —  477 GB  —  NVMe SSD  —  GPT
├─ p1  System (EFI)    260 MB   ← Windows Boot Manager ada di sini
├─ p2  Reserved (MSR)   16 MB
├─ p3  C: NTFS        475.5 GB   ← free 50.6 GB
├─ p4  Recovery          1 GB
└─ p5  Recovery        200 MB
```

Dua angka yang menentukan segalanya:

| Angka | Nilai | Konsekuensi |
|---|---|---|
| Free space C: | **50.6 GB** | Cukup, tapi tidak lega |
| ESP Windows | **260 MB** | **Terlalu kecil** untuk CachyOS |

---

## 1.1 Masalah utama: ESP 260 MB

Ini jebakan yang bikin banyak orang gagal, dan hampir tidak pernah dijelaskan.

CachyOS minta `/boot` **minimal 4 GB** (untuk Limine) atau 2 GB (systemd-boot).
ESP Windows kamu cuma **260 MB** dan sudah dipakai Windows Boot Manager.

Kalau kamu mount ESP 260 MB itu sebagai `/boot`, hasilnya:

- Kernel + initramfs + microcode + driver NVIDIA DKMS **tidak muat**
- Update kernel gagal di tengah jalan
- Sistem **tidak bisa boot** setelah update pertama

Dan kamu **tidak bisa memperbesar** partisi FAT32 di tempat. Dokumentasi CachyOS
menyebutnya sendiri:

> *"FAT filesystems cannot be resized in-place. To properly 'resize' the FAT EFI
> partition, one must back up the existing EFI filesystem, use a tool such as
> gparted to resize the existing partition and reformat the new partition, then
> copy the previous filesystem structure back into the EFI partition."*

Itu berisiko dan tidak perlu.

### Solusinya: `/boot` sendiri, ESP Windows tidak disentuh

```
Disk 0
├─ p1  EFI Windows    260 MB   ← JANGAN DISENTUH
├─ p2  MSR             16 MB   ← JANGAN DISENTUH
├─ p3  C: NTFS       475 GB    ← di-shrink
├─ p4  Recovery         1 GB   ← JANGAN DISENTUH
├─ p5  Recovery       200 MB   ← JANGAN DISENTUH
├─ p6  /boot FAT32      4 GB   ← BARU, jadi ESP Linux
└─ p7  / btrfs        sisa     ← BARU
```

Ini legal di UEFI: satu disk **boleh** punya lebih dari satu ESP. Firmware akan
melihat dua entri boot, dan itu memang yang kita mau.

Keuntungan tambahan yang besar: karena ESP Linux terpisah, **Windows Update tidak
bisa merusak bootloader Linux** dengan menimpa ESP. Ini penyebab paling umum
dual-boot rusak, dan kita menghindarinya secara struktural — bukan dengan doa.

---

## 1.2 Pilih bootloader: **Limine**

CachyOS menawarkan empat. Untuk kasus kamu, pilihannya jelas:

| Bootloader | `/boot` yang diminta | Cocok di sini? |
|---|---|---|
| **Limine** | FAT32 **4 GB**, mount `/boot` | ✅ **Pilih ini** |
| systemd-boot | FAT32 2 GB, mount `/boot` | ⚠️ Bisa, tapi harus copy binary Windows manual |
| GRUB | mount `/boot/efi` → **pakai ESP 260 MB** | ❌ ESP terlalu kecil, dan menulis ke ESP Windows |
| rEFInd | FAT32 2 GB | ⚠️ Bisa, tapi lebih ribet dari Limine |

Kenapa Limine:

- `/boot` sendiri 4 GB → tidak menyentuh ESP Windows
- Windows terdeteksi otomatis; kalau tidak, ada `limine-scan`
- Btrfs snapshot integration aktif by default di CachyOS
- Ini bootloader default CachyOS, jadi paling banyak teruji di distro ini

> **Kalau kamu pilih GRUB**, dia akan memasang dirinya ke ESP 260 MB milik
> Windows. Secara teori bisa (GRUB butuh ~50 MB), tapi kamu menaruh bootloader
> Linux di partisi yang dipakai Windows Update. Hindari.

---

## 1.3 Berapa besar yang harus di-shrink

Rekomendasi resmi CachyOS: minimal 30 GB untuk CachyOS saja. Tambah kebutuhan
kita:

| Komponen | Ukuran |
|---|---|
| `/boot` (Limine) | 4 GB |
| CachyOS base + kernel | ~10 GB |
| Hyprland + Qt6 + Quickshell | ~4 GB |
| Paket SekaiPop | ~3 GB |
| Font, theme, cache | ~2 GB |
| Ruang kerja + update kernel | ~6 GB |
| **Total** | **~29 GB** |

**Target: shrink 50 GB.** Dengan 50 GB kamu dapat 4 GB `/boot` + 46 GB root, dan
sekitar 17 GB sisa lega. Itu cukup nyaman.

Tapi free space kamu cuma 50.6 GB, dan Windows tidak akan membiarkan kamu shrink
sampai habis — ada file yang tidak bisa dipindah (pagefile, System Restore,
file yang sedang dipakai).

**Kabar baiknya: 50.6 GB itu bukan batas.** Scan rekursif menemukan ~36 GB yang
aman dibebaskan:

| Sumber | Ukuran |
|---|---|
| `Documents` (total) | 25.8 GB |
| ↳ `Plant Ai EVe` | 14.9 GB |
| ↳ `1Magang` | 2.2 GB |
| `Downloads` (total) | 17.1 GB |
| ↳ cache IDM | 4.0 GB |
| ↳ ISO CachyOS | 3.0 GB ← **simpan** |
| `Videos` (total) | 6.8 GB |

Setelah dibersihkan, free space naik ke **~87 GB**. Shrink 50 GB jadi nyaman:
Windows masih punya ~37 GB, CachyOS dapat 50 GB.

**Urutan yang disarankan:**

1. Hapus cache IDM (4 GB) — 1 menit
2. Pindahkan `Documents` + `Videos` ke drive eksternal (~32 GB) — sekaligus backup
3. Baru shrink

Detail perintahnya di
[00-persiapan.md §0.5b](00-persiapan.md#05b-membersihkan-windows-kalau-shrink-kurang).

Kalau kamu **tidak** mau membersihkan apa pun dan tetap coba shrink sekarang,
kemungkinan besar Windows hanya menawarkan 30–45 GB. Itu masih bisa jalan:
4 GB `/boot` + sisanya root, dengan sisa ~5–15 GB. Bisa, tapi sempit.

---

## 1.4 Membersihkan Windows dulu (disarankan)

**Langkah lengkapnya ada di
[00-persiapan.md §0.5b](00-persiapan.md#05b-membersihkan-windows-kalau-shrink-kurang)** —
termasuk daftar folder konkret di mesin kamu beserta ukurannya. Jangan duplikasi
di sini supaya tidak ada dua versi yang bisa berbeda.

Ringkasnya:

1. Hapus cache IDM (`DwnlData`) — 4 GB, aman
2. Pindahkan `Documents` + `Videos` ke drive eksternal — ~32 GB, sekaligus backup
3. `cleanmgr /sageset:1` lalu `cleanmgr /sagerun:1`
4. Matikan System Restore sementara

Satu hal yang hanya ada di sini — **pagefile bisa memblokir shrink**:

```powershell
Get-CimInstance Win32_PageFileUsage | Select-Object Name,AllocatedBaseSize
```

Kalau ukurannya besar (>4 GB) dan shrink mentok, pindahkan sementara ke
"No paging file" → reboot → shrink → kembalikan. Jangan biarkan permanen; Windows
butuh pagefile.

---

## 1.5 Shrink partisi C:

`Win + R` → `diskmgmt.msc`

1. Klik kanan **C:** → **Shrink Volume...**
2. Tunggu Windows menghitung (bisa 1–2 menit)
3. Lihat **"Size of available shrink space in MB"**

| Nilai yang muncul | Lakukan |
|---|---|
| ≥ 51200 (50 GB) | Isi `51200`, lanjut |
| 40960–51199 (40–50 GB) | Isi angka maksimum, **catat** berapa |
| < 40960 | Batal, bersihkan dulu (1.4), ulangi |

4. Klik **Shrink**

Hasilnya: **unallocated space** di akhir disk. **Jangan diformat. Jangan dibuat
partisi baru.** Calamares yang akan memakainya.

---

## 1.6 Boot dari USB dan mulai installer

1. Restart, tekan **Esc** berulang untuk boot menu (atau **F2** → Boot)
2. Pilih USB, pastikan yang **UEFI**
3. Di desktop live, klik **Launch Installer**
4. Language: English. Region: **Asia/Jakarta**
5. Keyboard: `us`

### Verifikasi mode UEFI — jangan dilewati

Buka terminal di live session:

```bash
efibootmgr -v
```

- Muncul daftar entri → **UEFI, benar**
- Muncul `EFI variables are not supported on this system` → **kamu boot Legacy**

Kalau Legacy, restart dan pilih entri USB yang UEFI. Kalau tetap Legacy, matikan
**CSM** di BIOS. Dokumentasi CachyOS: *"If you only get GRUB and Limine as boot
manager options, the system is booted in Legacy/BIOS mode."*

---

## 1.7 Partisi manual — bagian paling berbahaya

Pilih **Manual partitioning**.

> ⚠️ **Jangan pilih "Install alongside" atau "Replace partition".**
> Dokumentasi CachyOS menyebut keduanya *"not 100% reliable and can cause the
> installation to fail"*, dan `Replace partition` bisa menghapus Windows.

Kamu akan melihat daftar partisi. Yang **tidak boleh disentuh**:

| Partisi | Ukuran | Isi |
|---|---|---|
| `nvme0n1p1` | 260 MB | EFI Windows |
| `nvme0n1p2` | 16 MB | MSR |
| `nvme0n1p3` | 475 GB | Windows C: |
| `nvme0n1p4` | 1 GB | Recovery |
| `nvme0n1p5` | 200 MB | Recovery |

**Aturan: jangan pernah klik Delete atau Format pada lima partisi di atas.**

Sekarang buat dua partisi baru di **free space**:

### Partisi 1 — `/boot`

Klik **free space** → **Create**:

| Field | Isi |
|---|---|
| Size | `4096` MiB |
| File system | `fat32` |
| Mount point | `/boot` |
| Flags | `boot` |

### Partisi 2 — `/`

Klik **free space** yang tersisa → **Create**:

| Field | Isi |
|---|---|
| Size | sisanya (biarkan default) |
| File system | `btrfs` |
| Mount point | `/` |
| Flags | — |

> **Kenapa btrfs?** Karena CachyOS mengaktifkan `limine-snapper-sync` untuk
> btrfs secara default. Artinya kamu dapat snapshot otomatis sebelum update, dan
> bisa boot ke snapshot lama kalau update merusak sistem. Di distro yang sedang
> kamu bangun, ini penyelamat.

### Bootloader

Di bagian **Boot loader location** (atau **Install boot loader on**):

- Pilih **Limine**
- Target: **disk** `nvme0n1` (bukan partisi tertentu)

---

## 1.8 Sisa wizard

### Desktop Environment — **pilih "No Desktop"**

Scroll ke paling atas, pilih **No Desktop**. Alasannya lengkap di
[03-sekaipop.md](03-sekaipop.md#31-kenapa-setup-kita-justru-menghindari-masalah-terbesar),
ringkasnya: kalau pilih Hyprland edition, kamu dapat Noctalia + uwsm yang bentrok
dengan SekaiPop.

### Packages
Biarkan default. Jangan centang yang tidak kamu paham.

### Users
- Username huruf kecil, tanpa spasi
- **Password wajib diisi**
- **Jangan** centang "Log in automatically" — kalau shell rusak, kamu butuh TTY
- Centang "Use the same password for the administrator account"

### Review — baca sebelum klik Install

Pastikan:

- [ ] Tidak ada partisi Windows yang ditandai akan **diformat**
- [ ] Ada partisi baru 4 GB FAT32 → `/boot`
- [ ] Ada partisi baru btrfs → `/`
- [ ] Bootloader = Limine, target disk `nvme0n1`
- [ ] Desktop = No Desktop

Baru klik **Install Now**.

---

## 1.9 Boot pertama setelah install

Lepas USB, restart. Kamu akan melihat **menu Limine** dengan pilihan CachyOS.

### Kalau Windows tidak muncul di menu

Boot ke CachyOS (login TTY), lalu:

```bash
sudo limine-scan
```

Ini memindai ESP lain dan menambahkan entri Windows. Reboot untuk melihat
hasilnya.

Verifikasi entri yang ada:

```bash
sudo limine-entry-tool --list 2>/dev/null || ls /boot/limine/
```

### Kalau Windows masih tidak muncul

Cek apakah Windows Boot Manager benar-benar ada di ESP 260 MB:

```bash
lsblk -f
sudo mkdir -p /mnt/winboot
sudo mount /dev/nvme0n1p1 /mnt/winboot
ls /mnt/winboot/EFI/Microsoft/Boot/bootmgfw.efi
sudo umount /mnt/winboot
```

Kalau file `bootmgfw.efi` **ada**, Windows sehat — tinggal tambahkan entri
manual. Kalau **tidak ada**, Windows-nya bermasalah (bukan CachyOS).

### Set urutan boot supaya Limine jadi default

```bash
efibootmgr
```

Cari entri `Limine` (atau `CachyOS`), lihat nomornya, lalu:

```bash
sudo efibootmgr -o 0001,0000
```

(Ganti `0001` dengan nomor Limine, `0000` dengan Windows.)

Biasanya ini tidak perlu — installer sudah mengaturnya. Tapi kalau laptop boot
langsung ke Windows, ini perbaikannya.

---

## 1.10 Windows Update bisa merusak boot — dan cara mengatasinya

Ini risiko nyata yang disebut dokumentasi CachyOS sendiri:

> *"Windows updates can break the bootloader by overwriting the EFI partition.
> In some cases, issues might never occur, but for some users it can be a
> recurring problem."*

Setup kita **sudah mengurangi risiko ini** karena `/boot` Linux ada di partisi
terpisah — Windows Update tidak menulis ke sana.

Tapi Windows masih bisa mengubah **urutan boot di NVRAM**, sehingga laptop
langsung masuk Windows.

### Kalau terjadi

Boot ke CachyOS (lewat BIOS boot menu, tekan **Esc**/F8 saat start), lalu:

```bash
sudo efibootmgr -o 0001,0000
```

### Kalau Limine hilang sama sekali dari NVRAM

```bash
# Cari tahu di mana limine.efi
sudo find /boot -name '*.efi' 2>/dev/null
lsblk -f

# Daftarkan ulang
sudo efibootmgr --create --disk /dev/nvme0n1 --part 6 \
  --label "Limine" --loader '\EFI\limine\limine_x64.efi'
```

(Sesuaikan nomor partisi `6` dengan partisi `/boot` kamu — cek `lsblk`.)

---

## 1.11 Verifikasi setelah boot

```bash
# Distro
cat /etc/os-release | head -3

# Windows masih ada?
lsblk -f
sudo blkid | grep -i ntfs

# Bootloader melihat Windows?
sudo limine-entry-tool --list 2>/dev/null

# Mount point benar?
findmnt /boot
findmnt /

# Arsitektur CPU (Ryzen 5 7535HS = v3, bukan v4)
/lib/ld-linux-x86-64.so.2 --help | grep -A5 hwcaps
```

Yang harus terlihat:

- `/boot` = partisi 4 GB FAT32 yang baru
- `/` = btrfs
- Partisi NTFS Windows masih ada, ukurannya tidak berubah
- CPU mendukung `x86-64-v3`

---

## 1.12 Update sistem

```bash
sudo pacman -Syu
sudo reboot
```

Setelah reboot, **tes boot ke Windows sekali** sebelum lanjut ke driver GPU.
Lebih baik tahu sekarang kalau ada yang salah, daripada setelah kamu
menginvestasikan berjam-jam di CachyOS.

---

## 1.13 Kalau mau membatalkan dual boot

Hapus CachyOS dan kembalikan ruang ke Windows:

1. Boot USB CachyOS (live session)
2. Buka `gparted` atau `sudo cfdisk /dev/nvme0n1`
3. Hapus partisi `/boot` dan `/` (p6 dan p7)
4. **Jangan** sentuh p1–p5
5. Boot Windows → `diskmgmt.msc` → klik kanan C: → **Extend Volume**
6. Hapus entri Limine dari NVRAM:
   ```bash
   sudo efibootmgr -b 0001 -B
   ```

Windows akan kembali seperti semula. Data Windows tidak pernah tersentuh selama
kamu tidak memformat p3.

---

## Checklist

- [ ] Data penting sudah di drive eksternal
- [ ] BitLocker: `Fully Decrypted`
- [ ] `powercfg /H off` sudah dijalankan + reboot
- [ ] Unallocated space ≥ 40 GB
- [ ] `efibootmgr -v` di live session berjalan (artinya UEFI)
- [ ] Partisi baru: 4 GB FAT32 → `/boot`, sisa → `/` btrfs
- [ ] Bootloader: **Limine**, target disk `nvme0n1`
- [ ] Desktop: **No Desktop**
- [ ] Menu Limine menampilkan CachyOS **dan** Windows
- [ ] Sudah tes boot ke Windows sekali
- [ ] `sudo pacman -Syu` selesai tanpa error

Lanjut ke [02-driver-gpu.md](02-driver-gpu.md) — **jangan lewati ini.**
