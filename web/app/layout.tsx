import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";
// import "@rainbow-me/rainbowkit/dist/index.css";
import { UserProvider } from "../context/UserContext";
import { Providers } from "../providers/providers";
import "@rainbow-me/rainbowkit/styles.css";

const geistSans = localFont({
    src: "./fonts/GeistVF.woff",
    variable: "--font-geist-sans",
    weight: "100 900",
});
const geistMono = localFont({
    src: "./fonts/GeistMonoVF.woff",
    variable: "--font-geist-mono",
    weight: "100 900",
});

export const metadata: Metadata = {
    title: process.env.NEXT_PUBLIC_SELF_APP_NAME,
    description: process.env.NEXT_PUBLIC_SELF_APP_NAME,
};

export default function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="en">
            <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
                <Providers>
                    <UserProvider>{children}</UserProvider>
                </Providers>
            </body>
        </html>
    );
}
