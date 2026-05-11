// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Anchor} from "../src/Anchor.sol";
import {EQTY} from "../src/EQTY.sol";
import {Redeem} from "../src/Redeem.sol";

contract Deploy is Script {
    // Base Mainnet EQTY Token (already deployed)
    address constant EQTY_TOKEN_MAINNET = 0xC71F37D9bF4C5d1E7Fe4bCcB97e6f30B11b37D29;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address foundationWallet = vm.envAddress("FOUNDATION_WALLET");
        uint256 initialExchangeRate = vm.envUint("INITIAL_EXCHANGE_RATE");
        uint128 redeemAmount = uint128(vm.envUint("REDEEM_AMOUNT"));
        uint16 anchorEthPremiumBps = uint16(vm.envUint("ANCHOR_ETH_PREMIUM_BPS"));
        uint256 eqtyFee = vm.envOr("EQTY_FEE", uint256(100 ether));

        bool isMainnet = block.chainid == 8453;
        address eqtyToken = vm.envOr("EQTY_TOKEN_ADDRESS", isMainnet ? EQTY_TOKEN_MAINNET : address(0));
        address redeemContract = vm.envOr("REDEEM_CONTRACT_ADDRESS", address(0));

        console2.log("Deploying protocol...");
        console2.log("  Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console2.log("  Foundation:", foundationWallet);
        console2.log("  Initial exchange rate:", initialExchangeRate);
        console2.log("  Redeem amount:", redeemAmount);
        console2.log("  Anchor ETH premium bps:", anchorEthPremiumBps);
        console2.log("  EQTY fee:", eqtyFee);

        vm.startBroadcast(deployerPrivateKey);

        if (eqtyToken == address(0)) {
            address bridgeWallet = vm.envAddress("BRIDGE_WALLET");
            uint256 mintDeadline = vm.envOr("MINT_DEADLINE", block.timestamp + 365 days);

            EQTY eqty = new EQTY(bridgeWallet, mintDeadline);
            eqtyToken = address(eqty);

            console2.log("EQTY deployed at:", eqtyToken);
            console2.log("  Bridge wallet:", bridgeWallet);
            console2.log("  Mint deadline:", mintDeadline);
        } else {
            console2.log("Reusing EQTY token:", eqtyToken);
        }

        if (redeemContract == address(0)) {
            Redeem redeem = new Redeem(
                eqtyToken, foundationWallet, initialExchangeRate, redeemAmount, anchorEthPremiumBps
            );
            redeemContract = address(redeem);

            console2.log("Redeem deployed at:", redeemContract);
        } else {
            console2.log("Reusing Redeem contract:", redeemContract);
        }

        Anchor anchor = new Anchor();
        anchor.setEqtyToken(eqtyToken);
        anchor.setEqtyFee(eqtyFee);
        anchor.setRedeemContract(redeemContract);

        vm.stopBroadcast();

        console2.log("");
        console2.log("Deployment complete");
        console2.log("  EQTY token:", eqtyToken);
        console2.log("  Redeem:", redeemContract);
        console2.log("  Anchor:", address(anchor));
    }
}
