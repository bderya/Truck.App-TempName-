"use client";

import { createClient } from "@/lib/supabase/client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

const nav = [
  { href: "/", label: "Dashboard" },
  { href: "/map", label: "Canlı Harita" },
  { href: "/drivers", label: "Bekleyen Sürücüler" },
  { href: "/financials", label: "Finansal Özet" },
  { href: "/bookings", label: "Aktif Rezervasyonlar" },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  async function handleLogout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  return (
    <aside className="fixed left-0 top-0 z-40 h-screen w-56 border-r border-slate-700 bg-slate-800">
      <div className="flex h-full flex-col">
        <div className="border-b border-slate-700 p-4">
          <span className="text-lg font-bold text-white">Çekici Admin</span>
        </div>
        <nav className="flex-1 space-y-1 p-2">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={`block rounded-lg px-3 py-2 text-sm font-medium transition ${
                pathname === item.href
                  ? "bg-blue-500/20 text-blue-400"
                  : "text-slate-300 hover:bg-slate-700 hover:text-white"
              }`}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-slate-700 p-2">
          <button
            onClick={handleLogout}
            className="w-full rounded-lg px-3 py-2 text-left text-sm text-slate-400 hover:bg-slate-700 hover:text-white"
          >
            Çıkış yap
          </button>
        </div>
      </div>
    </aside>
  );
}
