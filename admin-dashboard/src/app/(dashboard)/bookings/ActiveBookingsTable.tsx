"use client";

import { createClient } from "@/lib/supabase/client";
import type { Booking } from "@/types/database";
import { useCallback, useEffect, useState } from "react";

const ACTIVE_STATUSES = ["pending", "assigned", "accepted", "on_the_way", "picked_up"];
const STATUS_LABELS: Record<string, string> = {
  pending: "Bekliyor",
  assigned: "Atandı",
  accepted: "Kabul",
  on_the_way: "Yolda",
  picked_up: "Alındı",
};

/** Online driver with distance to job pickup (for manual assign). */
interface OnlineDriver {
  driver_id: number;
  tow_truck_id: number;
  full_name: string;
  plate_number: string;
  current_latitude: number;
  current_longitude: number;
  distance_km: number;
}

function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export function ActiveBookingsTable() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [assignModal, setAssignModal] = useState<{
    booking: Booking;
    drivers: OnlineDriver[];
    loading: boolean;
    assigning: boolean;
  } | null>(null);
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

  const openAssignModal = useCallback(
    async (booking: Booking) => {
      setAssignModal({
        booking,
        drivers: [],
        loading: true,
        assigning: false,
      });

      const pickupLat = booking.pickup_lat;
      const pickupLng = booking.pickup_lng;

      const { data: trucks } = await supabase
        .from("tow_trucks")
        .select("id, driver_id, current_latitude, current_longitude, plate_number, users(full_name)")
        .eq("is_available", true);

      const drivers: OnlineDriver[] = [];
      const trucksList = (trucks || []) as Array<{
        id: number;
        driver_id: number;
        current_latitude: number;
        current_longitude: number;
        plate_number: string;
        users: { full_name: string } | null;
      }>;
      for (const t of trucksList) {
        const lat = Number(t.current_latitude);
        const lng = Number(t.current_longitude);
        const distance_km =
          pickupLat != null && pickupLng != null
            ? haversineKm(pickupLat, pickupLng, lat, lng)
            : 0;
        drivers.push({
          driver_id: t.driver_id,
          tow_truck_id: t.id,
          full_name: t.users?.full_name ?? `Sürücü #${t.driver_id}`,
          plate_number: t.plate_number ?? "",
          current_latitude: lat,
          current_longitude: lng,
          distance_km: Math.round(distance_km * 10) / 10,
        });
      }
      drivers.sort((a, b) => a.distance_km - b.distance_km);

      setAssignModal((m) => (m ? { ...m, drivers, loading: false } : null));
    },
    [supabase]
  );

  const runManualAssign = useCallback(
    async (driverId: number) => {
      const modal = assignModal;
      if (!modal) return;
      const jobId = modal.booking.id;
      setAssignModal((m) => (m ? { ...m, assigning: true } : null));
      const { data: { session } } = await supabase.auth.getSession();
      const url = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/manual-assign-job`;
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session?.access_token ?? ""}`,
        },
        body: JSON.stringify({ jobId, driverId }),
      });
      const json = await res.json().catch(() => ({}));
      setAssignModal((m) => (m ? { ...m, assigning: false } : null));
      if (json.ok) {
        setAssignModal(null);
        fetchBookings();
      } else {
        alert(json.error ?? "Atama başarısız");
      }
    },
    [assignModal, supabase.auth, fetchBookings]
  );

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
    <>
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
                <th className="px-4 py-3 font-medium">İşlem</th>
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
                          : b.status === "assigned"
                            ? "bg-purple-500/20 text-purple-400"
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
                  <td className="px-4 py-3">
                    {b.status === "pending" && (
                      <button
                        type="button"
                        onClick={() => openAssignModal(b)}
                        className="rounded bg-slate-600 px-2 py-1 text-xs font-medium text-white hover:bg-slate-500"
                      >
                        Atama yap
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {assignModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="max-h-[80vh] w-full max-w-md overflow-hidden rounded-xl border border-slate-600 bg-slate-800 shadow-xl">
            <div className="border-b border-slate-700 px-4 py-3">
              <h3 className="font-semibold text-white">Manuel atama — İş #{assignModal.booking.id}</h3>
              <p className="mt-1 truncate text-sm text-slate-400" title={assignModal.booking.pickup_address}>
                {assignModal.booking.pickup_address}
              </p>
            </div>
            <div className="max-h-96 overflow-y-auto p-4">
              {assignModal.loading ? (
                <p className="text-center text-slate-400">Yükleniyor...</p>
              ) : assignModal.drivers.length === 0 ? (
                <p className="text-center text-slate-400">Çevrimiçi sürücü yok.</p>
              ) : (
                <ul className="space-y-2">
                  {assignModal.drivers.map((d) => (
                    <li
                      key={d.driver_id}
                      className="flex items-center justify-between rounded-lg border border-slate-600 bg-slate-700/50 p-3"
                    >
                      <div>
                        <p className="font-medium text-white">{d.full_name}</p>
                        <p className="text-xs text-slate-400">
                          {d.plate_number} · {d.distance_km} km
                        </p>
                      </div>
                      <button
                        type="button"
                        disabled={assignModal.assigning}
                        onClick={() => runManualAssign(d.driver_id)}
                        className="rounded bg-emerald-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-emerald-500 disabled:opacity-50"
                      >
                        {assignModal.assigning ? "..." : "Ata"}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            <div className="border-t border-slate-700 px-4 py-3">
              <button
                type="button"
                onClick={() => setAssignModal(null)}
                className="w-full rounded bg-slate-600 py-2 text-sm font-medium text-white hover:bg-slate-500"
              >
                Kapat
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
