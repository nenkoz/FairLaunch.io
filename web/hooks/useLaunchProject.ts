import { useState, useEffect } from "react";
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseEther, parseUnits } from "viem";
import { TransactionReceipt } from "viem";
import { CONTRACTS } from "@/config/contracts";

export interface LaunchFormData {
    name: string;
    symbol: string;
    initialSupply: string;
    maxSupply: string;
    description: string;
    startTime: string;
    endTime: string;
    maxAllocation: string;
    tokensForGiveaway: string;
    devPercentage: number;
    liquidityPercentage: number;
    enableTradingImmediately: boolean;
}

interface UseLaunchProjectReturn {
    launch: (formData: LaunchFormData) => Promise<void>;
    step: number;
    isLoading: boolean;
    receipt: TransactionReceipt | undefined;
    error: Error | null;
}

export function useLaunchProject(): UseLaunchProjectReturn {
    const { address } = useAccount();
    const [step, setStep] = useState<number>(0);
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [isError, setIsError] = useState<any>(null);
    const [receipt, setReceipt] = useState<any>(null);

    const {
        data: hash,
        isPending,
        writeContract,
        error,
    } = useWriteContract({
        mutation: {
            onMutate: () => setStep(1),
            onError: () => setStep(0),
        },
    });

    // Use useEffect to update state based on wagmi hooks
    useEffect(() => {
        setIsLoading(isPending);
    }, [isPending]);

    useEffect(() => {
        setIsError(error);
    }, [error]);

    // Wait for transaction receipt when hash is available
    const {
        isLoading: isConfirming,
        isSuccess: isConfirmed,
        isError: isReceiptError,
        data: receiptData,
    } = useWaitForTransactionReceipt({
        hash,
    });

    // Update state based on transaction receipt
    useEffect(() => {
        setIsLoading(isConfirming);
    }, [isConfirming]);

    useEffect(() => {
        setIsError(isReceiptError);
    }, [isReceiptError]);

    useEffect(() => {
        if (receiptData) {
            setReceipt(receiptData);
            setStep(3); // Transaction completed
        }
    }, [receiptData]);

    const launch = async (formData: LaunchFormData): Promise<void> => {
        try {
            setStep(1);

            const tokenParams = {
                name: formData.name,
                symbol: formData.symbol,
                initialSupply: parseEther(formData.initialSupply),
                maxSupply: parseEther(formData.maxSupply),
                description: formData.description,
            };

            const giveawayParams = {
                startTime: Math.floor(new Date(formData.startTime).getTime() / 1000),
                endTime: Math.floor(new Date(formData.endTime).getTime() / 1000),
                maxAllocation: parseUnits(formData.maxAllocation, 6),
                tokensForGiveaway: parseEther(formData.tokensForGiveaway),
                devPercentage: formData.devPercentage,
                liquidityPercentage: formData.liquidityPercentage,
                enableTradingImmediately: formData.enableTradingImmediately,
            };

            setStep(2);
const tokenAddress=CONTRACTS.LAUNCH_PLATFORM.address as `0x${string}`
            writeContract({
                abi: CONTRACTS.LAUNCH_PLATFORM.abi,
                address: tokenAddress,
                functionName: "launchProject",
                args: [tokenParams, giveawayParams],
                value: parseEther("0.1"),
            });
            console.log("Launching project...");
            console.log("Token params:", tokenParams);
            console.log("Giveaway params:", giveawayParams);
            console.log("Hash:", hash);

            const res = await fetch("/api/launch", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Accept: "application/json",
                },
                body: JSON.stringify({ ...formData,hash, tokenAddress, creatorAddress: address }),
            });

            if (!res.ok) throw new Error("Backend failed");
            // displayToast("Project submitted successfully! Redirecting...");
        } catch (error) {
            console.error("Launch failed:", error);
            setStep(0);
        }
    };

    return {
        launch,
        step,
        isLoading,
        receipt,
        error: isError,
    };
}
