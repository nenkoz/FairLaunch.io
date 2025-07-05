import { ethers } from "ethers";
import { CONTRACTS } from "@/config/contracts";

interface ClaimStatus {
    canClaim: boolean;
    reason: number;
    reasonText: string;
}

interface AllocationInfo {
    dev: {
        allocated: string;
        claimed: string;
        percentage: number;
        hasClaimed: boolean;
    };
    liquidity: {
        allocated: string;
        claimed: string;
        percentage: number;
        hasClaimed: boolean;
    };
}

interface ClaimAllocations {
    dev: ClaimStatus;
    liquidity: ClaimStatus;
}

export class ProjectFinalizationManager {
    private provider: ethers.providers.Provider;
    private signer: ethers.Signer;
    private giveaway: ethers.Contract;

    constructor(provider: ethers.providers.Provider, signer: ethers.Signer) {
        this.provider = provider;
        this.signer = signer;
        this.giveaway = new ethers.Contract(CONTRACTS.GIVEAWAY.address, CONTRACTS.GIVEAWAY.abi, signer);
    }

    async finalizeGiveaway(giveawayId: number): Promise<string> {
        try {
            console.log("🏁 Finalizing giveaway...");

            const tx = await this.giveaway.finalizeGiveaway(giveawayId);
            const receipt = await tx.wait();

            console.log("✅ Giveaway finalized!");
            return receipt.transactionHash;
        } catch (error) {
            console.error("❌ Finalization failed:", error);
            throw error;
        }
    }

    // NEW: Professional allocation claiming methods
    async claimDevTokens(giveawayId: number): Promise<string> {
        try {
            console.log("👨‍💻 Claiming developer tokens...");

            const tx = await this.giveaway.claimDevTokens(giveawayId);
            const receipt = await tx.wait();

            console.log("✅ Developer tokens claimed!");
            return receipt.transactionHash;
        } catch (error) {
            console.error("❌ Dev token claim failed:", error);
            throw error;
        }
    }

    async claimLiquidityTokens(giveawayId: number): Promise<string> {
        try {
            console.log("💧 Claiming liquidity tokens...");

            const tx = await this.giveaway.claimLiquidityTokens(giveawayId);
            const receipt = await tx.wait();

            console.log("✅ Liquidity tokens claimed!");
            return receipt.transactionHash;
        } catch (error) {
            console.error("❌ Liquidity token claim failed:", error);
            throw error;
        }
    }

    // NEW: Check if allocations can be claimed
    async canClaimAllocations(giveawayId: number): Promise<ClaimAllocations> {
        try {
            const [canClaimDev, devReason] = await this.giveaway.canClaimDevTokens(giveawayId);
            const [canClaimLiquidity, liquidityReason] = await this.giveaway.canClaimLiquidityTokens(giveawayId);

            return {
                dev: {
                    canClaim: canClaimDev,
                    reason: devReason,
                    reasonText: this.getClaimReasonText(devReason),
                },
                liquidity: {
                    canClaim: canClaimLiquidity,
                    reason: liquidityReason,
                    reasonText: this.getClaimReasonText(liquidityReason),
                },
            };
        } catch (error) {
            console.error("❌ Failed to check claim status:", error);
            throw error;
        }
    }

    getClaimReasonText(reason: number): string {
        const reasons = ["Can claim", "Giveaway not finalized", "Already claimed", "No allocation"];
        return reasons[reason] || "Unknown reason";
    }

    // NEW: Get allocation information
    async getAllocationInfo(giveawayId: number): Promise<AllocationInfo> {
        try {
            const [devTokensAllocated, devTokensClaimed, devPercentage] = await this.giveaway.getDevTokenInfo(giveawayId);

            const [liquidityTokensAllocated, liquidityTokensClaimed, liquidityPercentage] = await this.giveaway.getLiquidityTokenInfo(giveawayId);

            return {
                dev: {
                    allocated: ethers.utils.formatEther(devTokensAllocated),
                    claimed: ethers.utils.formatEther(devTokensClaimed),
                    percentage: devPercentage.toNumber() / 100,
                    hasClaimed: devTokensClaimed.gt(0),
                },
                liquidity: {
                    allocated: ethers.utils.formatEther(liquidityTokensAllocated),
                    claimed: ethers.utils.formatEther(liquidityTokensClaimed),
                    percentage: liquidityPercentage.toNumber() / 100,
                    hasClaimed: liquidityTokensClaimed.gt(0),
                },
            };
        } catch (error) {
            console.error("❌ Failed to get allocation info:", error);
            throw error;
        }
    }

    async generateMerkleDistribution(giveawayId: number): Promise<any> {
        try {
            console.log("🌳 Generating merkle distribution...");

            // This uses the MerkleTreeUtils.ts
            const { GiveawayMerkleTree } = require("../contracts/script/MerkleTreeUtils.js");

            const distribution = await GiveawayMerkleTree.generateDistributionOffChain(this.giveaway, giveawayId);

            console.log("✅ Merkle tree generated!");
            return distribution;
        } catch (error) {
            console.error("❌ Merkle generation failed:", error);
            throw error;
        }
    }

    async setMerkleRoot(giveawayId: number, merkleRoot: string): Promise<string> {
        try {
            console.log("📝 Setting merkle root...");

            const tx = await this.giveaway.setMerkleRoot(giveawayId, merkleRoot);
            const receipt = await tx.wait();

            console.log("✅ Merkle root set!");
            return receipt.transactionHash;
        } catch (error) {
            console.error("❌ Setting merkle root failed:", error);
            throw error;
        }
    }

    async claimTokens(giveawayId: number, claimData: any): Promise<string> {
        try {
            console.log("💰 Claiming tokens...");

            const tx = await this.giveaway.merkleClaim(giveawayId, claimData.claimIndex, claimData.participant, claimData.tokenAmount, claimData.refundAmount, claimData.merkleProof);

            const receipt = await tx.wait();
            console.log("✅ Tokens claimed!");

            return receipt.transactionHash;
        } catch (error) {
            console.error("❌ Claim failed:", error);
            throw error;
        }
    }

    // NEW: Complete professional launch workflow
    async completeProfessionalLaunch(giveawayId: number): Promise<{
        finalizeTx: string;
        merkleRootTx: string;
        devClaimTx: string | null;
        liquidityClaimTx: string;
        distribution: any;
    }> {
        try {
            console.log("🚀 Starting professional launch completion...");

            // Step 1: Finalize giveaway
            const finalizeTx = await this.finalizeGiveaway(giveawayId);
            console.log("✅ Step 1: Giveaway finalized");

            // Step 2: Generate merkle distribution
            const distribution = await this.generateMerkleDistribution(giveawayId);
            console.log("✅ Step 2: Merkle distribution generated");

            // Step 3: Set merkle root
            const merkleRootTx = await this.setMerkleRoot(giveawayId, distribution.merkleRoot);
            console.log("✅ Step 3: Merkle root set");

            // Step 4: Claim dev tokens (if any)
            const canClaim = await this.canClaimAllocations(giveawayId);
            let devClaimTx: string | null = null;
            if (canClaim.dev.canClaim) {
                devClaimTx = await this.claimDevTokens(giveawayId);
                console.log("✅ Step 4: Dev tokens claimed");
            }

            // Step 5: Claim liquidity tokens (always required)
            const liquidityClaimTx = await this.claimLiquidityTokens(giveawayId);
            console.log("✅ Step 5: Liquidity tokens claimed");

            console.log("🎉 Professional launch completed successfully!");

            return {
                finalizeTx,
                merkleRootTx,
                devClaimTx,
                liquidityClaimTx,
                distribution,
            };
        } catch (error) {
            console.error("❌ Professional launch completion failed:", error);
            throw error;
        }
    }
}
