"use client";

import { createClient } from "@/lib/supabase/client";
import type { Booking } from "@/types/database";
import { useCallback, useEffect, useState } from "react";

const ACTIVE_STATUSES = ["pending", "accepted", "on_the_way", "picked_up"];
const STATUS_LABELS: Record<string, string> = {
  pending: "Bekliyor",
  accepted: "Kabul",
  on_the_way: "Yolda",
  picked_up: "Alındı",
};

export function ActiveBookingsTable() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const supabase = createClient();

  const fetchBookings = useCallback(async () => {
    const { data } = await supabase
      .from("bookings")
      .select("*")
      .in("status", ACTIVE_STATUSES)
      .order("created_at", { ascending: false });
    setBookings((data as Booking[]) || []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    fetchBookings();

    const channel = supabase
      .channel("active-bookings")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "bookings" },
        () => fetchBookings()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [supabase, fetchBookings]);

  if (loading) {
    return (
      <div className="rounded-xl border border-slate-700 bg-slate-800 p-8 text-center text-slate-400">
        Yükleniyor...
      </div>
    );
  }

  if (bookings.length === 0) {
    return (
      <div className="rounded-xl border border-slate-700 bg-slate-800 p-8 text-center text-slate-400">
        Aktif rezervasyon yok.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-slate-700">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="border-b border-slate-700 bg-slate-800/80 text-slate-400">
            <tr>
              <th className="px-4 py-3 font-medium">ID</th>
              <th className="px-4 py-3 font-medium">Alış</th>
              <th className="px-4 py-3 font-medium">Varış</th>
              <th className="px-4 py-3 font-medium">Durum</th>
              <th className="px-4 py-3 font-medium">Fiyat</th>
              <th className="px-4 py-3 font-medium">Tarih</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-700 bg-slate-800">
            {bookings.map((b) => (
              <tr key={b.id} className="transition hover:bg-slate-700/50">
                <td className="px-4 py-3 font-mono text-slate-300">#{b.id}</td>
                <td className="max-w-[200px] truncate px-4 py-3 text-slate-200" title={b.pickup_address}>
                  {b.pickup_address}
                </td>
                <td className="max-w-[200px] truncate px-4 py-3 text-slate-200" title={b.destination_address}>
                  {b.destination_address}
                </td>
                <td className="px-4 py-3">
                  <span
                    className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                      b.status === "pending"
                        ? "bg-amber-500/20 text-amber-400"
                        : b.status === "accepted"
                          ? "bg-blue-500/20 text-blue-400"
                          : "bg-green-500/20 text-green-400"
                    }`}
                  >
                    {STATUS_LABELS[b.status] ?? b.status}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-200">
                  {b.price != null ? `${Number(b.price).toFixed(0)} ₺` : "—"}
                </td>
                <td className="px-4 py-3 text-slate-500">
                  {new Date(b.created_at).toLocaleString("tr-TR")}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
