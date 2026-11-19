// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal Omni interfaces, adapted from the official Reactive Network
/// docs and reactive-network/reactive-smart-contract-demos interface definitions.
interface ISystemContract {
    struct CallbackConfiguration_V_1_0 {
        uint256 chainId;
        address recipient;
        uint64 gasLimit;
        bytes payload;
    }

    function subscribe(uint256 chainId, address contractAddress, uint256 topic0,
        uint256 topic1, uint256 topic2, uint256 topic3) external;
    function requestCallbackV_1_0(CallbackConfiguration_V_1_0 calldata config) external;
}

interface IReactive {
    struct LogRecord {
        uint256 chainId;
        address contractAddress;
        uint256 topic0;
        uint256 topic1;
        uint256 topic2;
        uint256 topic3;
        bytes data;
        uint256 blockNumber;
        uint256 opCode;
        uint256 blockHash;
        uint256 txHash;
        uint256 logIndex;
    }
    function react(LogRecord memory log) external;
}

/// @dev Omni-style minimal AbstractReactive base. The address and wildcard
/// match the current Omni docs; deliberately contains no legacy vmOnly logic.
abstract contract AbstractReactive is IReactive {
    ISystemContract internal constant SYSTEM = ISystemContract(
        0x8888888888888888888888888888888888888888
    );
    uint256 internal constant REACTIVE_IGNORE = type(uint256).max;
    address internal constant LEGACY_CRON_EMITTER =
        0x0000000000000000000000000000000000fffFfF;

    modifier onlySystem() {
        require(msg.sender == address(SYSTEM), "Only system");
        _;
    }
}
