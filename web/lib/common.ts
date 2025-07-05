import { verifyMessage as viemVerifyMessage, Address } from "viem";

export async function verifyMessage({ address, message, signature }: { address: Address; message: string; signature: any }): Promise<boolean> {
    console.table({ address, message, signature });
    try {
        const recovered = await viemVerifyMessage({ address, message, signature });
        console.log("viemVerifyMessage: ", recovered);
        return recovered;
    } catch (err) {
        return false;
    }
}

const VERIFICATION_TTL = 24 * 60 * 60 * 1000; // 24 hours

export const STORAGE_KEY = "verifiedWallets";

export const getVerifiedUsers = (): Record<string, number> => {
    try {
        return JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
    } catch {
        return {};
    }
};
export const setVerifiedUser = (address: string) => {
    console.log("setVerifiedUser", address);
    const data = getVerifiedUsers();
    console.log("setVerifiedUser:getVerifiedUsers", data);

    data[address] = Date.now();
    console.log("localStorage.setItem", STORAGE_KEY, data);

    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
};
export const removeVerifiedUser = (address: string) => {
    const data = getVerifiedUsers();
    delete data[address];
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
};
export const isUserVerified = (address: string): boolean => {
    const data = getVerifiedUsers();
    const ts = data[address];
    if (!ts) return false;
    if (Date.now() - ts > VERIFICATION_TTL) {
        removeVerifiedUser(address);
        return false;
    }
    return true;
};

export interface Project {
    id: string;
    address?: string;
    name?: string;
    description?: string;
    ticker?: string;
    price?: number;
    creatorAddress?: string;
    createdAt?: string;
    claimedFees?: string;
    unclaimedFees?: string;
    image?: string;
    status?: "ACTIVE" | string;
}
