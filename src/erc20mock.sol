// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ERC20Mock is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public mintAmount;
    bool public openForTrade = true;

    constructor(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        uint256 _amount
    )
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(MINTER_ROLE, _defaultAdmin);
        mintAmount = _amount;
    }

    function mint() external {
        _mint(msg.sender, mintAmount);
    }

    function mintTo(address account, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function setOpenForTrade(bool _openForTrade) external onlyRole(DEFAULT_ADMIN_ROLE) {
        openForTrade = _openForTrade;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (!openForTrade) {
            return false; // Trading is currently disabled
        }
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (!openForTrade) {
            return false; // Trading is currently disabled
        }
        return super.transfer(to, amount);
    }
}
