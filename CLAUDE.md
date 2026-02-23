# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based wrapper for running Claude Code CLI in isolated containers with network filtering. Uses a Squid proxy to restrict outbound connections to only the domains required for Claude Code operation.

## Usage

```bash
./claude.sh <project-directory-name>         # Run Claude Code for a project
./claude.sh <project-directory-name> --build # Force rebuild Docker images
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                        │
│  ┌──────────────┐         ┌──────────────────────────┐  │
│  │ claude-code  │ ──────> │ squid-proxy              │  │──> Internet
│  │ container    │  HTTP/S │ (domain allowlist)       │  │    (filtered)
│  └──────────────┘         └──────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Files

- `claude.sh` - Runner script that orchestrates docker-compose
- `docker-compose.yml` - Defines claude and proxy services with networking
- `Dockerfile.claude` - Claude Code image (Node.js + Claude CLI + fp)
- `Dockerfile.proxy` - Squid proxy image for network filtering
- `entrypoint.sh` - Container entrypoint that sets up fp plugin on first run
- `proxy/allowed-domains.txt` - Whitelisted domains (regex patterns)
- `proxy/squid.conf` - Squid proxy configuration

## Included Tools

- **Claude Code** - AI coding assistant CLI
- **fp** - Agent-native issue tracking (https://fp.dev)
  - Automatically configured on first container run
  - Initialize in project with `fp init`
  - Tell Claude to "use fp" for task management

## Network Security

The proxy container filters all outbound traffic. Only connections to domains in `proxy/allowed-domains.txt` are permitted:

- `*.anthropic.com` - Claude API
- `*.github.com`, `*.githubusercontent.com` - Git operations
- `*.npmjs.org` - NPM packages
- `*.statsig.com`, `*.sentry.io` - Telemetry
- `*.visualstudio.com` - VS Code integration

To add domains, edit `proxy/allowed-domains.txt` and rebuild with `--build`.

## Container Configuration

- Project mounted to `/<project-name>` with working directory set dynamically
- Shared settings directory (`claude-shared-settings/`) persists config across sessions
- Claude container routes all HTTP/HTTPS through the proxy container
- Containers named `<project>` and `<project>-proxy`

@.fp/FP_CLAUDE.md
