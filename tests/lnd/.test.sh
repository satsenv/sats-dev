#!/usr/bin/env bash
set -e

CLI="bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv"
LNCLI="lncli --network regtest --rpcserver=127.0.0.1:10009 --lnddir=$DEVENV_STATE/lnd --tlscertpath=$LND_CERT_FILE --macaroonpath=$LND_MACAROON_FILE"

wait_for_processes

# Generate a block so lnd has something to sync to
$CLI createwallet "test" 2>/dev/null || true
address=$($CLI -rpcwallet=test getnewaddress)
$CLI generatetoaddress 1 "$address" > /dev/null

# Verify lnd is running and connected to bitcoind
info=$($LNCLI getinfo 2>&1)
if echo "$info" | jq -e '.identity_pubkey' > /dev/null 2>&1; then
  echo "lnd is running" >&2
  echo "  pubkey: $(echo "$info" | jq -r '.identity_pubkey')" >&2
else
  echo "Failed to get lnd info: $info" >&2
  exit 1
fi

# Verify lnd is synced to chain
synced=$(echo "$info" | jq -r '.synced_to_chain')
block_height=$(echo "$info" | jq -r '.block_height')
if [ "$synced" = "true" ]; then
  echo "lnd is synced to chain at height $block_height" >&2
else
  echo "lnd is not synced (synced=$synced height=$block_height)" >&2
  echo "$info" | jq '{synced_to_chain, synced_to_graph, block_height, block_hash}' >&2
  exit 1
fi

# Verify environment variables for TLS cert and macaroon paths
if [ -z "$LND_CERT_FILE" ]; then
  echo "LND_CERT_FILE is not set" >&2
  exit 1
fi
if [ ! -f "$LND_CERT_FILE" ]; then
  echo "LND_CERT_FILE does not exist: $LND_CERT_FILE" >&2
  exit 1
fi
echo "  LND_CERT_FILE=$LND_CERT_FILE" >&2

if [ -z "$LND_MACAROON_FILE" ]; then
  echo "LND_MACAROON_FILE is not set" >&2
  exit 1
fi
if [ ! -f "$LND_MACAROON_FILE" ]; then
  echo "LND_MACAROON_FILE does not exist: $LND_MACAROON_FILE" >&2
  exit 1
fi
echo "  LND_MACAROON_FILE=$LND_MACAROON_FILE" >&2

if [ -z "$LND_GRPC_HOST" ]; then
  echo "LND_GRPC_HOST is not set" >&2
  exit 1
fi
echo "  LND_GRPC_HOST=$LND_GRPC_HOST" >&2

echo "lnd test passed" >&2
