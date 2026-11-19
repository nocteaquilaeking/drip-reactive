// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractReactive} from "./reactive/base/AbstractReactive.sol";
import {IReactive} from "./reactive/interfaces/IReactive.sol";
import {ISystemContract} from "./reactive/interfaces/ISystemContract.sol";

/// @notice Lasna timer adapter. Cron100 is emitted about every 100 Lasna blocks;
/// cronTicksPerDrip_ makes the demo interval adjustable on top of that cadence.
/// Inherits the official Reactive Omni base contracts (vendored under
/// src/reactive/), which provide the subscription wildcard sentinel and the
/// pay()/coverDebt() fee-settlement machinery the system contract requires.
contract DripScheduler is AbstractReactive {
    uint256 public constant VAULT_CHAIN_ID = 11155111;
    address internal constant LEGACY_CRON_EMITTER =
        0x0000000000000000000000000000000000fffFfF;
    uint256 public constant CRON100_TOPIC_0 =
        0xb49937fb8970e19fd46d48f7e3fb00d659deac0347f79cd7cb542f0fc1503c70;
    uint64 public constant CALLBACK_GAS_LIMIT = 250_000;

    address public immutable vault;
    uint256 public immutable cronTicksPerDrip;
    uint256 public ticks;

    event CallbackRequested(address indexed vault, uint256 indexed tickCount);
    event TickCounted(uint256 indexed tickCount);

    constructor(address vault_, uint256 cronTicksPerDrip_) payable {
        require(vault_ != address(0) && cronTicksPerDrip_ > 0, "Invalid config");
        vault = vault_;
        cronTicksPerDrip = cronTicksPerDrip_;
        SYSTEM.subscribe(block.chainid, LEGACY_CRON_EMITTER, CRON100_TOPIC_0,
            REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    /// @notice Settles any outstanding fee debt from this contract's balance.
    function coverDebt() external {
        _coverDebt();
    }

    function react(IReactive.LogRecord calldata log_) external override onlySystem {
        if (log_.topic0 != CRON100_TOPIC_0 || log_.contractAddress != LEGACY_CRON_EMITTER) return;
        ticks += 1;
        emit TickCounted(ticks);
        if (ticks % cronTicksPerDrip != 0) return;

        bytes memory payload = abi.encodeWithSignature("executeDrip(address)", address(0));
        SYSTEM.requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0({
            chainId: VAULT_CHAIN_ID,
            recipient: vault,
            gasLimit: CALLBACK_GAS_LIMIT,
            payload: payload
        }));
        emit CallbackRequested(vault, ticks);
    }
}
