// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DripScheduler} from "../src/DripScheduler.sol";

interface VmScriptLasna {
    function envUint(string calldata) external returns (uint256);
    function envAddress(string calldata) external returns (address);
    function startBroadcast(uint256) external;
    function stopBroadcast() external;
}

contract DeployLasna {
    VmScriptLasna private constant vm = VmScriptLasna(address(uint160(uint256(keccak256("hevm cheat code")))));
    function run() external returns (DripScheduler scheduler) {
        uint256 key = vm.envUint("LASNA_PRIVATE_KEY");
        address vault = vm.envAddress("DRIP_VAULT_ADDRESS");
        uint256 interval = vm.envUint("CRON_TICKS_PER_DRIP");
        vm.startBroadcast(key);
        scheduler = new DripScheduler(vault, interval);
        vm.stopBroadcast();
    }
}
