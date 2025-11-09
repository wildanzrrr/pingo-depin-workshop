// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { DePINNetwork } from "../src/DePINNetwork.sol";

contract DeployDePINNetwork is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        DePINNetwork depinNetwork = new DePINNetwork();

        console.log("DePINNetwork deployed at:", address(depinNetwork));

        vm.stopBroadcast();

        // Log deployment info
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Contract Address:", address(depinNetwork));
        console.log("==========================");
        console.log("");
    }
}
