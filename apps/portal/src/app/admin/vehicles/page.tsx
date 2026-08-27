"use client";

import { useEffect, useState } from "react";
import { apiFetch, apiUpload, ApiError } from "@/lib/api";

type Depot = { id: string; name: string };
type Vehicle = {
  id: string;
  depot_id?: string;
  fleet_no: string;
  registration: string;
  capacity_class?: string;
  propulsion?: string;
  status: string;
  maintenance_hold: boolean;
};

const emptyForm = { fleet_no: "", registration: "", depot_id: "", capacity_class: "", propulsion: "", status: "active", maintenance_hold: false };

export default function VehiclesPage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [depots, setDepots] = useState<Depot[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [importReport, setImportReport] = useState<any[] | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    try {
      const [v, d] = await Promise.all([
        apiFetch<{ items: Vehicle[] }>("/admin/vehicles"),
        apiFetch<{ items: Depot[] }>("/admin/depots"),
      ]);
      setVehicles(v.items ?? []);
      setDepots(d.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load vehicles");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await apiFetch("/admin/vehicles", {
        method: "POST",
        body: JSON.stringify({
          ...form,
          depot_id: form.depot_id || undefined,
          capacity_class: form.capacity_class || undefined,
          propulsion: form.propulsion || undefined,
        }),
      });
      setForm(emptyForm);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save vehicle");
    }
  }

  async function handleDelete(id: string) {
    if (!confirm("Delete this vehicle?")) return;
    await apiFetch(`/admin/vehicles/${id}`, { method: "DELETE" });
    await load();
  }

  async function handleCSV(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const text = await file.text();
    try {
      const report = await apiUpload<{ rows: any[] }>("/admin/vehicles/import", text, "text/csv");
      setImportReport(report.rows);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "CSV import failed");
    } finally {
      e.target.value = "";
    }
  }

  return (
    <div className="max-w-4xl space-y-8">
      <div>
        <h1 className="text-2xl font-semibold">Vehicles</h1>
        <p className="mt-1 text-sm text-slate-600">Registration, capacity, accessibility and maintenance holds.</p>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      <form onSubmit={handleSubmit} className="grid grid-cols-3 gap-3 rounded-lg border border-slate-200 bg-white p-4">
        <input required placeholder="Fleet no." value={form.fleet_no}
          onChange={(e) => setForm({ ...form, fleet_no: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input required placeholder="Registration" value={form.registration}
          onChange={(e) => setForm({ ...form, registration: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <select value={form.depot_id} onChange={(e) => setForm({ ...form, depot_id: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm">
          <option value="">No depot</option>
          {depots.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
        </select>
        <input placeholder="Capacity class" value={form.capacity_class}
          onChange={(e) => setForm({ ...form, capacity_class: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input placeholder="Propulsion" value={form.propulsion}
          onChange={(e) => setForm({ ...form, propulsion: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={form.maintenance_hold}
            onChange={(e) => setForm({ ...form, maintenance_hold: e.target.checked })} />
          Maintenance hold
        </label>
        <button type="submit" className="col-span-3 rounded bg-brand px-3 py-2 text-sm font-medium text-white hover:bg-brand-light">
          Save vehicle
        </button>
      </form>

      <div className="rounded-lg border border-slate-200 bg-white p-4">
        <label className="text-sm font-medium">Bulk import (CSV)</label>
        <p className="text-xs text-slate-500">Header row: fleet_no,registration,depot_id,capacity_class,propulsion,status,maintenance_hold</p>
        <input type="file" accept=".csv,text/csv" onChange={handleCSV} className="mt-2 text-sm" />
        {importReport && (
          <ul className="mt-3 max-h-40 overflow-auto text-xs">
            {importReport.map((row, i) => (
              <li key={i} className={row.status === "error" ? "text-red-600" : "text-emerald-600"}>
                row {row.row} ({row.key}): {row.status}{row.error ? ` — ${row.error}` : ""}
              </li>
            ))}
          </ul>
        )}
      </div>

      <table className="w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
        <thead className="bg-slate-100 text-left">
          <tr>
            <th className="p-2">Fleet no.</th>
            <th className="p-2">Registration</th>
            <th className="p-2">Depot</th>
            <th className="p-2">Status</th>
            <th className="p-2">Hold</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {loading && <tr><td className="p-3 text-slate-500" colSpan={6}>Loading…</td></tr>}
          {!loading && vehicles.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={6}>No vehicles yet.</td></tr>}
          {vehicles.map((v) => (
            <tr key={v.id} className="border-t border-slate-100">
              <td className="p-2">{v.fleet_no}</td>
              <td className="p-2">{v.registration}</td>
              <td className="p-2">{depots.find((d) => d.id === v.depot_id)?.name ?? "—"}</td>
              <td className="p-2">{v.status}</td>
              <td className="p-2">{v.maintenance_hold ? "Yes" : "—"}</td>
              <td className="p-2 text-right">
                <button onClick={() => handleDelete(v.id)} className="text-red-600 hover:underline">Delete</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
