"use client";

import { createClient } from "@/lib/supabase/client";
import { useCallback, useEffect, useState } from "react";

export interface ReviewRow {
  id: number;
  booking_id: number;
  driver_id: number;
  client_id: number;
  rating: number;
  comment: string | null;
  tags: string[] | null;
  created_at: string;
  driver_name?: string;
  client_name?: string;
}

export function ReviewsTable() {
  const [reviews, setReviews] = useState<ReviewRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [lowRatingsOnly, setLowRatingsOnly] = useState(false);
  const supabase = createClient();

  const fetchReviews = useCallback(async () => {
    let query = supabase
      .from("reviews")
      .select(`
        id,
        booking_id,
        driver_id,
        client_id,
        rating,
        comment,
        tags,
        created_at
      `)
      .order("created_at", { ascending: false });

    if (lowRatingsOnly) {
      query = query.lte("rating", 2);
    }

    const { data } = await query;
    const rows = (data || []) as ReviewRow[];

    if (rows.length > 0) {
      const driverIds = [...new Set(rows.map((r) => r.driver_id))];
      const clientIds = [...new Set(rows.map((r) => r.client_id))];
      const { data: users } = await supabase
        .from("users")
        .select("id, full_name")
        .in("id", [...driverIds, ...clientIds]);
      const userMap = new Map((users || []).map((u: { id: number; full_name: string }) => [u.id, u.full_name]));
      rows.forEach((r) => {
        r.driver_name = userMap.get(r.driver_id);
        r.client_name = userMap.get(r.client_id);
      });
    }

    setReviews(rows);
    setLoading(false);
  }, [supabase, lowRatingsOnly]);

  useEffect(() => {
    setLoading(true);
    fetchReviews();
  }, [fetchReviews]);

  if (loading) {
    return (
      <div className="rounded-xl border border-slate-700 bg-slate-800 p-8 text-center text-slate-400">
        Yükleniyor...
      </div>
    );
  }

  if (reviews.length === 0) {
    return (
      <div className="rounded-xl border border-slate-700 bg-slate-800 p-8 text-center text-slate-400">
        {lowRatingsOnly ? "Düşük puanlı değerlendirme yok." : "Henüz değerlendirme yok."}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        <label className="flex items-center gap-2 text-sm text-slate-300">
          <input
            type="checkbox"
            checked={lowRatingsOnly}
            onChange={(e) => setLowRatingsOnly(e.target.checked)}
            className="rounded border-slate-600 bg-slate-700 text-amber-500"
          />
          Düşük puanlar (≤2)
        </label>
      </div>
      <div className="overflow-hidden rounded-xl border border-slate-700">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-sm">
            <thead className="border-b border-slate-700 bg-slate-800/80 text-slate-400">
              <tr>
                <th className="px-4 py-3 font-medium">ID</th>
                <th className="px-4 py-3 font-medium">Rezervasyon</th>
                <th className="px-4 py-3 font-medium">Puan</th>
                <th className="px-4 py-3 font-medium">Sürücü</th>
                <th className="px-4 py-3 font-medium">Müşteri</th>
                <th className="px-4 py-3 font-medium">Yorum</th>
                <th className="px-4 py-3 font-medium">Etiketler</th>
                <th className="px-4 py-3 font-medium">Tarih</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-700 bg-slate-800">
              {reviews.map((r) => (
                <tr key={r.id} className="transition hover:bg-slate-700/50">
                  <td className="px-4 py-3 font-mono text-slate-300">#{r.id}</td>
                  <td className="px-4 py-3 font-mono text-slate-300">#{r.booking_id}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                        r.rating <= 2
                          ? "bg-red-500/20 text-red-400"
                          : r.rating <= 3
                            ? "bg-amber-500/20 text-amber-400"
                            : "bg-green-500/20 text-green-400"
                      }`}
                    >
                      {r.rating} ★
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-200">{r.driver_name ?? `#${r.driver_id}`}</td>
                  <td className="px-4 py-3 text-slate-200">{r.client_name ?? `#${r.client_id}`}</td>
                  <td className="max-w-[240px] truncate px-4 py-3 text-slate-300" title={r.comment ?? ""}>
                    {r.comment || "—"}
                  </td>
                  <td className="px-4 py-3 text-slate-400">
                    {Array.isArray(r.tags) && r.tags.length > 0 ? r.tags.join(", ") : "—"}
                  </td>
                  <td className="px-4 py-3 text-slate-500">
                    {new Date(r.created_at).toLocaleString("tr-TR")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
