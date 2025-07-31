// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVaultToken} from "./interfaces/IVaultToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract VaultToken is ERC20, AccessControl, IVaultToken{
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    address private _vaultAddr;

    uint8 private immutable i_decimals;

    modifier onlyVault {
        if(!hasRole(VAULT_ROLE, msg.sender)) revert IVaultToken__OnlyVault();
        _;
    }

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address admin) ERC20(_name, _symbol){
        if(admin == address(0)) revert IVaultToken__ZeroAddress();
        i_decimals = _decimals;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return i_decimals; // 部署时传 6（USDC 路径）或 18（ETH 路径）
    }

    function vault() external view returns (address){
        return _vaultAddr;
    }

    function setVault(address vaultAddr) external onlyRole(DEFAULT_ADMIN_ROLE){
        if(vaultAddr == address(0)) revert IVaultToken__ZeroAddress();
        if(_vaultAddr != address(0)) revert IVaultToken__VaultAlreadySet();

        _vaultAddr = vaultAddr;
        _grantRole(VAULT_ROLE, vaultAddr);
        emit VaultSet(vaultAddr);
    }

    function mint(address to, uint256 shares) external onlyVault{
        _mint(to, shares);
    }

    function burn(address from, uint256 shares) external onlyVault{
        _burn(from,shares);
    }
}