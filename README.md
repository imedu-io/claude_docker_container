# Claude Code Docker Container

A Docker-based solution for running Anthropic's Claude Code CLI in isolated, containerized environments.

## Overview

This project provides a secure way to run Claude Code against multiple projects using Docker containerization. It includes a Squid proxy that filters outbound connections to only the domains required for Claude Code operation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    claude-network                            │
│  ┌──────────────┐                                           │
│  │ project-A    │─────┐                                     │
│  └──────────────┘     │     ┌──────────────────────────┐    │
│  ┌──────────────┐     ├────>│ claude-shared-proxy      │────┼──> Internet
│  │ project-B    │─────┤     │ (single instance)        │    │    (filtered)
│  └──────────────┘     │     └──────────────────────────┘    │
│  ┌──────────────┐     │                                     │
│  │ project-C    │─────┘                                     │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

All Claude containers share a single proxy instance for efficient resource usage.

## Prerequisites

- Docker and Docker Compose installed
- Bash shell environment

## Installation

1. Install Claude code on your host machine (to initialize the local configurations and settings in ~/.claude): <https://code.claude.com/docs/en/setup>

2. Add this to you ~/.claude/settings.json

```json
{
  "permissions": {
    "allow": [
      "Bash(fp:*)"
    ],
    "deny": [
      "Bash(curl:*)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(**/.env.*)",
      "Read(**/.env)",
      "Bash(*.env*)",
      "Read(./.cursorignore)",
      "Read(./.cursorrules)",
      "Read(./.gitignore)",
      "Read(./.git)",
      "Read(./.vscode)",
      "Read(./.idea)",
      "Read(./secrets/**)",
      "Read(./.config/**)",
      "Read(./config/credentials.json)",
      "Read(./build)"
    ]
  },
  "enabledPlugins": {
    "fp@fiberplane-claude-code-plugins": true
  }
}
```

3. To enable OPTION+ENTER for newlines: create the file `~/.claude/keybindings.json` with the following content.

```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "alt+enter": "chat:newline"
      }
    }
  ]
}
```

4. Clone or copy all files to a project directory (e.g. ~/development/claude_docker_container)

5. Create project folders as siblings:

```text
claude_docker_container/
├── claude.sh              # Runner script
├── docker-compose.yml     # Container orchestration
├── Dockerfile.claude      # Claude Code image
├── Dockerfile.proxy       # Squid proxy image
├── entrypoint.sh          # Container entrypoint
└── proxy/
    ├── allowed-domains.txt # Whitelisted domains
    └── squid.conf          # Proxy configuration
your-project/          # Your project folder
other-project/         # Another project folder
```

6. Make the script executable:

```bash
chmod +x claude.sh
```

## Usage

### Basic Usage

```bash
./claude.sh <project-directory-name>
```

### Examples

```bash
./claude.sh ../my-project
./claude.sh ../my-other-project
```

Or just create an executable bash script in your parent project-folder like the one below, if you don't want to move into the project folder everytime:

```bash
# !/bin/bash
cd ~/development/claude_docker_container && ./claude.sh "../$1"
```

### Rebuild Docker Images

Use the `--build` flag to force a rebuild of all Docker images. Use `--build-proxy` or `--build-claude` to only build those containers.

```bash
./claude.sh my-project --build
./claude.sh my-project --build-claude
./claude.sh my-project --build-proxy

```

## How It Works

1. Validates that the specified project directory exists
2. Starts the shared Squid proxy (if not already running) with domain allowlist filtering
3. Launches Claude Code container routing all traffic through the proxy
4. Mounts the project directory to `/<project-name>` inside the container
5. Mounts shared settings for persistence across sessions
6. On first run, configures the fp plugin for Claude Code

The proxy starts once and remains running for all subsequent sessions. Multiple Claude containers can run simultaneously, all sharing the same proxy.

## Included Tools

### Claude Code

The AI coding assistant CLI from Anthropic.

### fp (Issue Tracking)

[fp](https://fp.dev) is an agent-native issue tracking CLI designed for Claude Code.

### svelte mcp (code linter)

Optional and included during the claude-container build because I mostly Svelte, but you can add more MCP's if you like. 

#### How it works

fp is integrated into the container in two layers:

1. **Binary installed in the container** — The Dockerfile installs the fp CLI so a Linux-compatible binary is always available, regardless of your host OS.
2. **Host data mounted at runtime** — The `projects` directory and `projects.toml` file from `~/.fiberplane/` on your host are mounted into the container. This means the container uses the same project registry and issue data as your host, so fp issues are accessible from both environments.

The relevant volume mounts in `docker-compose.yml`:

```yaml
- ~/.fiberplane/projects:/root/.fiberplane/projects:delegated
- ~/.fiberplane/projects.toml:/root/.fiberplane/projects.toml:delegated
```

#### Getting started

1. **Install fp on your host** — Follow the instructions at [fp.dev](https://fp.dev)
2. **Initialize fp in your project** — Run `fp init` in the project root. This creates an `.fp` folder in your project with the project config, and updates `projects.toml` in `~/.fiberplane/` with this project's ID. These two need to be in sync for fp to work correctly across host and container.
3. **Configure settings at the user level** — Any fp settings (e.g. auth tokens) should be placed in your host's `~/.fiberplane/` directory so they are shared with the container
4. **Start the container** — Run `./claude.sh your-project` and fp will be ready to use

On first container run, fp's Claude plugin is automatically configured via the entrypoint script. After that, tell Claude to "use fp" for task management.

## Network Security

The proxy container filters all outbound traffic. Only connections to whitelisted domains are permitted. See `allowed-domains.txt`.

All network attempts are loggin (along with their state: DENIED OR ALLOWED) on std-out, and in /var/log/squid/access.log.

### Adding Domains

To allow additional domains, edit `proxy/allowed-domains.txt` and rebuild:

```bash
./claude.sh my-project --build-proxy
```

## Features

- **Network Filtering** - Proxy-based domain allowlist for security
- **Multi-Project Support** - Run Claude Code against multiple project directories
- **Shared Proxy** - Single proxy instance serves all containers efficiently
- **Automatic Image Building** - Builds Docker images automatically on first run
- **Persistent Configuration** - Uses the settings from your host
- **Isolated Environments** - Each project runs in its own container
- **fp Integration** - Agent-native issue tracking pre-configured
- **Resource Limits** - Containers limited to 4GB RAM and 2 CPUs

## Uploading Files and Screenshots

The container has access to specific directories on your Mac for sharing files with Claude:

| Host Path | Container Path | Use Case |
|-----------|----------------|----------|
| `/var/folders/...` | `/var/folders/...` | Drag-and-drop your screenshots directly from the preview (=> this is not working yet) |
| `~/Screenshots` | `/Screenshots` | To upload screenshots into Claude Code. Assumes your screenshots are save to ~/Screenshots |

### Using ~/Screenshots Folder

If you save screenshots to `~/Screenshots` simply drag and drop them from the finder window, or reference them as:

```text
> Analyze /Screenshots/my-screenshot.png
```

### Adding More Folders

To mount additional directories, edit `docker-compose.yml` and add a volume:

```yaml
volumes:
  - ~/Documents:/Documents:ro  # Read-only access to Documents
```

Then restart the container.

## Performance

### Apple Silicon (M1/M2/M3/M4)

This project explicitly targets `linux/arm64` for native execution on Apple Silicon:

```bash
./claude.sh your-project --build
```

To verify your image is ARM64 native:

```bash
docker inspect claude-code | grep Architecture
# Should show: "Architecture": "arm64"
```

### macOS Considerations

Docker Desktop on macOS runs containers inside a Linux VM. This project uses optimized mount flags:

- `:cached` for project files (read-heavy)
- `:delegated` for config files (write-heavy)

### Resource Limits

Containers are limited to prevent runaway resource usage:

- Memory: 4GB
- CPUs: 2 cores

To adjust limits, edit `docker-compose.yml`:

```yaml
claude:
  mem_limit: 8g
  cpus: 4
```

### Large Projects

For very large codebases:

1. Use `.dockerignore` to exclude `node_modules`, build artifacts, etc.
2. Increase resource limits if needed
3. Use Docker's VirtioFS backend (Docker Desktop Settings > General)

## Files

| File | Description |
|------|-------------|
| `claude.sh` | Main runner script |
| `docker-compose.yml` | Container orchestration |
| `Dockerfile.claude` | Claude Code + fp image |
| `Dockerfile.proxy` | Squid proxy image |
| `entrypoint.sh` | First-run fp setup |
| `proxy/allowed-domains.txt` | Whitelisted domains (regex) |
| `proxy/squid.conf` | Squid configuration |

## Managing the Shared Proxy

The proxy runs as a long-lived container shared by all sessions.

### Check proxy status

```bash
docker ps --filter "name=claude-shared-proxy"
```

### View proxy logs

```bash
docker logs claude-shared-proxy
```

### Stop the proxy

```bash
docker stop claude-shared-proxy
```

### Restart the proxy

The proxy will automatically restart on the next `./claude.sh` invocation, or manually:

```bash
docker start claude-shared-proxy
```

## Troubleshooting

### Connection Refused Errors

If Claude Code can't reach required services, check if the domain is in `proxy/allowed-domains.txt`.

View proxy logs:

```bash
docker logs claude-shared-proxy
```

### Proxy Not Starting

Check proxy health:

```bash
docker inspect claude-shared-proxy --format='{{.State.Health.Status}}'
```

If unhealthy, check logs and restart:

```bash
docker logs claude-shared-proxy
docker restart claude-shared-proxy
```

### Rebuilding After Changes

Always rebuild after modifying Dockerfiles or proxy config:

```bash
./claude.sh my-project --build
```

### Multiple Sessions

You can run multiple Claude sessions simultaneously. Each gets a unique container name (`project-$$`) while sharing the proxy.

## License

MIT
