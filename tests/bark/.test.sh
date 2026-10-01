#!/usr/bin/env bash
set -e

CLI="bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv"
BARK="bark --datadir $DEVENV_STATE/bark-wallet"

wait_for_processes

# Generate a block so the chain has a tip
$CLI createwallet "test" 2>/dev/null || true
address=$($CLI -rpcwallet=test getnewaddress)
$CLI generatetoaddress 1 "$address" > /dev/null

# captaind answers its admin RPC
if captaind rpc --addr "$BARK_ADMIN_RPC_ADDR" wallet > /dev/null 2>&1; then
  echo "captaind admin RPC answers" >&2
else
  echo "captaind admin RPC did not answer on $BARK_ADMIN_RPC_ADDR" >&2
  exit 1
fi

# bark CLI wallet can be created against the local server and query it
$BARK create --regtest \
  --ark "$BARK_ASP_URL" \
  --bitcoind 127.0.0.1:18443 \
  --bitcoind-user devenv \
  --bitcoind-pass devenv > /dev/null

if ark_info=$($BARK ark-info 2>&1); then
  echo "bark ark-info succeeded" >&2
  echo "$ark_info" | head -n 5 >&2
else
  echo "bark ark-info failed: $ark_info" >&2
  exit 1
fi

# barkd answers HTTP (readiness-level status query)
if curl -sf "$BARKD_URL/ping" > /dev/null 2>&1; then
  echo "barkd /ping answered" >&2
else
  token=$(barkd --datadir "$DEVENV_STATE/barkd" secret show 2>/dev/null || true)
  if [ -n "$token" ] && curl -sf -H "Authorization: Bearer $token" "$BARKD_URL/ping" > /dev/null 2>&1; then
    echo "barkd /ping answered (authenticated)" >&2
  else
    echo "barkd did not answer on $BARKD_URL" >&2
    exit 1
  fi
fi

echo "bark test passed" >&2
