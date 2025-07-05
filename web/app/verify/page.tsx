"use client";

import { useState } from "react";
import { useUser } from "@/context/UserContext";
import { useRouter } from "next/navigation";
import NavComponent from "../../components/NavComponent";
import SelfPassportQRCode from "@/components/SelfPassportQRCode";

export default function VerifyPage() {
    const router = useRouter();
    const { user } = useUser();

    return (
        <div className="flex flex-col">
            <NavComponent />
            <div className="flex-1 flex items-center justify-center">
                <SelfPassportQRCode  />
            </div>
        </div>
    );
}
