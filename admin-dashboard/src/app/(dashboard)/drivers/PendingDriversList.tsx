"use client";

import { createClient } from "@/lib/supabase/client";
import type { User } from "@/types/database";
import { useRouter } from "next/navigation";
import { useState } from "react";

type DriverRow = User & { id: number };
type TrucksByDriver = Record<number, { plate_number: string; plate_image_url: string | null }>;

export function PendingDriversList({
  drivers,
  trucksByDriver,
}: {
  drivers: DriverRow[];
  trucksByDriver: TrucksByDriver;
}) {
  const router = useRouter();
  const [loadingId, setLoadingId] = useState<number | null>(null);
  const [selectedDoc, setSelectedDoc] = useState<string | null>(null);

  async function handleApprove(userId: number, approved: boolean) {
    setLoadingId(userId);
    const supabase = createClient();
    const { error } = await supabase.rpc("approve_user", {
      p_user_id: userId,
      p_status: approved ? "approved" : "rejected",
    });
    setLoadingId(null);
    if (!error) router.refresh();
  }

  const images = (d: DriverRow) => [
    { label: "Ehliyet", url: d.license_image_url },
    { label: "Sabıka kaydı", url: d.criminal_record_url },
    { label: "Selfie + Ehliyet", url: (d as { selfie_with_license_url?: string | null }).selfie_with_license_url },
    { label: "Plaka", url: trucksByDriver[d.id]?.plate_image_url ?? null },
  ].filter((x) => x.url);

  return (
    <div className="space-y-4">
      {drivers.length === 0 ? (
        <p className="rounded-xl border border-slate-700 bg-slate-800 p-8 text-center text-slate-400">
          Liste boş.
        </p>
      ) : (
        drivers.map((d) => (
          <div
            key={d.id}
            className="rounded-xl border border-slate-700 bg-slate-800 p-4 transition hover:border-slate-600"
          >
            <div className="flex flex-wrap items-start gap-6">
              <div className="min-w-[200px]">
                <h3 className="font-medium text-white">{d.full_name}</h3>
                <p className="text-sm text-slate-400">{d.phone_number}</p>
                <p className="mt-1 text-xs text-slate-500">
                  {trucksByDriver[d.id]?.plate_number ?? "—"} · {d.status}
                </p>
                <div className="mt-3 flex gap-2">
                  <button
                    onClick={() => handleApprove(d.id, true)}
                    disabled={loadingId === d.id}
                    className="rounded-lg bg-green-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-green-500 disabled:opacity-50"
                  >
                    Onayla
                  </button>
                  <button
                    onClick={() => handleApprove(d.id, false)}
                    disabled={loadingId === d.id}
                    className="rounded-lg bg-red-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-red-500 disabled:opacity-50"
                  >
                    Reddet
                  </button>
                </div>
              </div>
              <div className="flex flex-1 flex-wrap gap-4">
                {images(d).map((img) => (
                  <div key={img.label} className="flex flex-col">
                    <span className="mb-1 text-xs text-slate-500">{img.label}</span>
                    <button
                      type="button"
                      onClick={() => setSelectedDoc(selectedDoc === img.url ? null : img.url!)}
                      className="relative h-24 w-40 overflow-hidden rounded-lg border border-slate-600 bg-slate-700 object-cover hover:ring-2 hover:ring-blue-500"
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={img.url!}
                        alt={img.label}
                        className="h-full w-full object-cover"
                      />
                    </button>
                  </div>
                ))}
                {images(d).length === 0 && (
                  <p className="text-sm text-slate-500">Yüklenen belge yok.</p>
                )}
              </div>
            </div>
          </div>
        ))
      )}
      {selectedDoc && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
          onClick={() => setSelectedDoc(null)}
        >
          <div className="relative max-h-[90vh] max-w-2xl" onClick={(e) => e.stopPropagation()}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={selectedDoc}
              alt="Belge"
              className="max-h-[90vh] w-auto rounded-lg object-contain"
            />
            <button
              onClick={() => setSelectedDoc(null)}
              className="absolute -right-2 -top-2 rounded-full bg-slate-700 p-1 text-white hover:bg-slate-600"
            >
              ✕
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
