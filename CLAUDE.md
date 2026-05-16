# Cloudflare Tunnel - SSH Zero Trust

Docker Compose setup for Cloudflare Tunnel (`cloudflared`) providing browser-based SSH access via Zero Trust.

## Commands

```bash
docker compose up -d          # Start tunnel
docker compose down           # Stop tunnel
docker compose restart        # Restart tunnel
docker compose logs -f cloudflared  # View logs
docker compose pull && docker compose up -d  # Update image
./setup.sh                    # Full automated setup (SSH + tunnel)
```

## Environment

Copy `.env.example` to `.env` and set `TUNNEL_TOKEN` (JWT starting with `eyJ`, from Cloudflare Zero Trust dashboard).

## Architecture

Single container: `cloudflare/cloudflared:latest` with `network_mode: host` so it can reach host SSH on `localhost:22`. Uses `--protocol http2` (TCP) to avoid QUIC/UDP timeout issues on restrictive networks. Token-based auth (no credentials file).

## Gotchas

- `network_mode: host` is required on Linux — `host.docker.internal` doesn't exist outside Docker Desktop
- Container name is `cloudflared-ssh-tunnel` — referenced by setup.sh and health checks
- `.env` must not be committed (contains tunnel token)
- setup.sh requires Ubuntu/Debian and sudo access
