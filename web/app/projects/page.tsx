"use client";

import { useEffect, useState } from "react";
import { useUser } from "@/context/UserContext";
import { useRouter } from "next/navigation";
import NavComponent from "../../components/NavComponent";
import { formatDistanceToNow } from "date-fns";
import { Project } from "@/lib/common";
import ClipLoader from "react-spinners/ClipLoader";
import DepositModal from "../../components/DepositModal";
import { useBalance, useAccount } from "wagmi";

export default function ProjectsPage() {
    const router = useRouter();
    const { user } = useUser();
    const [projects, setProjects] = useState<Project[]>([]);
    const [claimed, setClaimed] = useState(0);
    const [unclaimed, setUnclaimed] = useState(0);
    const [loading, setLoading] = useState(true);
    const [open, setOpen] = useState(false);

    const { address, isConnected } = useAccount();
    const { data, isLoading } = useBalance({
        address,
    });

    useEffect(() => {
        if (!user?.address) {
            console.log("no address");
            setLoading(false);
            router.push("/");
            return;
        }

        const fetchProjects = async () => {
            setLoading(true);
            const res = await fetch("/api/user/projects?address=" + user.address);
            const data = await res.json();
            const list: Project[] = Object.values(data).map((p: any) => ({
                ...p,
                claimedFees: parseFloat(p.claimedFees || 0),
                unclaimedFees: parseFloat(p.unclaimedFees || 0),
            }));

            setProjects(list);
            // const totalClaimedFees =list.reduce((a, p) => a + p.claimedFees, 0)
            // const totalUnclaimedFees =list.reduce((a, p) => a + p.unclaimedFees, 0)
            setClaimed(0);
            setUnclaimed(0);
            setLoading(false);
        };

        fetchProjects();
    }, [user]);

    const claimStatus = "";

    return (
        <div className="flex flex-col">
            <NavComponent />
            <div className="flex-1 flex items-center justify-center">
                <div className="p-6 max-w-4xl mx-auto">
                    <h1 className="text-2xl font-bold text-yellow-600 mb-4">My projects</h1>
                    {loading && (
                        <div className="flex justify-center items-center py-12">
                            <ClipLoader color="#facc15" size={48} />
                        </div>
                    )}

                    {!loading && projects.length === 0 && (
                        <div className="p-6 text-center">
                            <h3 className="text-xl font-semibold text-black mb-2">No Projects</h3>
                            <p className="text-text-secondary">You haven't launched a project yet.</p>
                            <button onClick={() => router.push("/launch")} className="w-full bg-yellow-400 text-white py-3 rounded-full font-semibold hover:bg-yellow-600 transition">
                                Get Started
                            </button>
                        </div>
                    )}

                    {!loading && projects.length > 0 && (
                        <div className="grid md:grid-cols-2 gap-6">
                            {projects.map((project) => (
                                <div key={project.id} className="bg-white rounded-xl shadow p-4 relative">
                                    <div className="flex items-center gap-3" onClick={() => router.push(`/project/${project.ticker}`)}>
                                        <img src={project.image || "https://zengo.com/wp-content/uploads/ETH-USDC-300x300-1.png"} alt={project.name} className="w-12 h-12 rounded-full object-cover" />
                                        <div className="flex flex-col">
                                            <span className="font-semibold text-gray-800 lowercase">{project.name}</span>
                                            <span className="text-sm text-gray-500">${project.ticker}</span>
                                            <span className="text-xs text-gray-400 mt-1">Created: {formatDistanceToNow(new Date(Number(project.createdAt)), { addSuffix: true })}</span>
                                        </div>
                                    </div>
                                    <span className="absolute top-4 right-4 text-xs px-3 py-1 bg-yellow-200 text-yellow-800 rounded-full">{project.status}</span>
                                    <button onClick={() => setOpen(true)} className="px-4 py-2 bg-yellow-500 text-white font-semibold rounded hover:bg-yellow-600">
                                        Deposit
                                    </button>
                                    <button type="submit" className="w-full bg-yellow-400 text-white py-3 rounded-full font-semibold hover:bg-yellow-600 transition" disabled={claimStatus === "loading"}>
                                        {claimStatus === "loading" ? "Claiming..." : "Claim"}
                                    </button>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
            <DepositModal isOpen={open} onClose={() => setOpen(false)} />
        </div>
    );
}
