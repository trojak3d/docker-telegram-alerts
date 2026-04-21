#!/bin/sh
set -eu

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

normalize_field() {
  value="$1"
  if [ -z "$value" ] || [ "$value" = "<no value>" ]; then
    echo "unknown"
  else
    echo "$value"
  fi
}

send_message() {
  message="$1"

  if [ -n "${TELEGRAM_MESSAGE_THREAD_ID:-}" ]; then
    curl --silent --show-error --fail \
      --request POST \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "message_thread_id=${TELEGRAM_MESSAGE_THREAD_ID}" \
      --data-urlencode "disable_notification=${TELEGRAM_DISABLE_NOTIFICATION:-false}" \
      --data-urlencode "text=${message}" \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" >/dev/null
  else
    curl --silent --show-error --fail \
      --request POST \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "disable_notification=${TELEGRAM_DISABLE_NOTIFICATION:-false}" \
      --data-urlencode "text=${message}" \
      "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" >/dev/null
  fi
}

build_message() {
  event_kind="$1"
  container_name="$2"
  image_name="$3"
  stack_name="$4"
  service_name="$5"
  extra_line="$6"

  host_name="${ALERT_HOSTNAME:-server}"
  prefix="${TELEGRAM_MESSAGE_PREFIX:-Docker alert}"
  timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"

  printf '%s\n%s\nHost: %s\nContainer: %s\nImage: %s\nStack: %s\nService: %s\nTime: %s' \
    "$prefix" \
    "$event_kind" \
    "$host_name" \
    "$container_name" \
    "$image_name" \
    "$stack_name" \
    "$service_name" \
    "$timestamp"

  if [ -n "$extra_line" ]; then
    printf '\n%s' "$extra_line"
  fi
}

require_env "TELEGRAM_BOT_TOKEN"
require_env "TELEGRAM_CHAT_ID"

docker events --filter type=container --format '{{.Action}}|{{.Actor.ID}}|{{index .Actor.Attributes "name"}}|{{index .Actor.Attributes "image"}}|{{index .Actor.Attributes "com.example.stack"}}|{{index .Actor.Attributes "com.example.service"}}|{{index .Actor.Attributes "exitCode"}}' |
while IFS='|' read -r action container_id container_name image_name stack_name service_name exit_code; do
  container_name="$(normalize_field "$container_name")"
  image_name="$(normalize_field "$image_name")"
  stack_name="$(normalize_field "$stack_name")"
  service_name="$(normalize_field "$service_name")"
  exit_code="$(normalize_field "$exit_code")"

  extra_line="Container ID: $container_id"

  case "$action" in
    'health_status: unhealthy')
      message="$(build_message 'Status: unhealthy' "$container_name" "$image_name" "$stack_name" "$service_name" "$extra_line")"
      ;;
    'health_status: healthy')
      message="$(build_message 'Status: recovered' "$container_name" "$image_name" "$stack_name" "$service_name" "$extra_line")"
      ;;
    'die')
      die_extra_line="$(printf 'Container ID: %s\nExit code: %s' "$container_id" "$exit_code")"
      message="$(build_message 'Status: container died' "$container_name" "$image_name" "$stack_name" "$service_name" "$die_extra_line")"
      ;;
    'oom')
      message="$(build_message 'Status: out of memory' "$container_name" "$image_name" "$stack_name" "$service_name" "$extra_line")"
      ;;
    *)
      continue
      ;;
  esac

  send_message "$message"
done