# Dokumen Persyaratan - GGS (Ganteng Ganteng Serigala) — Red vs Blue Edition

## Pendahuluan

GGS (Ganteng Ganteng Serigala) adalah permainan deduksi sosial werewolf edisi **Red vs Blue** yang tersedia di platform Web, Android, dan iOS. Game ini menggunakan Supabase sebagai backend (Auth, Database, Realtime) dan dibangun dengan React + TypeScript + Vite dalam arsitektur monorepo Turborepo + pnpm.

Edisi Red vs Blue memperkenalkan sistem tim warna: 🔴 Red Team (Werewolf + Witch) vs 🔵 Blue Team (Seer, Doctor, Villager), dengan 5 role unik dan minimum 8 pemain.

## Glosarium

- **GGS_System**: Sistem utama permainan GGS yang mengelola seluruh logika game, antarmuka pengguna, dan komunikasi antar komponen
- **Game_Engine**: Modul inti yang mengelola state permainan, transisi fase, dan aturan permainan werewolf (packages/game-engine/)
- **Pemain**: Pengguna yang berpartisipasi dalam sesi permainan, baik manusia maupun bot AI
- **Bot_AI**: Pemain otomatis yang dikendalikan oleh kecerdasan buatan untuk mengisi slot pemain (packages/ai-engine/)
- **Peran/Role**: Karakter yang diberikan kepada pemain di awal permainan (Werewolf, Witch, Seer, Doctor, Villager)
- **Tim/Team**: Kelompok pemain berdasarkan warna — Red Team atau Blue Team
- **Sesi_Permainan**: Satu putaran lengkap permainan dari pembagian peran hingga ada pemenang
- **Fase_Siang**: Periode di mana semua pemain berdiskusi dan melakukan voting untuk eliminasi
- **Fase_Malam**: Periode di mana peran khusus melakukan aksi masing-masing secara rahasia
- **Voting_System**: Mekanisme pemungutan suara untuk menentukan pemain yang dieliminasi (direct click, tanpa konfirmasi popup)
- **Room_Manager**: Modul yang mengelola pembuatan, konfigurasi, dan penghapusan ruang permainan via Supabase
- **Animation_Engine**: Modul yang mengelola rendering animasi dan transisi visual
- **UI_Renderer**: Komponen yang menampilkan antarmuka pengguna menggunakan React + TypeScript
- **State_Manager**: Modul yang mengelola state aplikasi menggunakan Zustand
- **Narrator**: Komponen yang menyampaikan narasi permainan dan instruksi ke pemain
- **Timer_System**: Modul yang mengelola batas waktu untuk setiap fase dan aksi pemain
- **Chat_System**: Modul komunikasi antar pemain selama Fase_Siang
- **Role_Assigner**: Modul yang mendistribusikan peran secara acak kepada pemain di awal permainan
- **Auth_Service**: Modul autentikasi menggunakan Supabase Auth (email/password + guest mode)
- **Realtime_Service**: Modul komunikasi realtime menggunakan Supabase Realtime (channels, presence, broadcast)
- **Testament_System**: Modul yang memungkinkan pemain yang mati meninggalkan pesan terakhir (wasiat)
- **Profile_Service**: Modul yang mengelola profil pemain (display name, avatar, level, coins)

## Visi Pengembangan

### Fase 1: MVP Web — Red vs Blue Edition
- Autentikasi (Supabase Auth: email/password + guest)
- Sistem profil (avatar, display name)
- Home page (Quick Match, Create Room, Join Room)
- Room system dengan Supabase Realtime
- Lobby dengan circular seats
- Logika inti permainan werewolf Red vs Blue (5 role)
- Mode multiplayer online (Supabase Realtime)
- Mode single player vs Bot_AI (fallback)
- Visual dark medieval/forest theme
- Testament/wasiat system

### Fase 2: Polish & Social
- Friends system
- Ranking dan leaderboard
- Replay dan riwayat pertandingan
- Push notifications
- Advanced moderation

### Fase 3: Mobile & Scale
- Aplikasi Android dan iOS (Capacitor)
- Optimisasi mobile
- LiveOps dan content management
- Monetisasi (cosmetic-only)

---

## Aturan Permainan (Red vs Blue Edition v1.0)

### Tim
- 🔴 **Red Team**: Werewolf + Witch
- 🔵 **Blue Team**: Seer + Doctor + Villager

### Peran

| Role | Team | Aksi Malam | Catatan |
|------|------|------------|---------|
| 🐺 Werewolf | 🔴 Red | Kill 1 pemain | Saling tahu sesama werewolf |
| 🧙 Witch | 🔴 Red | Heal 1x ATAU Poison 1x | Tahu semua werewolf. WW tidak tahu siapa Witch. Tidak bisa Heal+Poison di malam yang sama |
| 🔮 Seer | 🔵 Blue | Scan 1 pemain | 2 Seer mulai dari 8+ pemain. Saling tahu identitas |
| 💉 Doctor | 🔵 Blue | Protect 1 pemain (3x total) | Tidak bisa protect pemain yang sama 2 malam berturut-turut |
| 🧑‍🌾 Villager | 🔵 Blue | Tidak ada | Mengandalkan diskusi & voting |

### Urutan Fase Malam
1. ① Werewolf → pilih 1 target untuk dibunuh
2. ② Doctor → protect 1 pemain (jika masih punya kuota)
3. ③ Witch → heal target wolf ATAU poison seseorang ATAU skip
4. ④ Seer(s) → masing-masing scan 1 pemain

### Komposisi Pemain

| Pemain | 🐺 WW | 🔮 Seer | 💉 Doctor | 🧙 Witch | 🧑‍🌾 Villager |
|--------|--------|---------|-----------|----------|------------|
| 8      | 2      | 2       | 1         | 1        | 2          |
| 9      | 2      | 2       | 1         | 1        | 3          |
| 10     | 3      | 2       | 1         | 1        | 3          |
| 11     | 3      | 2       | 1         | 1        | 4          |
| 12     | 4      | 2       | 1         | 1        | 4          |
| 13     | 4      | 2       | 1         | 1        | 5          |
| 14     | 4      | 2       | 1         | 1        | 6          |
| 15     | 4      | 2       | 1         | 1        | 7          |
| 16     | 4      | 2       | 1         | 1        | 8          |

### Kondisi Kemenangan
- 🔴 Red wins: jumlah Werewolf hidup >= jumlah Blue Team hidup
- 🔵 Blue wins: semua Werewolf tereliminasi
- Catatan: Witch dihitung Red Team tapi win condition hanya melihat Werewolf vs Blue

### Aturan Khusus
- Witch tahu semua werewolf tapi werewolf tidak tahu siapa Witch
- 2 Seer saling tahu identitas dari awal
- Doctor punya maks 3 proteksi total, tidak bisa protect target yang sama berturut-turut
- Role pemain yang mati **tetap tersembunyi** sampai game selesai
- Witch tidak bisa Heal + Poison di malam yang sama

---

## Persyaratan

### Persyaratan 1: Autentikasi dan Profil

**User Story:** Sebagai pemain, saya ingin login dan memiliki profil yang menyimpan identitas saya, sehingga pengalaman bermain terpersonalisasi.

#### Kriteria Penerimaan

1. WHEN pemain membuka aplikasi untuk pertama kali, THE Auth_Service SHALL menampilkan halaman auth dengan tab Login/Register
2. WHEN pemain memilih registrasi via email, THE Auth_Service SHALL membuat akun baru via Supabase Auth setelah validasi email dan password (minimal 6 karakter)
3. WHEN pemain memilih mode Guest, THE Auth_Service SHALL membuat anonymous session via Supabase Auth untuk akses bermain tanpa registrasi
4. WHEN pemain berhasil login untuk pertama kali, THE Profile_Service SHALL mengarahkan ke halaman Profile Setup untuk memilih avatar (dari 7 pilihan) dan display name
5. WHEN pemain sudah memiliki profil, THE GGS_System SHALL menampilkan Home page dengan info pemain (avatar, nama, level, coins)
6. THE Auth_Service SHALL menggunakan Supabase Auth session management (auto refresh token)
7. WHEN pemain logout, THE Auth_Service SHALL menghapus session dan mengarahkan ke halaman auth

### Persyaratan 2: Manajemen Room dan Lobby

**User Story:** Sebagai pemain, saya ingin membuat atau bergabung ke room permainan, sehingga saya dapat bermain bersama pemain lain.

#### Kriteria Penerimaan

1. WHEN pemain memilih "Create Room", THE Room_Manager SHALL membuat room baru di Supabase (tabel game_rooms) dengan kode 6 karakter unik dan mengarahkan ke lobby
2. WHEN pemain memasukkan kode room yang valid via "Join Room", THE Room_Manager SHALL menambahkan pemain ke room_players dan mengarahkan ke lobby
3. WHILE pemain berada di lobby, THE Realtime_Service SHALL menampilkan pemain yang bergabung/keluar secara real-time via Supabase Realtime (presence)
4. THE Room_Manager SHALL menampilkan lobby dengan circular seats arrangement yang terisi saat pemain bergabung
5. WHEN host menekan START dan jumlah pemain >= 8, THE Game_Engine SHALL memulai permainan
6. IF jumlah pemain < 8 saat host menekan START, THEN THE GGS_System SHALL menampilkan pesan error
7. THE Room_Manager SHALL memungkinkan host mengonfigurasi: max players (8-16), timer duration, dan role composition
8. WHEN pemain memilih "Quick Match", THE Room_Manager SHALL mencari room yang tersedia atau membuat single player vs AI jika tidak ada room

### Persyaratan 3: Distribusi Peran (Red vs Blue)

**User Story:** Sebagai pemain, saya ingin mendapatkan peran secara acak dan adil sesuai sistem Red vs Blue, sehingga permainan berlangsung seimbang.

#### Kriteria Penerimaan

1. WHEN sesi permainan dimulai, THE Role_Assigner SHALL mendistribusikan peran secara acak sesuai komposisi tabel (berdasarkan jumlah pemain 8-16)
2. THE Role_Assigner SHALL memastikan setiap pemain mendapat tepat satu peran dan satu tim (Red atau Blue)
3. WHEN peran didistribusikan, THE GGS_System SHALL menampilkan peran hanya kepada pemain yang bersangkutan
4. WHEN pemain adalah Werewolf, THE GGS_System SHALL menampilkan identitas semua Werewolf lain
5. WHEN pemain adalah Witch, THE GGS_System SHALL menampilkan identitas semua Werewolf (tapi Werewolf tidak tahu siapa Witch)
6. WHEN pemain adalah Seer, THE GGS_System SHALL menampilkan identitas Seer lainnya (2 Seer saling tahu)
7. THE Role_Assigner SHALL menggunakan cryptographically secure randomization untuk distribusi peran

### Persyaratan 4: Siklus Fase Malam

**User Story:** Sebagai pemain dengan peran khusus, saya ingin melakukan aksi malam sesuai urutan yang benar, sehingga mekanisme game berjalan fair.

#### Kriteria Penerimaan

1. WHEN Fase_Malam dimulai, THE Narrator SHALL mengumumkan malam tiba dengan animasi transisi
2. WHEN giliran Werewolf, THE Game_Engine SHALL memungkinkan semua Werewolf memilih 1 target untuk dibunuh (dari pemain hidup non-Werewolf)
3. WHEN giliran Doctor, THE Game_Engine SHALL memungkinkan Doctor memilih 1 pemain untuk dilindungi (jika masih punya kuota protect, maks 3 total)
4. THE Game_Engine SHALL mencegah Doctor melindungi pemain yang sama 2 malam berturut-turut
5. WHEN giliran Witch, THE Game_Engine SHALL menampilkan opsi: Heal target wolf (1x seumur game), Poison pemain lain (1x seumur game), atau Skip
6. THE Game_Engine SHALL mencegah Witch menggunakan Heal dan Poison di malam yang sama
7. WHEN giliran Seer, THE Game_Engine SHALL memungkinkan setiap Seer memilih 1 pemain untuk di-scan dan menampilkan tim (Red/Blue) target tersebut
8. WHEN semua aksi malam selesai, THE Game_Engine SHALL memproses resolusi: jika Doctor protect target Wolf → tidak ada korban; jika Witch heal target Wolf → tidak ada korban; jika Witch poison → target mati
9. THE Timer_System SHALL memberikan batas waktu 20 detik per aksi malam, dengan aksi default (skip) jika waktu habis
10. Urutan resolusi: Wolf attack → Doctor protect → Witch heal/poison → Seer scan

### Persyaratan 5: Siklus Fase Siang

**User Story:** Sebagai pemain, saya ingin berdiskusi dan memilih pemain yang dicurigai saat siang hari, sehingga saya dapat mengeliminasi ancaman.

#### Kriteria Penerimaan

1. WHEN Fase_Siang dimulai, THE Narrator SHALL mengumumkan hasil malam (siapa yang mati, tanpa reveal role)
2. IF ada pemain yang mati di malam, THE Testament_System SHALL memberikan kesempatan pemain yang mati untuk meninggalkan wasiat (30 detik)
3. WHILE Fase_Siang aktif, THE Timer_System SHALL menampilkan countdown diskusi (default 120 detik)
4. WHEN fase diskusi berakhir, THE Voting_System SHALL membuka periode voting
5. WHEN voting aktif, THE GGS_System SHALL memungkinkan pemain hidup memilih target eliminasi via **direct click** (tanpa confirmation popup)
6. WHEN semua pemain hidup telah vote ATAU waktu voting habis, THE Voting_System SHALL menghitung hasil
7. IF ada satu pemain dengan suara terbanyak, THE Game_Engine SHALL mengeliminasi pemain tersebut (role TETAP tersembunyi)
8. IF terjadi seri, THE Game_Engine SHALL melakukan voting ulang antara pemain yang seri
9. IF voting ulang masih seri, THE Game_Engine SHALL skip eliminasi putaran tersebut
10. WHEN pemain dieliminasi di siang hari, THE Testament_System SHALL memberikan kesempatan wasiat (30 detik)

### Persyaratan 6: Sistem Testament/Wasiat

**User Story:** Sebagai pemain yang dieliminasi, saya ingin meninggalkan pesan terakhir, sehingga saya dapat membantu tim saya dari kubur.

#### Kriteria Penerimaan

1. WHEN pemain mati (baik malam atau siang), THE Testament_System SHALL menampilkan input wasiat dengan timer 30 detik
2. THE Testament_System SHALL menampilkan wasiat kepada semua pemain yang masih hidup
3. WHEN timer wasiat habis atau pemain submit, THE Game_Engine SHALL melanjutkan ke fase berikutnya
4. THE Testament_System SHALL membatasi panjang wasiat (max 200 karakter)

### Persyaratan 7: Kondisi Kemenangan

**User Story:** Sebagai pemain, saya ingin permainan berakhir ketika kondisi kemenangan terpenuhi dengan pemenang yang jelas.

#### Kriteria Penerimaan

1. WHEN jumlah Werewolf hidup >= jumlah Blue Team hidup, THE Game_Engine SHALL mengakhiri permainan dengan kemenangan 🔴 Red Team
2. WHEN semua Werewolf tereliminasi, THE Game_Engine SHALL mengakhiri permainan dengan kemenangan 🔵 Blue Team
3. THE Game_Engine SHALL memeriksa win condition setelah setiap eliminasi (malam atau siang)
4. WHEN permainan berakhir, THE GGS_System SHALL menampilkan layar hasil: tim pemenang, reveal semua peran, statistik
5. WHEN layar hasil ditampilkan, THE GGS_System SHALL menyediakan opsi "Main Lagi" dan "Kembali ke Home"
6. Catatan: Witch dihitung sebagai Red Team member yang hidup, tapi win condition hanya membandingkan **Werewolf count** vs **Blue Team count**

### Persyaratan 8: Komunikasi Realtime

**User Story:** Sebagai pemain online, saya ingin semua aksi dan event terlihat secara real-time, sehingga pengalaman multiplayer terasa responsif.

#### Kriteria Penerimaan

1. THE Realtime_Service SHALL menggunakan Supabase Realtime channels untuk broadcast game state
2. WHEN host memproses game logic, THE Realtime_Service SHALL broadcast state update ke semua client dalam room
3. THE Realtime_Service SHALL menggunakan Supabase Presence untuk tracking pemain online di lobby
4. WHEN pemain bergabung atau keluar dari room, THE Realtime_Service SHALL menampilkan update secara instant ke semua pemain di lobby
5. THE Host SHALL bertindak sebagai "server" yang memproses game logic dan broadcast state (host-authoritative model)
6. WHEN pemain melakukan night action atau vote, THE Realtime_Service SHALL mengirim action ke host via broadcast channel
7. THE Timer_System SHALL disinkronisasi across semua client via Realtime broadcast

### Persyaratan 9: Bot AI (Single Player Fallback)

**User Story:** Sebagai pemain yang tidak menemukan room online, saya ingin bermain melawan bot AI sebagai fallback.

#### Kriteria Penerimaan

1. WHEN Quick Match tidak menemukan room tersedia, THE GGS_System SHALL menawarkan mode single player vs AI
2. WHEN dalam mode single player, THE Bot_AI SHALL mengisi semua slot pemain lain (7+ bot untuk minimum 8 pemain)
3. THE Bot_AI SHALL melakukan aksi sesuai role-nya: Werewolf memilih target, Seer scan, Doctor protect, Witch heal/poison, semua bot vote
4. THE Bot_AI SHALL memiliki variasi kesulitan (Easy, Medium, Hard) yang mempengaruhi kualitas keputusan
5. THE Bot_AI SHALL menghasilkan chat messages selama diskusi dengan typing simulation delay
6. THE Bot_AI SHALL memiliki nama dan avatar unik
7. THE Game_Engine SHALL auto-advance phases dan timer di mode single player

### Persyaratan 10: Sistem Chat dan Diskusi

**User Story:** Sebagai pemain, saya ingin berkomunikasi dengan pemain lain selama diskusi.

#### Kriteria Penerimaan

1. WHILE Fase_Siang aktif, THE Chat_System SHALL memungkinkan semua pemain hidup mengirim pesan teks
2. WHEN pemain telah dieliminasi, THE Chat_System SHALL mencegah pemain mengirim pesan (bisa baca, tidak bisa kirim)
3. THE Chat_System SHALL memfilter kata-kata kasar
4. IF pesan melebihi 200 karakter, THEN THE Chat_System SHALL memotong pesan
5. THE Chat_System SHALL menampilkan pesan secara real-time via Supabase Realtime broadcast

### Persyaratan 11: Antarmuka dan Visual

**User Story:** Sebagai pemain, saya ingin antarmuka dengan tema dark medieval yang imersif dan responsif.

#### Kriteria Penerimaan

1. THE UI_Renderer SHALL menggunakan dark medieval/forest theme sesuai color palette:
   - Background: #0a1628, Surface: #1a2744, Primary: #f59e0b (gold)
   - Red Team: #ef4444, Blue Team: #3b82f6
2. THE UI_Renderer SHALL menampilkan antarmuka responsif (320px - 1920px)
3. THE UI_Renderer SHALL menggunakan avatar images (7 karakter) untuk PlayerCard
4. THE GGS_System SHALL menampilkan Home page dengan: player info card (avatar + nama + level + coins), tombol Quick Play, Create Room, Join Room, Friends (coming soon)
5. THE GGS_System SHALL menampilkan Lobby dengan circular seats, room code (copyable), settings panel, dan START button (golden)
6. WHEN transisi fase terjadi, THE Animation_Engine SHALL memutar animasi transisi (max 2 detik)
7. THE UI_Renderer SHALL menggunakan direct click interaction (tanpa confirmation popup untuk voting/actions)
8. THE UI_Renderer SHALL menggunakan UI style: rounded corners (12-16px), glow effects, semi-transparent cards, golden gradient buttons

### Persyaratan 12: Sistem Timer dan Pacing

**User Story:** Sebagai pemain, saya ingin permainan memiliki tempo teratur dengan timer yang jelas.

#### Kriteria Penerimaan

1. THE Timer_System SHALL menampilkan countdown visual untuk setiap fase aktif
2. WHEN timer mencapai nol, THE Game_Engine SHALL otomatis transisi ke fase berikutnya
3. WHEN timer diskusi tersisa 10 detik, THE Timer_System SHALL menampilkan peringatan visual
4. THE Timer_System SHALL memberikan batas waktu 20 detik per aksi malam
5. THE Timer_System SHALL memberikan 30 detik untuk testament/wasiat
6. THE Timer_System SHALL disinkronisasi across semua client

### Persyaratan 13: State Management dan Persistence

**User Story:** Sebagai pemain, saya ingin state permainan konsisten dan tidak hilang jika terjadi gangguan.

#### Kriteria Penerimaan

1. THE State_Manager SHALL menggunakan Zustand untuk state management di client
2. THE State_Manager SHALL menyimpan game state ke localStorage sebagai backup
3. WHEN pemain reload halaman, THE State_Manager SHALL memulihkan state dan reconnect ke Realtime channel
4. IF state tidak valid, THE State_Manager SHALL menampilkan error dan opsi mulai baru
5. THE Realtime_Service SHALL handle reconnection dengan state sync dari host

### Persyaratan 14: Performa dan Kompatibilitas

**User Story:** Sebagai pemain, saya ingin game berjalan lancar di perangkat saya.

#### Kriteria Penerimaan

1. THE GGS_System SHALL memuat halaman awal dalam waktu < 5 detik pada koneksi 3G
2. THE GGS_System SHALL kompatibel dengan Chrome 90+, Firefox 88+, Safari 14+, Edge 90+
3. THE GGS_System SHALL mengompresi aset dengan total bundle < 5MB initial load
4. THE Animation_Engine SHALL menurunkan kualitas pada perangkat low-end
5. THE GGS_System SHALL responsive pada mobile (touch-friendly, min 44px touch targets)

### Persyaratan 15: Audio dan Efek Suara

**User Story:** Sebagai pemain, saya ingin efek suara yang atmosferik untuk pengalaman imersif.

#### Kriteria Penerimaan

1. WHEN Fase_Malam dimulai, THE GGS_System SHALL memutar musik latar misterius
2. WHEN Fase_Siang dimulai, THE GGS_System SHALL memutar musik latar yang lebih cerah
3. WHEN pemain dieliminasi, THE GGS_System SHALL memutar efek suara dramatis
4. THE GGS_System SHALL menyediakan kontrol volume terpisah (musik/sfx)
5. THE GGS_System SHALL menyimpan preferensi audio ke localStorage

---

## Database Schema (Supabase)

### Tabel Utama

```sql
-- Profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  avatar_id INTEGER NOT NULL DEFAULT 1 CHECK (avatar_id BETWEEN 1 AND 7),
  coins INTEGER DEFAULT 100,
  level INTEGER DEFAULT 1,
  xp INTEGER DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Game rooms table
CREATE TABLE game_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(6) UNIQUE NOT NULL,
  host_id UUID REFERENCES auth.users(id) NOT NULL,
  status VARCHAR(20) DEFAULT 'waiting' CHECK (status IN ('waiting', 'playing', 'finished')),
  config JSONB NOT NULL DEFAULT '{}',
  max_players INTEGER DEFAULT 8 CHECK (max_players BETWEEN 8 AND 16),
  current_players INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Room players table
CREATE TABLE room_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES game_rooms(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  slot INTEGER NOT NULL,
  is_ready BOOLEAN DEFAULT false,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, user_id),
  UNIQUE(room_id, slot)
);
```

### RLS Policies
- Profiles: public read, own insert/update
- Game rooms: public read, auth create, host update/delete
- Room players: public read, auth join, own leave/update

### Realtime
- game_rooms dan room_players ditambahkan ke supabase_realtime publication
- Game state broadcast via Supabase Realtime channels (bukan tabel)

---

## Arsitektur Teknis

### Stack
- **Frontend**: React + TypeScript + Vite (apps/web/)
- **Backend**: Supabase (Auth, PostgreSQL, Realtime, Storage)
- **State**: Zustand (client-side)
- **Game Logic**: packages/game-engine/ (shared, dijalankan di host client)
- **AI Logic**: packages/ai-engine/ (client-side untuk single player)
- **Mobile**: Capacitor (wrap web app)
- **Monorepo**: Turborepo + pnpm workspaces

### Flow Aplikasi
```
Auth → Profile Setup → Home → Create/Join Room → Lobby → Game → Results
                              ↓
                        Quick Match (no room found) → Single Player vs AI
```

### Multiplayer Model
- **Host-authoritative**: Host client menjalankan game engine dan broadcast state ke semua pemain via Supabase Realtime
- Semua client menerima state updates dan render UI
- Night actions dan votes dikirim ke host via Realtime broadcast
- Host memproses actions dan broadcast hasil

### Type System
```typescript
type Team = 'red' | 'blue';
type Role = 'villager' | 'werewolf' | 'seer' | 'doctor' | 'witch';

interface NightActions {
  wolfTarget: string | null;
  doctorTarget: string | null;
  witchAction: { type: 'heal' | 'poison' | 'skip'; target?: string } | null;
  seerTarget: string | null;
  seer2Target: string | null;
}
```

### Night Phase Order (Engine)
```
NIGHT_START → WOLF_TURN → DOCTOR_TURN → WITCH_TURN → SEER_TURN → NIGHT_RESOLVE
```

---

## Catatan Pengembangan

### Fase 1 (Current Focus)
- Auth + Profile + Home + Room + Lobby + Game + Results
- Supabase Realtime multiplayer
- Single player vs AI (fallback)
- Dark medieval theme
- 5 roles, min 8 players, Red vs Blue

### Fase 2 (Future)
- Friends system
- Ranking/leaderboard
- Replay system
- Advanced moderation
- Push notifications

### Fase 3 (Future)
- Mobile apps (Capacitor)
- LiveOps
- Monetisasi (cosmetic-only)
- Additional roles
