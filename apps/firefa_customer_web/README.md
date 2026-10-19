# FIREFA Customer Web

Aplikasi web pelanggan ke-3 untuk pemesanan mandiri dari QR meja. Aplikasi ini sengaja berdiri sendiri dari Main App dan Staff App.

## Menjalankan secara lokal

Sajikan direktori ini melalui web server statis (jangan buka sebagai `file://`). QR meja harus mengarah ke URL `index.html` dengan parameter `outletId`, `tableId`, dan `tableName`.

Tambahkan parameter `api` berisi base URL backend FIREFA, contoh:
`https://api.example.com/?api=https%3A%2F%2Fapi.example.com`

## Status integrasi API

Frontend dirancang memakai kontrak:
- `GET /api/v1/public/menu?outletId=<UUID>` → `{ "products": [{ "id", "name", "description", "unitPrice", "isActive", "imageUrl" }] }`
- `POST /api/v1/public/orders` dengan `{ outletId, tableId, tableName, customerName, notes, items: [{ productId, quantity }] }` dan header `Idempotency-Key`.

**Penting:** endpoint publik tersebut belum tersedia di backend pada commit awal aplikasi ini. UI akan menyatakan layanan belum aktif dan tidak berpura-pura bahwa pesanan sudah diterima. Agar order benar-benar masuk ke Main App, endpoint harus dibuat dengan validasi outlet/menu, idempotensi, penyimpanan transaksi, dan sinkronisasi pesanan ke POS. Jangan mengaktifkan untuk produksi sebelum integrasi backend tersebut selesai dan diuji.
