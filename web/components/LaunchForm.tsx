import { useState, useEffect } from "react";
import { useAccount, useWriteContract } from "wagmi";
import { utils } from "ethers";
import { AllocationValidator, ValidationResult, TokenBreakdown } from "@/utils/allocationValidation";
import { LaunchFormData, useLaunchProject } from "@/hooks/useLaunchProject";
import "react-datepicker/dist/react-datepicker.css";
import { formatDatetimeLocal } from "@/lib/common";
import ClipLoader from "react-spinners/ClipLoader";

export default function LaunchForm() {
    const { status: walletStatus, address, isDisconnected } = useAccount();

    const [toastMessage, setToastMessage] = useState("");
    const [showToast, setShowToast] = useState(false);
    const [pageIsLoading, setPageIsLoading] = useState(true);

    const displayToast = (message: string) => {
        setToastMessage(message);
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
    };

    const { launch, step, isLoading, receipt, error } = useLaunchProject();

    const [tokenBreakdown, setTokenBreakdown] = useState<TokenBreakdown | null>(null);
    const [allocationValidation, setAllocationValidation] = useState<ValidationResult>({
        isValid: true,
        errors: [],
        participantPercentage: 7000,
    });

    const [formData, setFormData] = useState<LaunchFormData>({
        name: "",
        symbol: "",
        description: "",
        initialSupply: "1000000",
        maxSupply: "10000000",
        startTime: formatDatetimeLocal(new Date()),
        endTime: formatDatetimeLocal(new Date(Date.now() + 1000 * 60 * 60 * 24)), // +1 day
        maxAllocation: "50000",
        tokensForGiveaway: "100000",
        devPercentage: 1000, // 10% default
        liquidityPercentage: 2000, // 20% minimum default
        enableTradingImmediately: true, // Professional default
    });

    // Real-time allocation validation
    useEffect(() => {
        const validation = AllocationValidator.validateAllocation(formData.devPercentage, formData.liquidityPercentage);
        setAllocationValidation(validation);

        if (validation.isValid && formData.tokensForGiveaway) {
            const breakdown = AllocationValidator.calculateTokenBreakdown(utils.parseEther(formData.tokensForGiveaway || "0"), formData.devPercentage, formData.liquidityPercentage);
            setTokenBreakdown(breakdown);
        }
    }, [formData.devPercentage, formData.liquidityPercentage, formData.tokensForGiveaway]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!allocationValidation.isValid) {
            displayToast("Please fix allocation errors before launching");
            console.error("Allocation errors", allocationValidation.errors);
            return;
        }
        launch(formData);
    };

    useEffect(() => {
        if (walletStatus === "connected") {
            setPageIsLoading(false);
        }
    }, [walletStatus]);

    // Show success state with allocation details
    if (receipt) {
        return (
            <div className="success-screen p-6 bg-green-50 rounded-lg">
                <h2 className="text-2xl font-bold text-green-800 mb-4">🎉 Professional Project Launched!</h2>
                <div className="space-y-2 text-green-700">
                    <p>
                        <strong>Transaction:</strong> {receipt.transactionHash}
                    </p>
                    <p>
                        <strong>Status:</strong> Ready for participants with immediate trading
                    </p>

                    {tokenBreakdown && (
                        <div className="mt-4 p-4 bg-white rounded border">
                            <h3 className="font-semibold mb-2">Token Allocation Breakdown:</h3>
                            <div className="grid grid-cols-3 gap-4 text-sm">
                                <div>
                                    <div className="font-medium">Developer</div>
                                    <div>{tokenBreakdown.devPercentage.toFixed(1)}%</div>
                                    <div>{utils.formatEther(tokenBreakdown.devTokens).toLocaleString()} tokens</div>
                                </div>
                                <div>
                                    <div className="font-medium">Liquidity</div>
                                    <div>{tokenBreakdown.liquidityPercentage.toFixed(1)}%</div>
                                    <div>{utils.formatEther(tokenBreakdown.liquidityTokens).toLocaleString()} tokens</div>
                                </div>
                                <div>
                                    <div className="font-medium">Participants</div>
                                    <div>{tokenBreakdown.participantPercentage.toFixed(1)}%</div>
                                    <div>{utils.formatEther(tokenBreakdown.participantTokens).toLocaleString()} tokens</div>
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        );
    }

    return (
        <>

            {pageIsLoading && (
                         <div className="flex flex-col justify-center items-center py-12">
                         <ClipLoader color="#facc15" size={48} />
                         <p className="text-gray-500 text-sm">Preparing your form...</p>
                     </div>
                    )}

            {!pageIsLoading && walletStatus === "disconnected" && <div className="text-red-600 font-semibold text-center">You are disconnected! 🎉</div>}
            {!pageIsLoading && walletStatus === "connected" && (
                <form onSubmit={handleSubmit} className="space-y-6">
                    {/* Token Details */}
                    <div className="space-y-4">
                        <h3 className="text-lg font-semibold">Token Configuration</h3>
                        <div className="grid grid-cols-2 gap-4">
                            <input type="text" placeholder="Project Name" value={formData.name} onChange={(e) => setFormData({ ...formData, name: e.target.value })} className="border rounded px-3 py-2" required />
                            <input type="text" placeholder="Symbol (e.g., PROJ)" value={formData.symbol} onChange={(e) => setFormData({ ...formData, symbol: e.target.value.toUpperCase() })} className="border rounded px-3 py-2" required />
                        </div>

                        <textarea placeholder="Project Description" value={formData.description} onChange={(e) => setFormData({ ...formData, description: e.target.value })} className="w-full border rounded px-3 py-2 h-24" required />

                        <div className="grid grid-cols-2 gap-4">
                            <input type="number" placeholder="Initial Supply" value={formData.initialSupply} onChange={(e) => setFormData({ ...formData, initialSupply: e.target.value })} className="border rounded px-3 py-2" required />
                            <input type="number" placeholder="Max Supply" value={formData.maxSupply} onChange={(e) => setFormData({ ...formData, maxSupply: e.target.value })} className="border rounded px-3 py-2" required />
                        </div>
                    </div>

                    {/* Professional Allocation Section */}
                    <div className="space-y-4 p-4 bg-blue-50 rounded-lg">
                        <h3 className="text-lg font-semibold text-blue-800">🏆 Professional Allocation Settings</h3>

                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <label className="block text-sm font-medium mb-1">Developer Allocation</label>
                                <div className="flex items-center space-x-2">
                                    <input type="range" min="0" max="5000" step="100" value={formData.devPercentage} onChange={(e) => setFormData({ ...formData, devPercentage: parseInt(e.target.value) })} className="flex-1" />
                                    <span className="w-12 text-sm">{(formData.devPercentage / 100).toFixed(1)}%</span>
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium mb-1">Liquidity Allocation</label>
                                <div className="flex items-center space-x-2">
                                    <input type="range" min="2000" max="5000" step="100" value={formData.liquidityPercentage} onChange={(e) => setFormData({ ...formData, liquidityPercentage: parseInt(e.target.value) })} className="flex-1" />
                                    <span className="w-12 text-sm">{(formData.liquidityPercentage / 100).toFixed(1)}%</span>
                                </div>
                            </div>
                        </div>

                        {/* Allocation Validation Display */}
                        <div className={`p-3 rounded ${allocationValidation.isValid ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"}`}>
                            {allocationValidation.isValid ? (
                                <div>
                                    <div className="font-medium">✅ Professional Allocation Valid</div>
                                    <div className="text-sm">Participants will receive {(allocationValidation.participantPercentage / 100).toFixed(1)}% of tokens</div>
                                </div>
                            ) : (
                                <div>
                                    <div className="font-medium">❌ Allocation Issues:</div>
                                    <ul className="text-sm list-disc list-inside">
                                        {allocationValidation.errors.map((error, idx) => (
                                            <li key={idx}>{error}</li>
                                        ))}
                                    </ul>
                                </div>
                            )}
                        </div>

                        {/* Token Breakdown Preview */}
                        {tokenBreakdown && allocationValidation.isValid && (
                            <div className="p-3 bg-white rounded border">
                                <div className="text-sm font-medium mb-2">Token Distribution Preview:</div>
                                <div className="grid grid-cols-3 gap-2 text-xs">
                                    <div className="text-center p-2 bg-purple-100 rounded">
                                        <div className="font-medium">Developer</div>
                                        <div>{utils.formatEther(tokenBreakdown.devTokens).toLocaleString()}</div>
                                    </div>
                                    <div className="text-center p-2 bg-blue-100 rounded">
                                        <div className="font-medium">Liquidity</div>
                                        <div>{utils.formatEther(tokenBreakdown.liquidityTokens).toLocaleString()}</div>
                                    </div>
                                    <div className="text-center p-2 bg-green-100 rounded">
                                        <div className="font-medium">Participants</div>
                                        <div>{utils.formatEther(tokenBreakdown.participantTokens).toLocaleString()}</div>
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>

                    {/* Giveaway Details */}
                    <div className="space-y-4">
                        <h3 className="text-lg font-semibold">Giveaway Configuration</h3>
                        <div className="grid grid-cols-2 gap-4">
                            <input type="datetime-local" placeholder="Start Time" value={formData.startTime} onChange={(e) => setFormData({ ...formData, startTime: e.target.value })} className="border rounded px-3 py-2" required />
                            <input type="datetime-local" placeholder="End Time" value={formData.endTime} onChange={(e) => setFormData({ ...formData, endTime: e.target.value })} className="border rounded px-3 py-2" required />
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <input type="number" placeholder="Max USDC Allocation" value={formData.maxAllocation} onChange={(e) => setFormData({ ...formData, maxAllocation: e.target.value })} className="border rounded px-3 py-2" required />
                            <input type="number" placeholder="Total Tokens for Giveaway" value={formData.tokensForGiveaway} onChange={(e) => setFormData({ ...formData, tokensForGiveaway: e.target.value })} className="border rounded px-3 py-2" required />
                        </div>

                        <label className="flex items-center space-x-2">
                            <input type="checkbox" checked={formData.enableTradingImmediately} onChange={(e) => setFormData({ ...formData, enableTradingImmediately: e.target.checked })} />
                            <span>Enable trading immediately (Recommended for professional launches)</span>
                        </label>
                    </div>

                    <button type="submit" disabled={isLoading || !allocationValidation.isValid} className="w-full bg-yellow-500 text-white py-3 rounded-lg font-semibold hover:bg-yellow-500 disabled:opacity-50">
                        {isLoading && "Preparing Launch..."}
                        {!isLoading && "🚀 Launch Project (0.1 ETH)"}
                    </button>

                    <div className="text-xs text-gray-600 text-center">Professional standards: 20% minimum liquidity • Maximum 70% total allocations • Immediate trading ready</div>
                </form>
            )}
            {showToast && <div className="fixed bottom-4 right-4 bg-gray-800 text-white py-2 px-4 rounded shadow-lg animate-fade-in text-sm">{toastMessage}</div>}
        </>
    );
}
