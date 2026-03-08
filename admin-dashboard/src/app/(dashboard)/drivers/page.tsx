import { createServerSupabaseClient } from "@/lib/supabase/server";
import Link from "next/link";
import { PendingDriversList } from "./PendingDriversList";

export default async function DriversPage({
  searchParams,
}: {
  searchParams: Promise<{ pending?: string }>;
}) {
  const { pending: pendingParam } = await searchParams;
  const supabase = await createServerSupabaseClient();
  const { data: drivers } = await supabase
    .from("users")
    .select("id, full_name, phone_number, status, is_verified, license_image_url, criminal_record_url, selfie_with_license_url, created_at")
    .eq("user_type", "driver")
    .order("created_at", { ascending: false });

  const { data: trucks } = drivers?.length
    ? await supabase
        .from("tow_trucks")
        .select("driver_id, plate_number, plate_image_url")
        .in("driver_id", drivers.map((d) => d.id))
    : { data: [] };

  const trucksByDriver = (trucks || []).reduce(
    (acc: Record<number, { plate_number: string; plate_image_url: string | null }>, t: { driver_id: number; plate_number: string; plate_image_url: string | null }) => {
      acc[t.driver_id] = { plate_number: t.plate_number, plate_image_url: t.plate_image_url };
      return acc;
    },
    {}
  );

  const pending = (drivers || []).filter((d) => d.status === "pending" || !d.is_verified);
  const list = pendingParam === "1" ? pending : (drivers || []);

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-white">Sürücüler</h1>
      <div className="mb-4 flex gap-2">
        <Link
          href="/drivers?pending=1"
          className="rounded-lg border border-amber-500/50 bg-slate-800 px-4 py-2 text-sm font-medium text-amber-400 hover:bg-slate-700"
        >
          Onay bekleyen ({pending.length})
        </Link>
        <Link
          href="/drivers"
          className="rounded-lg border border-slate-600 bg-slate-800 px-4 py-2 text-sm font-medium text-slate-300 hover:bg-slate-700"
        >
          Tümü
        </Link>
      </div>
      <PendingDriversList
        drivers={list}
        trucksByDriver={trucksByDriver}
      />
    </div>
  );
}
