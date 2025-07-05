"use client";

import React, { useState, useEffect } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { celoAlfajores } from "wagmi/chains";
import { RainbowKitProvider } from "@rainbow-me/rainbowkit";

import { config } from "../wagmi_config";

const queryClient = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
    const [mounted, setMounted] = useState(false);
    useEffect(() => setMounted(true), []);

    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider
                    appInfo={{
                        appName: "Giveaway",
                    }}
                    modalSize="compact"
                    showRecentTransactions={true}
                    initialChain={celoAlfajores}>
                    {children}
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    );
}
