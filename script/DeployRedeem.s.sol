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

    // Base Sepolia EQTY Token (from env)
    address constant EQTY_TOKEN_TESTNET = address(0);

    // Foundation wallet (receives fees)
    address constant FOUNDATION_WALLET = 0x2Bc456799F3Cf071B10CE7216269471e0A40381a;

    // Initial exchange rate (ETH per 10k EQTY)
    uint256 constant INITIAL_RATE = 0.001 ether; // Example: 0.001 ETH per 10k EQTY

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Allow rate override from environment
        uint256 initialRate = vm.envOr("INITIAL_RATE", INITIAL_RATE);
        address envEqtyToken = vm.envOr("EQTY_TOKEN_ADDRESS", address(0));

        // Determine network
        bool isMainnet = block.chainid == 8453;
        address eqtyToken = isMainnet ? EQTY_TOKEN_MAINNET : envEqtyToken;

        require(eqtyToken != address(0), "EQTY token address not set (use EQTY_TOKEN_ADDRESS)");

        console2.log("Deploying RedeemEQTY...");
        console2.log("  Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console2.log("  EQTY Token:", eqtyToken);
        console2.log("  Foundation:", FOUNDATION_WALLET);
        console2.log("  Initial Rate:", initialRate);
        console2.log("  Owner: deployer (msg.sender)");

        vm.startBroadcast(deployerPrivateKey);

        RedeemEQTY redeemContract = new RedeemEQTY(eqtyToken, FOUNDATION_WALLET);

        // Set initial exchange rate (REQUIRED before first redeem)
        if (initialRate > 0) {
            redeemContract.setCurrentRate(initialRate);
            console2.log("  Initial rate set to:", initialRate);
        }

        vm.stopBroadcast();

        console2.log("");
        console2.log("RedeemEQTY deployed at:", address(redeemContract));
        console2.log("  Initial ETH fee: 0%");
        console2.log("  Initial EQTY fee: 0%");
        console2.log("  Redeem amount: 10,000 EQTY");
        console2.log("  Max rate change: 10% per redeem");
        console2.log("");
        console2.log("  IMPORTANT: Update OwnableNFT contract with:");
        console2.log("  ownable.setRedeemContract(", address(redeemContract), ")");
        console2.log("");
        console2.log("  To transfer ownership to DAO:");
        console2.log("  1. Call transferOwnership(newOwner)");
        console2.log("  2. New owner must call acceptOwnership()");
    }
}
