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

    // Foundation wallet configured in Redeem constructor
    address constant FOUNDATION_WALLET = 0x2Bc456799F3Cf071B10CE7216269471e0A40381a;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 initialExchangeRate = vm.envUint("INITIAL_EXCHANGE_RATE");
        uint128 redeemAmount = uint128(vm.envUint("REDEEM_AMOUNT"));

        // Determine network
        bool isMainnet = block.chainid == 8453;
        address eqtyToken = vm.envOr("EQTY_TOKEN_ADDRESS", isMainnet ? EQTY_TOKEN_MAINNET : address(0));

        console2.log("Deploying Redeem...");
        console2.log("  Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console2.log("  Foundation:", FOUNDATION_WALLET);
        console2.log("  Initial exchange rate:", initialExchangeRate);
        console2.log("  Redeem amount:", redeemAmount);

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

        Redeem redeemContract = new Redeem(eqtyToken, FOUNDATION_WALLET, initialExchangeRate, redeemAmount);

        vm.stopBroadcast();

        console2.log("");
        console2.log("Redeem deployed at:", address(redeemContract));
        console2.log("EQTY token:", eqtyToken);
        console2.log("  Initial exchange rate:", initialExchangeRate);
        console2.log("  Redeem amount:", redeemAmount);
        console2.log("  Max rate change: 10% per redeem");
        console2.log("");
        console2.log("  IMPORTANT: Update Anchor contract with:");
        console2.log("  anchor.setRedeemContract(", address(redeemContract), ")");
    }
}
