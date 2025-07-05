export function handleContractError(error) {
    // Parse common contract errors
    if (error.message.includes("InvalidName")) {
        return "Token name is invalid or already taken";
    }

    if (error.message.includes("InsufficientCreationFee")) {
        return "Please send exactly 0.1 ETH as creation fee";
    }

    if (error.message.includes("VerificationRequired")) {
        return "Please complete Self.xyz passport verification first";
    }

    if (error.message.includes("AlreadyParticipated")) {
        return "You have already participated in this giveaway";
    }

    if (error.message.includes("GiveawayNotActive")) {
        return "This giveaway is not currently active";
    }

    if (error.message.includes("InsufficientDeposit")) {
        return "Deposit amount must be greater than 0";
    }

    // NEW: Professional allocation errors
    if (error.message.includes("InvalidDevPercentage")) {
        return "Developer allocation cannot exceed 100%";
    }

    if (error.message.includes("InvalidLiquidityPercentage")) {
        return "Minimum 20% liquidity required for professional standards";
    }

    if (error.message.includes("InvalidAllocationSum")) {
        return "Combined dev + liquidity allocations cannot exceed 70%";
    }

    if (error.message.includes("DevTokensAlreadyClaimed")) {
        return "Developer tokens have already been claimed";
    }

    if (error.message.includes("LiquidityTokensAlreadyClaimed")) {
        return "Liquidity tokens have already been claimed";
    }

    if (error.message.includes("DevTokensNotAllocated")) {
        return "No developer tokens were allocated for this project";
    }

    if (error.message.includes("LiquidityTokensNotAllocated")) {
        return "No liquidity tokens were allocated for this project";
    }

    // Default error
    return error.message || "Transaction failed";
}

// Usage in components with allocation validation
try {
    await launchProject();
} catch (error) {
    const userFriendlyError = handleContractError(error);
    setErrorMessage(userFriendlyError);
}

// Professional allocation validation helper
export function validateProfessionalAllocations(devPercentage, liquidityPercentage) {
    const errors = [];

    if (liquidityPercentage < 2000) {
        errors.push("Minimum 20% liquidity required for professional standards");
    }

    if (devPercentage + liquidityPercentage > 7000) {
        errors.push("Combined allocations cannot exceed 70% (dev + liquidity)");
    }

    if (devPercentage < 0 || devPercentage > 10000) {
        errors.push("Developer allocation must be between 0% and 100%");
    }

    if (liquidityPercentage < 0 || liquidityPercentage > 10000) {
        errors.push("Liquidity allocation must be between 0% and 100%");
    }

    return {
        isValid: errors.length === 0,
        errors,
        participantPercentage: 10000 - devPercentage - liquidityPercentage,
    };
}
