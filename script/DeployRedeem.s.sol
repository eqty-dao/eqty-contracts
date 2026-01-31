// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {RedeemEQTY} from "../src/RedeemEQTY.sol";

/**
 * @title DeployRedeemEQTY
 * @notice Deployment script for RedeemEQTY contract
 * 
 * Usage:
 *   # Testnet (Base Sepolia)
 *   forge script script/DeployRedeem.s.sol:DeployRedeemEQTY --rpc-url base_sepolia --broadcast --verify
 * 
 *   # Mainnet (Base)
 *   forge script script/DeployRedeem.s.sol:DeployRedeemEQTY --rpc-url base_mainnet --broadcast --verify
 */
contract DeployRedeemEQTY is Script {
    // Base Mainnet EQTY Token (already deployed)
    address constant EQTY_TOKEN_MAINNET = 0xC71F37D9bF4C5d1E7Fe4bCcB97e6f30B11b37D29;
    
    // Base Sepolia EQTY Token (TODO: Deploy test token or use existing)
    address constant EQTY_TOKEN_TESTNET = address(0); // <-- FILL IN
    
    // Foundation wallet (receives fees)
    address constant FOUNDATION_WALLET = 0x2Bc456799F3Cf071B10CE7216269471e0A40381a;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Determine network
        bool isMainnet = block.chainid == 8453;
        address eqtyToken = isMainnet ? EQTY_TOKEN_MAINNET : EQTY_TOKEN_TESTNET;
        
        require(eqtyToken != address(0), "EQTY token address not set");
        
        console2.log("Deploying RedeemEQTY...");
        console2.log("  Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console2.log("  EQTY Token:", eqtyToken);
        console2.log("  Foundation:", FOUNDATION_WALLET);
        console2.log("  Owner: deployer (msg.sender)");
        
        vm.startBroadcast(deployerPrivateKey);
        
        RedeemEQTY redeemContract = new RedeemEQTY(
            eqtyToken,
            FOUNDATION_WALLET
        );
        
        vm.stopBroadcast();
        
        console2.log("RedeemEQTY deployed at:", address(redeemContract));
        console2.log("  Initial ETH fee: 0%");
        console2.log("  Initial EQTY fee: 0%");
        console2.log("  Redeem amount: 10,000 EQTY");
    }
}
