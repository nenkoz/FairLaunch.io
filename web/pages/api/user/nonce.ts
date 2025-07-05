import type { NextApiRequest, NextApiResponse } from "next";
import redis from "@/lib/redis";
import { randomBytes } from "crypto";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const address = req.query.address?.toString().toLowerCase();
    console.log("nonce handler: ", address);
    if (!address) return res.status(400).send("Missing address");

    const nonce = `Sign to authenticate: ${randomBytes(16).toString("hex")}`;
    await redis.set(`nonce_${address}`, nonce, "EX", 3600); // 1hr expiry

    res.send(nonce);
}
