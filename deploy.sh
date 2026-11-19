#!/usr/bin/env bash
set -euo pipefail

: "${SEPOLIA_RPC_URL:?Set Ethereum Sepolia RPC URL}"
: "${LASNA_RPC_URL:?Set Lasna RPC URL}"
: "${SEPOLIA_PRIVATE_KEY:?Set Sepolia deployer key}"
: "${LASNA_PRIVATE_KEY:?Set Lasna deployer key}"
: "${SEPOLIA_CALLBACK_PROXY:=0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4}"
: "${DRIP_SCHEDULER_ADDRESS:?Set predicted Lasna scheduler address before deployment}"
: "${DRIP_VAULT_ADDRESS:?Set predicted Ethereum Sepolia vault address before deployment}"
: "${CRON_TICKS_PER_DRIP:=2}"
: "${SCHEDULER_FUNDING:=1500000000000000000}"
export SEPOLIA_CALLBACK_PROXY CRON_TICKS_PER_DRIP SCHEDULER_FUNDING

echo "Deploying scheduler to Lasna (vault: $DRIP_VAULT_ADDRESS)..."
forge script script/DeployLasna.s.sol:DeployLasna --rpc-url "$LASNA_RPC_URL" --broadcast
echo "Scheduler: $DRIP_SCHEDULER_ADDRESS"

echo "Deploying token and vault to Ethereum Sepolia (scheduler: $DRIP_SCHEDULER_ADDRESS)..."
forge script script/DeployBase.s.sol:DeployBase --rpc-url "$SEPOLIA_RPC_URL" --broadcast
echo "Token and vault deployment transactions: broadcast/DeployBase.s.sol/11155111/run-latest.json"
echo "Scheduler deployment transaction: broadcast/DeployLasna.s.sol/5318007/run-latest.json"
if command -v jq >/dev/null 2>&1; then
  jq -r '.transactions[] | select(.transactionType == "CREATE") | "  \(.contractName): \(.contractAddress) tx=\(.hash)"' broadcast/DeployBase.s.sol/11155111/run-latest.json
  jq -r '.transactions[] | select(.transactionType == "CREATE") | "  \(.contractName): \(.contractAddress) tx=\(.hash)"' broadcast/DeployLasna.s.sol/5318007/run-latest.json
else
  echo "Install jq to print parsed deployed addresses and hashes; raw records are in broadcast/."
fi
