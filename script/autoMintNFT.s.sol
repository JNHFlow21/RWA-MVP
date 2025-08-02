// SPDX_License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BasicNFT} from "../src/testNFT/BasicNFT.sol";
import {DeployBasicNFT} from "./DeployBasicNFT.s.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract autoMintLuffyNFT is Script {
    string public constant LUFFY_URI = "ipfs://QmV2WHpdB9FcEApEqn1yAgLo7UovXG7qZjUNmMAjsEonH8";

    HelperConfig helperConfig = new HelperConfig();
    ChainConfig chainConfig = helperConfig.getActiveChainConfig();

    function run() public {
        address contractAddress = DevOpsTools.get_most_recent_deployment("BasicNFT", block.chainid);
        mintNFT(contractAddress);
    }

    function mintNFT(address contractAddress) public {
        vm.startBroadcast(chainConfig.deployerPrivateKey);
        BasicNFT(contractAddress).mintNFT(LUFFY_URI);
        vm.stopBroadcast();
    }
}
