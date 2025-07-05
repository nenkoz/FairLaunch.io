import { NextApiRequest, NextApiResponse } from "next";
import redis, { getUserByAddress } from "@/lib/redis";

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const { address } = req.body;
    const user = await getUserByAddress(address);
    if (!user) {
        return res.status(404).json({ message: "User not found", user: null });
    }

    return res.status(200).json({ message: "Success", user: user });
}
