import { BigNumber } from "ethers";

export interface ValidationResult {
    isValid: boolean;
    errors: string[];
    participantPercentage: number;
}

export interface TokenBreakdown {
    devTokens: BigNumber;
    liquidityTokens: BigNumber;
    participantTokens: BigNumber;
    devPercentage: number;
    liquidityPercentage: number;
    participantPercentage: number;
}

export class AllocationValidator {
    static validateAllocation(devPercentage: number, liquidityPercentage: number): ValidationResult {
        const errors: string[] = [];

        // Check individual limits
        if (devPercentage > 10000) {
            errors.push("Developer allocation cannot exceed 100%");
        }

        if (liquidityPercentage > 10000) {
            errors.push("Liquidity allocation cannot exceed 100%");
        }

        // Check professional minimum liquidity
        if (liquidityPercentage < 2000) {
            errors.push("Minimum 20% liquidity required for professional standards");
        }

        // Check professional maximum combined
        if (devPercentage + liquidityPercentage > 7000) {
            errors.push("Combined allocations cannot exceed 70% (dev + liquidity)");
        }

        return {
            isValid: errors.length === 0,
            errors,
            participantPercentage: 10000 - devPercentage - liquidityPercentage,
        };
    }

    static calculateTokenBreakdown(totalTokens: BigNumber, devPercentage: number, liquidityPercentage: number): TokenBreakdown {
        const devTokens = totalTokens.mul(devPercentage).div(10000);
        const liquidityTokens = totalTokens.mul(liquidityPercentage).div(10000);
        const participantTokens = totalTokens.sub(devTokens).sub(liquidityTokens);

        return {
            devTokens,
            liquidityTokens,
            participantTokens,
            devPercentage: devPercentage / 100,
            liquidityPercentage: liquidityPercentage / 100,
            participantPercentage: (10000 - devPercentage - liquidityPercentage) / 100,
        };
    }
}
