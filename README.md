# docker-telegram-alerts

[![GitHub Repo](https://img.shields.io/badge/GitHub-trojak3d/docker--telegram--alerts-blue?logo=github)](https://github.com/trojak3d/docker-telegram-alerts)  
[![GHCR](https://img.shields.io/badge/GHCR-ghcr.io%2Ftrojak3d%2Fdocker--telegram--alerts-blue?logo=github)](https://ghcr.io/trojak3d/docker-telegram-alerts)

A lightweight Docker helper container that monitors the Docker Engine event stream and sends Telegram notifications when containers become unhealthy, recover, die, or run out of memory.

## How it works

1. On startup, the alerter:
   - Validates required environment variables
   - Connects to the Docker Engine event stream via the Docker socket

2. For each relevant container event, the alerter:
   - Formats a message including host, container name, image, stack, service, timestamp, and (for `die` events) exit code
   - Sends the message to the configured Telegram chat via the Bot API

Monitored events:

| Event | Alert sent |
|---|---|
| `health_status: unhealthy` | Status: unhealthy |
| `health_status: healthy` | Status: recovered |
| `die` | Status: container died (with exit code) |
| `oom` | Status: out of memory |

All other events are silently ignored.

## Requirements

- Docker Engine
- Access to the Docker socket:
  - `/var/run/docker.sock` (recommended read-only)

> **Security note:** Mounting the Docker socket gives the container visibility over all host container events. Use only in trusted environments.

## Configuration

Environment variables:

| Variable | Required | Default | Description |
|---|---|---|---|
| `TELEGRAM_BOT_TOKEN` | Yes | — | Telegram bot token from BotFather |
| `TELEGRAM_CHAT_ID` | Yes | — | Target chat or channel ID |
| `ALERT_HOSTNAME` | No | `server` | Hostname shown in alert messages |
| `TELEGRAM_MESSAGE_PREFIX` | No | `Docker alert` | First line of every message |
| `TELEGRAM_DISABLE_NOTIFICATION` | No | `false` | Send silently (`true`/`false`) |
| `TELEGRAM_MESSAGE_THREAD_ID` | No | — | Forum topic thread ID (if applicable) |
| `TZ` | No | UTC | Timezone for timestamps in messages |

## Example Docker Compose Configuration

```yaml
services:
  docker-telegram-alerts:
    image: ghcr.io/trojak3d/docker-telegram-alerts:latest
    container_name: docker-telegram-alerts
    environment:
      - ALERT_HOSTNAME=${ALERT_HOSTNAME}
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      - TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
      - TELEGRAM_MESSAGE_PREFIX=${TELEGRAM_MESSAGE_PREFIX}
      - TELEGRAM_DISABLE_NOTIFICATION=${TELEGRAM_DISABLE_NOTIFICATION}
      - TELEGRAM_MESSAGE_THREAD_ID=${TELEGRAM_MESSAGE_THREAD_ID}
      - TZ=${TZ}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
```

A `stack.env` file can be used to provide the variable values:

```env
TZ=Europe/London
ALERT_HOSTNAME=my-server
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
TELEGRAM_MESSAGE_PREFIX=Docker alert
TELEGRAM_DISABLE_NOTIFICATION=false
TELEGRAM_MESSAGE_THREAD_ID=
```

## Stack and Service Labels

Alert messages include `Stack` and `Service` fields. These are read from the container labels `com.example.stack` and `com.example.service`. Add these to any container you want identified by name in alerts:

```yaml
labels:
  com.example.stack: "my-stack"
  com.example.service: "my-service"
```

Containers without these labels will show `unknown` in those fields.

## Example Alert Message

```
Docker alert
Status: container died
Host: my-server
Container: my-app
Image: my-app:latest
Stack: my-stack
Service: my-service
Time: 2026-04-21 14:30:00 BST
Container ID: a1b2c3d4e5f6
Exit code: 1
```

## License

MIT License