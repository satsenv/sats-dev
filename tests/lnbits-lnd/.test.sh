#!/usr/bin/env bash
set -e

wait_for_processes

log_file="$DEVENV_STATE/lnbits/lnbits.log"
if [ ! -f "$log_file" ]; then
  echo "Expected lnbits log at $log_file, but it does not exist" >&2
  exit 1
fi

# Give lnbits a moment to emit its startup banner (log_server_info runs after
# set_funding_source, so either "Funding source: ..." or "Error initializing ..."
# will appear in the log once startup completes).
for _ in $(seq 1 30); do
  if grep -q "Funding source:" "$log_file" 2>/dev/null; then
    break
  fi
  sleep 1
done

if grep -q "Error initializing LndWallet" "$log_file"; then
  echo "lnbits failed to initialize the LndWallet funding source:" >&2
  grep -n "Error initializing\|lnd_grpc" "$log_file" >&2 || true
  exit 1
fi

if ! grep -q "Funding source: LndWallet" "$log_file"; then
  echo "lnbits did not report 'Funding source: LndWallet' in its log" >&2
  grep -n "Funding source" "$log_file" >&2 || true
  exit 1
fi

echo "lnbits is configured with the LndWallet funding source" >&2

# Sanity: homepage still serves the LNbits UI.
output=$(curl -sSf http://127.0.0.1:8231/)
if ! echo "$output" | grep -q "<title>LNbits</title>"; then
  echo "lnbits homepage did not return the expected title" >&2
  exit 1
fi

echo "lnbits-lnd test passed" >&2
