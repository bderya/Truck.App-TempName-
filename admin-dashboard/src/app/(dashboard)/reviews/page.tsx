import { ReviewsTable } from "./ReviewsTable";

export default function ReviewsPage() {
  return (
    <div>
      <h1 className="mb-2 text-2xl font-bold text-white">Değerlendirmeler</h1>
      <p className="mb-6 text-slate-400">
        Müşteri yorumları ve puanları. Düşük puanları filtreleyerek anlaşmazlıkları hızlı inceleyin.
      </p>
      <ReviewsTable />
    </div>
  );
}
