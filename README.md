# Secure Node.js Docker Image

This repository demonstrates a hardened, production-oriented Docker build for a minimal Node.js web application.

## Purpose

The project focuses on Docker and container security best practices, including:

- minimal base image selection
- pinned image versions
- multi-stage Docker builds
- production-only dependency installation
- non-root execution with UID 1001
- health checks
- reduced attack surface
- build-context hygiene via `.dockerignore`

## Included Files

- `Dockerfile` — hardened production image definition
- `.dockerignore` — excludes unnecessary files from the Docker build context
- `server.js` — minimal HTTP service with a `/health` endpoint
- `package.json` — minimal Node.js application metadata
- `IMAGE-ANALYSIS.md` — security and image-analysis writeup

## Minimal Application Behavior

The app listens on port 3000 and responds with JSON at both:

- `/` — basic application response
- `/health` — health endpoint used by the container healthcheck

## Build

```bash
docker build -t secure-node-app:1.0 .
```

## Run

```bash
docker run --rm -p 3000:3000 secure-node-app:1.0
```

Then open:

```text
http://localhost:3000/
http://localhost:3000/health
```

## Check Effective User

```bash
docker run --rm secure-node-app:1.0 id
```

Expected result should show a non-root user, typically UID 1001.

## Notes

This repository intentionally keeps the application minimal so the focus remains on secure container design and Docker practices rather than application complexity.

