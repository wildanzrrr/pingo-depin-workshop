// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

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

    function testTransferFromWithClosedForTrade() public {
        // Set trading closed
        vm.startPrank(ADMIN);
        usdc.setOpenForTrade(false);
        vm.stopPrank();

        // Mint tokens to USER
        vm.startPrank(USER);
        usdc.mint();
        usdc.approve(address(this), 10_000_000);
        vm.stopPrank();

        // Attempt transferFrom as contract (spender)
        uint256 beforeFrom = usdc.balanceOf(USER);
        uint256 beforeTo = usdc.balanceOf(address(0x3));
        bool success = usdc.transferFrom(USER, address(0x3), 10_000_000);
        require(!success, "transferFrom should have failed");
        assertEq(usdc.balanceOf(USER), beforeFrom, "Sender balance should not change");
        assertEq(usdc.balanceOf(address(0x3)), beforeTo, "Recipient balance should not change");
    }

    function testTransferFromWithOpenForTrade() public {
        // Set trading open
        vm.startPrank(ADMIN);
        usdc.setOpenForTrade(true);
        vm.stopPrank();

        // Mint tokens to USER
        vm.startPrank(USER);
        usdc.mint();
        usdc.approve(address(this), 10_000_000);
        vm.stopPrank();

        // Attempt transferFrom as contract (spender)
        uint256 beforeFrom = usdc.balanceOf(USER);
        uint256 beforeTo = usdc.balanceOf(address(0x3));
        bool success = usdc.transferFrom(USER, address(0x3), 10_000_000);
        require(success, "transferFrom should have succeeded");
        assertEq(usdc.balanceOf(USER), beforeFrom - 10_000_000, "Sender balance should decrease");
        assertEq(usdc.balanceOf(address(0x3)), beforeTo + 10_000_000, "Recipient balance should increase");
    }
}
