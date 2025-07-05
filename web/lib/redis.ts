// lib/redis.ts
import Redis from "ioredis";
import { Project } from "./common";

const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");

export async function getUserByAddress(address: string) {
    if (typeof window !== "undefined") return null;
    console.log("getUserByAddress: ", address);
    const user = await redis.hgetall(`users_${address.toLowerCase()}`);
    return Object.keys(user).length ? user : null;
}

export async function createUser({ address, name }: { address: string; name: string }) {
    if (typeof window !== "undefined") return null;
    const key = `users_${address.toLowerCase()}`;
    const now = new Date().toISOString();
    console.log("createUser: ", { key, name, createdAt: now });
    await redis.hmset(key, { name, address, createdAt: now });
    return { address, name, createdAt: now };
}

export async function getProjectBySlug(slug: string): Promise<Project | null> {
    if (typeof window !== "undefined") return null;
    console.log("getProjectBySlug: ", slug);

    const tickers = await redis.smembers("project_tickers");
    console.log("getProjectBySlug:tickers ", tickers);

    if (!tickers.includes(slug)) {
        return null;
    }

    const data = await redis.hgetall(`project_${slug}`);
    const pj: Project = { id: slug, ...data };
    return Object.keys(data).length ? pj : null;
}

export default redis;
