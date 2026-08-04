# GGS Werewolf — Developer Convenience Makefile

.PHONY: setup dev-db dev-backend dev-flutter lint-go lint-flutter test-go test-flutter clean help

help:
	@echo "GGS Werewolf — Available Commands"
	@echo "  make setup         — First-time setup (.env, DB, migrations)"
	@echo "  make dev-db        — Start PostgreSQL via docker-compose"
	@echo "  make dev-backend   — Run Go backend (requires .env)"
	@echo "  make dev-flutter   — Run Flutter app on Android emulator"
	@echo "  make lint-go       — Run go vet on backend"
	@echo "  make lint-flutter  — Run flutter analyze"
	@echo "  make test-go       — Run Go tests with race detector"
	@echo "  make test-flutter  — Run Flutter widget/unit tests"
	@echo "  make clean         — Remove build artifacts"

setup:
	@echo "▶ Setting up GGS Werewolf development environment..."
	@if [ ! -f .env ]; then cp .env.example .env && echo "  ✅ .env created — edit it with your values"; else echo "  ℹ  .env already exists"; fi
	@mkdir -p nginx/certs
	@echo "  ✅ nginx/certs directory ready"
	@echo ""
	@echo "  Next steps:"
	@echo "  1. Edit .env with your secrets"
	@echo "  2. Run 'make dev-db' to start PostgreSQL"
	@echo "  3. Run 'make dev-backend' to start the Go server"
	@echo "  4. Run 'make dev-flutter' to run the Flutter app"

dev-db:
	@echo "▶ Starting PostgreSQL..."
	docker-compose up db -d
	@echo "  ✅ PostgreSQL running on localhost:5432"

dev-backend:
	@if [ ! -f .env ]; then echo "❌ .env not found — run 'make setup' first"; exit 1; fi
	@echo "▶ Starting Go backend..."
	cd backend/go-server && export $$(grep -v '^#' ../../.env | xargs) && go run cmd/server/main.go

dev-flutter:
	@echo "▶ Running Flutter app..."
	cd apps/mobile && flutter run --dart-define=API_URL=http://10.0.2.2:8080 --dart-define=WS_URL=ws://10.0.2.2:8080/ws

lint-go:
	@echo "▶ Running Go vet..."
	cd backend/go-server && go vet ./...
	@echo "  ✅ Go lint passed"

lint-flutter:
	@echo "▶ Running Flutter analyze..."
	cd apps/mobile && flutter analyze --no-fatal-infos
	@echo "  ✅ Flutter analyze done"

test-go:
	@echo "▶ Running Go tests..."
	cd backend/go-server && go test -race -count=1 ./...

test-flutter:
	@echo "▶ Running Flutter tests..."
	cd apps/mobile && flutter test

clean:
	@echo "▶ Cleaning build artifacts..."
	cd backend/go-server && go clean ./...
	cd apps/mobile && flutter clean
	@echo "  ✅ Clean done"
