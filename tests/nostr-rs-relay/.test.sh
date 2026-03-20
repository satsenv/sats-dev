#!/usr/bin/env bash
set -e

wait_for_processes

# Verify the relay is responding to WebSocket connections
# nostr-rs-relay returns NIP-11 relay info on HTTP GET requests
info=$(curl -sf -H "Accept: application/nostr+json" "http://127.0.0.1:8080")

name=$(echo "$info" | jq -r '.name')
if [ -n "$name" ] && [ "$name" != "null" ]; then
  echo "nostr-rs-relay is running" >&2
  echo "  name: $name" >&2
else
  echo "Failed to get relay info: $info" >&2
  exit 1
fi

echo "nostr-rs-relay test passed" >&2
