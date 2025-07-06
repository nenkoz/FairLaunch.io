import { ethers } from "ethers";
import { NextApiRequest, NextApiResponse } from "next";
import { CONTRACTS, FEES } from "@/config/contracts";
import { AllocationValidator } from "@/utils/allocationValidation";
import redis from "@/lib/redis";

interface LaunchProjectRequest {
    hash: string;
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
    tokenAddress: string;
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
    if (req.method !== "POST") {
        return res.status(405).json({ success: false, error: "Method not allowed" });
    }

    try {
        const {
            hash,
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
            tokenAddress,
        } = req.body as LaunchProjectRequest;

        // Validate required fields
        if (!name || !symbol || !description || !creatorAddress) {
            return res.status(400).json({
                success: false,
                error: "Missing required fields: name, symbol, description, creatorAddress",
            });
        }

        // Validate allocation parameters
        const validation = AllocationValidator.validateAllocation(devPercentage, liquidityPercentage);
        if (!validation.isValid) {
            return res.status(400).json({
                success: false,
                error: "Invalid allocation parameters",
                details: validation.errors,
            });
        }

        // Check if ticker already exists
        const tickerExists = await redis.sismember(`project_tickers`, symbol);
        if (tickerExists) {
            return res.status(400).json({
                success: false,
                error: `Ticker ${symbol} already exists`,
            });
        }

        // Calculate token breakdown
        const tokenBreakdown = AllocationValidator.calculateTokenBreakdown(ethers.utils.parseEther(tokensForGiveaway), devPercentage, liquidityPercentage);

        console.log("API: Token breakdown calculated:", {
            devTokens: ethers.utils.formatEther(tokenBreakdown.devTokens),
            liquidityTokens: ethers.utils.formatEther(tokenBreakdown.liquidityTokens),
            participantTokens: ethers.utils.formatEther(tokenBreakdown.participantTokens),
        });

        // Prepare launch project data for storage
        const launchProjectData = {
            hash,
            name,
            symbol,
            description,
            initialSupply,
            maxSupply,
            startTime,
            endTime,
            maxAllocation,
            tokensForGiveaway,
            devPercentage: devPercentage.toString(),
            liquidityPercentage: liquidityPercentage.toString(),
            enableTradingImmediately: enableTradingImmediately.toString(),
            creatorAddress,
            tokenBreakdown: JSON.stringify({
                devTokens: ethers.utils.formatEther(tokenBreakdown.devTokens),
                liquidityTokens: ethers.utils.formatEther(tokenBreakdown.liquidityTokens),
                participantTokens: ethers.utils.formatEther(tokenBreakdown.participantTokens),
            }),
            status: "ACTIVE",
            createdAt: new Date().getTime(),
        };

        await redis.hset(`project_${symbol.toLowerCase()}`, launchProjectData);
        await redis.sadd("project_tickers", symbol);
        await redis.sadd(`projects_user_${creatorAddress}`, symbol);

        res.status(200).json({
            success: true,
            data: {
                launchId: `launch_${symbol}_${Date.now()}`,
                tokenAddress,
                giveawayId: "0",
                transactionHash: hash,
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
        console.error("API: Launch failed:", error);

        res.status(500).json({
            success: false,
            error: error.message || "Internal server error",
        });
    }
}
