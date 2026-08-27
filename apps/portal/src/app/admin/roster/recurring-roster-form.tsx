"use client";

import { useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";

type Driver = { user_id: string; display_name?: string; invite_email?: string };
type Vehicle = { id: string; fleet_no: string };
type Entry = { weekday: string; block_ref: string; trip_ids: string; driver_id: string; vehicle_id: string };
type ExpandRow = { service_date: string; block_ref: string; assignment_id?: string; conflicts?: { kind: string; message: string }[] };

const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
const emptyEntry: Entry = { weekday: "monday", block_ref: "", trip_ids: "", driver_id: "", vehicle_id: "" };

export default function RecurringRosterForm({ drivers, vehicles, onApplied }: { drivers: Driver[]; vehicles: Vehicle[]; onApplied: () => void }) {
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [entries, setEntries] = useState<Entry[]>([{ ...emptyEntry }]);
  const [rows, setRows] = useState<ExpandRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  function updateEntry(i: number, patch: Partial<Entry>) {
    setEntries((rows) => rows.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      const result = await apiFetch<{ rows: ExpandRow[] }>("/admin/roster/expand", {
        method: "POST",
        body: JSON.stringify({
          from,
          to,
          entries: entries.map((e) => ({
            weekday: e.weekday,
            block_ref: e.block_ref,
            trip_ids: e.trip_ids.split(",").map((s) => s.trim()).filter(Boolean),
            driver_id: e.driver_id,
            vehicle_id: e.vehicle_id,
          })),
        }),
      });
      setRows(result.rows ?? []);
      onApplied();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "failed to expand roster");
    }
  }

  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4">
      <h2 className="text-lg font-semibold">Recurring roster</h2>
      <p className="mt-1 text-sm text-slate-600">
        Apply a weekly pattern across a date range. Each row is one weekday/block/driver/vehicle
        combination; blocks are created automatically for every matching date.
      </p>
      {error && <p className="mt-2 rounded bg-red-50 p-2 text-sm text-red-700">{error}</p>}

      <form onSubmit={submit} className="mt-3 space-y-3">
        <div className="flex gap-2">
          <input required type="date" value={from} onChange={(e) => setFrom(e.target.value)}
            className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
          <input required type="date" value={to} onChange={(e) => setTo(e.target.value)}
            className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        </div>

        {entries.map((entry, i) => (
          <div key={i} className="grid grid-cols-6 gap-2">
            <select value={entry.weekday} onChange={(e) => updateEntry(i, { weekday: e.target.value })}
              className="rounded border border-slate-300 px-2 py-1.5 text-sm">
              {WEEKDAYS.map((d) => <option key={d} value={d}>{d}</option>)}
            </select>
            <input required placeholder="block_ref" value={entry.block_ref} onChange={(e) => updateEntry(i, { block_ref: e.target.value })}
              className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
            <input required placeholder="trip_id,trip_id" value={entry.trip_ids} onChange={(e) => updateEntry(i, { trip_ids: e.target.value })}
              className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
            <select required value={entry.driver_id} onChange={(e) => updateEntry(i, { driver_id: e.target.value })}
              className="rounded border border-slate-300 px-2 py-1.5 text-sm">
              <option value="">Driver…</option>
              {drivers.map((d) => <option key={d.user_id} value={d.user_id}>{d.display_name ?? d.invite_email ?? d.user_id}</option>)}
            </select>
            <select required value={entry.vehicle_id} onChange={(e) => updateEntry(i, { vehicle_id: e.target.value })}
              className="rounded border border-slate-300 px-2 py-1.5 text-sm">
              <option value="">Vehicle…</option>
              {vehicles.map((v) => <option key={v.id} value={v.id}>{v.fleet_no}</option>)}
            </select>
            <button type="button" onClick={() => setEntries((rows) => rows.filter((_, idx) => idx !== i))}
              className="text-sm text-red-600">Remove</button>
          </div>
        ))}

        <div className="flex gap-2">
          <button type="button" onClick={() => setEntries((rows) => [...rows, { ...emptyEntry }])}
            className="rounded border border-slate-300 px-3 py-1.5 text-sm">
            Add row
          </button>
          <button type="submit" className="rounded bg-brand px-3 py-1.5 text-sm font-medium text-white hover:bg-brand-light">
            Apply roster
          </button>
        </div>
      </form>

      {rows && (
        <div className="mt-4">
          <div className="text-sm font-medium">
            {rows.filter((r) => r.assignment_id).length} assigned, {rows.filter((r) => !r.assignment_id).length} skipped with conflicts
          </div>
          <ul className="mt-2 max-h-48 space-y-1 overflow-auto text-xs">
            {rows.map((r, i) => (
              <li key={i} className={r.assignment_id ? "text-emerald-600" : "text-amber-700"}>
                {r.service_date} — {r.block_ref}: {r.assignment_id ? "assigned" : (r.conflicts ?? []).map((c) => c.message).join("; ")}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
