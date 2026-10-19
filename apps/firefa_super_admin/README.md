# FIREFA Super Admin & Cloud Sync

Portal statis aplikasi keempat FIREFA. Portal ini memakai identitas platform terpisah dari role tenant Owner/Kasir.

## Menjalankan lokal

1. Jalankan backend dan PostgreSQL dengan konfigurasi dari root `.env`.
2. Isi `PLATFORM_ADMIN_BOOTSTRAP_TOKEN` dengan secret acak unik minimal 32 karakter. Jangan gunakan token yang sama dengan `JWT_SECRET` atau `BOOTSTRAP_TOKEN`.
3. Jalankan migrasi backend: `npm run db:migrate` dari folder `backend`.
4. Sajikan folder ini melalui static HTTP server, lalu buka `index.html`.
5. Atur URL backend (default `http://localhost:3000`).
6. Pada setup awal saja, gunakan bagian **Setup awal Super Admin**. Bootstrap hanya berhasil jika belum ada akun platform admin. Simpan password dengan aman; jangan bagikan token bootstrap.
7. Login menggunakan akun Super Admin yang dibuat.

## Fitur portal

- Pemeriksaan publik `/health/live` dan `/health/ready`.
- URL backend tersimpan di local storage browser.
- Login platform di `POST /api/v1/platform-admin/auth/login`; token akses hanya disimpan di memori tab.
- Ringkasan jumlah tenant/outlet serta agregat event audit dan sync.
- Daftar tenant/outlet, audit log, dan status agregat Cloud Sync.
- Membuat tenant dan outlet, serta mengubah status aktif/nonaktif dengan audit platform.
- Validasi input outlet, koordinat, dan radius geofence 25–2.000 meter.

## Endpoint platform

Semua endpoint berikut selain bootstrap dan login memerlukan bearer token dengan scope `platform_admin` dan akun platform yang masih aktif.

| Method | Endpoint | Kegunaan |
|---|---|---|
| POST | `/api/v1/platform-admin/auth/bootstrap` | Membuat admin pertama, dilindungi header `X-Platform-Bootstrap-Token` |
| POST | `/api/v1/platform-admin/auth/login` | Login admin platform |
| GET | `/api/v1/platform-admin/overview` | Ringkasan tenant, outlet, audit, dan receipt sync |
| GET / POST | `/api/v1/platform-admin/tenants` | Daftar atau membuat tenant |
| PATCH | `/api/v1/platform-admin/tenants/:tenantId/status` | Mengaktifkan/menangguhkan tenant |
| GET / POST | `/api/v1/platform-admin/outlets` | Daftar atau membuat outlet |
| PATCH | `/api/v1/platform-admin/outlets/:outletId/status` | Mengaktifkan/menonaktifkan outlet |
| GET | `/api/v1/platform-admin/audit-logs` | Membaca audit tenant dan aktivitas platform |
| GET | `/api/v1/platform-admin/sync-status` | Agregat receipt sync dan perangkat per tenant |

## Batasan dan keamanan

- Super Admin **bukan** role tenant. Constraint membership Owner/Kasir tidak dilonggarkan.
- Endpoint admin memeriksa JWT scope dan memverifikasi kembali status akun platform pada database.
- Bootstrap dibatasi token khusus, lock transaksi PostgreSQL, dan hanya bisa dilakukan sekali.
- Perubahan tenant/outlet dicatat di `platform_admin_audit_logs`.
- Status sync menunjukkan receipt dan perangkat yang tercatat; itu **bukan** bukti semua antrean offline sudah terkirim atau tidak ada konflik.
- Portal statis tidak menyediakan backend, TLS, secret manager, rate limiting, atau deployment. Untuk produksi, sajikan portal dan API melalui HTTPS, batasi akses jaringan, lindungi secret bootstrap, dan verifikasi seluruh job CI sebelum rilis.
