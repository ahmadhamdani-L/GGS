# Rencana Implementasi: GGS Red vs Blue Edition

## Ikhtisar

Implementasi GGS Werewolf Red vs Blue Edition dengan Supabase backend. Mencakup auth, profil, room system, lobby, game engine (5 roles, 2 teams), multiplayer realtime, single player vs AI, dark medieval UI, dan testament system.

Tech stack: Turborepo + pnpm, React + TypeScript + Vite, Supabase (Auth/DB/Realtime), Zustand, packages/game-engine, packages/ai-engine.

## Tasks

- [x] 1. Setup Avatars + Supabase Client
  - [x] 1.1 Copy avatar files dan setup Supabase client
    - Copy 7 avatar files dari /GGS/ ke apps/web/public/avatars/avatar-{1-7}.png
    - Create apps/web/src/lib/supabase.ts (createClient with VITE_SUPABASE_URL dan VITE_SUPABASE_ANON_KEY)
    - Install @supabase/supabase-js di apps/web
    - Verify .env sudah ada dan .gitignore mencakup .env
    - _Persyaratan: P1, P8_

- [ ] 2. Auth System
  - [ ] 2.1 Implementasi auth store dan pages
    - Create apps/web/src/stores/authStore.ts (Zustand: user, profile, session, loading, login, logout, signup, loginAsGuest, fetchProfile)
    - Create apps/web/src/pages/AuthPage.tsx (login/register tabs, email+password fields, guest button)
    - Create apps/web/src/components/auth/ProtectedRoute.tsx (redirect ke /auth jika belum login)
    - Update App.tsx routing: /auth public, semua route lain butuh auth
    - _Persyaratan: P1.1, P1.2, P1.3, P1.6, P1.7_

- [ ] 3. Profile System
  - [ ] 3.1 Implementasi profile setup
    - Create apps/web/src/pages/ProfileSetupPage.tsx (avatar grid 7 images + display name input + save button)
    - Setelah first login, jika belum punya display_name → redirect ke /profile/setup
    - Create ProfileCard component (avatar + name + level) untuk reuse di Home dan Lobby
    - _Persyaratan: P1.4, P1.5_

- [ ] 4. Home Page
  - [ ] 4.1 Implementasi home page dengan dark medieval theme
    - Create apps/web/src/pages/HomePage.tsx
    - Player info card top (avatar + name + level + coins dari profile)
    - Big buttons: Quick Play, Create Room, Join Room (input 6-char code), Friends (coming soon badge)
    - Bottom: Settings gear icon
    - Full dark medieval background (CSS gradient + forest silhouette SVG)
    - Apply color palette: bg #0a1628, surface #1a2744, primary #f59e0b (gold)
    - _Persyaratan: P11.1, P11.3, P11.4_

- [ ] 5. Room System (Supabase Realtime)
  - [ ] 5.1 Implementasi create/join room
    - Create Room: insert into game_rooms (generate 6-char code), navigate ke lobby
    - Join Room: validate code, insert into room_players, navigate ke lobby
    - Quick Match: cari room dengan status='waiting', jika tidak ada → single player mode
    - Create apps/web/src/lib/roomService.ts (createRoom, joinRoom, leaveRoom, findAvailableRoom)
    - _Persyaratan: P2.1, P2.2, P2.8_

  - [ ] 5.2 Implementasi lobby page dengan Supabase Realtime
    - Create apps/web/src/pages/LobbyPage.tsx
    - Circular seats arrangement (8-16 kursi)
    - Dark forest background dengan lantern CSS effects
    - Room code display top-left (copyable)
    - Subscribe ke Supabase Realtime presence untuk player join/leave
    - Subscribe ke room_players table changes
    - Real-time player avatars filling seats
    - Settings panel (host only): max players, timer config
    - START button (golden, host only, enabled when ≥8 players ready)
    - INVITE button (copy room code)
    - Chat panel at bottom (Supabase Realtime broadcast)
    - _Persyaratan: P2.3, P2.4, P2.5, P2.6, P2.7, P8.3, P8.4, P11.5_

- [ ] 6. Game Engine Update (Red vs Blue)
  - [ ] 6.1 Update shared-types untuk Red vs Blue
    - Update packages/shared-types/src/game.types.ts:
      - Team = 'red' | 'blue'
      - Role = 'villager' | 'werewolf' | 'seer' | 'doctor' | 'witch'
      - Add WitchAction type
      - Update NightActions (wolfTarget, doctorTarget, witchAction, seerTargets)
      - Update GameState (witchHealUsed, witchPoisonUsed, doctorProtectsRemaining, doctorLastTarget, pendingTestament)
      - Update GameConfig (min 8, max 16)
    - _Persyaratan: P3, P4, P7_

  - [ ] 6.2 Update game-engine untuk Red vs Blue rules
    - Update role compositions: 8-16 players (always 2 Seer, 1 Doctor, 1 Witch)
    - Update night phase order: WOLF_TURN → DOCTOR_TURN → WITCH_TURN → SEER_TURN
    - Implement Witch mechanics: heal 1x per game, poison 1x per game, cannot both same night
    - Implement Doctor constraints: max 3 protects, cannot protect same target consecutively
    - Implement 2 Seer system (each scans independently)
    - Update win condition: aliveWerewolves >= aliveBlueTeam (Witch not counted in comparison)
    - Add TESTAMENT phase after eliminations
    - Update information visibility: WW see each other, Witch sees WW, Seers see each other
    - _Persyaratan: P3.1-P3.7, P4.1-P4.10, P5.1-P5.10, P6.1-P6.4, P7.1-P7.6_

  - [ ] 6.3 Update ai-engine untuk Red vs Blue
    - Add Witch strategy (heal/poison decision making)
    - Update Seer strategy (2 Seers coordinate)
    - Update Doctor strategy (manage 3 protect quota)
    - Update Werewolf strategy (aware of Witch ally but don't know who)
    - Update win condition awareness for all bot strategies
    - _Persyaratan: P9.2, P9.3_

- [ ] 7. Game Flow (Multiplayer Realtime)
  - [ ] 7.1 Implementasi game state broadcast
    - Create apps/web/src/hooks/useMultiplayerGame.ts
    - Host runs game engine locally, broadcasts state via Supabase Realtime channel
    - All clients receive state updates and render
    - Night actions: player sends action via broadcast → host processes
    - Voting: direct click → broadcast vote → host resolves
    - Timer synced via broadcast (host sends deadline timestamp)
    - Win condition check after each elimination
    - _Persyaratan: P8.1, P8.2, P8.5, P8.6, P8.7, P12.6_

  - [ ] 7.2 Implementasi testament/wasiat system
    - When player dies (night or day): show testament input overlay (30s timer)
    - Player types message (max 200 chars) → broadcast to all
    - After timer or submit → advance game
    - All living players see the testament
    - _Persyaratan: P6.1, P6.2, P6.3, P6.4_

  - [ ] 7.3 Implementasi night action UI (Red vs Blue)
    - Wolf turn: select target from alive non-wolf players
    - Doctor turn: select target to protect (show remaining quota, cannot select last target)
    - Witch turn: show options — Heal (if not used, show wolf's target), Poison (select target), Skip
    - Seer turn: select target to scan, show result (Red/Blue team)
    - Timer 20s per action, auto-skip if expired
    - _Persyaratan: P4.2-P4.9, P12.4_

  - [ ] 7.4 Implementasi voting UI
    - Direct click on player to vote (no confirmation popup)
    - Show vote progress (who has voted, not who they voted for)
    - Resolve: majority → eliminate (role stays hidden), tie → revote tied players, second tie → skip
    - _Persyaratan: P5.4-P5.9_

- [ ] 8. Single Player Mode (Fallback)
  - [ ] 8.1 Implementasi single player vs AI
    - If Quick Match finds no rooms → offer single player
    - Create apps/web/src/hooks/useSinglePlayerGame.ts
    - 1 human + 7+ bots (fill to 8 minimum)
    - Use game-engine + ai-engine packages
    - Auto-advance phases, timer runs, bots act with delay
    - Bot chat messages with typing simulation
    - _Persyaratan: P9.1-P9.7_

- [ ] 9. Visual Polish
  - [ ] 9.1 Apply dark medieval theme across all pages
    - PlayerCard uses actual avatar images (/avatars/avatar-{id}.png)
    - Golden gradient buttons with glow effects
    - Semi-transparent card backgrounds with border glow
    - Rounded corners (12-16px), subtle borders
    - Phase transition animations (Siang↔Malam, max 2 detik)
    - Narrator overlay with typewriter text effect
    - Responsive: 320px - 1920px, touch-friendly (44px min targets)
    - _Persyaratan: P11.1-P11.8, P14.5_

  - [ ] 9.2 Implementasi audio system
    - BGM malam (misterius) dan siang (cerah), crossfade on transition
    - SFX: eliminasi, vote cast, timer warning, role reveal
    - Volume controls (musik/sfx terpisah) di Settings
    - Save audio preferences ke localStorage
    - _Persyaratan: P15.1-P15.5_

- [ ] 10. Chat System
  - [ ] 10.1 Implementasi in-game chat
    - Chat aktif hanya saat Fase Siang (diskusi)
    - Dead players: bisa baca, tidak bisa kirim
    - Filter kata kasar
    - Max 200 karakter per pesan
    - Broadcast via Supabase Realtime channel
    - Bot chat messages during discussion (typing simulation)
    - _Persyaratan: P10.1-P10.5_

- [ ] 11. Results Page
  - [ ] 11.1 Implementasi results page
    - Winner announcement (Red/Blue team) dengan animasi
    - Reveal semua roles dan teams
    - Stats: durasi, rounds, eliminations
    - Buttons: Play Again (same config), Back to Home
    - _Persyaratan: P7.4, P7.5_

- [ ] 12. Final Polish & Testing
  - [ ] 12.1 State persistence dan recovery
    - Save game state ke localStorage sebagai backup
    - On reload: recover state + reconnect Realtime channel
    - Handle reconnection gracefully (sync from host)
    - _Persyaratan: P13.1-P13.5_

  - [ ] 12.2 Performance optimization
    - Lazy load pages (React.lazy + Suspense)
    - Bundle < 5MB initial load
    - Responsive pada mobile
    - Adaptive animation quality on low-end devices
    - _Persyaratan: P14.1-P14.5_

  - [ ] 12.3 End-to-end verification
    - Verify full flow: Auth → Profile → Home → Create Room → Lobby → Game → Results
    - Verify single player: Home → Quick Match (no rooms) → Single Player → Game → Results
    - Verify all 5 roles work correctly in night phase
    - Verify testament system works for night and day deaths
    - Verify win conditions (Red wins / Blue wins)
    - Build production successfully

## Catatan

- Task 1 sudah selesai (avatars + supabase client)
- Urutan eksekusi: Auth → Profile → Home → Room/Lobby → Game Engine Update → Multiplayer → Single Player → Polish
- Revamp-plan.md adalah source of truth untuk game rules
- Host-authoritative model: host client runs game engine, broadcasts via Supabase Realtime
- Direct click voting (no confirmation popup)
- Roles stay hidden until game ends (RESULTS phase)
- Testament/wasiat: 30s timer for dead players to leave message
