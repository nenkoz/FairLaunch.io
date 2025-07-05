// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory} from "../src/TokenFactory.sol";
import {Giveaway} from "../src/Giveaway.sol";
import {LaunchPlatform} from "../src/LaunchPlatform.sol";

/**
 * @title Complete System Deployment
 * @dev This is the PRIMARY deployment script for the entire platform
 * @notice Deploys TokenFactory, Giveaway, and LaunchPlatform in one transaction
 *
 * Usage:
 *   forge script script/DeployComplete.s.sol --rpc-url <RPC_URL> --broadcast --verify
 *
 * Environment Variables Required:
 *   - PRIVATE_KEY: Deployer private key
 *   - PLATFORM_FEE_RECIPIENT (optional): Fee recipient address
 *   - USDC_ADDRESS (optional): USDC contract address
 */
contract DeployComplete is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Contract constructor parameters
        address platformFeeRecipient = vm.envOr(
            "PLATFORM_FEE_RECIPIENT",
            deployer // Default to deployer if not set
        );

        // USDC address for giveaway contract
        address usdc = vm.envOr(
            "USDC_ADDRESS",
            address(0x765DE816845861e75A25fCA122bb6898B8B1282a) // CELO mainnet USDC
        );

        console.log("=== Complete System Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Platform Fee Recipient:", platformFeeRecipient);
        console.log("USDC Address:", usdc);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TokenFactory
        TokenFactory tokenFactory = new TokenFactory(platformFeeRecipient);
        console.log("TokenFactory deployed at:", address(tokenFactory));

        // Deploy Giveaway contract
        Giveaway giveaway = new Giveaway(usdc, platformFeeRecipient);
        console.log("Giveaway deployed at:", address(giveaway));

        // Deploy LaunchPlatform (orchestrator)
        LaunchPlatform launchPlatform = new LaunchPlatform(
            address(tokenFactory),
            address(giveaway),
            platformFeeRecipient
        );
        console.log("LaunchPlatform deployed at:", address(launchPlatform));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("TokenFactory:", address(tokenFactory));
        console.log("Giveaway:", address(giveaway));
        console.log("LaunchPlatform:", address(launchPlatform));
        console.log("Platform Fee Recipient:", platformFeeRecipient);
        console.log("USDC Address:", usdc);

        // Verify contracts are working
        console.log("\n=== Contract Verification ===");
        console.log("TokenFactory Owner:", tokenFactory.owner());
        console.log("Giveaway Owner:", giveaway.owner());
        console.log("LaunchPlatform Owner:", launchPlatform.owner());
        console.log("Creation Fee:", tokenFactory.CREATION_FEE());
        console.log("Min Initial Supply:", tokenFactory.MIN_INITIAL_SUPPLY());
        console.log("Max Initial Supply:", tokenFactory.MAX_INITIAL_SUPPLY());

        console.log("\n=== Frontend Integration Guide ===");
        console.log("PRIMARY INTERFACE: Use LaunchPlatform for simple UX");
        console.log("   - Single transaction to launch project");
        console.log("   - Automatic token creation + giveaway setup");
        console.log("   - Built-in parameter validation");

        console.log("\nADVANCED INTERFACE: Use individual contracts");
        console.log("   - TokenFactory: For standalone token creation");
        console.log("   - Giveaway: For existing tokens");
        console.log("   - Full control over each step");

        console.log("\n=== Environment Variables ===");
        console.log("# Primary (Recommended)");
        console.log("LAUNCH_PLATFORM_ADDRESS=", address(launchPlatform));
        console.log("");
        console.log("# Individual Contracts");
        console.log("TOKEN_FACTORY_ADDRESS=", address(tokenFactory));
        console.log("GIVEAWAY_ADDRESS=", address(giveaway));
        console.log("");
        console.log("# Configuration");
        console.log("PLATFORM_FEE_RECIPIENT=", platformFeeRecipient);
        console.log("USDC_ADDRESS=", usdc);

        console.log("\n=== Usage Recommendations ===");
        console.log("For 95% of use cases: Use LaunchPlatform.launchProject()");
        console.log(
            "For advanced users: Use TokenFactory + Giveaway separately"
        );
        console.log("For token-only projects: Use TokenFactory.createToken()");
        console.log("For existing tokens: Use Giveaway.createGiveaway()");
    }
}
