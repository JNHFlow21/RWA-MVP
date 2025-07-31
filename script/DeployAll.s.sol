// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {KycPassNFT} from "../src/KycPassNFT.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";

contract DeployAll is Script {
    uint8 constant DECIMALS = 18;

    HelperConfig helperConfig = new HelperConfig();
    ChainConfig chainConfig = helperConfig.getActiveChainConfig();
    address admin = vm.addr(chainConfig.deployerPrivateKey);

    function run() public returns (KycPassNFT, ChainConfig memory, VaultToken) {
        vm.startBroadcast(chainConfig.deployerPrivateKey);
        KycPassNFT kycPassNFT = new KycPassNFT("KycPassNFT", "KPNFT", admin);
        VaultToken vaultToken = new VaultToken("RWA-Share", "RWAS", DECIMALS, admin);
        vm.stopBroadcast();
        return (kycPassNFT, chainConfig, vaultToken);
    }
}
