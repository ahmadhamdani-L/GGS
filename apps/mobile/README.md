# GGS Werewolf — Mobile Application (Flutter Client)

Aplikasi mobile untuk **GGS (Ganteng Ganteng Serigala) Werewolf — Red vs Blue Edition** dibangun menggunakan Flutter.

Untuk petunjuk lengkap mengenai:
- Menjalankan Backend (Go Server)
- Mengonfigurasi API dan WebSocket Endpoint
- Menjalankan aplikasi di iOS Simulator & Android Emulator
- Menjalankan aplikasi di HP Fisik (Android & iOS)
- Melakukan testing dan build/packaging aplikasi

Silakan rujuk ke **[Root README.md](../../README.md)** proyek ini.

## Quick Start (Klien Mobile)

1. Pastikan dependencies terinstal:
   ```bash
   flutter pub get
   ```
2. Jalankan aplikasi pada simulator/device default (menggunakan `localhost`):
   ```bash
   flutter run
   ```
3. Jalankan aplikasi menggunakan IP lokal komputer Anda (untuk HP fisik / Android emulator):
   ```bash
   flutter run --dart-define-from-file=.env
   ```
   *(Pastikan isi `.env` sudah disesuaikan dengan IP komputer host Anda).*
