# Cloudflare Tunnel for SSH Zero Trust Access

A production-ready Docker Compose setup for Cloudflare Tunnel (`cloudflared`) that enables secure SSH access to your host machine via Cloudflare Zero Trust browser-based SSH terminal.

## Overview

This setup runs Cloudflare's `cloudflared` tunnel agent in a Docker container, creating a secure outbound connection to Cloudflare's edge network. The tunnel proxies SSH connections from the Cloudflare Zero Trust dashboard directly to your host machine's SSH service.

**Recommended Setup Method:** Use the provided `setup.sh` script for a fully automated installation that handles everything including OpenSSH Server installation, SSH configuration, and tunnel startup.

```
┌─────────────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Cloudflare Zero Trust   │────▶│ Cloudflare Tunnel │────▶│ Host SSH (port 22)│
│ (Browser SSH Terminal)  │     │  (Docker Container)│    │ (User: kelanach) │
└─────────────────────────┘     └──────────────────┘     └─────────────────┘
```

**Key Features:**
- No exposed ports on your host machine
- No public IP required
- Browser-based SSH access through Cloudflare Zero Trust
- Automatic authentication and access policies
- Docker-based deployment (no native binary installation)

## Prerequisites

Before you begin, ensure you have:

| Requirement | Description |
|-------------|-------------|
| **Cloudflare Account** | With Zero Trust access enabled |
| **Existing Tunnel** | Created in Cloudflare Zero Trust dashboard |
| **Tunnel Token** | Your tunnel's authentication token |
| **Docker** | Installed and running on your host |
| **Docker Compose** | v2.0+ (or `docker compose` plugin) |
| **SSH Service** | Optional - installed automatically by `setup.sh` (required for manual setup) |

### Checking Prerequisites

```bash
# Check Docker is installed
docker --version

# Check Docker Compose is available
docker compose version

# Verify SSH is running on the host
sudo systemctl status ssh
```

## One-Command Setup (Recommended)

For a completely automated setup that installs and configures everything (including OpenSSH Server if not present), use the provided setup script:

```bash
./setup.sh
```

**The setup script will:**
- Check prerequisites (Docker, Docker Compose)
- Install and configure OpenSSH Server if not present
- Enable and start the SSH service
- Validate your TUNNEL_TOKEN in `.env`
- Start the Docker Compose tunnel
- Verify everything is working
- Provide next steps for Cloudflare Zero Trust configuration

**Requirements for setup.sh:**
- Ubuntu/Debian-based system
- Docker and Docker Compose installed
- TUNNEL_TOKEN already configured in `.env` file
- sudo access (for installing SSH server)

The script is idempotent - safe to run multiple times.

## Manual Setup

If you prefer manual setup or the automated script doesn't work for your environment, follow these steps:

### 1. Ensure SSH is Running

First, verify SSH is installed and running on your host:

```bash
# Install OpenSSH Server if not present
sudo apt update && sudo apt install -y openssh-server

# Enable and start SSH service
sudo systemctl enable ssh
sudo systemctl start ssh

# Verify SSH is listening on port 22
sudo ss -tlnp | grep :22
```

### 2. Clone or Navigate to Directory

```bash
cd /home/kelanach/Public/main-linux-kelanach/code-berkah-titipan-tuhan/code/local-docker-app/main/cloudflare
```

### 3. Configure Your Tunnel Token

Copy the example environment file and add your tunnel token:

```bash
cp .env.example .env
nano .env  # or your preferred editor
```

Paste your Cloudflare tunnel token:

```env
TUNNEL_TOKEN=eyJhIjoixxxx...your-token-here
```

**Where to find your token:**
1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** → **Tunnels**
3. Select your tunnel
4. Click the token copy button next to "Tunnel Token"

### 4. Start the Tunnel

```bash
docker compose up -d
```

### 5. Verify the Tunnel is Running

```bash
# Check container status
docker compose ps

# View logs
docker compose logs -f cloudflared
```

You should see logs indicating the tunnel is active and connected.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TUNNEL_TOKEN` | Yes | Your Cloudflare tunnel authentication token from the Zero Trust dashboard |

## Docker Compose Commands

```bash
# Start the tunnel (detached)
docker compose up -d

# Stop the tunnel
docker compose down

# Restart the tunnel
docker compose restart

# View real-time logs
docker compose logs -f cloudflared

# View container status
docker compose ps

# Update to latest image
docker compose pull
docker compose up -d
```

## Cloudflare Zero Trust Configuration

After your tunnel is running, you need to configure the SSH application in Cloudflare Zero Trust.

### Step 1: Create SSH Application

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** → **Applications**
3. Click **Add an application**
4. Select **Self-hosted**
5. Configure the application:
   - **Application Name**: e.g., "Ubuntu SSH - kelanach"
   - **Session Duration**: e.g., "24h"
   - **Path**: Leave as default (or specify a custom path)
6. Under **Identity Providers**, select your login method (e.g., "One-Time PIN", "Email", or your SSO)

### Step 2: Configure Application Settings

1. **Settings** tab:
   - **Application Name**: Your chosen name
   - **Session Duration**: As desired
   - **Type**: SSH
   - **Allowed IDPs**: Select your identity provider(s)

2. **Policies** tab:
   - Add policy for who can access
   - Example: "Email domain is `yourdomain.com`"

### Step 3: Configure SSH Destination

1. Go to **Access** → **Tunnels** → Your tunnel
2. Click **Configure** → **Public Hostname**
3. Add a new public hostname:
   - **Subdomain**: Your chosen subdomain (e.g., `ssh-homelab`)
   - **Domain**: Your domain (e.g., `kelanach.xyz` or `workers.dev` if no domain)
   - **Service**: SSH
   - **URL**: `ssh://localhost:22`
   - **No TLS Verify**: Checked (since it's localhost SSH)

**Example Configuration:**
- Subdomain: `ssh-homelab`
- Domain: `kelanach.xyz`
- Full URL: `https://ssh-homelab.kelanach.xyz`

### Step 4: Test Browser-Based SSH

1. Go to your application URL: `https://ssh-homelab.kelanach.xyz` (or your configured URL)
2. You'll be redirected through Cloudflare Access
3. Authenticate using your configured method
4. The browser-based SSH terminal will appear
5. Log in with your host credentials (user `kelanach`)

### Access Policy Examples

**Email Domain Policy:**
```
Action: Allow
Selector: Email
Operator: Contains
Value: @yourdomain.com
```

**Specific Email Policy:**
```
Action: Allow
Selector: Email
Operator: Is
Value: your-email@example.com
```

**One-Time PIN (OTP) Policy:**
1. Enable "One-Time PIN" as an identity provider
2. Add policy requiring OTP authentication
3. Users will receive a code via email

**Geo-location Policy:**
```
Action: Allow
Selector: Country
Operator: In
Value: US, CA, GB
```

## Verification Steps

### 1. Verify Container is Running

```bash
docker compose ps
```

Expected output: Status should be `Up` or `Up (healthy)`

### 2. Verify Tunnel Connection

```bash
docker compose logs cloudflared | grep "Registered tunnel connection"
```

### 3. Verify SSH Service on Host

```bash
sudo systemctl status ssh
sudo ss -tlnp | grep :22
```

### 4. Test Zero Trust Access

1. Visit your application URL in a browser
2. Complete authentication flow
3. Verify SSH terminal appears in browser
4. Log in with your credentials

## Troubleshooting

### Container Won't Start

**Symptom:** `docker compose up -d` fails immediately

**Solutions:**
1. Verify `.env` file exists and is readable
2. Check tunnel token format (should be a long JWT string starting with `eyJ`)
3. Check Docker daemon is running: `sudo systemctl status docker`
4. Check logs: `docker compose logs cloudflared`

### Tunnel Connects But SSH Unreachable

**Symptom:** Tunnel shows as connected, but SSH fails

**Solutions:**
1. Verify SSH is running on host: `sudo systemctl status ssh`
2. Check SSH is listening on port 22: `sudo ss -tlnp | grep :22`
3. Verify `network_mode: host` is set in docker-compose.yml
4. Check firewall isn't blocking SSH: `sudo ufw status`

### "Connection Refused" Error

**Symptom:** Browser shows connection refused

**Solutions:**
1. Verify the public hostname in Cloudflare dashboard points to `ssh://localhost:22`
2. Check "No TLS Verify" is enabled for the SSH service
3. Ensure tunnel token matches the correct tunnel

### Container Restarts Continuously

**Symptom:** Container keeps restarting (crash loop)

**Solutions:**
1. Check logs: `docker compose logs cloudflared`
2. Common causes:
   - Invalid tunnel token
   - Network connectivity issues
   - Tunnel was deleted from Cloudflare dashboard

### Access Policy Denies Access

**Symptom:** Authentication succeeds but access is denied

**Solutions:**
1. Review your application policies in Cloudflare dashboard
2. Ensure your email/account matches the allow policy
3. Check if additional authentication factors are required

### Tunnel Connections Keep Timing Out ("no recent network activity")

**Symptom:** Logs show repeated `Registered tunnel connection` followed by `timeout: no recent network activity` every ~70 seconds, tunnel appears offline in Cloudflare dashboard

**Cause:** QUIC protocol uses UDP, which gets dropped by some ISP routers, NATs, or firewalls after a short idle period

**Solution:** The compose file uses `--protocol http2` to force TCP connections instead. If you removed this flag, add it back:
```yaml
command: tunnel --protocol http2 run
```

### Update Cloudflared Image

```bash
docker compose pull
docker compose up -d
```

## Security Notes

### Secrets Management

| File | Git Status | Purpose |
|------|------------|---------|
| `.env` | **DO NOT COMMIT** | Contains your actual tunnel token |
| `.env.example` | Safe to commit | Template with placeholder values |
| `compose.yaml` | Safe to commit | References `${TUNNEL_TOKEN}` from .env |

### Best Practices

1. **Never commit `.env`** to version control
2. **Rotate tunnel tokens** periodically:
   - Delete old token in Cloudflare dashboard
   - Generate new token
   - Update `.env` file
   - Restart container: `docker compose restart`
3. **Use strong access policies**:
   - Require email verification
   - Consider multi-factor authentication
   - Limit by geographic region if needed
4. **Monitor access logs** in Cloudflare Zero Trust dashboard
5. **Keep Docker image updated**: `docker compose pull && docker compose up -d`

### Permissions

The container runs with minimal privileges and only requires:
- Network access (for tunnel connection)
- Environment variable access (for token)

No host filesystem mounts are required for token-based authentication.

## Architecture

### Container Configuration

- **Image**: `cloudflare/cloudflared:latest` (auto-updates with `docker compose pull`)
- **Protocol**: `http2` (TCP) — avoids QUIC/UDP timeout issues on restrictive networks
- **Network Mode**: `host` - allows container to reach host SSH on `localhost:22`
- **Restart**: `unless-stopped` - auto-restart on failure/reboot
- **Authentication**: Token-based (no credentials file needed)

### Data Flow

1. User navigates to Cloudflare Zero Trust application URL
2. Cloudflare Access authenticates user via configured policies
3. Upon success, Cloudflare establishes SSH connection through tunnel
4. `cloudflared` container proxies SSH to host's `localhost:22`
5. Browser-based terminal displays SSH session

### Why `network_mode: host`?

On Linux, `host.docker.internal` (available in Docker Desktop) doesn't exist. Using `network_mode: host` allows the container to access services running on the host machine via `localhost` or `127.0.0.1`, which is essential for proxying SSH to the host's SSH daemon.

## Support & Resources

- [Cloudflare Zero Trust Documentation](https://developers.cloudflare.com/cloudflare-one/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [cloudflared GitHub Repository](https://github.com/cloudflare/cloudflared)

## License

This configuration is provided as-is for use with Cloudflare's services.
