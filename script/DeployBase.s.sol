// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DripToken} from "../src/DripToken.sol";
import {DripVault} from "../src/DripVault.sol";

interface VmScript {
    function envUint(string calldata) external returns (uint256);
    function envAddress(string calldata) external returns (address);
    function startBroadcast(uint256) external;
    function stopBroadcast() external;
}

contract DeployBase {
    VmScript private constant vm = VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));
    function run() external returns (DripToken token, DripVault vault) {
        uint256 key = vm.envUint("BASE_SEPOLIA_PRIVATE_KEY");
        address proxy = vm.envAddress("BASE_SEPOLIA_CALLBACK_PROXY");
        address reactive = vm.envAddress("DRIP_SCHEDULER_ADDRESS");
        vm.startBroadcast(key);
        token = new DripToken();
        vault = new DripVault(address(token), proxy, reactive);
        vm.stopBroadcast();
    }
}
