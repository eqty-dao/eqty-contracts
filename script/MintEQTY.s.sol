// This mint script is for testing / testnet only.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {EQTY} from "../src/EQTY.sol";

contract MintEQTY is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address eqtyToken = vm.envAddress("EQTY_TOKEN_ADDRESS");
        address mintTo = vm.envOr("MINT_TO", vm.envAddress("FOUNDATION_WALLET"));
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(1_000_000 ether));

        vm.startBroadcast(deployerPrivateKey);

        EQTY(eqtyToken).mint(mintTo, mintAmount);

        vm.stopBroadcast();

        console2.log("Minted EQTY");
        console2.log("  Token:", eqtyToken);
        console2.log("  To:", mintTo);
        console2.log("  Amount:", mintAmount);
    }
}
