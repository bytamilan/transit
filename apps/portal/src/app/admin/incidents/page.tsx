"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";

type Incident = {
  id: string;
  assignment_id?: string;
  kind: string;
  note?: string;
  ts: string;
  resolved_at?: string;
};

export default function IncidentsPage() {
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [openOnly, setOpenOnly] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const res = await apiFetch<{ items: Incident[] }>(`/admin/incidents?open=${openOnly}`);
      setIncidents(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load incidents");
    }
  }, [openOnly]);

  useEffect(() => {
    load();
  }, [load]);

  async function resolve(id: string) {
    await apiFetch(`/admin/incidents/${id}/resolve`, { method: "POST" });
    await load();
  }

  return (
    <div className="max-w-3xl space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Incidents</h1>
          <p className="mt-1 text-sm text-slate-600">One-tap reports from the driver app.</p>
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={openOnly} onChange={(e) => setOpenOnly(e.target.checked)} />
          Open only
        </label>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      <table className="w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
        <thead className="bg-slate-100 text-left">
          <tr><th className="p-2">When</th><th className="p-2">Kind</th><th className="p-2">Note</th><th className="p-2">Status</th><th className="p-2"></th></tr>
        </thead>
        <tbody>
          {incidents.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={5}>No incidents.</td></tr>}
          {incidents.map((inc) => (
            <tr key={inc.id} className="border-t border-slate-100">
              <td className="p-2 text-xs">{new Date(inc.ts).toLocaleString()}</td>
              <td className="p-2 capitalize">{inc.kind}</td>
              <td className="p-2">{inc.note ?? "—"}</td>
              <td className="p-2">{inc.resolved_at ? "Resolved" : "Open"}</td>
              <td className="p-2 text-right">
                {!inc.resolved_at && (
                  <button onClick={() => resolve(inc.id)} className="text-brand hover:underline">Resolve</button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
