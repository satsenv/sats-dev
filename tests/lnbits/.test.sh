#!/usr/bin/env bash
set -e

wait_for_processes

# LNbits serves its index page with a <title>LNbits</title> tag
output=$(curl -sSf http://127.0.0.1:8231/)

if echo "$output" | grep -q "<title>LNbits</title>"; then
  echo "lnbits homepage returned expected <title>LNbits</title>" >&2
else
  echo "Failed to find <title>LNbits</title> in homepage response" >&2
  echo "$output" | head -n 40 >&2
  exit 1
fi

echo "lnbits test passed" >&2
