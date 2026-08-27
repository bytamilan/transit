"use client";

import { useEffect, useState } from "react";
import { apiFetch, apiUpload, ApiError } from "@/lib/api";

type Depot = { id: string; name: string };
type Driver = {
  user_id: string;
  depot_id?: string;
  display_name?: string;
  invite_email?: string;
  invite_phone?: string;
  licence_expires_on?: string;
  status: string;
  licence_warning: boolean;
  licence_expired: boolean;
};

const emptyForm = { email: "", phone: "", display_name: "", depot_id: "", licence_number: "", licence_expires_on: "" };

export default function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [depots, setDepots] = useState<Depot[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [importReport, setImportReport] = useState<any[] | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    try {
      const [d, dep] = await Promise.all([
        apiFetch<{ items: Driver[] }>("/admin/drivers"),
        apiFetch<{ items: Depot[] }>("/admin/depots"),
      ]);
      setDrivers(d.items ?? []);
      setDepots(dep.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load drivers");
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
      await apiFetch("/admin/drivers", {
        method: "POST",
        body: JSON.stringify({
          ...form,
          depot_id: form.depot_id || undefined,
          display_name: form.display_name || undefined,
          licence_number: form.licence_number || undefined,
          licence_expires_on: form.licence_expires_on || undefined,
        }),
      });
      setForm(emptyForm);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to invite driver");
    }
  }

  async function setStatus(id: string, action: "suspend" | "reactivate") {
    await apiFetch(`/admin/drivers/${id}/${action}`, { method: "POST" });
    await load();
  }

  async function handleCSV(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const text = await file.text();
    try {
      const report = await apiUpload<{ rows: any[] }>("/admin/drivers/import", text, "text/csv");
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
        <h1 className="text-2xl font-semibold">Drivers</h1>
        <p className="mt-1 text-sm text-slate-600">
          Invite by email or phone, assign a depot, and track licence expiry. Licence expiry blocks duty
          assignment automatically and warns 30 days out.
        </p>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      <form onSubmit={handleSubmit} className="grid grid-cols-3 gap-3 rounded-lg border border-slate-200 bg-white p-4">
        <input placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input placeholder="Phone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input placeholder="Display name" value={form.display_name} onChange={(e) => setForm({ ...form, display_name: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <select value={form.depot_id} onChange={(e) => setForm({ ...form, depot_id: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm">
          <option value="">No depot</option>
          {depots.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
        </select>
        <input placeholder="Licence number" value={form.licence_number} onChange={(e) => setForm({ ...form, licence_number: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input type="date" placeholder="Licence expires" value={form.licence_expires_on}
          onChange={(e) => setForm({ ...form, licence_expires_on: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <button type="submit" className="col-span-3 rounded bg-brand px-3 py-2 text-sm font-medium text-white hover:bg-brand-light">
          Invite / save driver
        </button>
      </form>

      <div className="rounded-lg border border-slate-200 bg-white p-4">
        <label className="text-sm font-medium">Bulk import (CSV)</label>
        <p className="text-xs text-slate-500">Header row: email,phone,display_name,depot_id,licence_number,licence_expires_on</p>
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
            <th className="p-2">Name</th>
            <th className="p-2">Contact</th>
            <th className="p-2">Depot</th>
            <th className="p-2">Licence</th>
            <th className="p-2">Status</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {loading && <tr><td className="p-3 text-slate-500" colSpan={6}>Loading…</td></tr>}
          {!loading && drivers.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={6}>No drivers yet.</td></tr>}
          {drivers.map((d) => (
            <tr key={d.user_id} className="border-t border-slate-100">
              <td className="p-2">{d.display_name ?? "—"}</td>
              <td className="p-2">{d.invite_email ?? d.invite_phone ?? "—"}</td>
              <td className="p-2">{depots.find((x) => x.id === d.depot_id)?.name ?? "—"}</td>
              <td className="p-2">
                {d.licence_expires_on ?? "—"}
                {d.licence_expired && <span className="ml-2 rounded bg-red-100 px-1.5 py-0.5 text-xs text-red-700">expired</span>}
                {!d.licence_expired && d.licence_warning && <span className="ml-2 rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-700">expiring soon</span>}
              </td>
              <td className="p-2">{d.status}</td>
              <td className="p-2 text-right">
                {d.status === "suspended" ? (
                  <button onClick={() => setStatus(d.user_id, "reactivate")} className="text-emerald-600 hover:underline">Reactivate</button>
                ) : (
                  <button onClick={() => setStatus(d.user_id, "suspend")} className="text-red-600 hover:underline">Suspend</button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
