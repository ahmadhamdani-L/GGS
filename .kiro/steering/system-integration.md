# GGS Werewolf — System Integration Map

This steering file documents all endpoints, features, game logic, business logic, and frontend-backend integration status for the GGS Werewolf Red vs Blue application.

## Quick Reference

- **Backend**: Go (net/http + gorilla/websocket) on port 8080
- **Frontend**: Flutter (Riverpod + GoRouter) — Android + iOS
- **Database**: PostgreSQL with in-memory fallback
- **Auth**: JWT (access 15min + refresh 7 days) with bcrypt
- **Realtime**: WebSocket with token-bucket rate limiting
- **Config**: `apps/mobile/lib/core/config.dart` for API/WS URLs

## Architecture Rules

1. Every REST endpoint in `backend/go-server/cmd/server/main.go` must have a corresponding method in `apps/mobile/lib/services/api_service.dart`
2. Every WebSocket message type in `internal/ws/hub.go` → `handleMessage()` must have a corresponding handler in the Flutter provider (`room_provider.dart` or `game_provider.dart`)
3. Game state is always filtered per-player before broadcast (see `internal/game/filter.go`)
4. All DB operations go through `internal/db/` package — never raw SQL in handlers
5. Rate limiting is applied at the route level in main.go via token-bucket middleware
