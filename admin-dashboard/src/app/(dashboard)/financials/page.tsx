import { createServerSupabaseClient } from "@/lib/supabase/server";
import { FinancialCharts } from "./FinancialCharts";

export default async function FinancialsPage() {
  const supabase = await createServerSupabaseClient();
  const { data: completed } = await supabase
    .from("bookings")
    .select("id, price, driver_net_amount, platform_commission_percent, created_at, ended_at")
    .eq("status", "completed")
    .not("price", "is", null)
    .order("ended_at", { ascending: true });

  const byDay: Record<string, { revenue: number; commission: number; payout: number }> = {};
  (completed || []).forEach((b) => {
    const ended = b.ended_at || b.created_at;
    const day = ended ? new Date(ended).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10);
    if (!byDay[day]) byDay[day] = { revenue: 0, commission: 0, payout: 0 };
    const price = Number(b.price) || 0;
    const driverNet = b.driver_net_amount != null ? Number(b.driver_net_amount) : price * 0.85;
    const commission = price - driverNet;
    byDay[day].revenue += price;
    byDay[day].commission += commission;
    byDay[day].payout += driverNet;
  });

  const last7 = Object.entries(byDay)
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-7);
  const dailyData = last7.map(([date, d]) => ({
    date,
    revenue: Math.round(d.revenue * 100) / 100,
    commission: Math.round(d.commission * 100) / 100,
    payout: Math.round(d.payout * 100) / 100,
  }));

  const totals = dailyData.length
    ? dailyData.reduce(
        (acc, d) => ({
          revenue: acc.revenue + d.revenue,
          commission: acc.commission + d.commission,
          payout: acc.payout + d.payout,
        }),
        { revenue: 0, commission: 0, payout: 0 }
      )
    : { revenue: 0, commission: 0, payout: 0 };

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-white">Finansal Özet</h1>
      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-700 bg-slate-800 p-4">
          <p className="text-sm text-slate-400">Toplam Gelir (son 7 gün)</p>
          <p className="text-xl font-bold text-white">{totals.revenue.toFixed(0)} ₺</p>
        </div>
        <div className="rounded-xl border border-amber-500/30 bg-slate-800 p-4">
          <p className="text-sm text-slate-400">Platform Komisyonu</p>
          <p className="text-xl font-bold text-amber-400">{totals.commission.toFixed(0)} ₺</p>
        </div>
        <div className="rounded-xl border border-green-500/30 bg-slate-800 p-4">
          <p className="text-sm text-slate-400">Sürücü Ödemeleri</p>
          <p className="text-xl font-bold text-green-400">{totals.payout.toFixed(0)} ₺</p>
        </div>
      </div>
      <FinancialCharts data={dailyData} />
    </div>
  );
}
