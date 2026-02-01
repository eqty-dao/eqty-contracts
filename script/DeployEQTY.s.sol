// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {EQTY} from "../src/EQTY.sol";

contract DeployEQTY is Script {
    function run() external returns (EQTY) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bridgeWallet = vm.envAddress("BRIDGE_WALLET");
        uint256 mintDeadline = vm.envOr("MINT_DEADLINE", block.timestamp + 365 days);
        
        vm.startBroadcast(deployerPrivateKey);
        
        EQTY eqty = new EQTY(bridgeWallet, mintDeadline);
        
        console2.log("EQTY deployed at:", address(eqty));
        console2.log("Bridge wallet:", bridgeWallet);
        console2.log("Mint deadline:", mintDeadline);
        console2.log("Cap:", eqty.cap());
        
        vm.stopBroadcast();
        
        return eqty;
    }
}
