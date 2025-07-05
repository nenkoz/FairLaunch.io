import { NextRequest, NextResponse } from "next/server";

export function middleware(request: NextRequest) {
    const authToken = request.headers.get("authorization") || request.cookies.get("auth-token")?.value;
    console.log("checking middleware", authToken);
    if (!authToken) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
    return NextResponse.next();
}

export const config = {
    matcher: ["/api/user/verif"],
};
