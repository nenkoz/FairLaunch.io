import type { NextApiRequest, NextApiResponse } from "next";
import redis from "@/lib/redis";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const { slug } = req.query;
    console.log("handler:project slug", slug);

    if (!slug || typeof slug !== "string") {
        return res.status(400).json({ error: "Missing slug" });
    }

    try {
        const normalizedSlug = slug.toLowerCase();
        const validTickers = await redis.smembers("project_tickers");
        if (!validTickers.includes(normalizedSlug)) {
            return res.status(404).json({ error: "Project not found" });
        }

        const project = await redis.hgetall(`project_${normalizedSlug}`);
        if (!project || Object.keys(project).length === 0) {
            return res.status(404).json({ error: "Project data missing" });
        }

        return res.status(200).json({ ...project, id: normalizedSlug });
    } catch (err) {
        console.error("Error fetching project:", err);
        return res.status(500).json({ error: "Internal server error" });
    }
}
