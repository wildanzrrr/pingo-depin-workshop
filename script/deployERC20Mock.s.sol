// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { ERC20Mock } from "../src/erc20mock.sol";
import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployERC20Mock is Script {
    function run() public {
        vm.startBroadcast();

        address admin = vm.envAddress("MOCK_ADMIN_ADDRESS");
        string memory name = vm.envString("MOCK_TOKEN_NAME");
        string memory symbol = vm.envString("MOCK_TOKEN_SYMBOL");
        uint256 amount = vm.envUint("MOCK_MINT_AMOUNT");

        ERC20Mock token = new ERC20Mock(admin, name, symbol, amount);

        console.log("ERC20Mock deployed at:", address(token));
        vm.stopBroadcast();
    }
}
