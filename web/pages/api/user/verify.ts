import { NextApiRequest, NextApiResponse } from "next";
import redis from "@/lib/redis";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    if (req.method !== "POST") {
        return res.status(405).json({ message: "Method not allowed" });
    }

    const { address } = req.body;

    await redis.hset(`user_${address}`, "verified", "true");
    // await redis.hset(`user_nullifier:${address}`, "verified", true);

    return res.status(200).json({ message: " successfully" });
}
