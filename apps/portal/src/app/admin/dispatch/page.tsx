"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";

type DispatchVehicle = {
  assignment_id: string;
  block_id: string;
  vehicle_id: string;
  fleet_no: string;
  driver_id: string;
  driver_name?: string;
  trip_id: string;
  lat: number;
  lon: number;
  speed?: number;
  ping_ts: string;
  occupancy?: number;
  delay_seconds?: number;
  off_route: boolean;
};

type Alerts = {
  unassigned_blocks_today: number;
  licence_warnings: number;
  licence_expired: number;
  off_route_vehicles: number;
  open_incidents: number;
};

type PingTraceEntry = { ts: string; lat: number; lon: number; speed?: number };
type Driver = { user_id: string; display_name?: string; invite_email?: string };
type Vehicle = { id: string; fleet_no: string };
type Conflict = { kind: string; message: string };

function delayColor(seconds?: number, offRoute?: boolean) {
  if (offRoute) return "text-red-600 font-semibold";
  if (seconds === undefined) return "text-slate-500";
  if (seconds > 300) return "text-red-600 font-semibold";
  if (seconds > 120) return "text-amber-600 font-semibold";
  return "text-emerald-600";
}

export default function DispatchPage() {
  const [vehicles, setVehicles] = useState<DispatchVehicle[]>([]);
  const [alerts, setAlerts] = useState<Alerts | null>(null);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [vehicleList, setVehicleList] = useState<Vehicle[]>([]);
  const [selected, setSelected] = useState<DispatchVehicle | null>(null);
  const [trace, setTrace] = useState<PingTraceEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [v, a] = await Promise.all([
        apiFetch<{ items: DispatchVehicle[] }>("/admin/dispatch/vehicles"),
        apiFetch<Alerts>("/admin/dispatch/alerts"),
      ]);
      setVehicles(v.items ?? []);
      setAlerts(a);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load dispatch board");
    }
  }, []);

  useEffect(() => {
    load();
    apiFetch<{ items: Driver[] }>("/admin/drivers").then((r) => setDrivers(r.items ?? [])).catch(() => {});
    apiFetch<{ items: Vehicle[] }>("/admin/vehicles").then((r) => setVehicleList(r.items ?? [])).catch(() => {});
    const interval = setInterval(load, 10_000);
    return () => clearInterval(interval);
  }, [load]);

  async function openDetail(v: DispatchVehicle) {
    setSelected(v);
    setTrace(null);
    try {
      const res = await apiFetch<{ items: PingTraceEntry[] }>(`/admin/duty-assignments/${v.assignment_id}/pings`);
      setTrace(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load ping trace");
    }
  }

  return (
    <div className="max-w-5xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Live dispatch</h1>
        <p className="mt-1 text-sm text-slate-600">Every vehicle currently on duty, refreshed every 10 seconds.</p>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      {alerts && (
        <div className="grid grid-cols-5 gap-3">
          <AlertTile label="Unassigned blocks" value={alerts.unassigned_blocks_today} warn={alerts.unassigned_blocks_today > 0} />
          <AlertTile label="Licence warnings" value={alerts.licence_warnings} warn={alerts.licence_warnings > 0} />
          <AlertTile label="Licences expired" value={alerts.licence_expired} warn={alerts.licence_expired > 0} />
          <AlertTile label="Off-route" value={alerts.off_route_vehicles} warn={alerts.off_route_vehicles > 0} />
          <AlertTile label="Open incidents" value={alerts.open_incidents} warn={alerts.open_incidents > 0} />
        </div>
      )}

      <table className="w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
        <thead className="bg-slate-100 text-left">
          <tr>
            <th className="p-2">Vehicle</th>
            <th className="p-2">Driver</th>
            <th className="p-2">Delay</th>
            <th className="p-2">Occupancy</th>
            <th className="p-2">Updated</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {vehicles.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={6}>No vehicles currently on duty.</td></tr>}
          {vehicles.map((v) => (
            <tr key={v.assignment_id} className="border-t border-slate-100">
              <td className="p-2">{v.fleet_no || v.vehicle_id.slice(0, 8)}</td>
              <td className="p-2">{v.driver_name ?? v.driver_id.slice(0, 8)}</td>
              <td className={`p-2 ${delayColor(v.delay_seconds, v.off_route)}`}>
                {v.off_route ? "Off-route" : v.delay_seconds === undefined ? "—" : `${Math.round(v.delay_seconds / 60)} min`}
              </td>
              <td className="p-2">{v.occupancy ?? "—"}</td>
              <td className="p-2 text-xs text-slate-500">{new Date(v.ping_ts).toLocaleTimeString()}</td>
              <td className="p-2 text-right">
                <button onClick={() => openDetail(v)} className="text-brand hover:underline">Details</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {selected && (
        <VehicleDrillDown
          vehicle={selected}
          trace={trace}
          drivers={drivers}
          vehicleList={vehicleList}
          onClose={() => setSelected(null)}
          onChanged={load}
        />
      )}
    </div>
  );
}

function AlertTile({ label, value, warn }: { label: string; value: number; warn: boolean }) {
  return (
    <div className={`rounded-lg border p-3 ${warn ? "border-amber-300 bg-amber-50" : "border-slate-200 bg-white"}`}>
      <div className={`text-2xl font-semibold ${warn ? "text-amber-700" : "text-slate-800"}`}>{value}</div>
      <div className="text-xs text-slate-500">{label}</div>
    </div>
  );
}

function VehicleDrillDown({
  vehicle, trace, drivers, vehicleList, onClose, onChanged,
}: {
  vehicle: DispatchVehicle;
  trace: PingTraceEntry[] | null;
  drivers: Driver[];
  vehicleList: Vehicle[];
  onClose: () => void;
  onChanged: () => void;
}) {
  const [message, setMessage] = useState("");
  const [reassignDriver, setReassignDriver] = useState("");
  const [reassignVehicle, setReassignVehicle] = useState("");
  const [mode, setMode] = useState<"reassign" | "handover">("reassign");
  const [conflicts, setConflicts] = useState<Conflict[] | null>(null);
  const [status, setStatus] = useState<string | null>(null);

  async function sendMessage() {
    if (!message.trim()) return;
    await apiFetch(`/admin/duty-assignments/${vehicle.assignment_id}/message`, { method: "POST", body: JSON.stringify({ body: message }) });
    setMessage("");
    setStatus("Message sent.");
  }

  async function submitChange() {
    setConflicts(null);
    setStatus(null);
    if (!reassignDriver || !reassignVehicle) return;
    try {
      await apiFetch(`/admin/duty-assignments/${vehicle.assignment_id}/${mode}`, {
        method: "POST",
        body: JSON.stringify({ driver_id: reassignDriver, vehicle_id: reassignVehicle }),
      });
      setStatus(mode === "reassign" ? "Reassigned." : "Handed over — a new duty assignment now covers the rest of the block.");
      onChanged();
    } catch (e) {
      if (e instanceof ApiError && e.status === 409) {
        setConflicts((e.body as any)?.conflicts ?? []);
      } else {
        setStatus(e instanceof ApiError ? e.message : "failed to update assignment");
      }
    }
  }

  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4">
      <div className="flex items-center justify-between">
        <h2 className="font-medium">{vehicle.fleet_no || vehicle.vehicle_id} — {vehicle.driver_name ?? vehicle.driver_id}</h2>
        <button onClick={onClose} className="text-sm text-slate-500">Close</button>
      </div>

      {status && <p className="mt-2 rounded bg-slate-50 p-2 text-sm">{status}</p>}
      {conflicts && conflicts.length > 0 && (
        <div className="mt-2 rounded bg-amber-50 p-2 text-sm text-amber-800">
          <ul className="list-disc pl-5">{conflicts.map((c, i) => <li key={i}>{c.message}</li>)}</ul>
        </div>
      )}

      <div className="mt-4 grid grid-cols-2 gap-6">
        <div>
          <h3 className="text-sm font-medium">Recent ping trace</h3>
          <div className="mt-2 max-h-48 overflow-auto rounded border border-slate-100 text-xs">
            <table className="w-full">
              <thead className="bg-slate-50 text-left"><tr><th className="p-1">Time</th><th className="p-1">Lat</th><th className="p-1">Lon</th><th className="p-1">Speed</th></tr></thead>
              <tbody>
                {trace === null && <tr><td className="p-2 text-slate-400" colSpan={4}>Loading…</td></tr>}
                {trace?.length === 0 && <tr><td className="p-2 text-slate-400" colSpan={4}>No pings recorded.</td></tr>}
                {trace?.slice(-30).reverse().map((p, i) => (
                  <tr key={i} className="border-t border-slate-100">
                    <td className="p-1">{new Date(p.ts).toLocaleTimeString()}</td>
                    <td className="p-1">{p.lat.toFixed(5)}</td>
                    <td className="p-1">{p.lon.toFixed(5)}</td>
                    <td className="p-1">{p.speed ? `${(p.speed * 3.6).toFixed(0)} km/h` : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <h3 className="mt-4 text-sm font-medium">Message driver</h3>
          <div className="mt-2 flex gap-2">
            <input value={message} onChange={(e) => setMessage(e.target.value)} placeholder="Message…"
              className="flex-1 rounded border border-slate-300 px-2 py-1.5 text-sm" />
            <button onClick={sendMessage} className="rounded bg-brand px-3 py-1.5 text-sm font-medium text-white hover:bg-brand-light">Send</button>
          </div>
        </div>

        <div>
          <h3 className="text-sm font-medium">Reassign / hand over</h3>
          <div className="mt-2 flex gap-2 text-sm">
            <label className="flex items-center gap-1">
              <input type="radio" checked={mode === "reassign"} onChange={() => setMode("reassign")} /> Reassign in place
            </label>
            <label className="flex items-center gap-1">
              <input type="radio" checked={mode === "handover"} onChange={() => setMode("handover")} /> Vehicle swap (handover)
            </label>
          </div>
          <div className="mt-2 space-y-2">
            <select value={reassignDriver} onChange={(e) => setReassignDriver(e.target.value)}
              className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm">
              <option value="">New driver…</option>
              {drivers.map((d) => <option key={d.user_id} value={d.user_id}>{d.display_name ?? d.invite_email ?? d.user_id}</option>)}
            </select>
            <select value={reassignVehicle} onChange={(e) => setReassignVehicle(e.target.value)}
              className="w-full rounded border border-slate-300 px-2 py-1.5 text-sm">
              <option value="">New vehicle…</option>
              {vehicleList.map((v) => <option key={v.id} value={v.id}>{v.fleet_no}</option>)}
            </select>
            <button onClick={submitChange} disabled={!reassignDriver || !reassignVehicle}
              className="w-full rounded bg-brand px-3 py-1.5 text-sm font-medium text-white hover:bg-brand-light disabled:opacity-50">
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
