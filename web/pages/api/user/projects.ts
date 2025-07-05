// pages/api/projects.ts
import type { NextApiRequest, NextApiResponse } from "next";
import redis from "@/lib/redis"; // ioredis instance

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const address = req.query.address?.toString().toLowerCase();
    if (!address) {
        console.log("User ID required");
        return res.status(401).json({ error: "User ID required" });
    }

    try {
        const userProjects = await redis.smembers(`projects_user_${address}`);
        const projectsWithDataArray = await Promise.all(
            userProjects.map(async (ticker) => {
                const data = await redis.hgetall(`project_${ticker}`);
                return {
                    id: ticker,
                    ...data,
                };
            })
        );

        return res.status(200).json(projectsWithDataArray);
    } catch (error) {
        console.error("Failed to fetch projects:", error);
        return res.status(500).json({ error: "Failed to fetch projects" });
    }
}
