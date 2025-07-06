"use client";

import { useState } from "react";
import { useUser } from "@/context/UserContext";
import { useRouter } from "next/navigation";
import NavComponent from "../../components/NavComponent";
import LaunchForm from "@/components/LaunchForm";    

export default function LaunchFormPage() {
    const router = useRouter();
    const { user } = useUser();


    return (
        <div>
            <NavComponent />
            <div className="max-w-xl mx-auto p-6">
                <h1 className="text-2xl font-bold text-yellow-600 mb-4">Launch your project</h1>
                <LaunchForm />
            </div>
        </div>
    );
}
