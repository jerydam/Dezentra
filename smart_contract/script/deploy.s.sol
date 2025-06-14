// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DezentraLogistics} from "../src/logistic.sol";
import {Tether} from "../src/token.sol";

contract Deploy is Script {
    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Tether (USDT mock)
        Tether usdt = new Tether();
        console.log("Tether deployed at:", address(usdt));

        // Deploy DezentraLogistics with Tether address
        DezentraLogistics logistics = new DezentraLogistics(address(usdt));
        console.log("DezentraLogistics deployed at:", address(logistics));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}