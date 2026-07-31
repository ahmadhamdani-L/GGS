# GGS (Ganteng Ganteng Serigala)

Permainan deduksi sosial bergaya werewolf/mafia untuk Web, Android, dan iOS.

## Tech Stack

- **Monorepo:** Turborepo + pnpm workspaces
- **Frontend:** React + TypeScript + Vite
- **State:** Zustand
- **Animasi:** Lottie + Framer Motion
- **Audio:** Howler.js
- **Testing:** Vitest + fast-check

## Struktur Proyek

```
ggs/
├── apps/
│   └── web/                  # React web app
├── packages/
│   ├── shared-types/         # TypeScript interfaces & types
│   ├── game-engine/          # Core game logic
│   ├── ai-engine/            # Bot AI logic
│   ├── animation-assets/     # Lottie animation files
│   └── config/               # Shared tsconfig & ESLint
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

## Getting Started

```bash
# Install dependencies
pnpm install

# Run development
pnpm dev

# Build all packages
pnpm build

# Run tests
pnpm test

# Lint
pnpm lint
```

## Fase Pengembangan

1. **Fase 1 (MVP):** Game engine, web UI, multiplayer lokal, bot AI
2. **Fase 2:** Multiplayer online, WebSocket, autentikasi
3. **Fase 3:** Mobile apps, ranking, replay
4. **Fase 4:** Monetisasi, scale

## License

Private - All rights reserved.
