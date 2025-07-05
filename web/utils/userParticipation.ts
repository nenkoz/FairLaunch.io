import { ethers, BigNumber } from "ethers";
import { CONTRACTS } from "@/config/contracts";

interface ParticipantInfo {
    depositAmount: string;
    verified: boolean;
    userIdentifier: string;
    verificationTimestamp: string;
}

interface ProjectAllocation {
    participants: {
        tokens: string;
        percentage: number;
    };
    developer: {
        tokens: string;
        percentage: number;
    };
    liquidity: {
        tokens: string;
        percentage: number;
    };
}

export class UserParticipationManager {
    private provider: ethers.providers.Provider;
    private signer: ethers.Signer;
    private giveaway: ethers.Contract;
    private usdc: ethers.Contract;

    constructor(provider: ethers.providers.Provider, signer: ethers.Signer) {
        this.provider = provider;
        this.signer = signer;
        this.giveaway = new ethers.Contract(CONTRACTS.GIVEAWAY.address, CONTRACTS.GIVEAWAY.abi, signer);
        this.usdc = new ethers.Contract(CONTRACTS.USDC.address, CONTRACTS.USDC.abi, signer);
    }

    async registerPassportVerification(nullifier: BigNumber, userIdentifier: BigNumber): Promise<string> {
        try {
            console.log("🛡️ Registering passport verification...");

            const tx = await this.giveaway.registerPassportVerification(nullifier, userIdentifier);

            const receipt = await tx.wait();
            console.log("✅ Passport verified!");

            return receipt.transactionHash;
        } catch (error) {
            console.error("❌ Passport verification failed:", error);
            throw error;
        }
    }

    async depositToGiveaway(giveawayId: number, amount: string): Promise<string> {
        try {
            console.log("💰 Depositing to giveaway...");

            // Step 1: Approve USDC
            const amountWei = ethers.utils.parseUnits(amount, 6);
            const approveTx = await this.usdc.approve(CONTRACTS.GIVEAWAY.address, amountWei);
            await approveTx.wait();
            console.log("✅ USDC approved");

            // Step 2: Make deposit
            const depositTx = await this.giveaway.deposit(giveawayId, amountWei);
            const receipt = await depositTx.wait();
            console.log("✅ Deposit successful!");

            return receipt.transactionHash;
        } catch (error) {
            console.error("❌ Deposit failed:", error);
            throw error;
        }
    }

    async getParticipantInfo(giveawayId: number, participantAddress: string): Promise<ParticipantInfo> {
        try {
            const participant = await this.giveaway.getParticipant(giveawayId, participantAddress);
            const verification = await this.giveaway.getVerification(participantAddress);

            return {
                depositAmount: ethers.utils.formatUnits(participant.depositAmount, 6),
                verified: participant.verified,
                userIdentifier: participant.userIdentifier.toString(),
                verificationTimestamp: verification.timestamp.toString(),
            };
        } catch (error) {
            console.error("❌ Failed to get participant info:", error);
            throw error;
        }
    }

    // NEW: Get project allocation information for participants
    async getProjectAllocation(giveawayId: number): Promise<ProjectAllocation> {
        try {
            const [participantTokens, devTokens, liquidityTokens, participantPercentage, devPercentage, liquidityPercentage] = await this.giveaway.getAllocationBreakdown(giveawayId);

            return {
                participants: {
                    tokens: ethers.utils.formatEther(participantTokens),
                    percentage: participantPercentage.toNumber() / 100,
                },
                developer: {
                    tokens: ethers.utils.formatEther(devTokens),
                    percentage: devPercentage.toNumber() / 100,
                },
                liquidity: {
                    tokens: ethers.utils.formatEther(liquidityTokens),
                    percentage: liquidityPercentage.toNumber() / 100,
                },
            };
        } catch (error) {
            console.error("❌ Failed to get project allocation:", error);
            throw error;
        }
    }

    // NEW: Get available tokens for participants (excluding dev/liquidity)
    async getTokensForParticipants(giveawayId: number): Promise<string> {
        try {
            const tokensForParticipants = await this.giveaway.getTokensForParticipants(giveawayId);
            return ethers.utils.formatEther(tokensForParticipants);
        } catch (error) {
            console.error("❌ Failed to get tokens for participants:", error);
            throw error;
        }
    }

    // NEW: Get token price (for participants only)
    async getTokenPriceForParticipants(giveawayId: number): Promise<string> {
        try {
            const tokenPrice = await this.giveaway.getTokenPrice(giveawayId);
            return ethers.utils.formatUnits(tokenPrice, 6); // USDC per token
        } catch (error) {
            console.error("❌ Failed to get token price:", error);
            throw error;
        }
    }
}
