import { ActiveBookingsTable } from "./ActiveBookingsTable";

export default function BookingsPage() {
  return (
    <div>
      <h1 className="mb-2 text-2xl font-bold text-white">Aktif Rezervasyonlar</h1>
      <p className="mb-6 text-slate-400">
        Tablo Supabase Realtime ile anlık güncellenir.
      </p>
      <ActiveBookingsTable />
    </div>
  );
}
