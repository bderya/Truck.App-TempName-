import { createServerSupabaseClient } from "@/lib/supabase/server";
import Link from "next/link";

export default async function DashboardPage() {
  const supabase = await createServerSupabaseClient();
  const [{ count: driversCount }, { count: pendingCount }, { count: activeBookingsCount }] =
    await Promise.all([
      supabase.from("users").select("id", { count: "exact", head: true }).eq("user_type", "driver"),
      supabase.from("users").select("id", { count: "exact", head: true }).eq("user_type", "driver").eq("status", "pending"),
      supabase
        .from("bookings")
        .select("id", { count: "exact", head: true })
        .in("status", ["pending", "accepted", "on_the_way", "picked_up"]),
    ]);

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-white">Dashboard</h1>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Link
          href="/drivers"
          className="rounded-xl border border-slate-700 bg-slate-800 p-5 transition hover:border-slate-600"
        >
          <p className="text-sm text-slate-400">Toplam Sürücü</p>
          <p className="mt-1 text-2xl font-bold text-white">{driversCount ?? 0}</p>
        </Link>
        <Link
          href="/drivers?pending=1"
          className="rounded-xl border border-amber-500/30 bg-slate-800 p-5 transition hover:border-amber-500/50"
        >
          <p className="text-sm text-slate-400">Onay Bekleyen</p>
          <p className="mt-1 text-2xl font-bold text-amber-400">{pendingCount ?? 0}</p>
        </Link>
        <Link
          href="/bookings"
          className="rounded-xl border border-slate-700 bg-slate-800 p-5 transition hover:border-slate-600"
        >
          <p className="text-sm text-slate-400">Aktif Rezervasyon</p>
          <p className="mt-1 text-2xl font-bold text-white">{activeBookingsCount ?? 0}</p>
        </Link>
        <Link
          href="/financials"
          className="rounded-xl border border-slate-700 bg-slate-800 p-5 transition hover:border-slate-600"
        >
          <p className="text-sm text-slate-400">Finansal Özet</p>
          <p className="mt-1 text-2xl font-bold text-white">→</p>
        </Link>
      </div>
      <div className="mt-8">
        <Link
          href="/map"
          className="inline-flex items-center gap-2 rounded-lg bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600"
        >
          Canlı Haritayı Aç
        </Link>
      </div>
    </div>
  );
}
