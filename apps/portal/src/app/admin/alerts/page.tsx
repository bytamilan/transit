"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";

type Alert = {
  id: string;
  cause: string;
  effect: string;
  header_text: Record<string, string>;
  description_text: Record<string, string>;
  url?: Record<string, string>;
  informed_routes: string[];
  informed_stops: string[];
  active_from: string;
  active_until?: string;
  resolved_at?: string;
};

const CAUSES = [
  "unknown_cause", "other_cause", "technical_problem", "strike", "demonstration",
  "accident", "holiday", "weather", "maintenance", "construction", "police_activity", "medical_emergency",
];
const EFFECTS = [
  "no_service", "reduced_service", "significant_delays", "detour", "additional_service",
  "modified_service", "other_effect", "unknown_effect", "stop_moved", "no_effect", "accessibility_issue",
];

const emptyForm = {
  cause: "accident",
  effect: "detour",
  headerEn: "",
  descriptionEn: "",
  secondLocale: "",
  headerSecond: "",
  descriptionSecond: "",
  informedRoutes: "",
  informedStops: "",
  activeUntil: "",
};

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [showAll, setShowAll] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiFetch<{ items: Alert[] }>(`/admin/alerts?active=${!showAll}`);
      setAlerts(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load alerts");
    } finally {
      setLoading(false);
    }
  }, [showAll]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!form.headerEn.trim()) {
      setError("An English header is required.");
      return;
    }
    const header_text: Record<string, string> = { en: form.headerEn };
    const description_text: Record<string, string> = {};
    if (form.descriptionEn.trim()) description_text.en = form.descriptionEn;
    if (form.secondLocale.trim() && form.headerSecond.trim()) {
      header_text[form.secondLocale.trim()] = form.headerSecond;
      if (form.descriptionSecond.trim()) description_text[form.secondLocale.trim()] = form.descriptionSecond;
    }

    try {
      await apiFetch("/admin/alerts", {
        method: "POST",
        body: JSON.stringify({
          cause: form.cause,
          effect: form.effect,
          header_text,
          description_text,
          informed_routes: form.informedRoutes.split(",").map((s) => s.trim()).filter(Boolean),
          informed_stops: form.informedStops.split(",").map((s) => s.trim()).filter(Boolean),
          active_until: form.activeUntil ? new Date(form.activeUntil).toISOString() : undefined,
        }),
      });
      setForm(emptyForm);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to create alert");
    }
  }

  async function resolve(id: string) {
    await apiFetch(`/admin/alerts/${id}/resolve`, { method: "POST" });
    await load();
  }

  async function remove(id: string) {
    if (!confirm("Delete this alert permanently?")) return;
    await apiFetch(`/admin/alerts/${id}`, { method: "DELETE" });
    await load();
  }

  return (
    <div className="max-w-4xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Service alerts</h1>
        <p className="mt-1 text-sm text-slate-600">
          Published to the GTFS-RT ServiceAlerts feed and the rider app&apos;s alert banner.
        </p>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      <form onSubmit={handleSubmit} className="space-y-3 rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="font-medium">New alert</h2>
        <div className="grid grid-cols-2 gap-3">
          <label className="text-sm">
            Cause
            <select value={form.cause} onChange={(e) => setForm({ ...form, cause: e.target.value })} className="mt-1 block w-full rounded border-slate-300">
              {CAUSES.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          </label>
          <label className="text-sm">
            Effect
            <select value={form.effect} onChange={(e) => setForm({ ...form, effect: e.target.value })} className="mt-1 block w-full rounded border-slate-300">
              {EFFECTS.map((e) => <option key={e} value={e}>{e}</option>)}
            </select>
          </label>
        </div>

        <label className="block text-sm">
          Header (English) *
          <input value={form.headerEn} onChange={(e) => setForm({ ...form, headerEn: e.target.value })} className="mt-1 block w-full rounded border-slate-300" placeholder="Route 12 detoured due to construction" />
        </label>
        <label className="block text-sm">
          Description (English)
          <textarea value={form.descriptionEn} onChange={(e) => setForm({ ...form, descriptionEn: e.target.value })} className="mt-1 block w-full rounded border-slate-300" rows={2} />
        </label>

        <div className="grid grid-cols-3 gap-3">
          <label className="text-sm">
            Second locale code
            <input value={form.secondLocale} onChange={(e) => setForm({ ...form, secondLocale: e.target.value })} className="mt-1 block w-full rounded border-slate-300" placeholder="ta" />
          </label>
          <label className="col-span-2 text-sm">
            Header (second locale)
            <input value={form.headerSecond} onChange={(e) => setForm({ ...form, headerSecond: e.target.value })} className="mt-1 block w-full rounded border-slate-300" />
          </label>
        </div>
        <label className="block text-sm">
          Description (second locale)
          <textarea value={form.descriptionSecond} onChange={(e) => setForm({ ...form, descriptionSecond: e.target.value })} className="mt-1 block w-full rounded border-slate-300" rows={2} />
        </label>

        <div className="grid grid-cols-3 gap-3">
          <label className="text-sm">
            Informed routes (comma-separated route_id)
            <input value={form.informedRoutes} onChange={(e) => setForm({ ...form, informedRoutes: e.target.value })} className="mt-1 block w-full rounded border-slate-300" placeholder="leave blank for agency-wide" />
          </label>
          <label className="text-sm">
            Informed stops (comma-separated stop_id)
            <input value={form.informedStops} onChange={(e) => setForm({ ...form, informedStops: e.target.value })} className="mt-1 block w-full rounded border-slate-300" />
          </label>
          <label className="text-sm">
            Active until (optional)
            <input type="datetime-local" value={form.activeUntil} onChange={(e) => setForm({ ...form, activeUntil: e.target.value })} className="mt-1 block w-full rounded border-slate-300" />
          </label>
        </div>

        <button type="submit" className="rounded bg-brand px-4 py-2 text-sm font-medium text-white hover:opacity-90">
          Publish alert
        </button>
      </form>

      <div className="flex items-center justify-between">
        <h2 className="font-medium">Alerts</h2>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} />
          Show resolved/expired too
        </label>
      </div>

      <table className="w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
        <thead className="bg-slate-100 text-left">
          <tr><th className="p-2">Header</th><th className="p-2">Cause</th><th className="p-2">Effect</th><th className="p-2">Applies to</th><th className="p-2">Status</th><th className="p-2"></th></tr>
        </thead>
        <tbody>
          {!loading && alerts.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={6}>No alerts.</td></tr>}
          {alerts.map((a) => (
            <tr key={a.id} className="border-t border-slate-100">
              <td className="p-2">{a.header_text.en ?? Object.values(a.header_text)[0]}</td>
              <td className="p-2 capitalize">{a.cause.replace(/_/g, " ")}</td>
              <td className="p-2 capitalize">{a.effect.replace(/_/g, " ")}</td>
              <td className="p-2 text-xs">
                {a.informed_routes.length === 0 && a.informed_stops.length === 0
                  ? "Agency-wide"
                  : [...a.informed_routes.map((r) => `route:${r}`), ...a.informed_stops.map((s) => `stop:${s}`)].join(", ")}
              </td>
              <td className="p-2">{a.resolved_at ? "Resolved" : "Active"}</td>
              <td className="p-2 text-right space-x-3">
                {!a.resolved_at && (
                  <button onClick={() => resolve(a.id)} className="text-brand hover:underline">Resolve</button>
                )}
                <button onClick={() => remove(a.id)} className="text-red-600 hover:underline">Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
