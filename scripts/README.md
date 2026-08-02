# GGS Werewolf — Scripts

## Available Scripts

### `backup-db.sh`
Automated PostgreSQL backup with S3 upload and retention cleanup.

```bash
# One-time run
DB_PASSWORD=your-pass ./scripts/backup-db.sh

# Cron (daily at 2 AM)
0 2 * * * DB_PASSWORD=your-pass S3_BUCKET=ggs-backups /path/to/backup-db.sh
```

### `setup-tls.sh`
Generate TLS certificates for HTTPS.

```bash
# Development (self-signed)
./scripts/setup-tls.sh

# Production (Let's Encrypt)
ENV=production DOMAIN=api.ggs-werewolf.com ./scripts/setup-tls.sh
```

### `load-test.js`
k6 load testing script. Simulates concurrent users creating rooms.

```bash
# Install k6
brew install k6

# Run against local server
k6 run scripts/load-test.js

# Run against production (careful!)
k6 run -e API_URL=https://api.ggs-werewolf.com -e WS_URL=wss://api.ggs-werewolf.com/ws scripts/load-test.js

# Custom VU count
k6 run --vus 50 --duration 2m scripts/load-test.js
```

## Environment Variables

| Variable | Default | Used By |
|----------|---------|---------|
| `DB_HOST` | localhost | backup-db.sh |
| `DB_PASSWORD` | (required) | backup-db.sh |
| `S3_BUCKET` | (optional) | backup-db.sh |
| `DOMAIN` | localhost | setup-tls.sh |
| `ENV` | dev | setup-tls.sh |
| `API_URL` | http://localhost:8080 | load-test.js |
| `WS_URL` | ws://localhost:8080/ws | load-test.js |

## Sentry Setup

Add your Sentry DSN to the environment:

```bash
# .env
SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
```

The backend auto-initializes Sentry if `SENTRY_DSN` is set. Error tracking covers:
- Panic recovery
- HTTP 5xx errors
- WebSocket connection failures
- Database query errors
