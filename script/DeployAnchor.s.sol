// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Anchor} from "../src/Anchor.sol";

contract DeployAnchor is Script {
    function run() external returns (Anchor) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address eqtyToken = vm.envAddress("EQTY_TOKEN_ADDRESS");
        uint256 anchorFee = vm.envOr("ANCHOR_FEE", uint256(0.1 ether)); // Default 0.1 EQTY
        
        vm.startBroadcast(deployerPrivateKey);
        
        Anchor anchor = new Anchor();
        
        // Configure anchor
        if (eqtyToken != address(0)) {
            anchor.setEqtyToken(eqtyToken);
            anchor.setAnchorFee(anchorFee);
        }
        
        console2.log("Anchor deployed at:", address(anchor));
        console2.log("EQTY token:", eqtyToken);
        console2.log("Anchor fee:", anchorFee);
        
        vm.stopBroadcast();
        
        return anchor;
    }
}
