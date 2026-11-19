#!/usr/bin/env bash
set -euo pipefail

: "${BASE_SEPOLIA_RPC_URL:?Set Base Sepolia RPC URL}"
: "${LASNA_RPC_URL:?Set Lasna RPC URL}"
: "${BASE_SEPOLIA_PRIVATE_KEY:?Set Base Sepolia deployer key}"
: "${LASNA_PRIVATE_KEY:?Set Lasna deployer key}"
: "${BASE_SEPOLIA_CALLBACK_PROXY:=0x476F44b11F5C942c58f4c8E3d0300E5710743585}"
: "${DRIP_SCHEDULER_ADDRESS:?Set predicted Lasna scheduler address before deployment}"
: "${DRIP_VAULT_ADDRESS:?Set predicted Base Sepolia vault address before deployment}"
: "${CRON_TICKS_PER_DRIP:=2}"
export BASE_SEPOLIA_CALLBACK_PROXY CRON_TICKS_PER_DRIP

echo "Deploying scheduler to Lasna (vault: $DRIP_VAULT_ADDRESS)..."
forge script script/DeployLasna.s.sol:DeployLasna --rpc-url "$LASNA_RPC_URL" --broadcast
echo "Scheduler: $DRIP_SCHEDULER_ADDRESS"

echo "Deploying token and vault to Base Sepolia (scheduler: $DRIP_SCHEDULER_ADDRESS)..."
forge script script/DeployBase.s.sol:DeployBase --rpc-url "$BASE_SEPOLIA_RPC_URL" --broadcast
echo "Token and vault deployment transactions: broadcast/DeployBase.s.sol/84532/run-latest.json"
echo "Scheduler deployment transaction: broadcast/DeployLasna.s.sol/5318007/run-latest.json"
if command -v jq >/dev/null 2>&1; then
  jq -r '.transactions[] | select(.transactionType == "CREATE") | "  \(.contractName): \(.contractAddress) tx=\(.hash)"' broadcast/DeployBase.s.sol/84532/run-latest.json
  jq -r '.transactions[] | select(.transactionType == "CREATE") | "  \(.contractName): \(.contractAddress) tx=\(.hash)"' broadcast/DeployLasna.s.sol/5318007/run-latest.json
else
  echo "Install jq to print parsed deployed addresses and hashes; raw records are in broadcast/."
fi
