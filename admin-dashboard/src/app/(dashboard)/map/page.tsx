import dynamic from "next/dynamic";

const LiveMap = dynamic(() => import("./LiveMap"), {
  ssr: false,
  loading: () => (
    <div className="flex h-[calc(100vh-6rem)] items-center justify-center rounded-xl border border-slate-700 bg-slate-800">
      <p className="text-slate-400">Harita yükleniyor...</p>
    </div>
  ),
});

export default function MapPage() {
  return (
    <div>
      <h1 className="mb-4 text-2xl font-bold text-white">Canlı Harita</h1>
      <p className="mb-4 text-slate-400">
        Sürücü konumları ve aktif rezervasyonlar (yeşil: alış, kırmızı: varış)
      </p>
      <LiveMap />
    </div>
  );
}
