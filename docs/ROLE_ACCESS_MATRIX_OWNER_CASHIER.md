# Matriks Hak Akses FIREFA — Owner dan Kasir

Tanggal: 16 Oktober 2026  
Branch: `development`

## Aturan role operasional

FIREFA hanya mendukung dua role operasional:

- `owner` — label UI **Owner**.
- `cashier` — label UI **Kasir**.

Role operasional lain seperti `staff`, `manager`, `kitchen`, dan `super_admin` tidak boleh diberikan lewat tenant membership operasional. Sistem/platform administration, jika kelak dibutuhkan, harus dipisahkan dari role outlet dan dirancang secara eksplisit.

## Matriks akses

| Kemampuan | Owner | Kasir | Kontrol utama |
|---|---:|---:|---|
| Dashboard | Ya | Ya | Flutter permission |
| POS dan transaksi kasir | Ya | Ya | Flutter + authenticated sync API |
| Melihat/mengelola pesanan biasa | Ya | Ya | Flutter + outlet-scoped sync API |
| Meja | Ya | Ya | Flutter permission |
| Konfigurasi printer kasir | Ya | Ya | Flutter permission |
| Shift kasir | Ya | Ya | Flutter permission |
| Melihat katalog produk | Ya | Ya | API requires active outlet membership |
| Membuat/mengubah produk | Ya | Tidak | API Owner-only |
| Melihat inventori | Ya | Tidak di UI | API requires active outlet membership |
| Membuat item inventori | Ya | Tidak | API Owner-only |
| Mutasi/penyesuaian stok | Ya | Tidak | API Owner-only |
| Pemulihan order hilang (`order.recovered`) | Ya | Tidak | API Owner-only |
| Laporan, keuangan, pelanggan, pengaturan, staf, outlet, audit | Ya | Tidak | Flutter permission; no corresponding mutation routes exposed to cashier in current API |

Semua endpoint terproteksi tetap memerlukan JWT valid dan tenant/outlet membership aktif. Token berisi role tidak menggantikan pemeriksaan membership di database. Akses lintas outlet harus ditolak.

## Perubahan yang diterapkan

- Login hanya memilih membership dengan role `owner` atau `cashier`; membership dengan role lain tidak bisa dipakai untuk mendapatkan sesi.
- Migration `006_owner_cashier_roles_only.sql` membatasi constraint database ke `owner` dan `cashier`.
- Migration sengaja **gagal secara aman** jika database sudah memiliki membership dengan role lain. Jangan otomatis mengubah `staff` atau `super_admin` menjadi Owner/Kasir; audit dan remap data lama dengan persetujuan pemilik terlebih dahulu.
- Endpoint mutasi katalog/inventori memerlukan Owner.
- Endpoint sync biasa tetap mengizinkan Owner/Kasir dalam outlet yang terdaftar; `order.recovered` hanya Owner.
- Tes integrasi mencakup penolakan role tak didukung di database, penolakan Kasir untuk create/update produk, create item/mutasi inventori, dan pemulihan order.

## Batasan

Role check backend menggunakan tenant membership yang sedang aktif serta outlet membership yang cocok. Flutter hanya menyembunyikan/membatasi UI; backend adalah pengaman otoritatif. Jika nanti endpoint baru ditambahkan, endpoint itu wajib memiliki tes negatif untuk Kasir bila operasinya Owner-only.

## Validasi

Backend workflow CI pada branch `development` menjalankan typecheck, build, migrasi PostgreSQL, tes unit/integrasi, idempotensi migrasi, pemeriksaan tabel, readiness API, dan Docker build. Status terbaru setelah commit tahap ini perlu dilihat di GitHub Actions; laporan ini tidak menyatakan lulus sebelum workflow selesai.
