// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PassportVerify} from "../src/PassportVerify.sol";

/**
 * @title SetScope Script
 * @dev Script to update the scope for the PassportVerify contract
 * 
 * Usage:
 *   CONTRACT_ADDRESS=<address> NEW_SCOPE=<scope> forge script script/SetScope.s.sol:SetScope --rpc-url <RPC_URL> --broadcast
 * 
 * Environment Variables Required:
 *   - PRIVATE_KEY: Deployer private key (must be the contract owner)
 *   - CONTRACT_ADDRESS: Address of the PassportVerify contract
 *   - NEW_SCOPE: New scope value to set
 */
contract SetScope is Script {
    function setUp() public {}

    function run() public {
        // Get parameters from environment variables
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        uint256 newScope = vm.envUint("NEW_SCOPE");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Set Scope Script ===");
        console.log("Deployer:", deployer);
        console.log("Contract Address:", contractAddress);
        console.log("New Scope:", newScope);

        // Get contract instance
        PassportVerify passportVerify = PassportVerify(contractAddress);

        // Check if deployer is the owner
        address contractOwner = passportVerify.owner();
        console.log("Contract Owner:", contractOwner);
        
        if (deployer != contractOwner) {
            console.log("ERROR: Deployer is not the contract owner!");
            console.log("Only the contract owner can call setScope()");
            revert("Not authorized: caller is not the owner");
        }

        // Get current scope for comparison
        try passportVerify.scope() returns (uint256 currentScope) {
            console.log("Current scope:", currentScope);
            
            if (currentScope == newScope) {
                console.log("WARNING: New scope is the same as current scope");
                console.log("No action needed");
                return;
            }
        } catch {
            console.log("Could not read current scope");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Call setScope function
        console.log("Calling setScope...");
        try passportVerify.setScope(newScope) {
            console.log("setScope() called successfully");
        } catch Error(string memory reason) {
            console.log("ERROR: setScope() failed with reason:", reason);
            revert(reason);
        } catch {
            console.log("ERROR: setScope() failed with unknown error");
            revert("Unknown error in setScope");
        }

        vm.stopBroadcast();

        // Verify the scope was updated
        try passportVerify.scope() returns (uint256 updatedScope) {
            console.log("Updated scope:", updatedScope);
            
            if (updatedScope == newScope) {
                console.log("Scope update successful!");
            } else {
                console.log("Scope update failed - scope mismatch");
                console.log("Expected:", newScope);
                console.log("Actual:", updatedScope);
            }
        } catch {
            console.log("Could not verify updated scope");
        }

        console.log("\n=== Scope Update Summary ===");
        console.log("Contract:", contractAddress);
        console.log("Owner:", contractOwner);
        console.log("New Scope:", newScope);
        console.log("Transaction completed successfully!");
    }
} 