"use client";

import { useEffect, useState, lazy, Suspense } from "react";
import { useRouter } from "next/navigation";
import { User, useUser } from "@/context/UserContext";
import { useAccount, useSignMessage } from "wagmi";
import { isUserVerified, removeVerifiedUser, setVerifiedUser } from "@/lib/common";
import { SelfQRcodeWrapper, countries, SelfAppBuilder } from "@selfxyz/qrcode";

export default function SelfPassportQRCode() {
    const { status: accountStatus, address } = useAccount();
    const router = useRouter();

    const { isDisconnected } = useAccount();
    const [showToast, setShowToast] = useState(false);
    const [toastMessage, setToastMessage] = useState("");
    const { user, setUser } = useUser();

    const [selfApp, setSelfApp] = useState<any>(null);
    const [isVerified, setIsVerified] = useState<boolean>(false);

    const displayToast = (message: string) => {
        setToastMessage(message);
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
    };


    useEffect(() => {
        if (accountStatus !== "connected" || !address) {
            setSelfApp(null);
            return;
        }

        displayToast("Wallet connected!");
        if (localStorage.getItem("passport_verified")) {
            setIsVerified(true);
            return;
        }

        // if (isUserVerified(address)) {
        //     setIsVerified(true);
        //     return;
        // }

        (async () => {
            try {
                const app = new SelfAppBuilder({
                    version: 2,
                    appName: process.env.NEXT_PUBLIC_SELF_APP_NAME,
                    scope: process.env.NEXT_PUBLIC_SELF_SCOPE,
                    endpoint: process.env.NEXT_PUBLIC_PASSPORT_ADDRESS,
                    logoBase64: "https://static.vecteezy.com/system/resources/previews/021/627/718/non_2x/celo-coin-stacks-cryptocurrency-3d-render-illustration-free-png.png",
                    userId: address,
                    endpointType: "staging_celo",
                    userIdType: "hex",
                    userDefinedData: "basic",
                    devMode: true,
                    disclosures: { minimumAge: 18, ofac: false },
                }).build();
                setSelfApp(app);
            } catch (error) {
                console.error("Failed to initialize Self app:", error);
                displayToast("Error initializing verification");
            }
        })();
    }, [accountStatus, address]);

    const handleSuccessfulVerification = () => {
        if (address) {
            setVerifiedUser(address);
            setIsVerified(true);
            localStorage.setItem("passport_verified", "true");
            displayToast("Verification successful! Redirecting...");
            setTimeout(() => {
                router.push("/launch");
            }, 1500);
        }
    };

    return (
        <div className="w-full max-w-sm bg-white shadow-lg rounded-2xl p-6 space-y-4">
            <h1 className="text-2xl font-bold text-yellow-600"> {accountStatus === "connected" && selfApp && !isVerified ? `Scan QR code (by Self.xyz)` : `Connect your wallet to begin`}</h1>

            {accountStatus === "connected" && selfApp && !isVerified && (
                <Suspense
                    fallback={
                        <div className="w-[256px] h-[256px] bg-gray-200 animate-pulse flex items-center justify-center">
                            <p className="text-gray-500 text-sm">Loading QR Code...</p>
                        </div>
                    }>
                    <SelfQRcodeWrapper selfApp={selfApp} onSuccess={handleSuccessfulVerification} onError={() => displayToast("Error: Failed to verify identity")} />
                </Suspense>
            )}

            {accountStatus === "connected" && user?.verified && <div className="text-green-600 font-semibold text-center">You are verified! 🎉</div>}
        </div>
    );
}
