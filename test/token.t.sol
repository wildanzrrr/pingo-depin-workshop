// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";
import { ERC20Mock } from "../src/erc20mock.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract TokensTest is Test {
    ERC20Mock private usdc;
    address private constant ADMIN = address(0x1);
    address private constant USER = address(0x2);
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        usdc = new ERC20Mock(ADMIN, "USD Coin", "USDC", 100_000_000);
    }

    function testMintUsdcWithUser() public {
        vm.startPrank(USER);
        usdc.mint();
        uint256 userBalance = usdc.balanceOf(USER);
        assertEq(userBalance, 100_000_000, "User should have minted 100_000_000 USDC");
        vm.stopPrank();
    }

    function testMintTokensWithAdmin() public {
        vm.startPrank(ADMIN);
        usdc.mintTo(USER, 50_000_000);
        uint256 userBalance = usdc.balanceOf(USER);
        assertEq(userBalance, 50_000_000, "User should have minted 50_000_000 USDC");
        vm.stopPrank();
    }

    function testMintoToWithUser() public {
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, USER, MINTER_ROLE)
        );
        usdc.mintTo(USER, 50_000_000);
        vm.stopPrank();
    }

    function testDecimals() public view {
        uint8 decimals = usdc.decimals();
        assertEq(decimals, 6, "USDC should have 6 decimals");
    }

    function testSetOpenForTrade() public {
        vm.startPrank(ADMIN);
        usdc.setOpenForTrade(false);
        assertFalse(usdc.openForTrade(), "Trading should be disabled");
        vm.stopPrank();
    }

    function testTransferWithOpenForTrade() public {
        vm.startPrank(ADMIN);
        usdc.setOpenForTrade(true);
        vm.stopPrank();

        vm.startPrank(USER);
        usdc.mint();
        usdc.transfer(address(0x3), 10_000_000);
        assertEq(usdc.balanceOf(address(0x3)), 10_000_000, "10_000_000 USDC should be transferred");
        vm.stopPrank();
    }

    function testTransferWithClosedForTrade() public {
        vm.startPrank(ADMIN);
        usdc.setOpenForTrade(false);
        vm.stopPrank();

        vm.startPrank(USER);
        usdc.mint();
        bool success = usdc.transfer(address(0x3), 10_000_000);
        require(!success, "Transfer should have failed");
        assertEq(usdc.balanceOf(address(0x3)), 0, "No USDC should be transferred");
        vm.stopPrank();
    }
}
