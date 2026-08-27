"use client";

import { useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import RecurringRosterForm from "./recurring-roster-form";

type Block = { id: string; block_ref: string; service_date: string; trip_ids: string[] };
type Assignment = {
  id: string; block_id: string; driver_id: string; vehicle_id: string;
  service_date: string; status: string; handover_from_id?: string;
};
type Driver = { user_id: string; display_name?: string; invite_email?: string };
type Vehicle = { id: string; fleet_no: string };
type Conflict = { kind: string; message: string };

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

export default function RosterPage() {
  const [serviceDate, setServiceDate] = useState(todayISO());
  const [unassigned, setUnassigned] = useState<Block[]>([]);
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [assignForm, setAssignForm] = useState<{ blockId: string; driverId: string; vehicleId: string } | null>(null);
  const [conflicts, setConflicts] = useState<Conflict[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setError(null);
    try {
      const [u, a, d, v] = await Promise.all([
        apiFetch<{ items: Block[] }>(`/admin/blocks/unassigned?service_date=${serviceDate}`),
        apiFetch<{ items: Assignment[] }>(`/admin/duty-assignments?service_date=${serviceDate}`),
        apiFetch<{ items: Driver[] }>("/admin/drivers"),
        apiFetch<{ items: Vehicle[] }>("/admin/vehicles"),
      ]);
      setUnassigned(u.items ?? []);
      setAssignments(a.items ?? []);
      setDrivers(d.items ?? []);
      setVehicles(v.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load roster");
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [serviceDate]);

  async function submitAssign(blockId: string) {
    if (!assignForm) return;
    setConflicts(null);
    setError(null);
    try {
      await apiFetch("/admin/duty-assignments", {
        method: "POST",
        body: JSON.stringify({
          block_id: blockId, driver_id: assignForm.driverId, vehicle_id: assignForm.vehicleId, service_date: serviceDate,
        }),
      });
      setAssignForm(null);
      await load();
    } catch (e) {
      if (e instanceof ApiError && e.status === 409) {
        setConflicts((e.body as any)?.conflicts ?? []);
      } else {
        setError(e instanceof ApiError ? e.message : "failed to assign duty");
      }
    }
  }

  function driverLabel(id: string) {
    const d = drivers.find((x) => x.user_id === id);
    return d?.display_name ?? d?.invite_email ?? id.slice(0, 8);
  }
  function vehicleLabel(id: string) {
    return vehicles.find((v) => v.id === id)?.fleet_no ?? id.slice(0, 8);
  }

  return (
    <div className="max-w-4xl space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Duty roster</h1>
          <p className="mt-1 text-sm text-slate-600">Assign a driver and vehicle to each block for a service date.</p>
        </div>
        <input type="date" value={serviceDate} onChange={(e) => setServiceDate(e.target.value)}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}
      {conflicts && conflicts.length > 0 && (
        <div className="rounded bg-amber-50 p-3 text-sm text-amber-800">
          <div className="font-medium">Assignment blocked by conflicts:</div>
          <ul className="mt-1 list-disc pl-5">
            {conflicts.map((c, i) => <li key={i}>{c.message}</li>)}
          </ul>
        </div>
      )}

      <div>
        <h2 className="text-lg font-semibold">Unassigned blocks ({unassigned.length})</h2>
        <div className="mt-3 space-y-2">
          {unassigned.length === 0 && <p className="text-sm text-slate-500">Every block on this date has a driver and vehicle.</p>}
          {unassigned.map((b) => (
            <div key={b.id} className="rounded-lg border border-slate-200 bg-white p-3">
              <div className="flex items-center justify-between">
                <div className="font-mono text-sm">{b.block_ref}</div>
                <button
                  onClick={() => { setAssignForm({ blockId: b.id, driverId: "", vehicleId: "" }); setConflicts(null); }}
                  className="rounded bg-brand px-3 py-1 text-xs font-medium text-white hover:bg-brand-light"
                >
                  Assign
                </button>
              </div>
              {assignForm?.blockId === b.id && (
                <div className="mt-2 flex items-center gap-2">
                  <select value={assignForm.driverId} onChange={(e) => setAssignForm({ ...assignForm, driverId: e.target.value })}
                    className="rounded border border-slate-300 px-2 py-1 text-sm">
                    <option value="">Driver…</option>
                    {drivers.map((d) => <option key={d.user_id} value={d.user_id}>{d.display_name ?? d.invite_email ?? d.user_id}</option>)}
                  </select>
                  <select value={assignForm.vehicleId} onChange={(e) => setAssignForm({ ...assignForm, vehicleId: e.target.value })}
                    className="rounded border border-slate-300 px-2 py-1 text-sm">
                    <option value="">Vehicle…</option>
                    {vehicles.map((v) => <option key={v.id} value={v.id}>{v.fleet_no}</option>)}
                  </select>
                  <button
                    disabled={!assignForm.driverId || !assignForm.vehicleId}
                    onClick={() => submitAssign(b.id)}
                    className="rounded bg-emerald-600 px-3 py-1 text-xs font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
                  >
                    Confirm
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      <div>
        <h2 className="text-lg font-semibold">Assigned ({assignments.length})</h2>
        <table className="mt-3 w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
          <thead className="bg-slate-100 text-left">
            <tr><th className="p-2">Block</th><th className="p-2">Driver</th><th className="p-2">Vehicle</th><th className="p-2">Status</th></tr>
          </thead>
          <tbody>
            {assignments.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={4}>Nothing assigned yet.</td></tr>}
            {assignments.map((a) => (
              <tr key={a.id} className="border-t border-slate-100">
                <td className="p-2 font-mono text-xs">{a.block_id.slice(0, 8)}</td>
                <td className="p-2">{driverLabel(a.driver_id)}</td>
                <td className="p-2">{vehicleLabel(a.vehicle_id)}</td>
                <td className="p-2">{a.status}{a.handover_from_id ? " (handover)" : ""}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <RecurringRosterForm drivers={drivers} vehicles={vehicles} onApplied={load} />
    </div>
  );
}
