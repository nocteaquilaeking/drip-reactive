# Drip — demo video script (< 3 minutes)

Format: screen recording with captions (no voice-over needed). Walk the explorers in this order.

1. **Title card (5s)** — "Drip — set-and-forget recurring payments. No server, no keeper bot: the blockchain itself is the scheduler." Show the GitHub repo README architecture section.
2. **The problem (15s)** — Caption: "Recurring crypto payments today need a server or a keeper network watching the clock. Drip replaces that with Reactive Network's built-in CRON events."
3. **The setup (30s)** — Sepolia Etherscan: DripVault page. Show the `ScheduleConfigured` transaction (0x6eae54424e493c11cb3ba0fbfc5a9e46ffa0f033c9be1500c508ec10262ce05c): user deposited 50 DRIP once — 5 payments of 10 DRIP to the recipient.
4. **The timer (30s)** — Lasna Reactscan: DripScheduler page. Show `TickCounted` events arriving from CRON100 (~every 2 minutes) and the `CallbackRequested` event. Caption: "The scheduler lives on Lasna and counts the network's own CRON ticks. Nobody calls it — the network does."
5. **The payoff (40s)** — Back on Sepolia Etherscan: the vault's `Dripped` events and the recipient's DRIP balance going 0 → 10 → 20. Show one callback transaction from the Reactive callback proxy (0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4) calling `executeDrip`. Caption: "Every 2 ticks, a cross-chain callback releases the next payment — automatically."
6. **Safety (20s)** — Caption + code view: "The vault only obeys the official callback proxy, and only for this scheduler's identity. The user can pause or cancel and reclaim unspent funds at any time."
7. **Close (10s)** — "Drip: configure once, and the chain keeps the schedule. Built for the Reactive Omni Buildathon — Set It and Forget It." Repo URL on screen.

Explorer links:
- Vault: https://sepolia.etherscan.io/address/0x3cd538efa1e4a653c78d60d0ba5708c6f4ea5d51
- Token: https://sepolia.etherscan.io/address/0x262a38b0521c0cc6cda40f4d590192643d82db0d
- Scheduler: https://lasna.reactscan.net/address/0x49fc0e0a7f286e57e1c711cd02779825313db12a
