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


<>
<NavComponent />
<div className="flex flex-col items-center justify-center min-h-screen p-4 bg-yellow-50">
<SelfPassportQRCode  />
</div>
</>
    );
}
