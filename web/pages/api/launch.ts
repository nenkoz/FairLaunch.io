import { ethers } from "ethers";
import { NextApiRequest, NextApiResponse } from "next";
import { CONTRACTS, FEES, } from "@/config/contracts";
import { AllocationValidator } from "@/utils/allocationValidation";
import redis from "@/lib/redis";

interface LaunchProjectRequest {
    name: string;
    symbol: string;
    description: string;
    initialSupply: string;
    maxSupply: string;
    startTime: string;
    endTime: string;
    maxAllocation: string;
    tokensForGiveaway: string;
    devPercentage: number; // NEW: Developer allocation (0-5000 basis points)
    liquidityPercentage: number; // NEW: Liquidity allocation (2000-5000 basis points)
    enableTradingImmediately: boolean;
    creatorAddress: string;
}

interface LaunchProjectResponse {
    success: boolean;
    data?: {
        launchId: string;
        tokenAddress: string;
        giveawayId: string;
        transactionHash: string;
        allocation: {
            dev: {
                percentage: number;
                tokens: string;
            };
            liquidity: {
                percentage: number;
                tokens: string;
            };
            participants: {
                percentage: number;
                tokens: string;
            };
        };
    };
    error?: string;
    details?: string[];
}

export default async function launchProject(req: NextApiRequest, res: NextApiResponse<LaunchProjectResponse>) {
    try {
        const {
            name,
            symbol,
            description,
            initialSupply,
            maxSupply,
            startTime,
            endTime,
            maxAllocation,
            tokensForGiveaway,
            devPercentage, // NEW: Developer allocation (0-5000 basis points)
            liquidityPercentage, // NEW: Liquidity allocation (2000-5000 basis points)
            enableTradingImmediately,
            creatorAddress,
        } = req.body as LaunchProjectRequest;

     
        const tickerDt = await redis.sismember(`project_tickers`, symbol);
        if (tickerDt) {
            return res.status(400).json({success: false, error: " ticker already exists" });
        }

        // 1. Validate professional allocation parameters
        const validation = AllocationValidator.validateAllocation(devPercentage, liquidityPercentage);

        if (!validation.isValid) {
            return res.status(400).json({
                success: false,
                error: "Invalid allocation parameters",
                details: validation.errors,
            });
        }

        // 2. Setup contracts
        const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL!);
        const wallet = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY!, provider);

        const launchPlatform = new ethers.Contract(CONTRACTS.LAUNCH_PLATFORM.address, CONTRACTS.LAUNCH_PLATFORM.abi, wallet);

        // 3. Prepare parameters with professional allocations
        const tokenParams = {
            name,
            symbol,
            initialSupply: ethers.utils.parseEther(initialSupply),
            maxSupply: ethers.utils.parseEther(maxSupply),
            description,
        };

        const giveawayParams = {
            startTime: Math.floor(new Date(startTime).getTime() / 1000),
            endTime: Math.floor(new Date(endTime).getTime() / 1000),
            maxAllocation: ethers.utils.parseUnits(maxAllocation, 6), // USDC decimals
            tokensForGiveaway: ethers.utils.parseEther(tokensForGiveaway),
            devPercentage, // Basis points (e.g., 1000 = 10%)
            liquidityPercentage, // Basis points (e.g., 2000 = 20%)
            enableTradingImmediately,
        };

        // 4. Execute single transaction with professional parameters
        const tx = await launchPlatform.launchProject(tokenParams, giveawayParams, {
            value: FEES.TOKEN_CREATION,
            gasLimit: 2500000, // Increased for allocation features
        });

        const receipt = await tx.wait();

        // 5. Extract results from events
        const projectLaunchedEvent = receipt.events?.find((e: any) => e.event === "ProjectLaunched");

        const { launchId, tokenAddress, giveawayId, devPercentage: eventDevPercentage, liquidityPercentage: eventLiquidityPercentage } = projectLaunchedEvent.args;

        // 6. Calculate token breakdown for frontend
        const tokenBreakdown = AllocationValidator.calculateTokenBreakdown(ethers.utils.parseEther(tokensForGiveaway), devPercentage, liquidityPercentage);

        const launchProjectData = {
            name,
            symbol,
            description,
            address: tokenAddress,
            giveawayId: giveawayId.toString(),
            launchId: launchId.toString(),
            creatorAddress,
            devPercentage: devPercentage.toString(),
            liquidityPercentage: liquidityPercentage.toString(),
            tokenBreakdown: JSON.stringify(tokenBreakdown),
            status: "ACTIVE",
            createdAt: new Date().getTime(),
        }

        console.log("launchProject: saving in redis",launchProjectData)

        // 7. Store in database with allocation details
        await redis.hset(`project_${symbol.toLowerCase()}`, launchProjectData);
        await redis.sadd("project_tickers", symbol);
        await redis.sadd(`projects_user_${creatorAddress}`, symbol);

        res.status(200).json({
            success: true,
            data: {
                launchId: launchId.toString(),
                tokenAddress,
                giveawayId: giveawayId.toString(),
                transactionHash: receipt.transactionHash,
                allocation: {
                    dev: {
                        percentage: devPercentage / 100,
                        tokens: ethers.utils.formatEther(tokenBreakdown.devTokens),
                    },
                    liquidity: {
                        percentage: liquidityPercentage / 100,
                        tokens: ethers.utils.formatEther(tokenBreakdown.liquidityTokens),
                    },
                    participants: {
                        percentage: validation.participantPercentage / 100,
                        tokens: ethers.utils.formatEther(tokenBreakdown.participantTokens),
                    },
                },
            },
        });
    } catch (error: any) {
        console.error("Launch failed:", error);

        // Handle specific contract errors
        if (error.message.includes("InvalidLiquidityPercentage")) {
            return res.status(400).json({
                success: false,
                error: "Minimum 20% liquidity required for professional standards",
            });
        }

        if (error.message.includes("InvalidAllocationSum")) {
            return res.status(400).json({
                success: false,
                error: "Combined dev + liquidity allocations cannot exceed 70%",
            });
        }

        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
}
