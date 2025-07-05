import { useState, useEffect } from "react";

interface ProjectStatusData {
    [key: string]: any;
}

interface UseProjectStatusReturn {
    status: string;
    data: ProjectStatusData | null;
}

export function useProjectStatus(launchId: string | number | null): UseProjectStatusReturn {
    const [status, setStatus] = useState<string>("launching");
    const [data, setData] = useState<ProjectStatusData | null>(null);

    useEffect(() => {
        if (!launchId) return;

        const pollStatus = async (): Promise<void> => {
            try {
                const response = await fetch(`/api/project-status/${launchId}`);
                const result = await response.json();

                setStatus(result.status);
                setData(result.data);

                // Stop polling when complete
                if (result.status === "complete") {
                    clearInterval(interval);
                }
            } catch (error) {
                console.error("Status poll failed:", error);
            }
        };

        const interval = setInterval(pollStatus, 2000);
        pollStatus(); // Initial call

        return () => clearInterval(interval);
    }, [launchId]);

    return { status, data };
}
