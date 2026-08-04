# GGS (Ganteng Ganteng Serigala) Werewolf — Red vs Blue Edition

Permainan deduksi sosial bergaya Werewolf/Mafia multiplayer online berbasis role-playing untuk platform Android dan iOS, didukung oleh backend Go berkinerja tinggi.

---

## 🚀 Tech Stack

### Backend (Go Server)
- **Language:** Go (Golang) 1.21+
- **HTTP & Router:** Standard library `net/http`
- **Realtime:** Gorilla WebSockets (`gorilla/websocket`)
- **Database:** PostgreSQL 14+ (dengan fallback in-memory store untuk development)
- **Security:** JWT (RS256) untuk sesi, bcrypt untuk hashing password, rate limiting per-IP

### Frontend (Mobile App)
- **Framework:** Flutter 3.11+ (Dart 3.11+)
- **State Management:** Riverpod 2.6.1
- **Navigation:** GoRouter 14.8.1
- **Realtime Connection:** WebSocket Channel 3.0.1
- **Audio:** Audioplayers 6.1.0

---

## 📂 Struktur Proyek

```text
ggs/
├── apps/
│   └── mobile/              # Aplikasi mobile client (Flutter)
├── backend/
│   └── go-server/           # Server API & WebSocket (Go)
├── docker-compose.yml       # Konfigurasi PostgreSQL menggunakan Docker
├── AUDIT_REPORT.md          # Laporan audit stabilitas & bug
├── DOCUMENTATION.md        # Dokumentasi teknis & detail API
└── README.md                # Panduan utama proyek ini
```

---

## 🛠️ Persiapan Awal (Prerequisites)

Sebelum mulai, pastikan Anda telah menginstal tools berikut di komputer Anda:
1. **Go SDK:** versi 1.21 ke atas ([Download](https://go.dev/dl/))
2. **Flutter SDK:** versi 3.11 ke atas ([Download](https://docs.flutter.dev/get-started/install))
3. **Docker Desktop:** (Opsional, untuk menjalankan database PostgreSQL via container)
4. **Android Studio / Xcode:** Untuk kompilasi dan menjalankan simulator/emulator perangkat mobile.

---

## ⚡ 1. Menjalankan Backend (Go Server)

Server Go membutuhkan database PostgreSQL untuk menyimpan data profil, riwayat pertandingan, dll. Namun, server dilengkapi dengan **in-memory fallback** jika PostgreSQL tidak terdeteksi.

### Opsi A: Menggunakan PostgreSQL (Sangat Disarankan)

1. **Jalankan Postgres dengan Docker Compose:**
   Di direktori utama proyek (`ggs/`), jalankan perintah:
   ```bash
   docker compose up -d db
   ```
   *Catatan: Ini akan menjalankan PostgreSQL di port `5432` sesuai file `docker-compose.yml`.*

2. **Jalankan Server Go:**
   Masuk ke direktori backend, pasang `DATABASE_URL` di env, lalu jalankan server:
   ```bash
   cd backend/go-server
   export DATABASE_URL="postgres://postgres:postgres@localhost:5432/ggs_werewolf?sslmode=disable"
   go run cmd/server/main.go
   ```

### Opsi B: Tanpa PostgreSQL (In-Memory Fallback)

Jika Anda ingin menjalankan server dengan cepat tanpa setup database, Anda cukup menjalankan perintah di bawah. Server akan otomatis mendeteksi kegagalan koneksi PostgreSQL dan beralih menggunakan memori lokal komputer:
```bash
cd backend/go-server
go run cmd/server/main.go
```

> **Info:** Server backend akan berjalan di alamat `http://0.0.0.0:8080` (mendengarkan di semua interface jaringan agar bisa diakses oleh hp fisik).

---

## 📱 2. Menjalankan Frontend (Flutter Mobile App)

Masuk ke direktori mobile app dan unduh semua dependencies:
```bash
cd apps/mobile
flutter pub get
```

### Konfigurasi Endpoint Backend
Flutter berkomunikasi dengan backend melalui REST API dan WebSockets. Alamat server didefinisikan melalui `API_URL` dan `WS_URL` menggunakan `--dart-define` saat build/run.

Anda memiliki 3 cara utama untuk menjalankannya tergantung pada target device:

### A. iOS Simulator (Mac)
Simulator iOS berbagi localhost yang sama dengan mesin host Anda. Anda tidak perlu menyesuaikan IP:
```bash
flutter run
```
*(Default endpoint akan otomatis mengarah ke `http://localhost:8080`)*

---

### B. Android Emulator
Emulator Android berjalan di dalam sandbox jaringan tersendiri. Alamat `localhost` di dalam emulator merujuk ke emulator itu sendiri. Untuk mengakses host mesin Anda, gunakan IP khusus `10.0.2.2`:
```bash
flutter run \
  --dart-define=API_URL=http://10.0.2.2:8080 \
  --dart-define=WS_URL=ws://10.0.2.2:8080/ws
```

---

### C. HP Fisik (Android & iOS)

Untuk mengetes di HP fisik, laptop/komputer Anda dan HP **wajib terhubung di Wi-Fi yang sama**.

1. **Cari IP Lokal Laptop Anda:**
   - **macOS:** Jalankan perintah `ipconfig getifaddr en0` atau cek di *System Settings > Wi-Fi > Details*.
   - **Windows:** Jalankan perintah `ipconfig` di command prompt, cari IPv4 Address.
   - *Misal IP laptop Anda adalah:* `192.168.1.5`

2. **Jalankan Aplikasi dengan IP Tersebut:**
   ```bash
   flutter run \
     --dart-define=API_URL=http://192.168.1.5:8080 \
     --dart-define=WS_URL=ws://192.168.1.5:8080/ws
   ```

3. **Alternatif Menggunakan File `.env` (Lebih Praktis):**
   Ubah isi file `apps/mobile/.env` dan ganti `localhost` ke IP lokal laptop Anda:
   ```env
   API_URL=http://192.168.1.5:8080
   WS_URL=ws://192.168.1.5:8080/ws
   ```
   Lalu jalankan dengan perintah:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

#### 📌 Catatan Khusus HP Fisik Android:
- Aktifkan **Developer Options** dan **USB Debugging** pada HP Android Anda.
- Sambungkan HP menggunakan kabel data ke laptop, pilih opsi transfer file (MTP).
- Pastikan firewall laptop Anda tidak memblokir koneksi masuk pada port `8080`.

#### 📌 Catatan Khusus HP Fisik iOS:
- Sambungkan iPhone Anda ke Mac.
- Buka folder `apps/mobile/ios/Runner.xcworkspace` menggunakan Xcode.
- Pilih target device iPhone Anda, lalu atur **Signing & Capabilities** (pilih Development Team Anda).
- Aktifkan **Developer Mode** pada iPhone (Masuk ke *Settings > Privacy & Security > Developer Mode* lalu restart HP).
- Saat pertama kali aplikasi dibuka di HP, izinkan akses ke **Local Network** jika diminta agar aplikasi dapat menghubungi server di laptop.

---

## 🧪 3. Menjalankan Unit Tests

### Backend (Go)
Untuk menjalankan test suite backend:
```bash
cd backend/go-server
go test ./... -v
```

### Frontend (Flutter)
Untuk menjalankan test suite frontend:
```bash
cd apps/mobile
flutter test
```

---

## 📦 4. Build executable / Package Aplikasi

Jika ingin melakukan compile aplikasi Flutter ke format distribusi:

### Android (APK atau App Bundle)
```bash
cd apps/mobile

# Build Debug APK
flutter build apk --debug

# Build Release APK
flutter build apk --release --dart-define-from-file=.env

# Build App Bundle (untuk upload ke Google Play Console)
flutter build appbundle --dart-define-from-file=.env
```
*Output file APK berada di: `build/app/outputs/flutter-apk/app-release.apk`*

### iOS (IPA)
```bash
cd apps/mobile
flutter build ipa --release --dart-define-from-file=.env
```
*Gunakan Xcode Organizer untuk mengupload ke TestFlight atau Apple App Store.*
