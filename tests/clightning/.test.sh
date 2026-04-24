#!/usr/bin/env bash
set -e

CLI="bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv"
LCLI="lightning-cli --lightning-dir=$DEVENV_STATE/clightning --network=regtest"

wait_for_processes

# Generate a block so clightning has a chain tip to sync to
$CLI createwallet "test" 2>/dev/null || true
address=$($CLI -rpcwallet=test getnewaddress)
$CLI generatetoaddress 1 "$address" > /dev/null

# Verify clightning is running and connected to bitcoind
info=$($LCLI getinfo 2>&1)
if echo "$info" | jq -e '.id' > /dev/null 2>&1; then
  echo "clightning is running" >&2
  echo "  pubkey: $(echo "$info" | jq -r '.id')" >&2
else
  echo "Failed to get clightning info: $info" >&2
  exit 1
fi

# Verify network matches regtest
network=$(echo "$info" | jq -r '.network')
if [ "$network" != "regtest" ]; then
  echo "clightning network mismatch: expected regtest, got $network" >&2
  exit 1
fi
echo "  network: $network" >&2

# Verify bitcoind-backed blockheight advances. clightning polls bitcoind on an
# interval, so retry briefly to give it a chance to see the new block.
blockheight=0
for _ in $(seq 1 30); do
  blockheight=$($LCLI getinfo | jq -r '.blockheight')
  if [ "$blockheight" -ge 1 ]; then
    break
  fi
  sleep 1
done
echo "  blockheight: $blockheight" >&2
if [ "$blockheight" -lt 1 ]; then
  echo "clightning did not observe the generated block" >&2
  exit 1
fi

# Verify the wallet defaulted to a sqlite3 db under dataDir
wallet_db="$DEVENV_STATE/clightning/regtest/lightningd.sqlite3"
if [ ! -f "$wallet_db" ]; then
  echo "expected default sqlite wallet at $wallet_db" >&2
  exit 1
fi
echo "  wallet: $wallet_db" >&2

echo "clightning test passed" >&2
