"use client";

import { createContext, useContext, useState, useEffect, Dispatch, SetStateAction } from "react";

export interface User {
    id: string;
    name: string;
    email: string;
    address: string;
    age?: number;
    photo_url?: string | null;
    verified: boolean;
}

interface UserContextType {
    user: User | null;
    setUser: Dispatch<SetStateAction<User | null>>;
}

const UserContext = createContext<UserContextType | null>(null);

export const UserProvider = ({ children }: { children: React.ReactNode }) => {
    const [user, setUser] = useState<User | null>(null);

    useEffect(() => {
        const storedId = localStorage.getItem("userId");
        if (!storedId) return;

        fetch(`/api/user/${storedId}`)
            .then((res) => res.json())
            .then((data) => {
                if (!data.user) return;
                setUser({
                    id: data.user.id,
                    name: data.user.name,
                    email: data.user.email,
                    address: data.user.address,
                    age: data.user.age,
                    photo_url: data.user.photo_url ?? null,
                    verified: data.user.verified === "true",
                });
            });
    }, []);

    return <UserContext.Provider value={{ user, setUser }}>{children}</UserContext.Provider>;
};

export const useUser = () => {
    const context = useContext(UserContext);
    if (!context) {
        throw new Error("useUser must be used within a UserProvider");
    }
    return context;
};
