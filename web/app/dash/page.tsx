"use client";

import { useState } from "react";
import { useUser } from "@/context/UserContext";
import { useRouter } from "next/navigation";
import NavComponent from "../../components/NavComponent";
import { AllocationDashboard } from "@/components/AllocationDashboard";

export default function LaunchFormPage() {
    const router = useRouter();
    const { user } = useUser();

    return (
        <div className="flex flex-col">
            <NavComponent />
            <div className="flex-1 flex items-center justify-center pt-12">
                <AllocationDashboard giveawayId={1} />
            </div>
        </div>
    );
}
