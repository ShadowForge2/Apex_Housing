# APEX Housing — Deployment Guide

## Prerequisites

- VPS running Ubuntu 22.04+ (Ewender or similar)
- Domain pointed to your server IP (`apex-housing.online`)
- SSH access as root or sudo user

---

## Step 1: SSH into your server

```bash
ssh root@YOUR_SERVER_IP
```

## Step 2: Install Docker & Docker Compose

```bash
apt update && apt upgrade -y
apt install -y curl git ufw

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker && systemctl start docker

# Install Docker Compose plugin
apt install -y docker-compose-plugin

# Verify
docker --version
docker compose version
```

## Step 3: Configure firewall

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
```

## Step 4: Clone the repo

```bash
cd /opt
git clone https://github.com/ShadowForge2/Apex_Housing.git apex
cd apex
```

## Step 5: Create the .env file

```bash
cp backend/.env.example backend/.env
nano backend/.env
```

**Fill in every value.** Critical ones:

```env
# Generate a new secret key:
# python3 -c "import secrets; print(secrets.token_hex(32))"
SECRET_KEY=your_new_64_char_hex_key

# Database — use Supabase or local Postgres (see Step 5b)
DATABASE_URL=postgresql+asyncpg://user:pass@host:6543/postgres

# Redis
REDIS_URL=redis://:YOUR_STRONG_REDIS_PASSWORD@redis:6379/0
REDIS_PASSWORD=YOUR_STRONG_REDIS_PASSWORD

# Postgres (only if running local DB)
POSTGRES_USER=apex
POSTGRES_PASSWORD=YOUR_STRONG_DB_PASSWORD
POSTGRES_DB=apex_housing

# Paystack
PAYSTACK_SECRET_KEY=sk_live_xxx
PAYSTACK_PUBLIC_KEY=pk_live_xxx
PAYSTACK_WEBHOOK_SECRET=whsec_xxx

# CORS — add your real domain
CORS_ORIGINS=["https://apex-housing.online","https://www.apex-housing.online"]

# Firebase (push notifications)
FIREBASE_CREDENTIALS_PATH=firebase_credentials.json

# Sentry (optional but recommended)
SENTRY_DSN=https://xxx@sentry.io/xxx
```

Save and exit: `Ctrl+O`, `Enter`, `Ctrl+X`.

## Step 5b: Database choice

### Option A: Keep using Supabase (recommended)

Your `DATABASE_URL` already points to Supabase. Just make sure it's correct in `.env`.

### Option B: Self-host Postgres in Docker

Already handled — the `docker-compose.yml` includes a Postgres service. Just set strong `POSTGRES_PASSWORD` in `.env`.

## Step 6: Upload Firebase credentials

If you have `firebase_credentials.json`, upload it:

```bash
# From your local machine:
scp /path/to/firebase_credentials.json root@YOUR_SERVER_IP:/opt/apex/backend/firebase_credentials.json
```

Or paste it on the server:
```bash
nano /opt/apex/backend/firebase_credentials.json
# Paste the JSON content, save and exit
```

## Step 7: Point your domain

In your DNS provider (Namecheap, Cloudflare, etc.):

| Type  | Name | Value             |
|-------|------|-------------------|
| A     | @    | YOUR_SERVER_IP    |
| A     | www  | YOUR_SERVER_IP    |

Wait 5-10 minutes for DNS propagation.

## Step 8: Get SSL certificate (first time only)

```bash
# Start nginx without SSL first
docker compose up -d nginx

# Get certificate
docker compose run --rm certbot certonly \
  --webroot -w /var/www/html \
  -d apex-housing.online \
  -d www.apex-housing.online \
  --email your@email.com \
  --agree-tos \
  --no-eff-email

# Restart nginx with SSL
docker compose restart nginx
```

## Step 9: Run database migrations

```bash
# Run migrations inside the API container
docker compose exec api alembic upgrade head
```

If that fails, try:
```bash
docker compose run --rm api alembic upgrade head
```

## Step 10: Start everything

```bash
docker compose up -d
```

This starts:
- `api` — FastAPI backend on port 8000
- `db` — Postgres (if not using Supabase)
- `redis` — Redis
- `celery_worker` — Background tasks
- `celery_beat` — Scheduled tasks
- `nginx` — Reverse proxy with SSL on ports 80/443
- `certbot` — Auto-renews SSL certificates

## Step 11: Verify it works

```bash
# Check all containers are running
docker compose ps

# Check API health
curl -k https://apex-housing.online/health

# Check API docs
curl -k https://apex-housing.online/docs

# View logs
docker compose logs -f api
docker compose logs -f nginx
```

## Step 12: Create admin user

```bash
docker compose exec api python -c "
import asyncio
from app.auth.service import AuthService
from app.database import get_db

async def create():
    async for db in get_db():
        service = AuthService(db)
        await service.register(
            email='admin@apexhousing.com',
            password='YOUR_ADMIN_PASSWORD',
            role='ADMIN',
            first_name='Admin',
            last_name='User'
        )
        print('Admin user created!')
        break

asyncio.run(create())
"
```

---

## Common Commands

```bash
# View logs
docker compose logs -f api
docker compose logs -f celery_worker

# Restart a service
docker compose restart api

# Stop everything
docker compose down

# Rebuild after code changes
docker compose up -d --build api celery_worker celery_beat

# Run a new migration
docker compose exec api alembic revision --autogenerate -m "description"
docker compose exec api alembic upgrade head

# Shell into the API container
docker compose exec api bash

# Check disk usage
docker system df
```

---

## Troubleshooting

**API won't start:**
```bash
docker compose logs api
# Check for missing env vars or DB connection errors
```

**SSL not working:**
```bash
# Check certbot logs
docker compose logs certbot
# Make sure DNS is pointing to your server
dig apex-housing.online
```

**Database connection refused:**
```bash
# If using Supabase, check your IP is whitelisted
# If self-hosted, check Postgres is running
docker compose ps db
docker compose logs db
```

**Redis connection error:**
```bash
# Make sure REDIS_PASSWORD matches in .env and docker-compose.yml
docker compose logs redis
```
