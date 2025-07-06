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
import { Home, Rocket, Wallet, Compass, Settings, Search } from "lucide-react";
import ProjectComponent from "@/components/ProjectComponent";

export default function ExplorePage() {
    const router = useRouter();
    const { user } = useUser();
    const [projects, setProjects] = useState<Project[]>([]);
    const [claimed, setClaimed] = useState(0);
    const [unclaimed, setUnclaimed] = useState(0);
    const [loading, setLoading] = useState(true);
    const [open, setOpen] = useState(false);

    const { address, isConnected } = useAccount();
    // const { data, isLoading } = useBalance({
    //     address,
    // });

    useEffect(() => {

        if (!address) {
            console.warn("no wagmi:address ", address);
            setLoading(false);
            return;
        }
console.log("wagmi:address ", address);
     

        (async () => {
            setLoading(true);
            try{
            const res = await fetch("/api/user/projects");
            const data = await res.json();
            console.log("API:Fetching projects:", data)
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
            }catch(e){
                console.error("Error fetching projects:", e);
                setLoading(false);
            }
        })()

    }, [address]);

    const claimStatus = "";

    return (
        <div className="flex flex-col">
            <NavComponent />
            <div className="flex-1 flex items-center justify-center">
                <div className="p-6 max-w-4xl mx-auto w-full">
                    <h1 className="text-2xl font-bold text-yellow-600 mb-4">Explore</h1>
                    {loading && (
                         <div className="flex flex-col justify-center items-center py-12">
                         <ClipLoader color="#facc15" size={48} />
                         <p className="text-gray-500 text-sm">Please wait...</p>
                     </div>
                    )}

                    {!loading && projects.length === 0 && (
                        <div className="p-6 text-center bg-gray-100 rounded-xl">
                            <Rocket className="w-12 h-12 mx-auto mb-4 text-yellow-500" />
                            <h3 className="text-xl font-semibold text-black mb-2">No Projects</h3>
                            <p className="text-text-secondary">Creators are still working on their projects.</p>
                            <button onClick={() => router.push("/launch")} className="w-full bg-yellow-400 text-white py-3 rounded-full font-semibold hover:bg-yellow-600 transition mt-4">
                                Why not be first?
                            </button>
                        </div>
                    )}

{!loading && projects.length > 0 && (
                        <div className="grid md:grid-cols-2 gap-6">
                            {projects.map((project) => (
                                <ProjectComponent key={project.symbol} project={project} onDeposit={() => setOpen(true)} canDeposit={true} />
                            ))}
                        </div>
                    )}
                </div>
            </div>
            <DepositModal isOpen={open} onClose={() => setOpen(false)} />
        </div>
    );
}
