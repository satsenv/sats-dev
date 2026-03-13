set -e

CLI="bitcoin-cli -regtest -rpcuser=devenv -rpcpassword=devenv"

wait_for_processes

# Verify bitcoind is running in regtest mode
chain=$($CLI getblockchaininfo | jq -r '.chain')
if [ "$chain" = "regtest" ]; then
  echo "bitcoind regtest is running" >&2
else
  echo "Expected regtest chain, got: $chain" >&2
  exit 1
fi

# Generate a block to confirm the node is functional
$CLI createwallet "test" 2>/dev/null || true
address=$($CLI -rpcwallet=test getnewaddress)
$CLI generatetoaddress 1 "$address" > /dev/null

count=$($CLI getblockcount)
if [ "$count" -ge 1 ]; then
  echo "Block generation works, count: $count" >&2
else
  echo "Expected block count >= 1, got: $count" >&2
  exit 1
fi

echo "bitcoind regtest test passed" >&2
