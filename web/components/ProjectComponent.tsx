"use client";

import { useRouter } from "next/navigation";
import { useUser } from "@/context/UserContext";
// import "../node_modules/@rainbow-me/rainbowkit/dist/index.css";
import { formatDistanceToNow } from "date-fns";
import { Project } from "@/lib/common";

export default function ProjectComponent({ project, onDeposit, canDeposit }: { project: Project, onDeposit: () => void, canDeposit: boolean }) {
    const { user } = useUser();
    const router = useRouter();

    return (
        <div key={project.symbol} className="bg-white rounded-xl shadow p-4 relative">
                                    <div className="flex items-center gap-3" onClick={() => router.push(`/project/${project.symbol}`)}>
                                        <img src={"https://zengo.com/wp-content/uploads/ETH-USDC-300x300-1.png"} alt={project.name} className="w-12 h-12 rounded-full object-cover" />
                                        <div className="flex flex-col">
                                            <span className="font-semibold text-gray-800 lowercase">{project.name}</span>
                                            <span className="text-sm text-gray-500">${project.symbol}</span>
                                            <span className="text-xs text-gray-400 mt-1">Created: {formatDistanceToNow(new Date(Number(project.createdAt)), { addSuffix: true })}</span>
                                        </div>
                                    </div>
                                    <span className="absolute top-4 right-4 text-xs px-3 py-1 bg-yellow-200 text-yellow-800 rounded-full">{project.status}</span>
                                    {canDeposit && (
                                    <button onClick={onDeposit} className="px-4 py-2 bg-yellow-500 text-white font-semibold rounded hover:bg-yellow-600">
                                        Deposit
                                    </button>
                                    )}
                                    {/* <button type="submit" className="w-full bg-yellow-400 text-white py-3 rounded-full font-semibold hover:bg-yellow-600 transition" disabled={claimStatus === "loading"}>
                                        {claimStatus === "loading" ? "Claiming..." : "Claim"}
                                    </button> */}
                                </div>
    );
}
