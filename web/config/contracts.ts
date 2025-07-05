import * as LaunchPlatformABI from "../abis/LaunchPlatform.json";
import * as GiveawayABI from "../abis/Giveaway.json";
import * as ERC20ABI from "../abis/ERC20.json";

export const CONTRACTS = {
    // Primary Interface - Use this for ALL project launches
    LAUNCH_PLATFORM: {
        address: process.env.NEXT_PUBLIC_LAUNCH_PLATFORM_ADDRESS || "",
        abi: LaunchPlatformABI.abi,
    },

    // For user participation and allocation management
    GIVEAWAY: {
        address: process.env.NEXT_PUBLIC_GIVEAWAY_ADDRESS || "",
        abi: GiveawayABI.abi,
    },

    // For USDC deposits
    USDC: {
        address: process.env.NEXT_PUBLIC_USDC_ADDRESS || "",
        abi: ERC20ABI.abi,
    },
};

export const FEES = {
    TOKEN_CREATION: "100000000000000000", // 0.1 ETH/CELO
    PLATFORM_FEE_BPS: 250, // 2.5%
};

export const PROFESSIONAL_LIMITS = {
    MIN_LIQUIDITY_PERCENTAGE: 2000, // 20% minimum
    MAX_COMBINED_PERCENTAGE: 7000, // 70% maximum
    MIN_PARTICIPANT_PERCENTAGE: 3000, // 30% minimum for participants
};
