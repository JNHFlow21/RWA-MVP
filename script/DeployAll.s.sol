// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";
import {DeployLib} from "./DeployLib.sol";

contract DeployAll is Script {
    uint8 constant DECIMALS = 18;

    HelperConfig helperConfig = new HelperConfig();
    ChainConfig chainConfig = helperConfig.getActiveChainConfig();
    address admin = vm.addr(chainConfig.deployerPrivateKey);

    function run() public returns (DeployLib.DeployConfig memory deployConfig) {
        vm.startBroadcast(chainConfig.deployerPrivateKey);
        deployConfig = DeployLib.deployAll(admin, admin);
        vm.stopBroadcast();

        vm.startPrank(admin);
        deployConfig.pass.grantRole(deployConfig.pass.KYC_ISSUER_ROLE(), admin);
        deployConfig.share.setVault(address(deployConfig.vault));
        vm.stopPrank();

        console2.log("Vault    :", address(deployConfig.vault));
        console2.log("USDC     :", address(deployConfig.usdc));
        console2.log("Share    :", address(deployConfig.share));
        console2.log("KycPass  :", address(deployConfig.pass));

        return deployConfig;
    }
}
