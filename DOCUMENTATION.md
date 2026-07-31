# GGS Werewolf - Red vs Blue Edition
## Dokumentasi Lengkap Aplikasi

**Versi:** 2.1.0  
**Platform:** Android & iOS (Flutter)  
**Backend:** Go  
**Database:** PostgreSQL

---

## Daftar Isi

1. [Overview](#1-overview)
2. [Tech Stack](#2-tech-stack)
3. [Arsitektur Sistem](#3-arsitektur-sistem)
4. [Security](#4-security)
5. [Game Rules](#5-game-rules)
6. [User Flow](#6-user-flow)
7. [API Reference](#7-api-reference)
8. [WebSocket Events](#8-websocket-events)
9. [Database Schema](#9-database-schema)
10. [Flutter Architecture](#10-flutter-architecture)
11. [Features](#11-features)
12. [Testing](#12-testing)
13. [How to Run](#13-how-to-run)

---

## 1. Overview

GGS Werewolf adalah game multiplayer online berbasis role-playing dengan tema **Red vs Blue Edition**. Game ini merupakan adaptasi modern dari permainan Mafia/Werewolf klasik dengan twist unik dimana pemain dibagi menjadi dua tim:

- **Red Team (Tim Merah):** Werewolf + Witch
- **Blue Team (Tim Biru):** Seer + Doctor + Villager

### Tujuan Permainan

- **Red Team Menang:** Jika jumlah werewolf yang hidup >= jumlah blue team yang hidup
- **Blue Team Menang:** Jika semua werewolf tereliminasi

---

## 2. Tech Stack

### Frontend (Mobile App)
| Teknologi | Versi | Kegunaan |
|-----------|-------|----------|
| Flutter | 3.11+ | Cross-platform UI framework |
| Dart | 3.11+ | Programming language |
| Riverpod | 2.6.1 | State management |
| GoRouter | 14.8.1 | Navigation & routing |
| WebSocket Channel | 3.0.1 | Realtime communication |
| HTTP | 1.2.2 | REST API calls |
| Flutter Secure Storage | 9.2.2 | Secure token storage |
| Audioplayers | 6.1.0 | Background music & SFX |
| Google Fonts | 6.2.1 | Typography |

### Backend (Go Server)
| Teknologi | Kegunaan |
|-----------|----------|
| Go (Golang) | Backend language |
| net/http | HTTP server |
| gorilla/websocket | WebSocket handling |
| lib/pq | PostgreSQL driver |
| bcrypt | Password hashing |
| JWT (RS256) | Access + Refresh tokens |

### Database
| Teknologi | Kegunaan |
|-----------|----------|
| PostgreSQL | Primary database |
| Connection Pooling | Configurable pool (max 25 conns) |
| In-memory fallback | Development fallback |

---

## 3. Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Pages     │  │  Providers  │  │       Services          │ │
│  │ - Auth      │  │ - Auth      │  │ - API Service (HTTP)    │ │
│  │ - Home      │  │ - Room      │  │ - WebSocket Service     │ │
│  │ - Lobby     │  │ - Game      │  │ - Audio Service         │ │
│  │ - Game      │  │ - Chibi     │  └─────────────────────────┘ │
│  │ - Results   │  │ - Outfit    │                              │
│  │ - Stats     │  └─────────────┘                              │
│  │ - Shop      │                                                │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
                    │                    │
                    │ HTTP (REST)        │ WebSocket
                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                        GO BACKEND                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │    API      │  │  WebSocket  │  │      Game Engine        │ │
│  │ - Auth      │  │    Hub      │  │ - Role Distribution     │ │
│  │ - Profile   │  │ - Rooms     │  │ - Night Phase Logic     │ │
│  │ - Stats     │  │ - Clients   │  │ - Day Phase Logic       │ │
│  │ - Social    │  │ - Broadcast │  │ - Win Condition Check   │ │
│  │ - Shop      │  │ - Timer     │  │ - State Filtering       │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Database Layer                         │  │
│  │ - Users, Profiles, Stats, Match History, Leaderboard     │  │
│  │ - Game Rooms, Achievements, Shop, Friends, Missions      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       POSTGRESQL                                 │
│  25+ Tables: users, profiles, player_stats, match_history,      │
│  leaderboard, game_rooms, shop_items, achievements, etc.        │
└─────────────────────────────────────────────────────────────────┘
```


---

## 4. Security

### 4.1 Authentication & Token System

#### JWT Token Pair (Access + Refresh)
```
┌─────────────────────────────────────────────────────────────────┐
│                    TOKEN FLOW                                    │
│                                                                  │
│  Login/Register → Access Token (15 min) + Refresh Token (7 days)│
│                                                                  │
│  Access Token expired? → POST /api/auth/refresh                 │
│                       → New Access Token + New Refresh Token    │
│                       → Old Refresh Token invalidated (rotation)│
│                                                                  │
│  Logout → POST /api/auth/logout → Revoke refresh token          │
└─────────────────────────────────────────────────────────────────┘
```

| Token Type | Lifetime | Storage | Purpose |
|------------|----------|---------|---------|
| Access Token | 15 minutes | FlutterSecureStorage | API authorization |
| Refresh Token | 7 days | FlutterSecureStorage | Obtain new access tokens |

#### Token Rotation
- Setiap refresh menghasilkan refresh token BARU
- Refresh token lama langsung di-invalidate
- Mencegah token reuse attack

### 4.2 Security Middleware Stack

```
Request → Logging → CORS → Security Headers → Rate Limit → Auth → Handler
```

| Middleware | Function |
|------------|----------|
| **Logging** | Request ID, duration, status, IP tracking |
| **CORS** | Origin whitelist validation |
| **Security Headers** | X-Content-Type-Options, X-Frame-Options, X-XSS-Protection |
| **Rate Limiting** | Per-IP limits (auth: 10/min, API: 100/min, WS: 5/min) |
| **Auth** | JWT validation, user context injection |

### 4.3 Input Validation

| Validation Type | Implementation |
|-----------------|----------------|
| **UUID Validation** | Regex check for all IDs (user, room, friend, report) |
| **Email Validation** | Format check + sanitization |
| **Password Rules** | Min 8 chars, bcrypt hashing (cost 12) |
| **Display Name** | 2-20 chars, alphanumeric + spaces |
| **Request Body Limit** | Max 10KB per request |
| **XSS Prevention** | HTML entity escaping on all string inputs |
| **SQL Injection** | Parameterized queries only |

### 4.4 WebSocket Security

| Security Measure | Description |
|------------------|-------------|
| **Token Auth** | JWT required in query param `?token=<jwt>` |
| **Origin Validation** | Whitelist check on upgrade request |
| **Rate Limiting** | Max 5 WS connections per minute per IP |
| **Message Validation** | JSON schema validation, action whitelist |
| **Self-Action Prevention** | Cannot vote/target self |

### 4.5 Game State Security

```
┌─────────────────────────────────────────────────────────────────┐
│                    STATE FILTERING                               │
│                                                                  │
│  Full Game State (Server) → Filter per Player → Client          │
│                                                                  │
│  Player sees:                                                   │
│  - Own role (always)                                            │
│  - Teammates if WW/Seer                                         │
│  - Wolf target if Witch                                         │
│  - Scan result if Seer                                          │
│  - Other players' roles: HIDDEN until game end                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.6 Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `JWT_SECRET` | Yes (prod) | JWT signing secret |
| `ALLOWED_ORIGINS` | Yes (prod) | Comma-separated CORS origins |
| `PORT` | No | Server port (default: 8080) |
| `DB_MAX_CONNECTIONS` | No | Pool size (default: 25) |
| `DB_MAX_IDLE_CONNECTIONS` | No | Idle pool (default: 5) |
| `LOG_HEALTH` | No | Log health checks (default: false) |

---

## 5. Game Rules

### 5.1 Roles & Teams

#### Red Team (Tim Merah)
| Role | Emoji | Kemampuan |
|------|-------|-----------|
| **Werewolf** | 🐺 | Membunuh 1 pemain setiap malam. Bisa melihat sesama werewolf. |
| **Witch** | 🧙 | Punya 1x Heal (selamatkan korban wolf) dan 1x Poison (bunuh siapapun). Tahu target werewolf. |

#### Blue Team (Tim Biru)
| Role | Emoji | Kemampuan |
|------|-------|-----------|
| **Seer** | 🔮 | Mengintip 1 pemain per malam untuk tahu timnya (Red/Blue). Bisa melihat sesama Seer. |
| **Doctor** | 💉 | Melindungi 1 pemain dari serangan werewolf. Max 3x proteksi sepanjang game. Tidak bisa protect pemain sama berturut-turut. |
| **Villager** | 🧑‍🌾 | Tidak punya kemampuan khusus. Mengandalkan diskusi dan voting. |

### 5.2 Role Composition (Berdasarkan Jumlah Pemain)

| Players | Werewolf | Seer | Doctor | Witch | Villager |
|---------|----------|------|--------|-------|----------|
| 8 | 2 | 2 | 1 | 1 | 2 |
| 9 | 2 | 2 | 1 | 1 | 3 |
| 10 | 3 | 2 | 1 | 1 | 3 |
| 11 | 3 | 2 | 1 | 1 | 4 |
| 12 | 4 | 2 | 1 | 1 | 4 |
| 13 | 4 | 2 | 1 | 1 | 5 |
| 14 | 4 | 2 | 1 | 1 | 6 |
| 15 | 4 | 2 | 1 | 1 | 7 |
| 16 | 4 | 2 | 1 | 1 | 8 |
| 17 | 5 | 2 | 1 | 1 | 8 |
| 18 | 5 | 2 | 1 | 1 | 9 |

### 5.3 Game Flow

```
┌──────────────┐
│    LOBBY     │ ─── Pemain berkumpul, host start game
└──────┬───────┘
       ▼
┌──────────────┐
│ ROLE REVEAL  │ ─── Setiap pemain melihat role mereka
└──────┬───────┘
       ▼
┌──────────────────────────────────────────────────┐
│                    NIGHT PHASE                    │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │ WOLF_TURN  │→ │DOCTOR_TURN │→ │ WITCH_TURN │ │
│  │ Pilih      │  │ Lindungi   │  │ Heal/Poison│ │
│  │ korban     │  │ 1 pemain   │  │ atau skip  │ │
│  └────────────┘  └────────────┘  └────────────┘ │
│                         ↓                        │
│              ┌────────────────┐                  │
│              │   SEER_TURN    │                  │
│              │ Intip 1 pemain │                  │
│              └────────────────┘                  │
└──────────────────────┬───────────────────────────┘
                       ▼
              ┌────────────────┐
              │  NIGHT_RESOLVE │ ─── Hitung korban malam
              └────────┬───────┘
                       ▼
              ┌────────────────┐
              │   DAY_START    │ ─── Umumkan siapa yang mati
              └────────┬───────┘
                       ▼
              ┌────────────────┐
              │   DISCUSSION   │ ─── 60 detik diskusi + chat
              └────────┬───────┘
                       ▼
              ┌────────────────┐
              │    VOTING      │ ─── 30 detik voting
              └────────┬───────┘
                       ▼
               ┌──────┴──────┐
               │  Tie Vote?  │
               └──────┬──────┘
          No ──┘      └── Yes (max 2x retry)
          ▼                    ▼
    ┌──────────┐        ┌──────────┐
    │ TESTAMENT│        │ Re-vote  │
    │ 10 detik │        │ (hanya   │
    └────┬─────┘        │ tied)    │
         ▼              └──────────┘
    ┌──────────┐
    │Check Win │
    └────┬─────┘
   Yes ──┤
         ▼              No
    ┌──────────┐        │
    │ GAME_END │        │
    └──────────┘        │
                        ▼
                 [Kembali ke NIGHT]
```


### 5.4 Night Resolution Order

1. **Wolf Attack** → Target ditentukan oleh konsensus werewolf
2. **Doctor Protection** → Jika target = wolf target, korban diselamatkan
3. **Witch Heal** → Jika digunakan, korban wolf diselamatkan (1x per game)
4. **Witch Poison** → Jika digunakan, target tambahan mati (1x per game)

### 5.5 Win Conditions

| Kondisi | Pemenang |
|---------|----------|
| Semua Werewolf mati | **Blue Team** |
| Alive Werewolves >= Alive Blue Team | **Red Team** |

### 5.6 Special Rules

- **Testament:** Pemain yang mati bisa menulis pesan terakhir (max 200 karakter, 10 detik)
- **Tie Vote:** Jika voting seri, dilakukan re-vote hanya untuk pemain yang seri (max 2x)
- **Chat:** Chat aktif saat Discussion & Voting. Pemain mati bisa baca tapi tidak kirim.
- **Team Chat:** Werewolf dan Seer bisa chat dengan tim mereka saat malam

---

## 6. User Flow

### 6.1 Authentication Flow

```
┌─────────────┐
│   SPLASH    │ ─── Check saved token
└──────┬──────┘
       │
   ┌───┴───┐
   │Token? │
   └───┬───┘
  No   │   Yes
   │   │    │
   ▼   │    ▼
┌──────┴───┐  ┌────────────┐
│   AUTH   │  │GET /profile│
│  PAGE    │  └─────┬──────┘
└────┬─────┘        │
     │         ┌────┴────┐
     │         │Valid?   │
     │         └────┬────┘
     │        No    │   Yes
     │         │    │    │
     │         ▼    │    ▼
     │     ┌───────┐│┌────────────┐
     │     │LOGOUT │││  Profile   │
     │     └───┬───┘││  Complete? │
     │         │    │└─────┬──────┘
     │         ▼    │  No  │  Yes
     │     [AUTH]   │   │  │
     │              │   ▼  ▼
     │              │┌────────┐┌──────┐
     └──────────────┘│PROFILE ││ HOME │
                     │ SETUP  │└──────┘
                     └────────┘
```

### 6.2 Room & Game Flow

```
┌──────────────────────────────────────────────────────────────┐
│                         HOME PAGE                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │Quick Play│  │Buat Room │  │Join Room │  │  Wardrobe    │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │  Friends     │ │
│       │             │             │         │  Stats       │ │
│       │             │             │         │  Leaderboard │ │
│       │             │             │         │  Shop        │ │
│       ▼             ▼             ▼         └──────────────┘ │
└───────┬─────────────┬─────────────┬──────────────────────────┘
        │             │             │
        │     ┌───────┴───────┐     │
        │     │  WS: create   │     │
        │     │    _room      │     │
        │     └───────┬───────┘     │
        │             ▼             │
        │     ┌───────────────┐     │
        │     │    LOBBY      │◄────┘ WS: join_room
        │     │ (Room Code)   │
        │     │ Host: Start   │
        │     └───────┬───────┘
        │             │ WS: start_game
        │             ▼
        │     ┌───────────────┐
        └────►│     GAME      │
              │ (Game Loop)   │
              └───────┬───────┘
                      │ Game End
                      ▼
              ┌───────────────┐
              │   RESULTS     │
              │ - Winner      │
              │ - All Roles   │
              │ - XP/Coins    │
              └───────┬───────┘
                      │
                      ▼
              ┌───────────────┐
              │     HOME      │
              └───────────────┘
```


---

## 7. API Reference

### 7.1 Base URL
```
HTTP:  http://localhost:8080
WS:    ws://localhost:8080/ws
```

### 7.2 Authentication Endpoints

#### POST `/api/auth/register`
Registrasi akun baru.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "displayName": "PlayerName"
}
```

**Response (201):**
```json
{
  "accessToken": "jwt_access_token",
  "refreshToken": "jwt_refresh_token",
  "expiresIn": 900,
  "user": { "id": "uuid", "email": "user@example.com", "isGuest": false },
  "profile": { "userId": "uuid", "displayName": "PlayerName", "avatarId": 1, "coins": 100, "level": 1 }
}
```

#### POST `/api/auth/login`
Login dengan akun existing.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200):**
```json
{
  "accessToken": "jwt_access_token",
  "refreshToken": "jwt_refresh_token",
  "expiresIn": 900
}
```

#### POST `/api/auth/refresh`
Refresh access token menggunakan refresh token.

**Request Body:**
```json
{
  "refreshToken": "jwt_refresh_token"
}
```

**Response (200):**
```json
{
  "accessToken": "new_jwt_access_token",
  "refreshToken": "new_jwt_refresh_token",
  "expiresIn": 900
}
```

#### POST `/api/auth/logout`
Logout dan revoke refresh token.

**Headers:** `Authorization: Bearer <access_token>`

**Response (200):**
```json
{
  "message": "logged out"
}
```

#### POST `/api/auth/guest`
Login sebagai guest (tanpa email/password).

**Request Body:**
```json
{
  "displayName": "GuestPlayer"
}
```

### 7.3 Profile Endpoints

#### GET `/api/profile`
Ambil profile user (requires auth).

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "userId": "uuid",
  "displayName": "PlayerName",
  "avatarId": 1,
  "coins": 500,
  "level": 5,
  "xp": 2500,
  "gamesPlayed": 20,
  "gamesWon": 12
}
```

#### PUT `/api/profile`
Update profile (requires auth).

**Request Body:**
```json
{
  "displayName": "NewName",
  "avatarId": 5
}
```

### 7.4 Stats & Leaderboard Endpoints

#### GET `/api/stats`
Statistik detail pemain (requires auth).

**Response:**
```json
{
  "gamesPlayed": 50,
  "gamesWon": 30,
  "gamesAsWerewolf": 15,
  "gamesAsSeer": 10,
  "gamesAsDoctor": 8,
  "gamesAsWitch": 7,
  "gamesAsVillager": 10,
  "wolvesFound": 25,
  "playersProtected": 12,
  "poisonsUsed": 5,
  "healsUsed": 6,
  "totalKills": 20,
  "currentWinStreak": 3,
  "longestWinStreak": 7,
  "rating": 1250,
  "rankTier": "silver"
}
```

#### GET `/api/history?limit=20`
Riwayat pertandingan (requires auth).

#### GET `/api/leaderboard?sort=rating&limit=50`
Leaderboard publik.

**Query Params:**
- `sort`: `rating` | `xp` | `wins`
- `limit`: 1-100 (default 50)

### 7.5 Social Endpoints

#### GET `/api/friends`
Daftar teman & pending requests (requires auth).

#### POST `/api/friends`
Friend actions (requires auth).

**Request Body:**
```json
{
  "friendId": "user_uuid",
  "action": "add" | "accept" | "block" | "remove"
}
```

#### POST `/api/report`
Laporkan pemain (requires auth).

#### GET `/api/recent-players`
Pemain yang baru bermain bersama (requires auth).

### 7.6 Other Endpoints

| Endpoint | Method | Auth | Deskripsi |
|----------|--------|------|-----------|
| `/api/health` | GET | No | Server health check |
| `/api/achievements` | GET | Yes | Daftar achievement |
| `/api/rank` | GET | Yes | Info ranking & season |
| `/api/inventory` | GET/POST | Yes | Inventory & equip items |
| `/api/flags` | GET | No | Feature flags |


---

## 8. WebSocket Events

### 8.1 Connection
```
ws://localhost:8080/ws?token=<jwt_token>
```

### 8.2 Client → Server Messages

| Type | Payload | Deskripsi |
|------|---------|-----------|
| `create_room` | `{ userId, maxPlayers }` | Buat room baru |
| `join_room` | `{ userId, roomCode }` | Join room dengan kode |
| `leave_room` | `{ userId, roomId }` | Keluar dari room |
| `player_ready` | `{ userId, roomId }` | Tandai siap |
| `start_game` | `{ roomId, hostId }` | Mulai game (host only) |
| `confirm_role_reveal` | `{ playerId }` | Konfirmasi lihat role |
| `submit_night_action` | `{ playerId, targetId }` | Aksi malam (wolf/seer/doctor) |
| `submit_witch_action` | `{ playerId, useHeal, poisonTarget }` | Aksi witch |
| `cast_vote` | `{ voterId, targetId }` | Vote eliminasi |
| `submit_testament` | `{ playerId, message }` | Kirim wasiat |
| `send_chat` | `{ senderId, content }` | Chat umum |
| `team_chat` | `{ senderId, content }` | Chat tim (wolf/seer) |
| `send_emote` | `{ playerId, emoteId }` | Kirim emote |
| `kick_player` | `{ roomId, targetUserId }` | Kick pemain (host) |
| `invite_to_room` | `{ targetUserId, roomCode }` | Undang teman |
| `update_room_settings` | `{ roomId, settings }` | Update settings (host) |
| `reconnect_game` | `{}` | Reconnect ke game aktif |
| `ping` | `{}` | Keep-alive |

### 8.3 Server → Client Messages

| Type | Payload | Deskripsi |
|------|---------|-----------|
| `room_created` | `{ roomId, roomCode, userId, hostId, players }` | Room berhasil dibuat |
| `room_joined` | `{ roomId, roomCode, userId, hostId, players }` | Berhasil join room |
| `room_updated` | `{ roomId, players }` | Update daftar pemain |
| `player_joined` | `{ userId, displayName, avatarId }` | Pemain baru masuk |
| `player_left` | `{ userId }` | Pemain keluar |
| `game_countdown` | `{ seconds }` | Countdown sebelum game |
| `game_state_update` | `{ ...gameState }` | Update state game (filtered per player) |
| `game_started` | `{ gameState }` | Game dimulai |
| `game_resumed` | `{ roomId, roomCode, gameState }` | Reconnect berhasil |
| `game_ended` | `{ winner }` | Game selesai |
| `chat_message` | `{ senderId, content }` | Pesan chat masuk |
| `team_chat_message` | `{ senderId, content, team }` | Pesan tim masuk |
| `emote_received` | `{ playerId, emoteId }` | Emote dari pemain |
| `game_invite` | `{ fromUserId, roomCode }` | Undangan game |
| `kicked` | `{ reason }` | Dikick dari room |
| `room_closed` | `{ reason }` | Room ditutup |
| `error` | `{ message }` | Error message |
| `pong` | `{}` | Response to ping |

### 8.4 Game State Structure (Filtered per Player)

```json
{
  "id": "game_uuid",
  "phase": "WOLF_TURN",
  "round": 2,
  "config": {
    "minPlayers": 8,
    "maxPlayers": 18,
    "timerDuration": { "discussion": 60, "voting": 30, "nightAction": 30, "testament": 10 },
    "hostId": "host_uuid"
  },
  "players": [
    {
      "id": "player_uuid",
      "name": "PlayerName",
      "avatar": "boy",
      "isBot": false,
      "role": "werewolf",  // Only visible for self or revealed
      "isAlive": true,
      "isConnected": true,
      "doctorProtectsUsed": 0
    }
  ],
  "nightActions": {
    "wolfTarget": "victim_id",       // Visible to witch
    "wolfVotes": { "wolf1": "target" },
    "seerTarget": "target_id",
    "seerResult": "red",             // Visible to seer only
    "doctorTarget": null,
    "witchAction": null,
    "currentTurn": "werewolf"
  },
  "votes": {
    "votes": { "voter1": "target1" },
    "round": 2,
    "isRetry": false,
    "tiedPlayers": null
  },
  "eliminationHistory": [
    { "playerId": "id", "round": 1, "phase": "night", "role": "villager" }
  ],
  "winner": null,
  "timerDeadline": 1719900000000,
  "testaments": [],
  "pendingTestamentPlayerId": null,
  "teammates": [
    { "id": "teammate_id", "name": "WolfFriend", "role": "werewolf" }
  ]
}
```

---

## 9. Database Schema

### 9.1 Core Tables

#### `users`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | User ID |
| email | TEXT (UNIQUE) | User email |
| password_hash | TEXT | Bcrypt hashed password |
| is_guest | BOOLEAN | Guest account flag |
| created_at | TIMESTAMPTZ | Registration time |

#### `profiles`
| Column | Type | Description |
|--------|------|-------------|
| user_id | UUID (PK, FK) | References users.id |
| display_name | TEXT | Player display name |
| avatar_id | INTEGER (1-12) | Selected avatar |
| coins | BIGINT | In-game currency |
| level | INTEGER | Player level |
| xp | BIGINT | Experience points |
| games_played | INTEGER | Total games |
| games_won | INTEGER | Games won |

#### `player_stats`
| Column | Type | Description |
|--------|------|-------------|
| user_id | UUID (PK, FK) | References users.id |
| games_as_werewolf | INTEGER | Games played as werewolf |
| games_as_seer | INTEGER | Games played as seer |
| games_as_doctor | INTEGER | Games played as doctor |
| games_as_witch | INTEGER | Games played as witch |
| games_as_villager | INTEGER | Games played as villager |
| wolves_found | INTEGER | Wolves identified (seer) |
| players_protected | INTEGER | Saves made (doctor) |
| poisons_used | INTEGER | Poison uses (witch) |
| heals_used | INTEGER | Heal uses (witch) |
| total_kills | INTEGER | Kills as werewolf |
| current_win_streak | INTEGER | Current streak |
| longest_win_streak | INTEGER | Best streak |
| rating | INTEGER | ELO rating (default 1000) |
| rank_tier | VARCHAR(20) | bronze/silver/gold/platinum/diamond |

#### `match_history`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Match record ID |
| user_id | UUID (FK) | Player |
| match_id | TEXT | Game ID |
| played_at | TIMESTAMPTZ | Match time |
| duration_sec | INTEGER | Game duration |
| total_rounds | INTEGER | Number of rounds |
| role | VARCHAR(20) | Role played |
| team | VARCHAR(10) | red/blue |
| won | BOOLEAN | Did player's team win |
| survived | BOOLEAN | Was player alive at end |
| xp_earned | INTEGER | XP gained |
| coins_earned | INTEGER | Coins gained |
| player_count | INTEGER | Players in match |

### 9.2 Game Tables

#### `game_rooms`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Room ID |
| code | VARCHAR(6) | 6-char room code |
| host_id | UUID (FK) | Host user |
| status | VARCHAR(20) | waiting/playing/finished |
| config | JSONB | Room configuration |
| max_players | INTEGER (8-16) | Max players allowed |
| current_players | INTEGER | Current count |

#### `room_players`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Record ID |
| room_id | UUID (FK) | Room reference |
| user_id | UUID (FK) | Player reference |
| slot | INTEGER | Seat number |
| is_ready | BOOLEAN | Ready status |

### 9.3 Social Tables

#### `friendships`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Record ID |
| user_id | UUID (FK) | Requester |
| friend_id | UUID (FK) | Target user |
| status | VARCHAR(20) | pending/accepted/blocked |

#### `reports`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Report ID |
| reporter_id | UUID (FK) | Who reported |
| reported_id | UUID (FK) | Who was reported |
| reason | VARCHAR(50) | Report reason |
| details | TEXT | Additional info |
| match_id | TEXT | Related match |
| status | VARCHAR(20) | pending/reviewed/actioned/dismissed |

### 9.4 Economy Tables

#### `shop_items`
| Column | Type | Description |
|--------|------|-------------|
| id | VARCHAR(50) (PK) | Item ID |
| name | TEXT | Item name |
| description | TEXT | Item description |
| emoji | VARCHAR(10) | Display emoji |
| category | VARCHAR(30) | borders/emotes/themes |
| price | INTEGER | Cost in coins |
| is_active | BOOLEAN | Available for purchase |

#### `user_purchases`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Purchase ID |
| user_id | UUID (FK) | Buyer |
| item_id | VARCHAR(50) (FK) | Item purchased |
| purchased_at | TIMESTAMPTZ | Purchase time |

#### `equipped_items`
| Column | Type | Description |
|--------|------|-------------|
| user_id | UUID (PK, FK) | User |
| frame_id | VARCHAR(50) | Equipped border |
| emote_set_id | VARCHAR(50) | Equipped emote set |
| theme_id | VARCHAR(50) | Equipped theme |

### 9.5 Engagement Tables

#### `player_achievements`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Record ID |
| user_id | UUID (FK) | Player |
| achievement_id | VARCHAR(50) | Achievement unlocked |
| unlocked_at | TIMESTAMPTZ | Unlock time |

#### `daily_missions`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Mission ID |
| user_id | UUID (FK) | Player |
| mission_type | VARCHAR(50) | Mission type |
| title | TEXT | Mission title |
| target | INTEGER | Goal amount |
| progress | INTEGER | Current progress |
| reward_coins | INTEGER | Coin reward |
| reward_xp | INTEGER | XP reward |
| completed | BOOLEAN | Completion status |
| assigned_at | DATE | Assignment date |

#### `notifications`
| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Notification ID |
| user_id | UUID (FK) | Recipient |
| type | VARCHAR(30) | Notification type |
| title | TEXT | Title |
| body | TEXT | Content |
| is_read | BOOLEAN | Read status |

### 9.6 Admin Tables

| Table | Purpose |
|-------|---------|
| `seasons` | Season info (start/end dates) |
| `season_history` | Player rank per season |
| `match_events` | Detailed game action log |
| `game_rounds` | Round summary per match |
| `chat_logs` | Chat history for moderation |
| `audit_logs` | Admin action log |
| `penalties` | User penalties (mute/ban) |
| `server_settings` | Server configuration |
| `feature_flags` | Feature toggles |


---

## 10. Flutter Architecture

### 10.1 Project Structure

```
apps/mobile/lib/
├── core/
│   ├── config.dart         # API_URL, WS_URL configuration
│   ├── constants.dart      # App constants
│   ├── router.dart         # GoRouter routes & redirects
│   └── theme.dart          # AppColors, gradients, styles
│
├── models/
│   ├── game_state.dart     # GameState, GamePhase, NightActions, VoteRecord
│   ├── player.dart         # Role, Team, Player, PlayerState
│   ├── room.dart           # GameRoom, RoomPlayer, UserProfile
│   ├── game_config.dart    # TimerConfig, GameConfig
│   └── ws_message.dart     # WebSocket message types
│
├── providers/
│   ├── auth_provider.dart  # AuthState, AuthNotifier (login/register/logout)
│   ├── room_provider.dart  # RoomState, RoomNotifier (create/join/leave)
│   ├── game_provider.dart  # GameNotifier (game actions)
│   ├── chibi_provider.dart # Character customization state
│   └── outfit_provider.dart# Outfit/wardrobe state
│
├── services/
│   ├── api_service.dart    # HTTP client for REST API
│   ├── websocket_service.dart # WebSocket client
│   └── audio_service.dart  # BGM & SFX player
│
├── pages/
│   ├── splash/             # Splash screen
│   ├── auth/               # Login, Register, Guest
│   ├── profile/            # Profile setup & view
│   ├── home/               # Main menu
│   ├── room/               # Room creation/join
│   ├── lobby/              # Pre-game lobby
│   ├── game/               # Main game screen
│   ├── results/            # Game results
│   ├── stats/              # Player statistics
│   ├── leaderboard/        # Rankings
│   ├── friends/            # Friends list
│   ├── shop/               # Coin store
│   ├── wardrobe/           # Character customization
│   ├── settings/           # App settings
│   └── main_shell.dart     # Bottom navigation shell
│
├── widgets/
│   ├── error_boundary.dart  # Error handling widgets
│   ├── accessible_button.dart # Accessibility widgets
│   ├── chibi_avatar.dart   # Animated character widget
│   ├── daily_missions.dart # Mission card widget
│   ├── notification_bell.dart # Notification indicator
│   └── gradient_button.dart # Styled button
│
└── main.dart               # App entry point
```

### 10.2 State Management (Riverpod)

```dart
// Providers hierarchy
apiServiceProvider      → ApiService (singleton)
webSocketProvider       → WebSocketService (singleton)
authProvider           → AuthNotifier (auth state)
roomProvider           → RoomNotifier (room/lobby state)
gameProvider           → GameNotifier (game state)
chibiProvider          → ChibiConfig (avatar customization)
outfitProvider         → Outfit (equipped items)
audioServiceProvider   → AudioService (music/sfx)
```

### 10.3 Optimized Selectors (Performance)

```dart
// Game provider exposes 15+ optimized selectors to reduce rebuilds:
currentPhaseProvider      // GamePhase only
currentRoundProvider      // Round number only
timerDeadlineProvider     // Timer deadline only
alivePlayersProvider      // Alive player list
myPlayerProvider          // Current player state
myRoleProvider            // Current player's role
myTeammatesProvider       // Teammates (WW/Seer)
wolfTargetProvider        // Wolf's current target
seerResultProvider        // Seer scan result
votesProvider             // Current vote tally
nightActionsProvider      // Night actions state
isMyTurnProvider          // Is it my turn?
canActProvider            // Can I perform action?
gameWinnerProvider        // Winner (if game ended)
eliminationHistoryProvider // Death log
```

### 10.4 Navigation Routes

| Route | Page | Auth Required |
|-------|------|---------------|
| `/splash` | SplashPage | No |
| `/auth` | AuthPage | No |
| `/profile/setup` | ProfileSetupPage | Yes |
| `/home` | MainShell (HomePage) | Yes |
| `/room` | RoomPage | Yes |
| `/lobby/:roomCode` | LobbyPage | Yes |
| `/game/:gameId` | GamePage | Yes |
| `/results/:gameId` | ResultsPage | Yes |
| `/stats` | StatsPage | Yes |
| `/leaderboard` | LeaderboardPage | Yes |
| `/profile` | ProfilePage | Yes |
| `/friends` | FriendsPage | Yes |
| `/shop` | ShopPage | Yes |
| `/wardrobe` | WardrobePage | Yes |
| `/settings` | SettingsPage | Yes |

### 10.5 Game Page Widgets

| Phase | Widget | Description |
|-------|--------|-------------|
| `ROLE_REVEAL` | `_RoleRevealScreen` | Show role + confirm button |
| `NIGHT_*` | `_NightScreen` | Player grid + role action panel |
| `DAY_START` | `_MorningScreen` | Death announcement |
| `DISCUSSION` | `_DiscussionScreen` | Player grid + chat |
| `VOTING` | `_VotingScreen` | Tappable player grid + vote count |
| `TESTAMENT` | `_TestamentScreen` | Testament input/display |
| `GAME_END` | `_GameEndScreen` | Winner + rewards + countdown |

### 10.6 Key Components

#### `_PlayerGrid18`
Reusable 18-seat grid layout (5-4-4-5 rows) used across all game screens.

#### `_GameSeatCard`
Individual player seat showing avatar, name, role (if visible), death status.

#### `_TopBar`
Game header with phase indicator, live timer countdown, player count.

#### `_SwipeableChatPanel`
Night phase chat with tabs for Room Chat (disabled) and Team Chat (werewolf/seer).

#### `_WitchActionPanel`
Special panel for witch showing wolf target + heal/poison/skip options.


### 10.7 Accessibility Widgets

| Widget | Purpose |
|--------|---------|
| `AccessibleButton` | Button with semantic label & min touch target |
| `AccessibleIconButton` | Icon button with tooltip & 48px touch target |
| `AccessibleCard` | Tappable card with selection state |
| `AccessibleText` | Text with heading semantics support |
| `AccessibleAvatar` | Player avatar with status announcements |
| `GameSemantics` | Generic semantic wrapper for game elements |

### 10.8 Error Handling Widgets

| Widget | Purpose |
|--------|---------|
| `ErrorBoundary` | Catches and displays errors gracefully |
| `LoadingWidget` | Consistent loading indicator |
| `EmptyStateWidget` | Empty state with action button |
| `ShimmerPlaceholder` | Loading skeleton animation |


---

## 11. Features

### 11.1 Implemented Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Secure Token Storage** | ✅ | FlutterSecureStorage for JWT |
| **Token Refresh** | ✅ | Auto-refresh with rotation |
| **Input Validation** | ✅ | UUID, email, action validation |
| **Rate Limiting** | ✅ | Per-IP rate limits |
| **Request Logging** | ✅ | Structured logging with request ID |
| **Auth System** | ✅ | Register, Login, Guest mode |
| **Profile** | ✅ | Display name, Avatar selection (12 avatars) |
| **Room System** | ✅ | Create room, Join with code, Leave room |
| **Lobby** | ✅ | Player list, Ready status, Host controls |
| **Game Engine** | ✅ | Full Red vs Blue logic |
| **Night Phase** | ✅ | Sequential turns (Wolf→Doctor→Witch→Seer) |
| **Day Phase** | ✅ | Discussion + Voting + Testament |
| **Timer System** | ✅ | Server-side auto-advance |
| **State Filtering** | ✅ | Each player only sees their role |
| **Team Chat** | ✅ | Werewolf & Seer team communication |
| **Testament** | ✅ | Last words for eliminated players |
| **Tie-break Voting** | ✅ | Re-vote for tied players (max 2x) |
| **Bot Fill** | ✅ | Auto-fill with AI bots to 18 players |
| **Results Page** | ✅ | Winner, all roles revealed, rewards |
| **Stats Page** | ✅ | Detailed player statistics |
| **Leaderboard** | ✅ | Public ranking by rating/XP/wins |
| **Match History** | ✅ | Past game records |
| **Achievements** | ✅ | Unlockable achievements |
| **Friends System** | ✅ | Add/remove friends, pending requests |
| **Shop** | ✅ | Buy borders, emotes, themes with coins |
| **Wardrobe** | ✅ | Equip purchased items |
| **Audio System** | ✅ | BGM for phases, SFX |
| **Phase Animations** | ✅ | Transition overlays |
| **Death Announcement** | ✅ | Visual death overlay |
| **Doctor Protect Counter** | ✅ | Shows remaining protects (3 max) |
| **Seer Result Display** | ✅ | Shows team (Red/Blue) of scanned player |
| **Reconnection** | ✅ | Rejoin active game after disconnect |

### 11.2 Assets

#### Avatars (12 total)
Located in `assets/avatars/`:
- boy.jpg, boyS.jpg, girl.jpg, girlS.jpg
- (and 8 more variants)

#### Backgrounds
| File | Usage |
|------|-------|
| `beranda.png` | Home page |
| `malam.png` | Night phase |
| `siang.png` | Day phase |
| `login-bg.png` | Auth page |

#### Audio
| Folder | Content |
|--------|---------|
| `assets/audio/bgm/` | Background music per phase |
| `assets/audio/sfx/` | Sound effects |

### 11.3 UI Theme

- **Style:** Dark medieval theme
- **Primary Color:** Golden (#F59E0B)
- **Red Team Color:** #EF4444
- **Blue Team Color:** #3B82F6
- **Background:** Dark gradients (#080D1A → #1E1B4B)
- **Cards:** Semi-transparent with blur effect

---

## 12. Testing

### 12.1 Go Backend Tests

```bash
cd backend/go-server
go test ./... -v
```

| Package | Test Count | Coverage |
|---------|------------|----------|
| `internal/auth` | 5 tests | JWT generation, validation, refresh |
| `internal/api` | 12 tests | Handlers, middleware, validation |
| `internal/game` | 10 tests | Game engine, roles, phases |
| **Integration** | 6 test suites | Auth flow, profile, guest, social, report |

#### Integration Test Suites

| Suite | Tests | Description |
|-------|-------|-------------|
| `TestAuthFlow_RegisterLoginRefresh` | 6 | Full auth cycle with token rotation |
| `TestAuthFlow_InvalidCredentials` | 4 | Wrong password, missing token |
| `TestProfileFlow_UpdateAndRetrieve` | 3 | Profile CRUD |
| `TestGuestFlow` | 2 | Guest creation and access |
| `TestSocialFlow_FriendsValidation` | 2 | Friend request validation |
| `TestReportFlow_Validation` | 3 | Report input validation |

### 12.2 Flutter Tests

```bash
cd apps/mobile
flutter test
```

| Test Type | Location | Count |
|-----------|----------|-------|
| **Provider Tests** | `test/providers/` | 16 tests |
| **Service Tests** | `test/services/` | 8 tests |
| **Widget Tests** | `test/widgets/` | 25 tests |

#### Widget Test Coverage

| Widget | Tests | Description |
|--------|-------|-------------|
| `ErrorBoundary` | 3 | Error catching, loading states |
| `LoadingWidget` | 2 | Message display, fullscreen mode |
| `EmptyStateWidget` | 3 | Message, icon, action button |
| `ShimmerPlaceholder` | 2 | Dimensions, animation |
| `AccessibleButton` | 4 | Semantics, disabled state, tap |
| `AccessibleIconButton` | 3 | Icon, tooltip, touch target |
| `AccessibleCard` | 3 | Content, tap, selection |
| `AccessibleText` | 2 | Render, heading semantics |
| `AccessibleAvatar` | 3 | Fallback, name, eliminated |

### 12.3 Running All Tests

```bash
# Backend
cd backend/go-server && go test ./... -v -cover

# Frontend
cd apps/mobile && flutter test --coverage

# Integration (requires running server)
cd backend/go-server && go test ./internal/api/... -v -run Integration
```

---

## 13. How to Run

### 13.1 Prerequisites

- **Flutter:** 3.11+
- **Go:** 1.21+
- **PostgreSQL:** 14+
- **Android Studio / Xcode** (for mobile builds)

### 13.2 Database Setup

```bash
# Create database
createdb ggs_werewolf

# Run migrations
psql -d ggs_werewolf -f backend/go-server/migrations/001_init.sql
```

### 13.3 Backend Setup

```bash
cd backend/go-server

# Set environment variable
export DATABASE_URL="postgres://postgres:postgres@localhost:5433/ggs_werewolf?sslmode=disable"

# Run server
go run cmd/server/main.go
```

Server akan berjalan di `http://localhost:8080`

### 13.4 Flutter Setup

```bash
cd apps/mobile

# Get dependencies
flutter pub get

# Run on emulator/simulator
flutter run

# Run on physical device (ganti IP sesuai komputer)
flutter run --dart-define=API_URL=http://192.168.x.x:8080 --dart-define=WS_URL=ws://192.168.x.x:8080/ws
```

### 13.5 Build APK

```bash
cd apps/mobile

# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 13.6 Environment Variables

#### Backend
| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 8080 | Server port |
| `DATABASE_URL` | localhost:5433 | PostgreSQL connection string |

#### Flutter (dart-define)
| Variable | Default | Description |
|----------|---------|-------------|
| `API_URL` | http://localhost:8080 | Backend HTTP URL |
| `WS_URL` | ws://localhost:8080/ws | Backend WebSocket URL |

---

## 14. Appendix

### 14.1 Error Codes

| Code | Message | Cause |
|------|---------|-------|
| 400 | "invalid body" | Malformed JSON request |
| 400 | "invalid uuid format" | Invalid ID format |
| 400 | "invalid action" | Unknown action type |
| 400 | "cannot target self" | Self-targeting prevented |
| 401 | "missing authorization" | No Bearer token |
| 401 | "invalid token" | Expired/invalid JWT |
| 401 | "refresh token expired" | Refresh token invalid |
| 404 | "profile not found" | User has no profile |
| 409 | "email already exists" | Duplicate registration |
| 429 | "rate limit exceeded" | Too many requests |

### 14.2 Game Phase Constants

```go
PhaseLobby        = "LOBBY"
PhaseRoleReveal   = "ROLE_REVEAL"
PhaseNightStart   = "NIGHT_START"
PhaseWolfTurn     = "WOLF_TURN"
PhaseDoctorTurn   = "DOCTOR_TURN"
PhaseWitchTurn    = "WITCH_TURN"
PhaseSeerTurn     = "SEER_TURN"
PhaseNightResolve = "NIGHT_RESOLVE"
PhaseDayStart     = "DAY_START"
PhaseDiscussion   = "DISCUSSION"
PhaseVoting       = "VOTING"
PhaseTestament    = "TESTAMENT"
PhaseGameEnd      = "GAME_END"
```

### 14.3 Timer Durations (Default)

| Phase | Duration |
|-------|----------|
| Discussion | 60 seconds |
| Voting | 30 seconds |
| Night Action | 30 seconds |
| Testament | 10 seconds |
| Role Reveal | 15 seconds |
| Day Start | 5 seconds |

---

**Document Version:** 2.1  
**Last Updated:** July 2026  
**Maintainer:** GGS Development Team
