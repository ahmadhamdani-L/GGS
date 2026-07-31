---
inclusion: always
---

# GGS Revamp Plan - Werewolf Red vs Blue Edition (v2 - Flutter + Go)

## ARCHITECTURE (CURRENT)

```
/ggs/
├── apps/mobile/              ← Flutter (Android + iOS)
│   ├── lib/
│   │   ├── core/            (config, theme, router, constants)
│   │   ├── models/          (game_state, player, room, ws_message, game_config)
│   │   ├── providers/       (auth, game, room — Riverpod)
│   │   ├── pages/           (auth, profile, home, lobby, game)
│   │   └── services/        (api_service, websocket_service)
│   └── assets/              (avatars 1-12, malam.png, siang.png, beranda.png, audio)
├── backend/go-server/        ← Go backend
│   ├── cmd/server/          (entry point)
│   ├── internal/
│   │   ├── auth/            (JWT)
│   │   ├── api/             (REST handlers)
│   │   ├── db/              (PostgreSQL — users, profiles, stats, leaderboard, match_history)
│   │   ├── game/            (game engine — state machine, roles, voting, win conditions)
│   │   └── ws/              (WebSocket hub, rooms, realtime game)
│   └── migrations/          (001_init.sql)
├── packages/                 ← TypeScript reference (game-engine, ai-engine, shared-types)
└── GGS/                      ← Original avatar source images
```

## CONFIRMED STACK
- **Frontend**: Flutter (Riverpod, GoRouter)
- **Backend**: Go (net/http, gorilla/websocket, lib/pq)
- **Database**: PostgreSQL
- **Auth**: JWT (bcrypt passwords)
- **Realtime**: WebSocket (Go hub → Flutter client)
- **Platforms**: Android + iOS only

## API ENDPOINTS
- POST `/api/auth/register` — email, password, displayName
- POST `/api/auth/login` — email, password
- POST `/api/auth/guest` — displayName
- GET|PUT `/api/profile` — profile CRUD (auth required)
- GET `/api/stats` — player statistics (auth required)
- GET `/api/history?limit=20` — match history (auth required)
- GET `/api/leaderboard?sort=rating&limit=50` — public leaderboard
- GET `/api/health` — server health + db status
- WS `/ws?token=<jwt>` — realtime game WebSocket

## GAME RULES (Red vs Blue Edition)
- 🔴 Red Team: Werewolf + Witch
- 🔵 Blue Team: Seer + Doctor + Villager
- Night order: Wolf → Doctor → Witch → Seer
- Win: Red if alive_werewolves >= alive_blue; Blue if all wolves dead
- 8-16 players, compositions in game engine
- Testament system for dying players
- Direct click voting (no popup)

## UI DESIGN
- Dark medieval theme, golden accents
- beranda.png → Home page background
- malam.png → Night phase background
- siang.png → Day phase background
- login-bg.png → Auth page background
- 12 avatar images
- Semi-transparent cards over backgrounds

## DATABASE
PostgreSQL tables: users, profiles, game_rooms, room_players, player_stats, match_history, leaderboard
Schema: `backend/go-server/migrations/001_init.sql`

## HOW TO RUN
```bash
# 1. Database setup
createdb ggs_werewolf
psql -d ggs_werewolf -f backend/go-server/migrations/001_init.sql

# 2. Go backend
cd backend/go-server
DATABASE_URL=postgres://postgres:postgres@localhost:5433/ggs_werewolf?sslmode=disable go run cmd/server/main.go

# 3. Flutter
cd apps/mobile
flutter run

# For physical device:
flutter run --dart-define=API_URL=http://192.168.x.x:8080 --dart-define=WS_URL=ws://192.168.x.x:8080/ws
```
