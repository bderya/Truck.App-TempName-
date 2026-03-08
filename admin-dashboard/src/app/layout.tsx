import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Çekici Admin",
  description: "Master Admin Dashboard",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="tr">
      <body className="min-h-screen bg-slate-900 text-slate-100 antialiased">
        {children}
      </body>
    </html>
  );
}
