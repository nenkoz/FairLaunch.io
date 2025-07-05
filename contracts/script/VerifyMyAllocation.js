const { ethers } = require('ethers');
const { GiveawayMerkleTree } = require('./MerkleTreeUtils');

/**
 * 🛡️ PARTICIPANT VERIFICATION SCRIPT
 * 
 * This script allows participants to independently verify their token allocation
 * without trusting the project owner. It only uses on-chain data and public algorithms.
 * 
 * HOW TO USE:
 * 1. Install dependencies: npm install ethers
 * 2. Set environment variables or modify the script
 * 3. Run: node VerifyMyAllocation.js
 */

async function verifyMyAllocation() {
    console.log('🛡️ Independent Allocation Verification Tool\n');
    
    // ============ CONFIGURATION ============
    // TODO: Replace with your values
    const config = {
        // Blockchain connection
        rpcUrl: process.env.RPC_URL || 'https://alfajores-forno.celo-testnet.org',
        
        // Contract details
        contractAddress: process.env.CONTRACT_ADDRESS || '0x...', // Replace with actual contract address
        
        // Verification details
        giveawayId: process.env.GIVEAWAY_ID || '0',
        participantAddress: process.env.MY_ADDRESS || '0x...', // Your wallet address
        
        // Distribution data (from the published distribution file)
        distributionFile: process.env.DISTRIBUTION_FILE || 'giveaway_0_distribution.json',
        
        // Or specify claimed amounts directly
        claimedTokens: process.env.CLAIMED_TOKENS || null,
        claimedRefund: process.env.CLAIMED_REFUND || null,
    };
    
    // ============ VALIDATION ============
    if (config.contractAddress === '0x...') {
        console.error('❌ Please set CONTRACT_ADDRESS environment variable or modify the script');
        process.exit(1);
    }
    
    if (config.participantAddress === '0x...') {
        console.error('❌ Please set MY_ADDRESS environment variable or modify the script');
        process.exit(1);
    }
    
    try {
        // ============ SETUP ============
        console.log('🔧 Setting up verification...');
        console.log(`   RPC URL: ${config.rpcUrl}`);
        console.log(`   Contract: ${config.contractAddress}`);
        console.log(`   Giveaway ID: ${config.giveawayId}`);
        console.log(`   Participant: ${config.participantAddress}`);
        
        const provider = new ethers.providers.JsonRpcProvider(config.rpcUrl);
        
        // Basic contract ABI - only the functions we need for verification
        const contractABI = [
            "function getGiveaway(uint256) view returns (tuple(address projectOwner, address tokenAddress, uint256 startTime, uint256 endTime, uint256 maxAllocation, uint256 totalTokensForSale, uint256 totalDeposited, uint256 participantCount, bool finalized, bool cancelled, bytes32 merkleRoot, bool merkleEnabled))",
            "function getParticipant(uint256, address) view returns (tuple(uint256 depositAmount, uint256 userIdentifier, bool verified))",
            "function getGiveawayParticipants(uint256) view returns (address[])"
        ];
        
        const contract = new ethers.Contract(config.contractAddress, contractABI, provider);
        
        // ============ GET CLAIMED AMOUNTS ============
        let claimedTokens, claimedRefund;
        
        if (config.claimedTokens && config.claimedRefund) {
            // Use provided amounts
            claimedTokens = config.claimedTokens;
            claimedRefund = config.claimedRefund;
            console.log(`📋 Using provided claimed amounts`);
        } else {
            // Try to load from distribution file
            try {
                const fs = require('fs');
                const distributionData = JSON.parse(fs.readFileSync(config.distributionFile, 'utf8'));
                
                const myData = distributionData.participants.find(p => 
                    p.address.toLowerCase() === config.participantAddress.toLowerCase()
                );
                
                if (!myData) {
                    console.error(`❌ Participant ${config.participantAddress} not found in distribution file`);
                    process.exit(1);
                }
                
                claimedTokens = myData.tokenAmount;
                claimedRefund = myData.refundAmount;
                console.log(`📋 Loaded claimed amounts from distribution file`);
                
            } catch (error) {
                console.error('❌ Could not load distribution file. Please provide CLAIMED_TOKENS and CLAIMED_REFUND.');
                console.error('   Distribution file should be provided by the project owner.');
                process.exit(1);
            }
        }
        
        // ============ VERIFY ALLOCATION ============
        console.log('\n🔍 Starting verification...');
        
        const verification = await GiveawayMerkleTree.verifyParticipantAllocation(
            contract,
            parseInt(config.giveawayId),
            config.participantAddress,
            claimedTokens,
            claimedRefund
        );
        
        // ============ RESULTS ============
        console.log('\n' + '='.repeat(60));
        console.log('🎯 VERIFICATION RESULTS');
        console.log('='.repeat(60));
        
        if (verification.verified) {
            console.log('✅ SUCCESS: Your allocation is VERIFIED!');
            console.log('   The claimed amounts match the calculated amounts.');
            console.log('   You can safely claim your tokens.');
        } else {
            console.log('❌ FAILED: Your allocation does NOT match!');
            console.log('   The claimed amounts do not match the calculated amounts.');
            console.log('   Please contact the project owner.');
        }
        
        console.log('\n📊 Detailed Results:');
        console.log(`   Your deposit: ${ethers.utils.formatUnits(verification.onChainData.participantDeposit, 6)} USDC`);
        console.log(`   Calculated tokens: ${ethers.utils.formatEther(verification.calculatedTokens)}`);
        console.log(`   Claimed tokens: ${ethers.utils.formatEther(verification.claimedTokens)}`);
        console.log(`   Tokens match: ${verification.tokensMatch ? '✅' : '❌'}`);
        console.log(`   Calculated refund: ${ethers.utils.formatUnits(verification.calculatedRefund, 6)} USDC`);
        console.log(`   Claimed refund: ${ethers.utils.formatUnits(verification.claimedRefund, 6)} USDC`);
        console.log(`   Refund match: ${verification.refundMatch ? '✅' : '❌'}`);
        
        // ============ SAVE VERIFICATION REPORT ============
        const fs = require('fs');
        const reportFilename = `verification_report_${config.participantAddress.slice(0, 6)}_${Date.now()}.json`;
        
        const report = {
            timestamp: new Date().toISOString(),
            participant: config.participantAddress,
            giveawayId: config.giveawayId,
            contractAddress: config.contractAddress,
            verification: verification,
            verdict: verification.verified ? 'VERIFIED' : 'FAILED'
        };
        
        fs.writeFileSync(reportFilename, JSON.stringify(report, null, 2));
        console.log(`\n💾 Verification report saved to: ${reportFilename}`);
        
        // ============ NEXT STEPS ============
        console.log('\n🚀 Next Steps:');
        if (verification.verified) {
            console.log('   1. ✅ Your allocation is verified - you can claim your tokens');
            console.log('   2. 📋 Keep the verification report for your records');
            console.log('   3. 🎯 Use the merkle proof from the distribution file to claim');
        } else {
            console.log('   1. ❌ Contact the project owner with your verification report');
            console.log('   2. 📋 Do not claim tokens until the issue is resolved');
            console.log('   3. 🛡️ Share this verification script with other participants');
        }
        
    } catch (error) {
        console.error('❌ Verification failed with error:', error.message);
        console.error('   Please check your configuration and try again.');
        process.exit(1);
    }
}

// Run if called directly
if (require.main === module) {
    verifyMyAllocation().catch(console.error);
}

module.exports = { verifyMyAllocation }; 