import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia, celo, celoAlfajores } from "wagmi/chains";

export const config = getDefaultConfig({
    appName: "RainbowKit demo",
    projectId: "YOUR_PROJECT_ID",
    // https://ethglobal.com/events/cannes/prizes/circle
    // chains: [mainnet, polygon, optimism, arbitrum, base],
    chains: [sepolia, celo, celoAlfajores],
    ssr: true,
});
