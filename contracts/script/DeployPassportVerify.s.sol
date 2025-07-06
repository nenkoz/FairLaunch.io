// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PassportVerify} from "../src/PassportVerify.sol";

/**
 * @title PassportVerify Deployment Script
 * @dev Deploys the PassportVerify contract for Self.xyz integration
 * 
 * Usage:
 *   forge script script/DeployPassportVerify.s.sol --rpc-url <RPC_URL> --broadcast --verify
 * 
 * Environment Variables Required:
 *   - PRIVATE_KEY: Deployer private key
 *   - IDENTITY_VERIFICATION_HUB: Self.xyz IdentityVerificationHub address
 *   - VERIFICATION_CONFIG_ID: Self.xyz verification config ID
 *   - SCOPE: Scope for the verification (optional, defaults to "fair")
 */
contract DeployPassportVerify is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get Self.xyz configuration
        address identityVerificationHub = vm.envAddress("IDENTITY_VERIFICATION_HUB");
        bytes32 verificationConfigId = vm.envBytes32("VERIFICATION_CONFIG_ID");
        uint256 scope = 1; 

        console.log("=== PassportVerify Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Identity Verification Hub:", identityVerificationHub);
        console.log("Verification Config ID:", vm.toString(verificationConfigId));
        console.log("Scope:", scope);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PassportVerify contract
        PassportVerify passportVerify = new PassportVerify(
            identityVerificationHub,
            scope,
            verificationConfigId
        );

        vm.stopBroadcast();

        console.log("PassportVerify deployed at:", address(passportVerify));

        // Save deployment info
        string memory deploymentInfo = vm.toString(abi.encodePacked(
            '{"contractAddress":"', vm.toString(address(passportVerify)), '",',
            '"identityVerificationHub":"', vm.toString(identityVerificationHub), '",',
            '"verificationConfigId":"', vm.toString(verificationConfigId), '",',
            '"scope":"', vm.toString(scope), '",',
            '"deployer":"', vm.toString(deployer), '",',
            '"network":"', vm.toString(block.chainid), '",',
            '"deploymentTime":"', vm.toString(block.timestamp), '"}'
        ));

        try vm.writeFile("./deployments/passport-verify.json", deploymentInfo) {
            console.log("Deployment info saved to: ./deployments/passport-verify.json");
        } catch {
            console.log("Warning: Could not save deployment info to file");
        }

        console.log("\n=== Deployment Summary ===");
        console.log("PassportVerify:", address(passportVerify));
        console.log("Identity Verification Hub:", identityVerificationHub);
        console.log("Verification Config ID:", vm.toString(verificationConfigId));
        console.log("Scope:", scope);
        console.log("Deployment info saved to: ./deployments/passport-verify.json");

        console.log("\n=== Environment Variables ===");
        console.log("PASSPORT_VERIFY_ADDRESS=", address(passportVerify));
        console.log("IDENTITY_VERIFICATION_HUB=", identityVerificationHub);
        console.log("VERIFICATION_CONFIG_ID=", vm.toString(verificationConfigId));
        console.log("SCOPE=", scope);
    }
} 