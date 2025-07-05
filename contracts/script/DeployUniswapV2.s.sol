// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {UniswapV2Factory} from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
import {UniswapV2Router02} from "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";

// import { WETH9 } from "v2-periphery/contracts/WETH9.sol";

// contract DeployUniswapV2 is Script {
//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         address deployer = vm.addr(deployerPrivateKey);
        
//         vm.startBroadcast(deployerPrivateKey);
        
//         // Deploy WETH9
//         WETH9 weth = new WETH9();
        
//         // Deploy Uniswap Factory (set feeToSetter to deployer)
//         UniswapV2Factory factory = new UniswapV2Factory(deployer);
        
//         // Deploy Router02 with factory & weth addresses
//         UniswapV2Router02 router = new UniswapV2Router02(address(factory), address(weth));
        
//         vm.stopBroadcast();
        
//         // Log deployed addresses
//         console2.log("=== Uniswap V2 Deployment Complete ===");
//         console2.log("Deployer:   ", deployer);
//         console2.log("WETH9:      ", address(weth));
//         console2.log("Factory:    ", address(factory));
//         console2.log("Router02:   ", address(router));
//         console2.log("=====================================");
//     }
// }