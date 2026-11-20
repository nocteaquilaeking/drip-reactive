# Drip

Drip is a first-version recurring DRIP payment demo for the Reactive Omni Buildathon, `Set It and Forget It` track. A user deposits the full schedule once; Reactive's Lasna timer later requests callbacks that release one installment at a time on Ethereum Sepolia.

## Architecture

`Lasna CRON100 → DripScheduler.react() → Omni SYSTEM callback request → Ethereum Sepolia callback proxy → DripVault.executeDrip() → recipient`

The reactive contract uses the Omni system at `0x8888888888888888888888888888888888888888` for subscriptions and `requestCallbackV_1_0`. Its CRON subscription listens on Lasna to the protocol's documented CRON emitter, `0x0000000000000000000000000000000000fffFfF`, and CRON100 topic `0xb49937fb8970e19fd46d48f7e3fb00d659deac0347f79cd7cb542f0fc1503c70`. CRON100 is emitted every 100 Lasna blocks (about 2 minutes). The configurable tick interval counts these events, so the default of 2 requests a drip about every 200 blocks.

Each request encodes `executeDrip(address)` with `address(0)` in the first argument. The callback system overwrites that leading address with the requesting reactive contract's identity. The vault requires both the Ethereum Sepolia callback proxy (`0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`) and the configured scheduler identity. A user can pause a schedule or cancel it and recover all unspent DRIP. This demo supports one active schedule per vault deployment.

The callback proxy bills the vault in Ethereum Sepolia ETH, and Lasna charges the scheduler in lREACT. Fund both contracts before expecting automation. Callback gas is set to 1,000,000. This value matters: the Sepolia callback proxy forwards the delivery transaction's gas minus a fixed overhead of about 200,000, and `executeDrip` needs roughly 284,000 gas. Earlier deployments of this project with limits of 250,000 and 500,000 starved every delivery inside the vault call (the proxy logged `CallbackFailure` each time); 1,000,000 forwards roughly 780,000 and the loop completes.

## Build and test

```sh
forge build
forge test
```

The project has no external dependencies. The minimal Reactive interfaces in `src/interfaces/ReactiveInterfaces.sol` are adapted from official Reactive docs and the Reactive Network demo interface pattern.

## Deploy

Set `SEPOLIA_RPC_URL`, `LASNA_RPC_URL`, `SEPOLIA_PRIVATE_KEY`, `LASNA_PRIVATE_KEY`, and `CRON_TICKS_PER_DRIP` (optional, defaults to 2). The Ethereum Sepolia callback proxy defaults to the documented address; override with `SEPOLIA_CALLBACK_PROXY` if the network configuration changes.

There is a deployment-address cycle because the vault authenticates a scheduler address while the scheduler needs its vault recipient. Before running `deploy.sh`, predict the CREATE addresses using the deployer accounts' next nonces, then set:

* `DRIP_SCHEDULER_ADDRESS`: predicted scheduler address on Lasna.
* `DRIP_VAULT_ADDRESS`: predicted vault address on Ethereum Sepolia.

Then run `./deploy.sh`. It submits Lasna first and Ethereum Sepolia second and prints the configured addresses. Check Foundry's `broadcast/` output for deployed token address and transaction hashes. Ensure the predicted addresses match the actual deployment results; each script deploys contracts in the documented order (Sepolia: token, then vault).

Deploy only these contracts for this demo; no deployment is performed by this repository. Configure the user's schedule by calling `faucet()` on DRIP, approving the vault, then calling `configure(recipient, amountPerDrip, totalDrips)`. The token faucet is intentionally public and demo-only.

### Deployments (live)

| Network | Contract | Address |
| --- | --- | --- |
| Ethereum Sepolia | DripToken | 0x262a38b0521c0cc6cda40f4d590192643d82db0d |
| Ethereum Sepolia | DripVault | 0x96A301C8AA409f0F826d5eDf06F8153c6e6498f6 |
| Lasna | DripScheduler | 0xF9d1E3cA81f6f105d8a913C8bdDC932ED7506b38 |

The live schedule on this vault: 5 drips of 10 DRIP each to `0x0F0c69250002aB838C2BeE7e6C56BB2e0b2ebB36`, one drip per 2 CRON100 ticks (configure transaction `0x7a64c1ba45bed17c8495d98c0004108bddbe455f3e862bb6195c5c17c248ea03`).

### Verified end-to-end loop

The full loop — CRON event on Lasna, callback request, proxy delivery on Sepolia, token transfer — has completed on-chain:

* Callback request (Lasna, scheduler → Omni system): [0x94aadbec283811c2268bce216e472d90ea480633b3d1fb82b63f574020b58b78](https://lasna.reactscan.net/tx/0x94aadbec283811c2268bce216e472d90ea480633b3d1fb82b63f574020b58b78)
* Callback delivery (Ethereum Sepolia, proxy → `DripVault.executeDrip`, `Dripped` event + 10 DRIP transfer to the recipient in the same transaction): [0x05e3434f2c551b595c9a6b449ff979b882cefe699025583a92326434411f32bc](https://sepolia.etherscan.io/tx/0x05e3434f2c551b595c9a6b449ff979b882cefe699025583a92326434411f32bc)

## Demo flow

1. On Ethereum Sepolia, verify `DripToken.faucet()` mints 1,000 DRIP to the caller.
2. Approve the vault for `amountPerDrip × totalDrips`, then call `configure` and verify the `ScheduleConfigured` event and vault token balance.
3. On Lasna, inspect the scheduler subscription transaction and its `TickCounted` events. After the configured number of CRON100 notifications, verify `CallbackRequested` and the Omni system's `CallbackRequest` for chain `11155111` and the vault recipient.
4. On Ethereum Sepolia, follow the callback delivery transaction from the documented proxy. Verify `Dripped` reports the user, recipient, installment, increasing index, and decreasing remaining count; verify the token transfer in the same transaction.
5. Repeat until `dripsRemaining` reaches zero, or call `pause()` / `cancel()` as the schedule owner and verify the remaining-token refund.

Explorers: [Lasna Reactscan](https://lasna.reactscan.net/address/0xF9d1E3cA81f6f105d8a913C8bdDC932ED7506b38) — scheduler and callback requests; [Ethereum Sepolia Etherscan](https://sepolia.etherscan.io/address/0x96A301C8AA409f0F826d5eDf06F8153c6e6498f6) — vault, schedule, and callback deliveries.

## Documentation references and implementation notes

* **Getting Started / Reactive Legacy vs. Reactive Omni**: Omni uses system address `0x888…8888`, `SYSTEM.subscribe`, system-authorized `react`, and `requestCallbackV_1_0`; legacy `vmOnly` and emitted `Callback` delivery are not used.
* **Reactive Contracts / Subscribing To CRON Events**: CRON100 topic and emitter, 100-block cadence, event routing by `topic0`, and six-argument wildcard subscription.
* **Reactive Contracts / Requesting Callbacks**: typed callback configuration and the leading placeholder address that is replaced by the requesting reactive contract identity.
* **Callback Contracts / Authorizing Callbacks**: callback delivery proxy plus injected reactive sender must both be checked.
* **Origins & Destinations**: Ethereum Sepolia is chain `11155111`, callback proxy `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`; Lasna is `5318007`.
* **Economy & System Interactions**: reactive work needs lREACT funding and callback recipient needs destination-chain native token funding.
* **Reactive Mainnet & Lasna Testnet**: Lasna RPC `https://lasna-rpc.rnk.dev/`, chain `5318007`, shared Omni system contract address.

The docs say the first 160 payload bits are replaced with the reactive identity; the interface behavior is protocol-managed, so local unit tests mock callback delivery rather than emulate that substitution. The docs do not provide a user-level recurring-payment registry or a standard ERC20 interface; this demo intentionally uses a single schedule and a small hand-written token.
