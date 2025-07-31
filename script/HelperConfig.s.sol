// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

struct ChainConfig {
    // Deployer
    uint256 deployerPrivateKey;

}

contract HelperConfig is Script {
    // Active Chain Config
    ChainConfig public activeChainConfig;

    // Environment Variables
    // RPC_URL
    string constant SEPOLIA_RPC_URL = "SEPOLIA_RPC_URL";
    string constant MAINNET_RPC_URL = "MAINNET_RPC_URL";
    string constant ANVIL_RPC_URL = "ANVIL_RPC_URL";
    // Private Key
    string constant SEPOLIA_PRIVATE_KEY = "SEPOLIA_PRIVATE_KEY";
    string constant MAINNET_PRIVATE_KEY = "MAINNET_PRIVATE_KEY";
    string constant ANVIL_PRIVATE_KEY = "ANVIL_PRIVATE_KEY";

    constructor() {
        uint256 chainId = block.chainid;
        if (chainId == 31337 || chainId == 1337) {
            activeChainConfig = getOrCreateAnvilConfig();
        } else if (chainId == 11155111) {
            activeChainConfig = getSepoliaConfig();
        } else if (chainId == 1) {
            activeChainConfig = getMainnetConfig();
        } else {
            revert("Chain not supported");
        }
    }

    // 要想在部署脚本中可见，必须使用external
    function getActiveChainConfig() external view returns (ChainConfig memory) {
        return activeChainConfig;
    }

    function getOrCreateAnvilConfig() public view returns (ChainConfig memory AnvilConfig) {
        AnvilConfig = ChainConfig({
            deployerPrivateKey: vm.envUint(ANVIL_PRIVATE_KEY)
        });
        return AnvilConfig;
    }

    function getSepoliaConfig() public view returns (ChainConfig memory SepoliaConfig) {
        SepoliaConfig = ChainConfig({
            deployerPrivateKey: vm.envUint(SEPOLIA_PRIVATE_KEY)
        });
        return SepoliaConfig;
    }

    function getMainnetConfig() public pure returns (ChainConfig memory MainnetConfig) {
        return MainnetConfig;
    }
}
