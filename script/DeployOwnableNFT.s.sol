// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {OwnableNFT} from "../src/OwnableNFT.sol";

contract DeployOwnableNFT is Script {
    function run() external returns (OwnableNFT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address redeemContract = vm.envOr("REDEEM_CONTRACT_ADDRESS", address(0));

        vm.startBroadcast(deployerPrivateKey);

        OwnableNFT ownable = new OwnableNFT("Ownable", "OWN");

        // Configure Redeem contract
        if (redeemContract != address(0)) {
            ownable.setRedeemContract(redeemContract);
            console2.log("Redeem contract set to:", redeemContract);
        }

        console2.log("OwnableNFT deployed at:", address(ownable));

        vm.stopBroadcast();

        return ownable;
    }
}
