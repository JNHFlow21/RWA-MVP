// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {KycPassNFT} from "../src/KycPassNFT.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";

contract DeployKycPassNFT is Script {
    HelperConfig helperConfig = new HelperConfig();
    ChainConfig chainConfig = helperConfig.getActiveChainConfig();
    address admin = vm.addr(chainConfig.deployerPrivateKey);

    string svgValid = vm.readFile("image/valid.svg");
    string svgRevoke = vm.readFile("image/revoke.svg");

    function run() public returns (KycPassNFT, ChainConfig memory) {
        vm.startBroadcast(chainConfig.deployerPrivateKey);
        KycPassNFT kycPassNFT = new KycPassNFT("KycPassNFT", "KPNFT", admin, svgValid, svgRevoke);
        vm.stopBroadcast();
        return (kycPassNFT, chainConfig);
    }
}
