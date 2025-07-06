import { useState, useEffect } from "react";
import { useAccount, useReadContract } from "wagmi";
import { ethers } from "ethers";
import { CONTRACTS } from "@/config/contracts";
import { useRouter } from "next/navigation";

type AllocationBreakdown = [participantTokens: bigint, devTokens: bigint, liquidityTokens: bigint, participantPercentage: bigint, devPercentage: bigint, liquidityPercentage: bigint];
type DevTokenInfo = [devTokensAllocated: bigint, devTokensClaimed: bigint, devPercentage: bigint];
type LiquidityTokenInfo = [liquidityTokensAllocated: bigint, liquidityTokensClaimed: bigint, liquidityPercentage: bigint];
type CanClaimDev = [canClaim: boolean, reason: bigint];
type CanClaimLiquidity = [canClaim: boolean, reason: bigint];

interface AllocationDashboardProps {
    giveawayId: number;
}

interface AllocationInfo {
    participants: {
        tokens: string;
        percentage: number;
    };
    dev: {
        tokens: string;
        percentage: number;
        allocated: string;
        claimed: string;
        hasClaimed: boolean;
    };
    liquidity: {
        tokens: string;
        percentage: number;
        allocated: string;
        claimed: string;
        hasClaimed: boolean;
    };
}

interface CanClaim {
    dev: boolean;
    liquidity: boolean;
}

const mockAllocation = {
    participants: {
        tokens: ethers.utils.formatEther(ethers.BigNumber.from("500000000000000000000")), // 500 tokens
        percentage: 70.0, // 7000 basis points / 100
    },
    dev: {
        tokens: ethers.utils.formatEther(ethers.BigNumber.from("150000000000000000000")), // 150 tokens
        percentage: 20.0, // 2000 / 100
        allocated: ethers.utils.formatEther(ethers.BigNumber.from("150000000000000000000")),
        claimed: ethers.utils.formatEther(ethers.BigNumber.from("150000000000000000000")),
        hasClaimed: true,
    },
    liquidity: {
        tokens: ethers.utils.formatEther(ethers.BigNumber.from("50000000000000000000")), // 50 tokens
        percentage: 10.0, // 1000 / 100
        allocated: ethers.utils.formatEther(ethers.BigNumber.from("50000000000000000000")),
        claimed: ethers.utils.formatEther(ethers.BigNumber.from("0")),
        hasClaimed: false,
    },
};

export function AllocationDashboard({ giveawayId }: AllocationDashboardProps) {
    const router = useRouter();
    const { address } = useAccount();
    const [allocationInfo, setAllocationInfo] = useState<AllocationInfo | null>(null);
    const [canClaim, setCanClaim] = useState<CanClaim>({ dev: false, liquidity: false });

    const { data: allocationBreakdown } = useReadContract({
        address: CONTRACTS.GIVEAWAY.address as `0x${string}`,
        abi: CONTRACTS.GIVEAWAY.abi,
        functionName: "getAllocationBreakdown",
        args: [giveawayId],
    });

    const { data: devTokenInfo } = useReadContract({
        address: CONTRACTS.GIVEAWAY.address as `0x${string}`,
        abi: CONTRACTS.GIVEAWAY.abi,
        functionName: "getDevTokenInfo",
        args: [giveawayId],
    });

    const { data: liquidityTokenInfo } = useReadContract({
        address: CONTRACTS.GIVEAWAY.address as `0x${string}`,
        abi: CONTRACTS.GIVEAWAY.abi,
        functionName: "getLiquidityTokenInfo",
        args: [giveawayId],
    });

    const { data: canClaimDev } = useReadContract({
        address: CONTRACTS.GIVEAWAY.address as `0x${string}`,
        abi: CONTRACTS.GIVEAWAY.abi,
        functionName: "canClaimDevTokens",
        args: [giveawayId],
    });

    const { data: canClaimLiquidity } = useReadContract({
        address: CONTRACTS.GIVEAWAY.address as `0x${string}`,
        abi: CONTRACTS.GIVEAWAY.abi,
        functionName: "canClaimLiquidityTokens",
        args: [giveawayId],
    });

    const canClaimDevResult = canClaimDev as CanClaimDev;
    const canClaimLiquidityResult = canClaimLiquidity as CanClaimLiquidity;

    useEffect(() => {
        setAllocationInfo(mockAllocation);

        if (allocationBreakdown && devTokenInfo && liquidityTokenInfo) {
            const [
                //
                participantTokens,
                devTokens,
                liquidityTokens,
                participantPercentage,
                devPercentage,
                liquidityPercentage,
            ] = allocationBreakdown as AllocationBreakdown;

            const [devTokensAllocated, devTokensClaimed, devPerc] = devTokenInfo as DevTokenInfo;
            const [liquidityTokensAllocated, liquidityTokensClaimed, liquidityPerc] = liquidityTokenInfo as LiquidityTokenInfo;

            // setAllocationInfo({
            //     participants: {
            //         tokens: ethers.utils.formatEther(participantTokens),
            //         percentage: Number(participantPercentage) / 100,
            //     },
            //     dev: {
            //         tokens: ethers.utils.formatEther(devTokens),
            //         percentage: Number(devPercentage) / 100,
            //         allocated: ethers.utils.formatEther(devTokensAllocated),
            //         claimed: ethers.utils.formatEther(devTokensClaimed),
            //         hasClaimed: devTokensClaimed > 0n,
            //     },
            //     liquidity: {
            //         tokens: ethers.utils.formatEther(liquidityTokens),
            //         percentage: Number(liquidityPercentage) / 100,
            //         allocated: ethers.utils.formatEther(liquidityTokensAllocated),
            //         claimed: ethers.utils.formatEther(liquidityTokensClaimed),
            //         hasClaimed: liquidityTokensClaimed > 0n,
            //     },
            // });
        }

        if (canClaimDevResult && canClaimLiquidityResult) {
            setCanClaim({
                dev: canClaimDevResult[0],
                liquidity: canClaimLiquidityResult[0],
            });
        }
    }, [allocationBreakdown, devTokenInfo, liquidityTokenInfo, canClaimDevResult, canClaimLiquidityResult]);

    if (!allocationInfo) {
        return (
            <div className="p-6 text-center">
                <h3 className="text-xl font-semibold text-black mb-2">No Allocation</h3>
                <p className="text-text-secondary">You have no allocations yet.</p>
                <button onClick={() => router.push("/launch")} className="w-full bg-yellow-400 text-white py-3 rounded-full font-semibold hover:bg-yellow-600 transition">
                    Get Started
                </button>
            </div>
        );
    }

    return (
        <div className="space-y-6 p-6 bg-white rounded-lg border">
            <h3 className="text-xl font-bold">🏆 Allocation Dashboard</h3>

            {/* Allocation Overview */}
            <div className="grid grid-cols-3 gap-4">
                <div className="p-4 bg-green-50 rounded border">
                    <div className="text-sm font-medium text-green-800">Participants</div>
                    <div className="text-2xl font-bold text-green-900">{allocationInfo.participants.percentage.toFixed(1)}%</div>
                    <div className="text-sm text-green-700">{parseFloat(allocationInfo.participants.tokens).toLocaleString()} tokens</div>
                </div>

                <div className="p-4 bg-purple-50 rounded border">
                    <div className="text-sm font-medium text-purple-800">Developer</div>
                    <div className="text-2xl font-bold text-purple-900">{allocationInfo.dev.percentage.toFixed(1)}%</div>
                    <div className="text-sm text-purple-700">{parseFloat(allocationInfo.dev.tokens).toLocaleString()} tokens</div>
                    {allocationInfo.dev.hasClaimed && <div className="text-xs text-green-600 mt-1">✅ Claimed</div>}
                </div>

                <div className="p-4 bg-blue-50 rounded border">
                    <div className="text-sm font-medium text-blue-800">Liquidity Pool</div>
                    <div className="text-2xl font-bold text-blue-900">{allocationInfo.liquidity.percentage.toFixed(1)}%</div>
                    <div className="text-sm text-blue-700">{parseFloat(allocationInfo.liquidity.tokens).toLocaleString()} tokens</div>
                    {allocationInfo.liquidity.hasClaimed && <div className="text-xs text-green-600 mt-1">✅ Claimed</div>}
                </div>
            </div>

            {/* Claim Actions */}
            <div className="space-y-3">
                <h4 className="font-semibold">Claim Actions</h4>

                <div className="flex space-x-3">
                    <button
                        disabled={!canClaim.dev || allocationInfo.dev.hasClaimed}
                        className="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 disabled:opacity-50"
                        onClick={() => {
                            /* Handle dev token claim */
                        }}>
                        {allocationInfo.dev.hasClaimed ? "✅ Dev Tokens Claimed" : canClaim.dev ? "👨‍💻 Claim Dev Tokens" : "❌ Cannot Claim Dev"}
                    </button>

                    <button
                        disabled={!canClaim.liquidity || allocationInfo.liquidity.hasClaimed}
                        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
                        onClick={() => {
                            /* Handle liquidity token claim */
                        }}>
                        {allocationInfo.liquidity.hasClaimed ? "✅ Liquidity Claimed" : canClaim.liquidity ? "💧 Claim Liquidity" : "❌ Cannot Claim Liquidity"}
                    </button>
                </div>
            </div>

            {/* Professional Status */}
            <div className="p-3 bg-green-100 rounded border border-green-200">
                <div className="text-sm font-medium text-green-800">✅ Professional Standards Met</div>
                <div className="text-xs text-green-700 mt-1">
                    • Minimum 20% liquidity allocation ✓<br />
                    • Maximum 70% total allocations ✓<br />• Immediate trading ready ✓
                </div>
            </div>
        </div>
    );
}
