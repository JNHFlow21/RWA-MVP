// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";
import {IKycPassNFT} from "../src/interfaces/IKycPassNFT.sol";

import {KycPassNFT} from "../src/KycPassNFT.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {SimpleRwVault} from "../src/SimpleRwVault.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";

contract DeployAll is Script {

    struct DeployConfig {
        USDCMock usdc;
        VaultToken share;
        KycPassNFT pass;
        SimpleRwVault vault;
    }
    
    DeployConfig deployConfig;
    HelperConfig helperConfig = new HelperConfig();
    ChainConfig chainConfig = helperConfig.getActiveChainConfig();
    address admin = vm.addr(chainConfig.deployerPrivateKey);

    string svgValid = vm.readFile("image/valid.svg");
    string svgRevoke = vm.readFile("image/revoke.svg");
    uint8 constant _decimals = 6;

    function run() public returns (DeployConfig memory , ChainConfig memory) {
        vm.startBroadcast(chainConfig.deployerPrivateKey);

        deployAllContract();

        // 断言：确保每个合约其实已经有代码（部署成功）
        require(address(deployConfig.usdc).code.length > 0, "USDCMock has no code");
        require(address(deployConfig.share).code.length > 0, "VaultToken has no code");
        require(address(deployConfig.pass).code.length > 0, "KycPassNFT has no code");
        require(address(deployConfig.vault).code.length > 0, "SimpleRwVault has no code");

        deployConfig.pass.grantRole(deployConfig.pass.KYC_ISSUER_ROLE(), admin);
        deployConfig.share.setVault(address(deployConfig.vault));

        // 动态构造 meta（避免构造时固定的过期时间）
        IKycPassNFT.PassMeta memory meta = IKycPassNFT.PassMeta({
            tier: 1,
            expiresAt: uint64(block.timestamp + 5 minutes), // 改为 5 分钟有效期
            countryCode: bytes32("CN")
        });

        // mintpass
        uint256 tokenId = deployConfig.pass.mintPass(admin,meta);
        address owner = deployConfig.pass.ownerOf(tokenId);
        require(owner == admin, "minted token not owned by admin");

        vm.stopBroadcast();

        console2.log("Vault    :", address(deployConfig.vault));
        console2.log("USDC     :", address(deployConfig.usdc));
        console2.log("Share    :", address(deployConfig.share));
        console2.log("KycPass  :", address(deployConfig.pass));
        console2.log("TokenURI:",  deployConfig.pass.tokenURI(tokenId));

        return (deployConfig, chainConfig);
    }

    function deployAllContract() internal{
        deployConfig.usdc = new USDCMock(admin);
        deployConfig.share = new VaultToken("Share", "SHR", _decimals, admin);
        deployConfig.pass = new KycPassNFT("Pass", "PASS", admin, svgValid, svgRevoke);
        deployConfig.vault = new SimpleRwVault(deployConfig.usdc, deployConfig.share, deployConfig.pass, admin, "https://example.com", 0, 0);
    }
}
