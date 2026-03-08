"use client";

import { createClient } from "@/lib/supabase/client";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

const ALLOWED_DOMAINS = (process.env.NEXT_PUBLIC_ALLOWED_ADMIN_DOMAINS || "")
  .split(",")
  .map((d) => d.trim().toLowerCase())
  .filter(Boolean);

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const errorParam = searchParams.get("error");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: "error" | "success"; text: string } | null>(
    errorParam === "domain"
      ? { type: "error", text: "Bu e-posta adresiyle giriş yetkiniz yok. Sadece yetkili domain kullanılabilir." }
      : null
  );

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setMessage(null);
    setLoading(true);
    const supabase = createClient();
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) {
      setMessage({ type: "error", text: error.message });
      return;
    }
    if (ALLOWED_DOMAINS.length > 0 && data.user?.email) {
      const emailLower = data.user.email.toLowerCase();
      const allowed = ALLOWED_DOMAINS.some(
        (d) => emailLower.endsWith(`@${d}`) || emailLower === d
      );
      if (!allowed) {
        await supabase.auth.signOut();
        setMessage({
          type: "error",
          text: "Bu e-posta domain'i admin paneline erişemez. Sadece yetkili domain kullanın.",
        });
        return;
      }
    }
    router.push("/");
    router.refresh();
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-900 px-4">
      <div className="w-full max-w-md rounded-2xl border border-slate-700 bg-slate-800 p-8 shadow-xl">
        <h1 className="mb-2 text-2xl font-bold text-white">Çekici Admin</h1>
        <p className="mb-6 text-slate-400">Yetkili e-posta ile giriş yapın</p>
        {message && (
          <div
            className={`mb-4 rounded-lg p-3 text-sm ${
              message.type === "error" ? "bg-red-900/50 text-red-200" : "bg-green-900/50 text-green-200"
            }`}
          >
            {message.text}
          </div>
        )}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="email" className="mb-1 block text-sm font-medium text-slate-300">
              E-posta
            </label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full rounded-lg border border-slate-600 bg-slate-700 px-4 py-2 text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              placeholder="admin@company.com"
            />
          </div>
          <div>
            <label htmlFor="password" className="mb-1 block text-sm font-medium text-slate-300">
              Şifre
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full rounded-lg border border-slate-600 bg-slate-700 px-4 py-2 text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-lg bg-blue-500 py-2.5 font-medium text-white transition hover:bg-blue-600 disabled:opacity-50"
          >
            {loading ? "Giriş yapılıyor..." : "Giriş yap"}
          </button>
        </form>
      </div>
    </div>
  );
}
