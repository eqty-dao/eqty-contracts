// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {EQTY} from "../src/EQTY.sol";
import {Redeem} from "../src/Redeem.sol";

/**
 * @title DeployRedeem
 * @notice Deployment script for Redeem contract
 *
 * Usage:
 *   # Testnet (Base Sepolia)
 *   forge script script/DeployRedeem.s.sol:DeployRedeem --rpc-url base_sepolia --broadcast --verify
 *
 *   # Mainnet (Base)
 *   forge script script/DeployRedeem.s.sol:DeployRedeem --rpc-url base_mainnet --broadcast --verify
 */
contract DeployRedeem is Script {
    // Base Mainnet EQTY Token (already deployed)
    address constant EQTY_TOKEN_MAINNET = 0xC71F37D9bF4C5d1E7Fe4bCcB97e6f30B11b37D29;

    // Foundation wallet (receives fees)
    address constant FOUNDATION_WALLET = 0x2Bc456799F3Cf071B10CE7216269471e0A40381a;

    // Initial exchange rate (ETH per 10k EQTY)
    uint256 constant INITIAL_RATE = 0.001 ether; // Example: 0.001 ETH per 10k EQTY

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Allow rate override from environment
        uint256 initialRate = vm.envOr("INITIAL_RATE", INITIAL_RATE);

        // Determine network
        bool isMainnet = block.chainid == 8453;
        address eqtyToken = vm.envOr("EQTY_TOKEN_ADDRESS", isMainnet ? EQTY_TOKEN_MAINNET : address(0));

        console2.log("Deploying Redeem...");
        console2.log("  Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console2.log("  Foundation:", FOUNDATION_WALLET);
        console2.log("  Initial Rate:", initialRate);
        console2.log("  Owner: deployer (msg.sender)");

        vm.startBroadcast(deployerPrivateKey);

        if (eqtyToken == address(0)) {
            address bridgeWallet = vm.envAddress("BRIDGE_WALLET");
            uint256 mintDeadline = vm.envOr("MINT_DEADLINE", block.timestamp + 365 days);

            EQTY eqty = new EQTY(bridgeWallet, mintDeadline);
            eqtyToken = address(eqty);

            console2.log("  EQTY deployed at:", eqtyToken);
            console2.log("  Bridge wallet:", bridgeWallet);
            console2.log("  Mint deadline:", mintDeadline);
        } else {
            console2.log("  Reusing EQTY token:", eqtyToken);
        }

        Redeem redeemContract = new Redeem(eqtyToken, FOUNDATION_WALLET);

        // Set initial exchange rate (REQUIRED before first redeem)
        if (initialRate > 0) {
            redeemContract.setCurrentRate(initialRate);
            console2.log("  Initial rate set to:", initialRate);
        }

        vm.stopBroadcast();

        console2.log("");
        console2.log("Redeem deployed at:", address(redeemContract));
        console2.log("EQTY token:", eqtyToken);
        console2.log("  Initial ETH fee: 0%");
        console2.log("  Initial EQTY fee: 0%");
        console2.log("  Redeem amount: 10,000 EQTY");
        console2.log("  Max rate change: 10% per redeem");
        console2.log("");
        console2.log("  IMPORTANT: Update Anchor contract with:");
        console2.log("  anchor.setRedeemContract(", address(redeemContract), ")");
        console2.log("");
        console2.log("  To transfer ownership to DAO:");
        console2.log("  1. Call transferOwnership(newOwner)");
        console2.log("  2. New owner must call acceptOwnership()");
    }
}
