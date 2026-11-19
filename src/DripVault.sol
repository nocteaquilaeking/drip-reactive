// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractCallback} from "./reactive/base/AbstractCallback.sol";
import {IPayable} from "./reactive/interfaces/IPayable.sol";

interface IERC20Drip {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Holds one demo schedule at a time and releases funds only through
/// authenticated Reactive callbacks on the destination chain. Inherits the
/// official AbstractCallback base (vendored under src/reactive/), which wires
/// this contract to the chain's callback proxy for fee settlement (pay() /
/// coverDebt()) and provides the callback-sender authentication modifier.
contract DripVault is AbstractCallback {
    struct Schedule {
        address user;
        address recipient;
        uint256 amountPerDrip;
        uint256 totalDrips;
        uint256 dripsRemaining;
        uint256 dripIndex;
        bool paused;
    }

    IERC20Drip public immutable token;
    Schedule private _schedule;

    event ScheduleConfigured(address indexed user, address indexed recipient, uint256 amount, uint256 totalDrips);
    event Dripped(address indexed user, address indexed recipient, uint256 amount, uint256 dripIndex, uint256 dripsRemaining);
    event SchedulePaused(address indexed user);
    event ScheduleCancelled(address indexed user, uint256 refunded);

    constructor(address token_, address callbackProxy_, address reactiveContract_)
        AbstractCallback(IPayable(payable(callbackProxy_)), reactiveContract_)
    {
        require(token_ != address(0) && callbackProxy_ != address(0) && reactiveContract_ != address(0), "Zero address");
        token = IERC20Drip(token_);
    }

    /// @notice The callback proxy this vault pays delivery fees to.
    function callbackProxy() external view returns (address) {
        return address(_SERVICE_PROVIDER);
    }

    /// @notice The reactive contract whose callbacks this vault accepts.
    function reactiveContract() external view returns (address) {
        return _CALLBACK_SENDER;
    }

    /// @notice Settles any outstanding fee debt from this contract's balance.
    function coverDebt() external {
        _coverDebt();
    }

    function configure(address recipient, uint256 amountPerDrip, uint256 totalDrips) external {
        require(_schedule.user == address(0) || _schedule.dripsRemaining == 0, "Schedule active");
        require(recipient != address(0) && recipient != msg.sender, "Invalid recipient");
        require(amountPerDrip > 0 && totalDrips > 0, "Invalid schedule");
        uint256 depositAmount = amountPerDrip * totalDrips;
        require(token.transferFrom(msg.sender, address(this), depositAmount), "Deposit failed");
        _schedule = Schedule(msg.sender, recipient, amountPerDrip, totalDrips, totalDrips, 0, false);
        emit ScheduleConfigured(msg.sender, recipient, amountPerDrip, totalDrips);
    }

    /// @dev The callback proxy overwrites the first payload address with the
    /// requesting reactive contract's identity. Both checks are required:
    /// the caller must be the proxy, and the injected identity must be the
    /// configured scheduler (enforced by the onlyCallbackSender modifier).
    function executeDrip(address reactiveIdentity) external onlyCallbackSender(reactiveIdentity) {
        require(msg.sender == address(_SERVICE_PROVIDER), "Only callback proxy");
        Schedule storage s = _schedule;
        require(s.user != address(0) && s.dripsRemaining > 0 && !s.paused, "No active schedule");

        s.dripsRemaining -= 1;
        s.dripIndex += 1;
        require(token.transfer(s.recipient, s.amountPerDrip), "Transfer failed");
        emit Dripped(s.user, s.recipient, s.amountPerDrip, s.dripIndex, s.dripsRemaining);
    }

    function pause() external onlyUser {
        require(_schedule.dripsRemaining > 0, "No active schedule");
        _schedule.paused = true;
        emit SchedulePaused(msg.sender);
    }

    function cancel() external onlyUser {
        Schedule storage s = _schedule;
        uint256 refund = s.amountPerDrip * s.dripsRemaining;
        address user = s.user;
        s.dripsRemaining = 0;
        s.paused = true;
        if (refund > 0) require(token.transfer(user, refund), "Refund failed");
        emit ScheduleCancelled(user, refund);
    }

    function schedule() external view returns (Schedule memory) { return _schedule; }

    modifier onlyUser() {
        require(msg.sender == _schedule.user && _schedule.user != address(0), "Only schedule owner");
        _;
    }
}
