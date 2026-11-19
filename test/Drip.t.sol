// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";
import {DripScheduler} from "../src/DripScheduler.sol";
import {IReactive} from "../src/reactive/interfaces/IReactive.sol";
import {ISystemContract} from "../src/reactive/interfaces/ISystemContract.sol";

interface Vm {
    function prank(address) external;
    function expectRevert(bytes calldata) external;
    function etch(address, bytes calldata) external;
}

contract MockSystem {
    uint256 public subscriptions;
    uint256 public callbackRequests;
    function subscribe(uint256,address,uint256,uint256,uint256,uint256) external { subscriptions++; }
    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 calldata) external { callbackRequests++; }
    function deliver(address target, IReactive.LogRecord calldata log_) external {
        IReactive(payable(target)).react(log_);
    }
}

contract DripTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant PROXY = address(0xCA11);
    address private constant REACTIVE = address(0x1234);

    function testVaultCallbackAndCancel() external {
        DripToken token = new DripToken();
        DripVault vault = new DripVault(address(token), PROXY, REACTIVE);
        vm.prank(ALICE); token.faucet();
        vm.prank(ALICE); token.approve(address(vault), 100 ether);
        vm.prank(ALICE); vault.configure(BOB, 10 ether, 5);

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Only callback proxy"));
        vault.executeDrip(REACTIVE);
        vm.prank(PROXY);
        vm.expectRevert(abi.encodeWithSignature("CallbackNotAuthorized(address,address)", address(0x999), REACTIVE));
        vault.executeDrip(address(0x999));
        vm.prank(PROXY); vault.executeDrip(REACTIVE);
        require(token.balanceOf(BOB) == 10 ether, "recipient not paid");
        DripVault.Schedule memory s = vault.schedule();
        require(s.dripIndex == 1 && s.dripsRemaining == 4, "bad schedule state");

        vm.prank(ALICE); vault.cancel();
        require(token.balanceOf(ALICE) == 990 ether, "refund incorrect");
        require(vault.schedule().dripsRemaining == 0, "schedule not cancelled");
    }

    function testSchedulerCountsCronAndRequestsAtInterval() external {
        MockSystem mockSystem = new MockSystem();
        address systemAddress = 0x8888888888888888888888888888888888888888;
        vm.etch(systemAddress, address(mockSystem).code);
        DripScheduler scheduler = new DripScheduler(address(0xBEEF), 2);
        MockSystem system = MockSystem(systemAddress);
        require(system.subscriptions() == 1, "did not subscribe");

        IReactive.LogRecord memory unrelated = _cronRecord(1);
        unrelated.topic0 = 42;
        system.deliver(address(scheduler), unrelated);
        require(scheduler.ticks() == 0 && system.callbackRequests() == 0, "accepted non-cron");

        system.deliver(address(scheduler), _cronRecord(1));
        require(scheduler.ticks() == 1 && system.callbackRequests() == 0, "early callback");
        system.deliver(address(scheduler), _cronRecord(2));
        require(scheduler.ticks() == 2 && system.callbackRequests() == 1, "missing callback");
    }

    function _cronRecord(uint256 blockNumber) private pure returns (IReactive.LogRecord memory r) {
        r.chainId = 5318007;
        r.contractAddress = 0x0000000000000000000000000000000000fffFfF;
        r.topic0 = 0xb49937fb8970e19fd46d48f7e3fb00d659deac0347f79cd7cb542f0fc1503c70;
        r.blockNumber = blockNumber;
    }
}
