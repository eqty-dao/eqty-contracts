// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Anchor} from "../src/Anchor.sol";

contract DeployAnchor is Script {
    function run() external returns (Anchor) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address eqtyToken = vm.envAddress("EQTY_TOKEN_ADDRESS");
        address redeemContract = vm.envOr("REDEEM_CONTRACT_ADDRESS", address(0));
        uint256 eqtyFee = vm.envOr("EQTY_FEE", uint256(100 ether)); // Default 100 EQTY per anchor

        vm.startBroadcast(deployerPrivateKey);

        Anchor anchor = new Anchor();

        // Configure EQTY token
        if (eqtyToken != address(0)) {
            anchor.setEqtyToken(eqtyToken);
            anchor.setEqtyFee(eqtyFee);
            console2.log("EQTY token:", eqtyToken);
            console2.log("EQTY fee:", eqtyFee);
        }

        // Configure Redeem contract for ETH payments
        if (redeemContract != address(0)) {
            anchor.setRedeemContract(redeemContract);
            console2.log("Redeem contract:", redeemContract);
        } else {
            console2.log("WARNING: Redeem contract not set - ETH payments disabled");
        }

        console2.log("Anchor deployed at:", address(anchor));

        vm.stopBroadcast();

        return anchor;
    }
}
