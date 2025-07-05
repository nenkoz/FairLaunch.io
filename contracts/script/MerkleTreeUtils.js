const { MerkleTree } = require('merkletreejs');
const { keccak256 } = require('ethers');

/**
 * Merkle Tree Utility for Giveaway Token Distribution
 * 
 * This utility generates merkle trees for gas-efficient token distribution
 * and creates proofs for individual claims.
 */
class GiveawayMerkleTree {
    constructor(participants) {
        this.participants = participants;
        this.tree = this.buildTree();
    }

    /**
     * Build merkle tree from participant data
     * @returns {MerkleTree} The constructed merkle tree
     */
    buildTree() {
        const leaves = this.participants.map((participant, index) => {
            return keccak256(
                ethers.utils.solidityPack(
                    ['uint256', 'address', 'uint256', 'uint256'],
                    [index, participant.address, participant.tokenAmount, participant.refundAmount]
                )
            );
        });

        return new MerkleTree(leaves, keccak256, { sortPairs: true });
    }

    /**
     * Get merkle root
     * @returns {string} The merkle root as hex string
     */
    getRoot() {
        return this.tree.getHexRoot();
    }

    /**
     * Get merkle proof for a specific participant
     * @param {number} index - Index of the participant
     * @returns {string[]} Array of proof hashes
     */
    getProof(index) {
        const leaf = keccak256(
            ethers.utils.solidityPack(
                ['uint256', 'address', 'uint256', 'uint256'],
                [
                    index,
                    this.participants[index].address,
                    this.participants[index].tokenAmount,
                    this.participants[index].refundAmount
                ]
            )
        );
        return this.tree.getHexProof(leaf);
    }

    /**
     * Verify a merkle proof
     * @param {number} index - Index of the participant
     * @param {string[]} proof - Merkle proof array
     * @returns {boolean} Whether the proof is valid
     */
    verifyProof(index, proof) {
        const leaf = keccak256(
            ethers.utils.solidityPack(
                ['uint256', 'address', 'uint256', 'uint256'],
                [
                    index,
                    this.participants[index].address,
                    this.participants[index].tokenAmount,
                    this.participants[index].refundAmount
                ]
            )
        );
        return this.tree.verify(proof, leaf, this.getRoot());
    }

    // ============ REMOVED: On-chain calculation method (inefficient) ============
    // Previously: generateDistributionFromContract() - made 1000s of blockchain calls
    // Now: Use generateDistributionOffChain() for maximum efficiency

    /**
     * 🔥 PRIMARY: Complete workflow with OFF-CHAIN calculations (maximum efficiency!)
     * @param {Contract} giveawayContract - Ethers contract instance
     * @param {number} giveawayId - ID of the giveaway
     * @param {Object} signer - Ethers signer (project owner)
     * @returns {Object} Distribution data and transaction receipt
     */
    static async deployMerkleDistribution(giveawayContract, giveawayId, signer) {
        console.log(`⚡ Deploying merkle distribution with OFF-CHAIN calculations for giveaway ${giveawayId}...`);
        
        // 1. Generate distribution data using OFF-CHAIN calculations
        const distribution = await this.generateDistributionOffChain(giveawayContract, giveawayId);
        
        // 2. Set merkle root in contract
        console.log(`📝 Setting merkle root in contract...`);
        const tx = await giveawayContract.connect(signer).setMerkleRoot(giveawayId, distribution.merkleRoot);
        const receipt = await tx.wait();
        
        console.log(`✅ Merkle root set! Transaction: ${receipt.transactionHash}`);
        console.log(`⚡ Used OFF-CHAIN calculations for maximum efficiency!`);
        
        return {
            distribution,
            transactionHash: receipt.transactionHash,
            gasUsed: receipt.gasUsed.toString()
        };
    }

    /**
     * 🔥 Get claim data for a specific participant
     * @param {Object} distribution - Distribution data from generateDistributionOffChain
     * @param {string} participantAddress - Address of the participant
     * @returns {Object} Claim data for the participant
     */
    static getClaimData(distribution, participantAddress) {
        const participant = distribution.participants.find(p => 
            p.address.toLowerCase() === participantAddress.toLowerCase()
        );
        
        if (!participant) {
            throw new Error(`Participant ${participantAddress} not found in distribution`);
        }
        
        return {
            claimIndex: participant.index,
            participant: participant.address,
            tokenAmount: participant.tokenAmount,
            refundAmount: participant.refundAmount,
            merkleProof: participant.proof
        };
    }

    /**
     * 🛡️ VERIFICATION: Independent verification utility for participants
     * @param {Contract} giveawayContract - Ethers contract instance
     * @param {number} giveawayId - ID of the giveaway
     * @param {string} participantAddress - Address of the participant
     * @param {string} claimedTokenAmount - Claimed token amount from distribution
     * @param {string} claimedRefundAmount - Claimed refund amount from distribution
     * @returns {Object} Verification result with detailed breakdown
     */
    static async verifyParticipantAllocation(giveawayContract, giveawayId, participantAddress, claimedTokenAmount, claimedRefundAmount) {
        console.log(`🛡️ Verifying allocation for participant ${participantAddress} in giveaway ${giveawayId}...`);
        
        // 1. Get on-chain data (this is the source of truth)
        const giveawayData = await giveawayContract.getGiveaway(giveawayId);
        const participantData = await giveawayContract.getParticipant(giveawayId, participantAddress);
        
        console.log(`📊 On-chain data verified:`);
        console.log(`   Participant deposit: ${ethers.utils.formatUnits(participantData.depositAmount, 6)} USDC`);
        console.log(`   Total deposits: ${ethers.utils.formatUnits(giveawayData.totalDeposited, 6)} USDC`);
        console.log(`   Max allocation: ${ethers.utils.formatUnits(giveawayData.maxAllocation, 6)} USDC`);
        console.log(`   Total tokens: ${ethers.utils.formatEther(giveawayData.totalTokensForSale)}`);
        console.log(`   Participant count: ${giveawayData.participantCount}`);
        
        // 2. Replicate the calculation logic independently
        const maxAllocation = giveawayData.maxAllocation;
        const totalTokensForSale = giveawayData.totalTokensForSale;
        const totalDeposited = giveawayData.totalDeposited;
        const participantCount = giveawayData.participantCount;
        const myDeposit = participantData.depositAmount;
        
        let calculatedTokens;
        let calculatedRefund;
        
        if (totalDeposited.lte(maxAllocation)) {
            // Under-allocated scenario
            console.log(`📊 Scenario: Under-allocated`);
            calculatedTokens = myDeposit.mul(totalTokensForSale).div(totalDeposited);
            calculatedRefund = ethers.BigNumber.from(0);
        } else {
            // Over-allocated scenario
            console.log(`📊 Scenario: Over-allocated`);
            const avgAllocation = maxAllocation.div(participantCount);
            console.log(`   Average allocation: ${ethers.utils.formatUnits(avgAllocation, 6)} USDC`);
            
            if (myDeposit.lt(avgAllocation)) {
                // Below average contribution
                console.log(`   Category: Below average contributor`);
                calculatedTokens = myDeposit.mul(totalTokensForSale).div(maxAllocation);
                calculatedRefund = ethers.BigNumber.from(0);
            } else {
                // Above average contribution - need to calculate global values
                console.log(`   Category: Above average contributor`);
                
                // Get all participants to calculate leftover and excess funds
                const allParticipants = await giveawayContract.getGiveawayParticipants(giveawayId);
                let totalLeftoverFunds = ethers.BigNumber.from(0);
                let totalExcessFunds = ethers.BigNumber.from(0);
                
                for (const addr of allParticipants) {
                    const p = await giveawayContract.getParticipant(giveawayId, addr);
                    if (p.depositAmount.lt(avgAllocation)) {
                        totalLeftoverFunds = totalLeftoverFunds.add(avgAllocation.sub(p.depositAmount));
                    } else {
                        totalExcessFunds = totalExcessFunds.add(p.depositAmount.sub(avgAllocation));
                    }
                }
                
                console.log(`   Total leftover funds: ${ethers.utils.formatUnits(totalLeftoverFunds, 6)} USDC`);
                console.log(`   Total excess funds: ${ethers.utils.formatUnits(totalExcessFunds, 6)} USDC`);
                
                // Calculate token allocation
                const baseAllocation = avgAllocation.mul(totalTokensForSale).div(maxAllocation);
                
                if (totalExcessFunds.gt(0)) {
                    const participantExcess = myDeposit.sub(avgAllocation);
                    const additionalAllocation = participantExcess
                        .mul(totalLeftoverFunds)
                        .mul(totalTokensForSale)
                        .div(totalExcessFunds.mul(maxAllocation));
                    calculatedTokens = baseAllocation.add(additionalAllocation);
                } else {
                    calculatedTokens = baseAllocation;
                }
                
                // Calculate refund
                const usedAmount = calculatedTokens.mul(maxAllocation).div(totalTokensForSale);
                calculatedRefund = myDeposit.sub(usedAmount);
            }
        }
        
        // 3. Compare with claimed amounts
        const claimedTokens = ethers.BigNumber.from(claimedTokenAmount);
        const claimedRefund = ethers.BigNumber.from(claimedRefundAmount);
        
        const tokensMatch = calculatedTokens.eq(claimedTokens);
        const refundMatch = calculatedRefund.eq(claimedRefund);
        const allMatch = tokensMatch && refundMatch;
        
        console.log(`\n🔍 Verification Results:`);
        console.log(`   Calculated tokens: ${ethers.utils.formatEther(calculatedTokens)}`);
        console.log(`   Claimed tokens: ${ethers.utils.formatEther(claimedTokens)}`);
        console.log(`   Tokens match: ${tokensMatch ? '✅' : '❌'}`);
        console.log(`   Calculated refund: ${ethers.utils.formatUnits(calculatedRefund, 6)} USDC`);
        console.log(`   Claimed refund: ${ethers.utils.formatUnits(claimedRefund, 6)} USDC`);
        console.log(`   Refund match: ${refundMatch ? '✅' : '❌'}`);
        console.log(`   Overall verification: ${allMatch ? '✅ VERIFIED' : '❌ FAILED'}`);
        
        return {
            verified: allMatch,
            calculatedTokens: calculatedTokens.toString(),
            claimedTokens: claimedTokens.toString(),
            tokensMatch,
            calculatedRefund: calculatedRefund.toString(),
            claimedRefund: claimedRefund.toString(),
            refundMatch,
            onChainData: {
                participantDeposit: participantData.depositAmount.toString(),
                totalDeposited: giveawayData.totalDeposited.toString(),
                maxAllocation: giveawayData.maxAllocation.toString(),
                totalTokensForSale: giveawayData.totalTokensForSale.toString(),
                participantCount: giveawayData.participantCount.toString()
            }
        };
    }

    /**
     * Legacy: Generate merkle distribution data for a giveaway (manual amounts)
     * @param {Object} giveawayData - Giveaway data with pre-calculated amounts
     * @returns {Object} Complete merkle distribution data
     */
    static generateDistribution(giveawayData) {
        const participants = giveawayData.participants.map((participant, index) => ({
            index,
            address: participant.address,
            tokenAmount: participant.tokenAmount,
            refundAmount: participant.refundAmount
        }));

        const merkleTree = new GiveawayMerkleTree(participants);
        
        return {
            merkleRoot: merkleTree.getRoot(),
            participants: participants.map((participant, index) => ({
                ...participant,
                proof: merkleTree.getProof(index)
            }))
        };
    }

    /**
     * 🔥 ULTIMATE: Pure off-chain calculations (maximum efficiency!)
     * @param {Contract} giveawayContract - Ethers contract instance
     * @param {number} giveawayId - ID of the giveaway
     * @returns {Object} Complete merkle distribution data with OFF-CHAIN calculations
     */
    static async generateDistributionOffChain(giveawayContract, giveawayId) {
        console.log(`⚡ Calculating merkle distribution OFF-CHAIN for giveaway ${giveawayId}...`);
        
        // 1. Get basic giveaway data and participants (minimal on-chain calls)
        const giveawayData = await giveawayContract.getGiveaway(giveawayId);
        const participantAddresses = await giveawayContract.getGiveawayParticipants(giveawayId);
        
        console.log(`👥 Found ${participantAddresses.length} participants`);
        console.log(`💰 Max allocation: ${ethers.utils.formatUnits(giveawayData.maxAllocation, 6)} USDC`);
        console.log(`🪙 Total tokens: ${ethers.utils.formatEther(giveawayData.totalTokensForSale)}`);
        
        // 2. Get all participant data in parallel
        const participantDataPromises = participantAddresses.map(async (address) => {
            const participantData = await giveawayContract.getParticipant(giveawayId, address);
            return {
                address,
                depositAmount: participantData.depositAmount
            };
        });
        
        const participantsData = await Promise.all(participantDataPromises);
        
        // 3. 🔥 REPLICATE THE SMART CONTRACT LOGIC IN JAVASCRIPT!
        const maxAllocation = giveawayData.maxAllocation;
        const totalTokensForSale = giveawayData.totalTokensForSale;
        const totalDeposited = giveawayData.totalDeposited;
        const participantCount = giveawayData.participantCount;
        
        let participants = [];
        
        if (totalDeposited.lte(maxAllocation)) {
            // Under-allocated scenario: simple proportional allocation
            console.log(`📊 Under-allocated scenario (${ethers.utils.formatUnits(totalDeposited, 6)} ≤ ${ethers.utils.formatUnits(maxAllocation, 6)} USDC)`);
            
            for (let i = 0; i < participantsData.length; i++) {
                const p = participantsData[i];
                const tokenAmount = p.depositAmount.mul(totalTokensForSale).div(totalDeposited);
                const refundAmount = ethers.BigNumber.from(0);
                
                participants.push({
                    index: i,
                    address: p.address,
                    tokenAmount: tokenAmount.toString(),
                    refundAmount: refundAmount.toString()
                });
                
                console.log(`✅ Participant ${i}: ${p.address} → ${ethers.utils.formatEther(tokenAmount)} tokens, ${ethers.utils.formatUnits(refundAmount, 6)} USDC refund`);
            }
        } else {
            // Over-allocated scenario: fair allocation algorithm
            console.log(`📊 Over-allocated scenario (${ethers.utils.formatUnits(totalDeposited, 6)} > ${ethers.utils.formatUnits(maxAllocation, 6)} USDC)`);
            
            const avgAllocation = maxAllocation.div(participantCount);
            console.log(`📊 Average allocation per participant: ${ethers.utils.formatUnits(avgAllocation, 6)} USDC`);
            
            // Calculate global values (like smart contract does)
            let totalLeftoverFunds = ethers.BigNumber.from(0);
            let totalExcessFunds = ethers.BigNumber.from(0);
            
            for (const p of participantsData) {
                if (p.depositAmount.lt(avgAllocation)) {
                    totalLeftoverFunds = totalLeftoverFunds.add(avgAllocation.sub(p.depositAmount));
                } else {
                    totalExcessFunds = totalExcessFunds.add(p.depositAmount.sub(avgAllocation));
                }
            }
            
            console.log(`📊 Total leftover funds: ${ethers.utils.formatUnits(totalLeftoverFunds, 6)} USDC`);
            console.log(`📊 Total excess funds: ${ethers.utils.formatUnits(totalExcessFunds, 6)} USDC`);
            
            // Calculate individual allocations
            for (let i = 0; i < participantsData.length; i++) {
                const p = participantsData[i];
                let tokenAmount;
                
                if (p.depositAmount.lt(avgAllocation)) {
                    // Person contributed less than average: gets tokens for what they paid
                    tokenAmount = p.depositAmount.mul(totalTokensForSale).div(maxAllocation);
                } else {
                    // Person contributed more than average: gets average allocation + share of leftover
                    const baseAllocation = avgAllocation.mul(totalTokensForSale).div(maxAllocation);
                    
                    if (totalExcessFunds.gt(0)) {
                        const participantExcess = p.depositAmount.sub(avgAllocation);
                        const additionalAllocation = participantExcess
                            .mul(totalLeftoverFunds)
                            .mul(totalTokensForSale)
                            .div(totalExcessFunds.mul(maxAllocation));
                        tokenAmount = baseAllocation.add(additionalAllocation);
                    } else {
                        tokenAmount = baseAllocation;
                    }
                }
                
                // Calculate refund
                const usedAmount = tokenAmount.mul(maxAllocation).div(totalTokensForSale);
                const refundAmount = p.depositAmount.sub(usedAmount);
                
                participants.push({
                    index: i,
                    address: p.address,
                    tokenAmount: tokenAmount.toString(),
                    refundAmount: refundAmount.toString()
                });
                
                console.log(`✅ Participant ${i}: ${p.address} → ${ethers.utils.formatEther(tokenAmount)} tokens, ${ethers.utils.formatUnits(refundAmount, 6)} USDC refund`);
            }
        }
        
        // 4. Build merkle tree with calculated amounts
        const merkleTree = new GiveawayMerkleTree(participants);
        const merkleRoot = merkleTree.getRoot();
        
        console.log(`🌳 Merkle root: ${merkleRoot}`);
        
        // 5. Generate proofs for each participant
        const participantsWithProofs = participants.map((participant, index) => ({
            ...participant,
            proof: merkleTree.getProof(index)
        }));
        
        return {
            merkleRoot,
            participants: participantsWithProofs,
            summary: {
                totalParticipants: participants.length,
                totalTokens: participants.reduce((sum, p) => sum.add(ethers.BigNumber.from(p.tokenAmount)), ethers.BigNumber.from(0)).toString(),
                totalRefunds: participants.reduce((sum, p) => sum.add(ethers.BigNumber.from(p.refundAmount)), ethers.BigNumber.from(0)).toString()
            },
            method: 'OFF_CHAIN'
        };
    }
}

/**
 * 🔥 COMPLETE: Full off-chain implementation example
 */
async function completeExample() {
    const ethers = require('ethers');
    
    // Setup provider and contract
    const provider = new ethers.providers.JsonRpcProvider('https://alfajores-forno.celo-testnet.org');
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    // Replace with your deployed contract address
    const giveawayAddress = '0x...';
    const giveawayABI = []; // Your contract ABI - replace with actual ABI
    const giveawayContract = new ethers.Contract(giveawayAddress, giveawayABI, provider);
    
    try {
        console.log('🚀 Full OFF-CHAIN Implementation Example\n');
        
        // 1. Deploy merkle distribution with off-chain calculations
        console.log('=== STEP 1: DEPLOY MERKLE DISTRIBUTION ===');
        const result = await GiveawayMerkleTree.deployMerkleDistribution(
            giveawayContract,
            0, // giveawayId
            signer
        );
        
        console.log('🎉 Distribution Summary:');
        console.log(`   Total Participants: ${result.distribution.summary.totalParticipants}`);
        console.log(`   Total Tokens: ${ethers.utils.formatEther(result.distribution.summary.totalTokens)}`);
        console.log(`   Total Refunds: ${ethers.utils.formatUnits(result.distribution.summary.totalRefunds, 6)} USDC`);
        console.log(`   Transaction Hash: ${result.transactionHash}`);
        console.log(`   Gas Used: ${result.gasUsed}`);
        console.log(`   Method: ${result.distribution.method}`);
        
        // 2. Get claim data for a specific participant
        console.log('\n=== STEP 2: GET CLAIM DATA ===');
        const claimData = GiveawayMerkleTree.getClaimData(
            result.distribution,
            result.distribution.participants[0].address // Use first participant
        );
        
        console.log('📋 Claim Data for Participant:');
        console.log(JSON.stringify(claimData, null, 2));
        
        // 3. VERIFICATION: Independent verification by participant
        console.log('\n=== STEP 3: INDEPENDENT VERIFICATION ===');
        const verification = await GiveawayMerkleTree.verifyParticipantAllocation(
            giveawayContract,
            0, // giveawayId
            claimData.participant,
            claimData.tokenAmount,
            claimData.refundAmount
        );
        
        console.log('🛡️ Verification completed!');
        console.log(`   Result: ${verification.verified ? '✅ VERIFIED' : '❌ FAILED'}`);
        
        // 4. Save distribution and verification data
        console.log('\n=== STEP 4: SAVE DATA ===');
        const fs = require('fs');
        
        // Save full distribution
        fs.writeFileSync(
            `giveaway_${0}_distribution.json`,
            JSON.stringify(result.distribution, null, 2)
        );
        
        // Save verification example
        fs.writeFileSync(
            `giveaway_${0}_verification_example.json`,
            JSON.stringify(verification, null, 2)
        );
        
        console.log('💾 Files saved:');
        console.log(`   - giveaway_${0}_distribution.json`);
        console.log(`   - giveaway_${0}_verification_example.json`);
        
        // 5. Show efficiency gains
        console.log('\n=== EFFICIENCY GAINS ===');
        console.log('⚡ OFF-CHAIN vs Traditional Approach:');
        console.log(`   Blockchain calls: ~${result.distribution.participants.length + 10} (vs ~${result.distribution.participants.length * 2 + 10} traditional)`);
        console.log(`   Calculation time: Seconds (vs minutes/hours)`);
        console.log(`   Gas costs: Minimal (vs expensive)`);
        console.log(`   Scalability: Unlimited (vs limited)`);
        console.log(`   Verification: Independent (vs trust-based)`);
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

/**
 * Legacy example usage function
 */
function exampleUsage() {
    // Example participant data
    const participants = [
        {
            address: '0x1234567890123456789012345678901234567890',
            tokenAmount: ethers.utils.parseEther('1000'), // 1000 tokens
            refundAmount: ethers.utils.parseUnits('50', 6) // 50 USDC
        },
        {
            address: '0x2345678901234567890123456789012345678901',
            tokenAmount: ethers.utils.parseEther('2000'), // 2000 tokens
            refundAmount: ethers.utils.parseUnits('100', 6) // 100 USDC
        },
        {
            address: '0x3456789012345678901234567890123456789012',
            tokenAmount: ethers.utils.parseEther('1500'), // 1500 tokens
            refundAmount: ethers.utils.parseUnits('75', 6) // 75 USDC
        }
    ];

    // Generate merkle tree
    const merkleTree = new GiveawayMerkleTree(participants);
    
    console.log('Merkle Root:', merkleTree.getRoot());
    console.log('Proof for participant 0:', merkleTree.getProof(0));
    console.log('Verification:', merkleTree.verifyProof(0, merkleTree.getProof(0)));
    
    // Generate complete distribution
    const distribution = GiveawayMerkleTree.generateDistribution({
        participants: participants
    });
    
    console.log('Complete Distribution:', JSON.stringify(distribution, null, 2));
}

module.exports = {
    GiveawayMerkleTree,
    completeExample,
    exampleUsage
};

// Export verification function for standalone use
module.exports.verifyAllocation = GiveawayMerkleTree.verifyParticipantAllocation; 