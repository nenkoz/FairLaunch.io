interface LaunchProgressProps {
    step: number;
    isLoading: boolean;
    isComplete: boolean;
}

interface Step {
    id: number;
    title: string;
    desc: string;
}

export function LaunchProgress({ step, isLoading, isComplete }: LaunchProgressProps) {
    const steps: Step[] = [
        { id: 1, title: "Creating Token", desc: "Deploying your project token..." },
        { id: 2, title: "Setting up Giveaway", desc: "Configuring token distribution..." },
        { id: 3, title: "Finalizing", desc: "Making your project live..." },
    ];

    return (
        <div className="space-y-4">
            {steps.map((s) => (
                <div key={s.id} className={`flex items-center space-x-3 ${step >= s.id ? "text-blue-600" : "text-gray-400"}`}>
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center ${step > s.id ? "bg-green-500 text-white" : step === s.id ? "bg-blue-500 text-white animate-pulse" : "bg-gray-200"}`}>{step > s.id ? "✓" : s.id}</div>
                    <div>
                        <div className="font-medium">{s.title}</div>
                        <div className="text-sm text-gray-600">{s.desc}</div>
                    </div>
                </div>
            ))}
        </div>
    );
}
