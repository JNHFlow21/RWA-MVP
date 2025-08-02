// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BasicNFT} from "../src/testNFT/BasicNFT.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";

contract DeployBasicNFT is Script {
    HelperConfig helperConfig = new HelperConfig();
    ChainConfig chainConfig = helperConfig.getActiveChainConfig();

    function run() external returns (BasicNFT) {
        vm.startBroadcast(chainConfig.deployerPrivateKey);
        BasicNFT basicNft = new BasicNFT("Luffy", "LFY");
        vm.stopBroadcast();
        return basicNft;
    }
}
