"use client";

import { useState } from "react";
import { X } from "lucide-react";
import { useBalance, useAccount } from "wagmi";
import { useUser } from "@/context/UserContext";

export default function DepositModal({ isOpen, onClose }: { isOpen: boolean; onClose: () => void }) {
    const [amount, setAmount] = useState("");
    const { user } = useUser();

    // const { address, isConnected } = useAccount();
    console.log("user.address ", user.address);
    const { data, isLoading } = useBalance({
        address: user.address || undefined,
    });

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex justify-center items-center z-50">
            <div className="bg-white rounded-2xl w-[380px] p-6 relative shadow-lg">
                <button onClick={onClose} className="absolute top-4 right-4 text-gray-400 hover:text-gray-600">
                    <X className="w-5 h-5" />
                </button>

                <h2 className="text-center text-lg font-semibold mb-1">Deposit</h2>
                <p className="text-center text-sm text-gray-500 mb-6">
                    {data?.formatted} {data?.symbol} Available
                </p>

                <div className="text-center ">
                    <p className="text-lg text-text-secondary  font-medium">$0.00 Available</p>
                    <div className="flex items-center justify-center my-16 gap-2 relative">
                        <input className="text-6xl font-bold text-text bg-transparent border-none outline-none placeholder:text-text-tertiary text-center" placeholder="$0" type="text" value="" />
                    </div>
                </div>

                {/* Amount */}
                <div className="text-center text-5xl font-light text-gray-400 mb-6">${amount || "0"}</div>

                {/* Button */}
                <button className="mt-6 w-full py-3 bg-yellow-500 text-white font-semibold rounded-full hover:bg-yellow-600 transition" disabled>
                    Next
                </button>
            </div>
        </div>
    );
}
