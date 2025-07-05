"use client";

import { useState } from "react";
import { useUser } from "@/context/UserContext";
import { useRouter } from "next/navigation";
import NavComponent from "../../components/NavComponent";
import LaunchForm from "@/components/LaunchForm";    

export default function LaunchFormPage() {
    const router = useRouter();
    const { user } = useUser();

    const [status, setStatus] = useState<"idle" | "loading" | "done">("idle");
    const [toastMessage, setToastMessage] = useState("");
    const [showToast, setShowToast] = useState(false);

    const displayToast = (message: string) => {
        setToastMessage(message);
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
    };

    return (
        <div>
            <NavComponent />
            <div className="max-w-xl mx-auto p-6 py-40">
                <h1 className="text-2xl font-bold text-yellow-600 mb-4">Launch your project</h1>
                <LaunchForm />
                {showToast && <div className="fixed bottom-4 right-4 bg-gray-800 text-white py-2 px-4 rounded shadow-lg animate-fade-in text-sm">{toastMessage}</div>}
            </div>
        </div>
    );
}
