// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VaultToken} from "../src/VaultToken.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";

contract DeployVaultToken is Script {
    uint8 constant DECIMALS = 6;

    HelperConfig helperConfig = new HelperConfig();
    ChainConfig chainConfig = helperConfig.getActiveChainConfig();
    address admin = vm.addr(chainConfig.deployerPrivateKey);

    function run() public returns (VaultToken, ChainConfig memory) {
        vm.startBroadcast(chainConfig.deployerPrivateKey);
        VaultToken vaultToken = new VaultToken("RWA-Share", "RWAS", DECIMALS, admin);
        vm.stopBroadcast();
        return (vaultToken, chainConfig);
    }
}
