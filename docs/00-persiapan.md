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

Hasil di mesin ini saat runbook ditulis: **51 GB free dari 475 GB**.

CachyOS butuh minimal 30 GB. Tapi:

| Kebutuhan | Perkiraan |
|---|---|
| CachyOS base + kernel | ~8 GB |
| Hyprland + Qt6 + Quickshell | ~4 GB |
| Paket SekaiPop (fitur penuh) | ~3 GB |
| Font, theme, cache | ~2 GB |
| Ruang kerja + update | ~5 GB |
| **Total realistis** | **~22–25 GB** |

Sisakan margin. Kalau setelah shrink tersisa < 45 GB, pertimbangkan salah satu:

1. **Hapus file dulu** — paling murah. Cari file besar:
   ```powershell
   Get-ChildItem C:\ -Recurse -File -ErrorAction SilentlyContinue |
     Sort-Object Length -Descending | Select-Object -First 20 FullName,@{n='GB';e={[math]::Round($_.Length/1GB,2)}}
   ```
2. **Cek apakah laptop ini benar-benar punya slot M.2 kedua.** Spesifikasi seri
   FA506 yang beredar menyebut 1 slot M.2 + 1 bay SATA 2.5". Buka penutup bawah
   dan lihat sendiri sebelum membeli apa pun.
3. **Install ke SSD eksternal (USB 3.2)** — lambat tapi tidak menyentuh disk
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
3. Isi jumlah MB. Untuk 60 GB: `61440`
4. **Shrink**

Sisakan **unallocated space**. Jangan diformat, jangan dibuat partisi baru —
CachyOS yang akan memakainya.

> Windows kadang menolak shrink kalau ada file yang tidak bisa dipindah
> (pagefile, hibernation file, restore point). Kalau tombol Shrink abu-abu atau
> hasilnya 0 MB: matikan System Restore sementara, matikan pagefile, lalu coba lagi.

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

Unduh ISO dari [cachyos.org/download](https://cachyos.org/download/) — pilih
**Desktop Edition**.

Buat bootable, pilih salah satu:

- **Rufus** (Windows) — paling gampang. Mode **DD** kalau muncul pilihan.
- **Ventoy** — kalau mau satu USB isi banyak ISO. Bisa taruh ISO sebagai file
  biasa, tidak perlu flash ulang tiap ganti distro.
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
Free space      : 51 GB sebelum shrink
Secure Boot     : dimatikan
BitLocker       : dimatikan
USB live        : CachyOS <versi>
USB cadangan    : ada / tidak ada
```

---

## Checklist sebelum lanjut

- [ ] Data penting sudah di drive eksternal
- [ ] `manage-bde -status` → `Fully Decrypted`
- [ ] `powercfg /H off` sudah dijalankan dan sudah reboot
- [ ] Unallocated space ≥ 45 GB sudah dibuat
- [ ] Secure Boot disabled
- [ ] USB bootable sudah jadi dan sudah dites boot (bukan cuma diflash)
- [ ] USB live cadangan ada
- [ ] Catatan di 0.8 sudah disimpan

Kalau ada yang belum, **jangan lanjut** ke [01-cachyos.md](01-cachyos.md).
