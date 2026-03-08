"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

const dataKeys = [
  { key: "revenue" as const, name: "Gelir", color: "#3b82f6" },
  { key: "commission" as const, name: "Komisyon", color: "#f59e0b" },
  { key: "payout" as const, name: "Ödeme", color: "#22c55e" },
];

type DayRow = { date: string; revenue: number; commission: number; payout: number };

export function FinancialCharts({ data }: { data: DayRow[] }) {
  const formatDate = (s: string) => {
    const d = new Date(s);
    return `${d.getDate()}/${d.getMonth() + 1}`;
  };

  return (
    <div className="space-y-6">
      <div className="rounded-xl border border-slate-700 bg-slate-800 p-4">
        <h2 className="mb-4 text-lg font-medium text-white">Son 7 gün – Günlük gelir, komisyon ve ödemeler</h2>
        <div className="h-80">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
              <XAxis
                dataKey="date"
                tickFormatter={formatDate}
                stroke="#94a3b8"
                fontSize={12}
              />
              <YAxis stroke="#94a3b8" fontSize={12} tickFormatter={(v) => `${v} ₺`} />
              <Tooltip
                contentStyle={{ backgroundColor: "#1e293b", border: "1px solid #334155", borderRadius: "8px" }}
                labelFormatter={formatDate}
                formatter={(value: number) => [`${value.toFixed(0)} ₺`, undefined]}
              />
              <Legend />
              {dataKeys.map(({ key, name, color }) => (
                <Area
                  key={key}
                  type="monotone"
                  dataKey={key}
                  name={name}
                  stroke={color}
                  fill={color}
                  fillOpacity={0.3}
                  strokeWidth={2}
                />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}
