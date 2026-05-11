// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Redeem} from "../src/Redeem.sol";

/**
 * @title DeployRedeem
 * @notice Deployment script for Redeem contract
 *
 * Usage:
 *   forge script script/DeployRedeem.s.sol:DeployRedeem --rpc-url "$BASE_SEPOLIA_RPC_URL" --broadcast --verify
 */
contract DeployRedeem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address eqtyToken = vm.envAddress("EQTY_TOKEN_ADDRESS");
        address foundationWallet = vm.envAddress("FOUNDATION_WALLET");
        uint256 initialExchangeRate = vm.envUint("INITIAL_EXCHANGE_RATE");
        uint128 redeemAmount = uint128(vm.envUint("REDEEM_AMOUNT"));

        console2.log("Deploying Redeem...");
        console2.log("  EQTY token:", eqtyToken);
        console2.log("  Foundation:", foundationWallet);
        console2.log("  Initial exchange rate:", initialExchangeRate);
        console2.log("  Redeem amount:", redeemAmount);

        vm.startBroadcast(deployerPrivateKey);

        Redeem redeemContract = new Redeem(eqtyToken, foundationWallet, initialExchangeRate, redeemAmount);

        vm.stopBroadcast();

        console2.log("");
        console2.log("Redeem deployed at:", address(redeemContract));
        console2.log("  Initial exchange rate:", initialExchangeRate);
        console2.log("  Redeem amount:", redeemAmount);
        console2.log("  Max rate change: 10% per redeem");
        console2.log("");
        console2.log("  IMPORTANT: Update Anchor contract with:");
        console2.log("  anchor.setRedeemContract(", address(redeemContract), ")");
    }
}
