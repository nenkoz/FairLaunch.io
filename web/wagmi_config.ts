import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia, celo, celoAlfajores } from "wagmi/chains";

// Check if project ID is properly configured
const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID;
if (!projectId || projectId === "YOUR_PROJECT_ID") {
    console.warn(
        "⚠️ WalletConnect Project ID not configured. Please set NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID in your environment variables. " +
        "Get your project ID from https://cloud.walletconnect.com/"
    );
}

export const config = getDefaultConfig({
    appName: "FairLaunch",
    projectId: projectId || "",
    chains: [sepolia, celo, celoAlfajores],
    ssr: true,
});
