# Overview

This repository is a development kit built around a Flutter web frontend and a FastAPI backend.
It is designed to provide a small internal tool platform with API testing, Slack notifications,
SSH execution, and LLM utilities.

## Architecture

![Project architecture image](docs/architecture.png)


## Features

- SNS login with Google and Kakao (OAuth 2.0)
- API collection test runner
- Activity/session logging
- Slack message sender
- LLM request testing
- SSH command execution helpers

## Setup

### Services

- `web`: Serves the Flutter web build with Nginx and reverse-proxies `/api/*` to `api`
- `api`: FastAPI (Uvicorn) with `root_path=/api`
- `postgres`, `redis`: Session/state storage

### Environment Variables (`.env`)

Copy `.env.example` to `.env` and fill in the required values.

Important groups:

- General: `LOG_LEVEL`, `VERSION`
- Session/Auth: `AUTO_LOGOUT_SECONDS`, `SESSION_*`
- Storage: `POSTGRES_DSN`, `POSTGRES_POOL_*`, `REDIS_URL`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- Files/Paths: `COLLECTION_FILE`, `COLLECTION_PATH`, `AWS_SSH_KEY_PATH`, `AWS_SSH_ALIASES_PATH`
- Integrations: `SLACK_WEBHOOK_URL`, `LLM_*`, `OPENWEBUI_*`
- Auth: `GOOGLE_*`, `KAKAO_*`
- Server: `SERVER_HOST`, `SERVER_PORT`

`COLLECTION_FILE` / `COLLECTION_PATH` are optional now. If omitted, compose uses
`./backend/collection.json` -> `/app/collection.json`.

### Run / Build

```bash
docker compose up --build
```

### Google Login Setup

1. Create OAuth client in Google Cloud Console (Web application).
2. Add authorized redirect URI: `http://localhost:8080/api/auth/google/callback`
3. Fill `.env` with:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `GOOGLE_REDIRECT_URI` (same as above unless changed)

### Kakao Login Setup

1. Create app in Kakao Developers and enable Kakao Login.
2. Add Redirect URI: `http://localhost:8080/api/auth/kakao/callback`
3. Fill `.env` with:
   - `KAKAO_REST_API_KEY`
   - `KAKAO_CLIENT_SECRET` (if enabled in Kakao security settings)
   - `KAKAO_REDIRECT_URI` (same as above unless changed)

### Cloudflare Setup

#### 1) Bot Fight Mode

Enable in Cloudflare dashboard:

1. Select your zone.
2. Go to `Security` -> `Bots`.
3. Turn on `Bot Fight Mode`.

#### 2) Turnstile

1. Create a Turnstile widget in Cloudflare (`Turnstile` -> `Add widget`).
2. Add your domain (for local test, include `localhost`).
3. Set `.env`:
   - `TURNSTILE_ENABLED=true`
   - `TURNSTILE_SITE_KEY=<your site key>`
   - `TURNSTILE_SECRET_KEY=<your secret key>`
4. Restart services.

When enabled, the login flow (`/api/auth/google/login`, `/api/auth/kakao/login`) validates a Turnstile token before OAuth redirect.

### Flutter Build Notes

If the Flutter project is missing generated scaffolding and Docker build fails, run:

```bash
cd frontend
flutter create .
flutter pub get
cd ..
docker compose up --build
```

## Access

- `http://localhost:8080/` (Web UI)
- `http://localhost:8080/api/health` (API health check)
- `http://localhost:8080/api/docs#/` (API docs)
