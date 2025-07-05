"use client";

import { useEffect, useState, lazy, Suspense } from "react";
import { useRouter } from "next/navigation";
import { User, useUser } from "@/context/UserContext";
import { useAccount, useSignMessage } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import "../../node_modules/@rainbow-me/rainbowkit/dist/index.css";
import { isUserVerified, removeVerifiedUser, setVerifiedUser } from "@/lib/common";
import NavComponent from "@/components/NavComponent";
import LaunchForm from "@/components/LaunchForm";

export default function AuthPage() {
    const { status: accountStatus, address, isDisconnected } = useAccount();
    const router = useRouter();
    const { user, setUser } = useUser();

    const [name, setName] = useState("David");
    const [nonce, setNonce] = useState("");

    const [status, setStatus] = useState<"registered" | "connected" | "idle">("idle");
    const [showToast, setShowToast] = useState(false);
    const [toastMessage, setToastMessage] = useState("");
    // const [user, setUser] = useState<User | null>(null);
    const [error, setError] = useState("");

    // state
    // const [userId, setUserId] = useState<string>("");
    const [isWalletVerified, setIsWalletVerified] = useState<boolean>(false);
    const [isVerified, setIsVerified] = useState<boolean>(false);
    const [isLoading, setIsLoading] = useState<boolean>(true);

    const { signMessageAsync } = useSignMessage();

    useEffect(() => {
        if (isDisconnected) {
            console.warn("not connected, logging out");
            logout();
        }
    }, [isDisconnected]);

    useEffect(() => {
        if (!address) {
            console.warn("no wagmi:address ", address);
            return;
        }
        console.log("wagmi:address ", address);
        console.log("current:local:context ", user);
        setUser({
            id: "",
            name: "",
            email: "",
            address: address,
            age: 0,
            verified: false,
        });
        

        router.push("/launch");
        (async () => {
            try {
                const res = await fetch(`/api/user/nonce?address=${address}`);
                const data = await res.text();
                setNonce(data);
                // temporary
                console.log("setting in local store", address);
                setVerifiedUser(address);
                localStorage.setItem("userId", address);
                displayToast("Login you in...");
            } catch (e) {
                console.error("nonce Err:", e);
            }
        })();
    }, [address]);

    // useEffect(() => {
    //     if (user) {
    //         console.log("updated:local:context ", user);
    //     }
    // }, [user]);

    useEffect(() => {
        if (accountStatus !== "connected" || !address) {
            // clear on disconnect
            if (address) {
                removeVerifiedUser(address);
            }
            // setUserId("");
            setIsVerified(false);
            return;
        }

        // setUserId(address);
        displayToast("Wallet connected!");

        // if (isUserVerified(address)) {
        //     setIsVerified(true);
        //     return;
        // }
    }, [accountStatus, address]);

    useEffect(() => {
        if (!user?.id) {
            return;
        }
        setStatus("registered");
    }, [user]);

    useEffect(() => {
        if (error) {
            const timer = setTimeout(() => setError(""), 3000);
            return () => clearTimeout(timer);
        }
    }, [error]);

    const displayToast = (message: string) => {
        setToastMessage(message);
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
    };

    const logout = () => {
        localStorage.removeItem("userId");
        setUser(null);
        setName("");
        setStatus("idle");
        // displayToast("Logout successful!");
        setError("");
    };

    return (
        <>
            <NavComponent />
            <div className="flex flex-col items-center justify-center min-h-screen p-4 bg-yellow-50">
                <div className="w-full max-w-sm bg-white shadow-lg rounded-2xl p-6 space-y-4">
                    <h1 className="text-2xl font-bold text-yellow-600"> {isLoading ? `Loading...please wait` : `Connect your wallet to begin`}</h1>
                </div>
                
                {showToast && <div className="fixed bottom-4 right-4 bg-gray-800 text-white py-2 px-4 rounded shadow-lg animate-fade-in text-sm">{toastMessage}</div>}
            </div>
        </>
    );
}
