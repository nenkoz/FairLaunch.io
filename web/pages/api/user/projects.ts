// pages/api/projects.ts
import type { NextApiRequest, NextApiResponse } from "next";
import redis from "@/lib/redis";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const address = req.query.address?.toString().toLowerCase();
    let projects = [];
    try {
        if (address) {
            console.log("API:Fetching projects for user:", address);
            projects = await redis.smembers(`projects_user_${address}`);
        } else {
            projects = await redis.smembers(`project_tickers`);
        }

        if (projects.length === 0) {
            return res.status(200).json([]);
        }

        const projectsWithDataArray = await Promise.all(
            projects.map(async (ticker) => {
                ticker = ticker.toLowerCase();
                const data = await redis.hgetall(`project_${ticker}`);
                // Parse any JSON fields in the data using reduce
                const parsedData = Object.entries(data).reduce((acc, [key, value]) => {
                    try {
                        acc[key] = JSON.parse(value as string);
                    } catch {
                        acc[key] = value;
                    }
                    return acc;
                }, {} as Record<string, any>);

                return {
                    id: ticker,
                    ...parsedData,
                };
            })
        );

        return res.status(200).json(projectsWithDataArray);
    } catch (error) {
        console.error("Failed to fetch projects:", error);
        return res.status(500).json({ error: "Failed to fetch projects" });
    }
}
