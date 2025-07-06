"use client";

import { useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import Image from "next/image";
import { Home, Rocket, Wallet, Compass, Settings } from "lucide-react";
import { useDisconnect, useAccount } from "wagmi";
import { User, useUser } from "@/context/UserContext";
import { ConnectButton } from "@rainbow-me/rainbowkit";
// import "../node_modules/@rainbow-me/rainbowkit/dist/index.css";

export default function NavComponent() {
    const { user } = useUser();
    const router = useRouter();
    const { status: walletStatus } = useAccount();
    const { disconnect } = useDisconnect();
    const pathname = usePathname();

    return (
        <header className="bg-white border-b border-gray-100 sticky top-0 z-50 backdrop-blur-sm bg-white/95">
            <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8">
                <div className="flex justify-between items-center py-3 sm:py-6">
                    <div className="flex items-center min-w-0 flex-1">
                        <div className="min-w-0">
                            <h1 className="text-base sm:text-xl lg:text-2xl font-bold text-black truncate">
                                <span className="sm:hidden">Fairlaunch</span>
                                <span className="hidden sm:inline">Fairlaunch</span>
                            </h1>
                            <p className="text-xs sm:text-sm text-gray-600 mt-0.5 sm:mt-1 hidden sm:block">Advanced Sybil resistance transparent token giveaways</p>
                        </div>
                    </div>
                    <div className="flex items-center space-x-2 sm:space-x-4 lg:space-x-8 shrink-0">
                        {/* <a href="/projects" rel="noopener noreferrer" className="text-gray-600 hover:text-black transition-colors font-medium text-xs sm:text-sm hidden sm:inline">
                            <span className="lg:hidden"></span>
                            <span className="hidden lg:inline">Projects</span>
                        </a> */}
                        <a href="/explore" rel="noopener noreferrer" className="text-gray-600 hover:text-black transition-colors font-medium text-xs sm:text-sm hidden sm:inline">
                            <span className="lg:hidden"></span>
                            <span className="hidden lg:inline">Explore</span>
                        </a>
                        {walletStatus === "connected" && pathname !== "/launch" && (
                            <a href="/launch" className="bg-yellow-500 text-white px-4 py-2 rounded-md flex items-center hover:bg-yellow-600 transition-colors">
                                <span className="mr-2">Launch</span>
                                <Rocket className="w-6 h-6 sm:mr-2" />
                            </a>
                        )}
                        <ConnectButton showBalance={true} chainStatus="icon" accountStatus="avatar" />
                    </div>
                </div>
            </div>
        </header>
    );
}
