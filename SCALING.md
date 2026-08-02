# GGS Werewolf — Scaling Architecture

## Current State (Single Instance)

```
[Mobile App] ──WS──→ [Go Server :8080] ──SQL──→ [PostgreSQL]
                            │
                            ├── In-memory: Rate Limiting (tokenBucket)
                            ├── In-memory: Game Rooms + State
                            ├── In-memory: WebSocket Hub + Clients
                            └── PostgreSQL: Auth tokens, profiles, stats
```

**Capacity**: ~500-1000 concurrent users on a 2-core/4GB server.

---

## Phase 2: Add Redis (Target: 1,000-10,000 users)

```
[Mobile App] ──→ [Load Balancer (sticky sessions)]
                        │
                 ┌──────┼──────┐
                 ▼      ▼      ▼
            [Server 1] [Server 2] [Server 3]
                 │      │      │
                 └──────┼──────┘
                        ▼
                    [Redis]  ←── Rate limits, session cache, pub/sub
                        │
                    [PostgreSQL]
```

**Changes needed:**
1. Set `REDIS_URL` env var → `cache.Init()` will use Redis
2. Implement `cache.RedisStore` (use `github.com/redis/go-redis/v9`)
3. Rate limiter reads/writes to Redis (shared across instances)
4. Sticky sessions on LB (WebSocket connections stay on same server)

---

## Phase 3: Cross-Instance Game State (Target: 10,000-100,000 users)

```
[Mobile App] ──→ [LB] ──→ [Server N]
                              │
                              ├── Redis Pub/Sub (game state broadcasts)
                              ├── Redis: Room assignment (which server owns which room)
                              └── PostgreSQL: persistent data
```

**Changes needed:**
1. Room-to-server assignment table in Redis
2. Redis pub/sub for `game_state_update` cross-instance broadcasts
3. Player reconnect routes to correct server via Redis lookup
4. Game state snapshot to Redis (not just PostgreSQL) for fast recovery

---

## Phase 4: Dedicated Game Servers (Target: 100,000+ users)

```
[Mobile App] ──→ [API Gateway] ──→ [Auth Service]
                      │                   │
                      ▼                   ▼
               [Game Router] ──→ [Game Server Pool]
                      │                   │
                      └──→ [Redis Cluster] ←──┘
                                  │
                           [PostgreSQL Cluster]
```

**Changes needed:**
1. Separate game servers from API servers
2. Game server pool with auto-scaling
3. Matchmaking service
4. PostgreSQL read replicas

---

## Environment Variables for Scaling

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | (empty) | Redis connection string. Empty = in-memory mode |
| `INSTANCE_ID` | (auto) | Unique server instance identifier |
| `LB_STICKY_SESSIONS` | `true` | Whether load balancer uses sticky sessions |
| `MAX_ROOMS_PER_INSTANCE` | `100` | Max game rooms this instance handles |
| `GAME_STATE_TTL` | `3600` | Seconds to keep game state in Redis |

---

## What's Already Scaling-Ready

- ✅ Refresh tokens in PostgreSQL (shared across instances)
- ✅ Rate limiter is token-bucket (easy to swap to Redis-backed)
- ✅ `cache.Store` interface abstraction (plug in Redis without code changes)
- ✅ Game state serializable to JSON (can be stored in Redis)
- ✅ Graceful shutdown saves game snapshots
- ✅ Stateless JWT validation (any instance can validate)

## What Still Needs Work for Multi-Instance

- ⚠️ Rate limiter: swap `tokenBucket` to use `cache.Global.Incr()`
- ⚠️ WebSocket hub: needs Redis pub/sub for cross-instance messaging
- ⚠️ Room assignment: needs Redis-based room registry
- ⚠️ Profile cache: needs Redis-backed with proper invalidation


---

## Message Queue Architecture (Future)

When the system needs guaranteed delivery and cross-service communication:

```
[Game Server] ──publish──→ [NATS/Redis Streams] ──subscribe──→ [Notification Service]
                                    │                              [Analytics Service]  
                                    │                              [Leaderboard Service]
                                    └──subscribe──→ [Other Game Servers (cross-instance)]
```

**Use Cases for Message Queue:**
1. **Cross-instance game events** — When player A on Server 1 sends a gift to player B on Server 2
2. **Async notifications** — Push notifications, email triggers
3. **Event sourcing** — All game actions logged for replay/audit
4. **Analytics pipeline** — Game metrics, player behavior tracking
5. **Leaderboard updates** — Batched rank recalculations

**Recommended Stack:**
- **NATS** (lightweight, Go-native) for real-time game events
- **Redis Streams** for durable task queues (notifications, rewards)
- **PostgreSQL LISTEN/NOTIFY** for simple DB-triggered events (already available)

**Migration Path:**
1. Current: Direct function calls (single instance)
2. Phase 2: Redis pub/sub for cross-instance WebSocket broadcasts
3. Phase 3: NATS for microservice communication
4. Phase 4: Event sourcing with Redis Streams for full audit trail
