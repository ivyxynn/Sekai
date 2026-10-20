# 00 — Persiapan di Windows

Kerjakan **semua** langkah di halaman ini sebelum colok USB. Yang dilewati di sini
akan jadi masalah yang jauh lebih mahal nanti.

---

## 0.1 Backup — jangan dilewati

Dual-boot berarti mempartisi disk yang sedang dipakai Windows. Walaupun prosesnya
aman kalau diikuti, satu salah klik bisa menghapus partisi.

Yang wajib diselamatkan:

- `C:\Users\Asus\Documents` — ini isi tugas kuliah kamu, termasuk folder proyek
- Browser profile (bookmark, password) — sync ke akun atau export
- Lisensi software, file konfigurasi aplikasi
- Apa pun yang tidak bisa dibuat ulang

Simpan ke **drive eksternal**, bukan ke partisi lain di disk yang sama. Kalau
partisi hilang, semuanya hilang.

---

## 0.2 Matikan BitLocker

BitLocker akan mengunci Windows kalau boot manager berubah — dan dual-boot
**pasti** mengubahnya.

Cek status (PowerShell **as Administrator**):

```powershell
manage-bde -status
```

Kalau `Conversion Status` bukan `Fully Decrypted`:

```powershell
manage-bde -off C:
```

Tunggu sampai selesai — dekripsi 475 GB bisa lama. Cek progres dengan perintah
yang sama; tunggu sampai `Fully Decrypted`.

> Kalau kamu biarkan BitLocker aktif, setelah install CachyOS Windows akan minta
> recovery key dan kamu harus mengetik 48 digit. Kalau key-nya tidak kamu simpan,
> data hilang.

---

## 0.3 Matikan Fast Startup dan Hibernation

Fast Startup membuat Windows "tidur" alih-alih mati total, sehingga filesystem
NTFS tetap dalam keadaan ter-mount saat kamu boot Linux. Ini bisa membuat partisi
Windows korup.

PowerShell **as Administrator**:

```powershell
powercfg /H off
```

Lalu reboot. Ini juga otomatis mematikan hibernation.

---

## 0.4 Cek ruang disk

```powershell
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter,@{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB)}}
```

Hasil di mesin ini saat runbook ditulis: **50.6 GB free dari 475 GB**.

CachyOS butuh minimal 30 GB. Tapi:

| Kebutuhan | Perkiraan |
|---|---|
| `/boot` (Limine) | 4 GB |
| CachyOS base + kernel | ~10 GB |
| Hyprland + Qt6 + Quickshell | ~4 GB |
| Paket SekaiPop (fitur penuh) | ~3 GB |
| Font, theme, cache | ~2 GB |
| Ruang kerja + update kernel | ~6 GB |
| **Total realistis** | **~29 GB** |

Target: **shrink 50 GB** (4 GB `/boot` + 46 GB root).

Kalau Windows hanya menawarkan < 40 GB, bebaskan ruang dulu — lihat §0.5b.
Scan rekursif menemukan **~36 GB yang aman dibebaskan** di mesin kamu, jadi
free space bisa naik ke **~87 GB**.

Dua opsi lain kalau ruang tetap tidak cukup:

1. **Cek apakah laptop ini benar-benar punya slot M.2 kedua.** Spesifikasi seri
   FA506 yang beredar menyebut 1 slot M.2 + 1 bay SATA 2.5". Buka penutup bawah
   dan lihat sendiri sebelum membeli apa pun.
2. **Install ke SSD eksternal (USB 3.2)** — lambat tapi tidak menyentuh disk
   internal sama sekali. Cocok kalau kamu cuma mau coba.

---

## 0.5 Shrink partisi Windows

PowerShell **as Administrator**:

```powershell
Get-Partition -DriveLetter C | Select-Object Size,@{n='SizeGB';e={[math]::Round($_.Size/1GB)}}
```

Shrink lewat Disk Management (`diskmgmt.msc`) — lebih aman karena ada preview:

1. `Win + R` → `diskmgmt.msc`
2. Klik kanan partisi **C:** → **Shrink Volume**
3. Tunggu Windows menghitung (1–2 menit)
4. Isi jumlah MB — lihat tabel di bawah
5. **Shrink**

Target: **50 GB** (`51200` MB). Tapi Windows sering hanya mengizinkan lebih
kecil, karena ada file yang tidak bisa dipindah (pagefile, System Restore,
`System Volume Information`).

| Space yang ditawarkan | Lakukan |
|---|---|
| ≥ 51200 MB (50 GB) | Isi `51200` |
| 40960–51199 MB (40–50 GB) | Isi maksimum, **catat angkanya** |
| < 40960 MB (< 40 GB) | Batal, bersihkan dulu (§0.5b), ulangi |

Sisakan **unallocated space**. Jangan diformat, jangan dibuat partisi baru —
CachyOS yang akan memakainya.

> **Kalau tombol Shrink abu-abu atau hasilnya 0 MB**, penyebabnya hampir selalu
> file yang tidak bisa dipindah. Matikan System Restore sementara dan pindahkan
> pagefile, lalu coba lagi.

### 0.5b Membersihkan Windows kalau shrink kurang

Kalau Windows hanya menawarkan < 40 GB, bebaskan ruang dulu.

**Hasil scan rekursif di mesin kamu** (dicek langsung, angka sebenarnya):

| Lokasi | Ukuran | Bisa dipindah/dihapus? |
|---|---|---|
| `Documents\Plant Ai EVe` | **14.91 GB** | ⚠️ Proyek — pindahkan ke eksternal |
| `Downloads` (total) | **17.1 GB** | Sebagian besar bisa |
| ↳ `...\IDM\DwnlData` (cache IDM) | **3.96 GB** | ✅ **Hapus** — sisa download, tidak dipakai |
| ↳ `cachyos-desktop-linux-260809.iso` | **2.97 GB** | ❌ **Jangan** — ini ISO buat USB kamu |
| ↳ `ABDM` | 1.51 GB | Cek isinya dulu |
| `Videos` | **6.8 GB** | Pindahkan ke eksternal |
| ↳ `Editing` + `backup 1` | 4.64 GB | Pindahkan |
| `Documents\1Magang` | 2.23 GB | Pindahkan / backup |
| `Documents\Project 1` | 1.48 GB | Pindahkan / backup |

Total yang **aman dibebaskan: ~36 GB** (14.9 + 17.1 − 2.97 ISO + 6.8). Itu
mengubah free space dari **50.6 GB → ~87 GB**, dan shrink 50 GB jadi sangat
nyaman — Windows masih punya ~37 GB.

#### Langkah 1 — hapus cache IDM (paling gampang, 3.96 GB)

```powershell
# Lihat dulu isinya
Get-ChildItem "C:\Users\Asus\Downloads\Compressed\IDMan.6.42.56.Portable.kuyhAa\IDM\DwnlData" -Recurse -File |
  Select-Object @{n='MB';e={[math]::Round($_.Length/1MB,1)}},Name

# Hapus kalau sudah yakin
Remove-Item "C:\Users\Asus\Downloads\Compressed\IDMan.6.42.56.Portable.kuyhAa\IDM\DwnlData" -Recurse -Force
```

> ⚠️ **Jangan hapus ISO-nya.** `cachyos-desktop-linux-260809.iso` (2.97 GB) itu
> installer yang akan kamu pakai untuk USB. Sudah gw verifikasi valid (signature
> ISO9660 `CD001` di offset 32768).

#### Langkah 2 — pindahkan proyek & video ke eksternal

Ini sekaligus jadi **backup** yang kamu butuh di §0.1. Dua kebutuhan, satu
pekerjaan.

```powershell
# Ganti E:\ dengan drive eksternal kamu
$dest = "E:\SekaiBackup"

# Salin dulu — JANGAN langsung pindah
robocopy "C:\Users\Asus\Documents" "$dest\Documents" /E /XJ /R:1 /W:1
robocopy "C:\Users\Asus\Videos"    "$dest\Videos"    /E /XJ /R:1 /W:1
```

Setelah selesai, **verifikasi** jumlah file cocok:

```powershell
(Get-ChildItem "C:\Users\Asus\Documents" -Recurse -File).Count
(Get-ChildItem "$dest\Documents" -Recurse -File).Count
```

Kalau angkanya sama, baru hapus yang besar dari C: — dan hanya kalau kamu
memang tidak butuh akses offline:

```powershell
# Contoh: hanya proyek terbesar
Remove-Item "C:\Users\Asus\Documents\Plant Ai EVe" -Recurse -Force
```

> **Jangan hapus seluruh `Documents`.** Beberapa aplikasi Windows menyimpan
> config di sana. Pindahkan per folder, bukan borongan.

#### Langkah 3 — kalau masih kurang

```powershell
cleanmgr /sageset:1
# centang semua (terutama Windows Update Cleanup), lalu:
cleanmgr /sagerun:1
```

Matikan System Restore sementara — `System Volume Information` memblokir shrink:

`Win + R` → `SystemPropertiesProtection` → pilih **C:** → **Configure** →
**Disable system protection**

> Nyalakan kembali setelah shrink selesai. Tanpa itu kamu kehilangan rollback
> driver Windows.

Cek `Program Files (x86)` (49 GB) dan `Program Files` (31.7 GB) — di situ ada
game/aplikasi besar. Uninstall yang tidak dipakai lewat **Settings → Apps**,
jangan hapus folder manual.

---

## 0.6 Matikan Secure Boot

Di BIOS/UEFI laptop ASUS:

1. Restart, tekan **F2** berulang saat logo ASUS muncul
2. Masuk **Security** → **Secure Boot** → **Secure Boot Control** → **Disabled**
3. **F10** untuk simpan dan keluar

Kenapa: driver NVIDIA proprietary dan beberapa modul kernel tidak di-sign untuk
Secure Boot. Kalau kamu butuh Secure Boot menyala (misalnya untuk anti-cheat
game), itu bisa diurus nanti dengan `sbctl` — tapi jangan di awal, karena
menambah variabel yang belum perlu.

---

## 0.7 Siapkan USB

Butuh USB **minimal 8 GB**, isinya akan dihapus total.

### Kamu sudah punya ISO-nya

Di `C:\Users\Asus\Downloads\cachyos-desktop-linux-260809.iso` (**2.97 GB**).
Sudah diverifikasi valid — punya signature ISO9660 `CD001` di offset 32768.

Artinya **kamu tidak perlu download ulang**. Langsung pakai file itu.

> Kalau mau ISO terbaru, cek dulu tanggal rilis di
> [cachyos.org/download](https://cachyos.org/download/). ISO tanggal 9 Agustus
> 2026 sudah cukup baru; installer CachyOS bersifat *online*, jadi paket tetap
> diambil versi terbaru saat install.

Buat bootable dengan salah satu:

- **Rufus** (Windows) — paling gampang. Mode **DD** kalau muncul pilihan.
- **Ventoy** — kalau mau satu USB isi banyak ISO. Taruh ISO sebagai file biasa,
  tidak perlu flash ulang.
- **balenaEtcher** — paling sederhana, tapi lambat.

> **Siapkan USB kedua** dengan CachyOS atau Arch live. Ini bukan paranoia: kalau
> boot manager rusak, USB live adalah satu-satunya cara memperbaiki tanpa
> install ulang. Satu USB yang sama bisa dipakai, tapi kalau USB-nya rusak atau
> hilang, kamu terjebak.

---

## 0.8 Catat ini sebelum reboot

Isi dan simpan di HP atau kertas:

```
Model laptop    : ASUS TUF Gaming A15 FA506NF
GPU             : AMD Radeon iGPU + NVIDIA RTX 2050
Disk            : SAMSUNG MZVL8512HELU (477 GB, satu-satunya)
Partisi         : p1 EFI 260MB | p2 MSR | p3 C: 475GB | p4-p5 Recovery
Free space      : 50.6 GB sebelum shrink (~87 GB setelah bersihkan §0.5b)
Shrink dapat    : ______ GB  (catat hasil Disk Management)
Secure Boot     : dimatikan
BitLocker       : dimatikan
System Restore  : dimatikan sementara (nyalakan lagi setelah shrink)
USB live        : CachyOS <versi>
USB cadangan    : ada / tidak ada
```

---

## Checklist sebelum lanjut

- [ ] Data penting sudah di drive eksternal
- [ ] `manage-bde -status` → `Fully Decrypted`
- [ ] `powercfg /H off` sudah dijalankan dan sudah reboot
- [ ] Windows dibersihkan kalau shrink < 40 GB (§0.5b)
- [ ] Unallocated space ≥ 40 GB sudah dibuat
- [ ] System Restore dinyalakan kembali setelah shrink
- [ ] Secure Boot disabled
- [ ] USB bootable sudah jadi dan sudah dites boot (bukan cuma diflash)
- [ ] USB live cadangan ada
- [ ] Catatan di 0.8 sudah disimpan, termasuk **angka shrink**

Kalau ada yang belum, **jangan lanjut** ke [01-cachyos.md](01-cachyos.md).
