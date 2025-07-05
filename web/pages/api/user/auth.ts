// pages/api/auth/verify.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { verifyMessage } from "@/lib/common";
import redis, { getUserByAddress, createUser } from "@/lib/redis";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    let { address, signature, name } = req.body;
    address = address.toLowerCase();
    const nonce = await redis.get(`nonce_${address}`);

    if (!nonce) {
        return res.status(400).json({ error: "Missing nonce" });
    }

    const valid = await verifyMessage({ address, message: nonce, signature });
    if (!valid) {
        return res.status(401).json({ error: "Invalid signature" });
    }

    // prevent replay
    await redis.del(`nonce_${address}`);

    let user = await getUserByAddress(address);
    if (!user && name) {
        user = await createUser({ address, name });
        return res.status(200).json({ success: true, user });
    }

    console.log("user already here");
    return res.status(200).json({ success: true, exists: true, user });
}
