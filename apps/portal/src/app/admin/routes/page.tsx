"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { apiFetch, ApiError } from "@/lib/api";

type Route = { route_id: string; route_short_name?: string; route_long_name?: string; route_type: number };
type Calendar = {
  service_id: string;
  monday: boolean; tuesday: boolean; wednesday: boolean; thursday: boolean;
  friday: boolean; saturday: boolean; sunday: boolean;
  start_date: string; end_date: string;
};

const emptyRoute = { route_id: "", route_short_name: "", route_long_name: "", route_type: 3 };
const emptyCalendar = {
  service_id: "", monday: true, tuesday: true, wednesday: true, thursday: true, friday: true,
  saturday: false, sunday: false, start_date: "", end_date: "",
};
const DAYS: (keyof typeof emptyCalendar)[] = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

export default function RoutesPage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [calendars, setCalendars] = useState<Calendar[]>([]);
  const [routeForm, setRouteForm] = useState(emptyRoute);
  const [calForm, setCalForm] = useState(emptyCalendar);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try {
      const [r, c] = await Promise.all([
        apiFetch<{ items: Route[] }>("/admin/routes"),
        apiFetch<{ items: Calendar[] }>("/admin/calendars"),
      ]);
      setRoutes(r.items ?? []);
      setCalendars(c.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load routes");
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function saveRoute(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await apiFetch("/admin/routes", { method: "POST", body: JSON.stringify(routeForm) });
      setRouteForm(emptyRoute);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save route");
    }
  }

  async function saveCalendar(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await apiFetch("/admin/calendars", { method: "POST", body: JSON.stringify(calForm) });
      setCalForm(emptyCalendar);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save calendar");
    }
  }

  return (
    <div className="max-w-4xl space-y-8">
      <div>
        <h1 className="text-2xl font-semibold">Routes & timetables</h1>
        <p className="mt-1 text-sm text-slate-600">
          Create routes and service calendars here, then open a route to build its stop sequence.
          Edits land directly in the canonical GTFS tables and are audited.
        </p>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      <form onSubmit={saveRoute} className="grid grid-cols-4 gap-3 rounded-lg border border-slate-200 bg-white p-4">
        <input required placeholder="route_id" value={routeForm.route_id}
          onChange={(e) => setRouteForm({ ...routeForm, route_id: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input placeholder="Short name" value={routeForm.route_short_name}
          onChange={(e) => setRouteForm({ ...routeForm, route_short_name: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input placeholder="Long name" value={routeForm.route_long_name}
          onChange={(e) => setRouteForm({ ...routeForm, route_long_name: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input type="number" placeholder="GTFS route_type" value={routeForm.route_type}
          onChange={(e) => setRouteForm({ ...routeForm, route_type: Number(e.target.value) })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <button type="submit" className="col-span-4 rounded bg-brand px-3 py-2 text-sm font-medium text-white hover:bg-brand-light">
          Save route
        </button>
      </form>

      <table className="w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
        <thead className="bg-slate-100 text-left">
          <tr><th className="p-2">Route</th><th className="p-2">Short name</th><th className="p-2">Long name</th><th className="p-2"></th></tr>
        </thead>
        <tbody>
          {routes.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={4}>No routes yet.</td></tr>}
          {routes.map((r) => (
            <tr key={r.route_id} className="border-t border-slate-100">
              <td className="p-2 font-mono text-xs">{r.route_id}</td>
              <td className="p-2">{r.route_short_name ?? "—"}</td>
              <td className="p-2">{r.route_long_name ?? "—"}</td>
              <td className="p-2 text-right">
                <Link href={`/admin/routes/${r.route_id}`} className="text-brand hover:underline">Edit trips →</Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <div>
        <h2 className="text-lg font-semibold">Service calendars</h2>
        <form onSubmit={saveCalendar} className="mt-3 grid grid-cols-4 gap-3 rounded-lg border border-slate-200 bg-white p-4">
          <input required placeholder="service_id" value={calForm.service_id}
            onChange={(e) => setCalForm({ ...calForm, service_id: e.target.value })}
            className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
          <input required type="date" value={calForm.start_date}
            onChange={(e) => setCalForm({ ...calForm, start_date: e.target.value })}
            className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
          <input required type="date" value={calForm.end_date}
            onChange={(e) => setCalForm({ ...calForm, end_date: e.target.value })}
            className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
          <div className="flex items-center gap-2 text-xs">
            {DAYS.map((d) => (
              <label key={d} className="flex items-center gap-1">
                <input type="checkbox" checked={calForm[d] as boolean}
                  onChange={(e) => setCalForm({ ...calForm, [d]: e.target.checked })} />
                {d.slice(0, 3)}
              </label>
            ))}
          </div>
          <button type="submit" className="col-span-4 rounded bg-brand px-3 py-2 text-sm font-medium text-white hover:bg-brand-light">
            Save calendar
          </button>
        </form>

        <table className="mt-3 w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
          <thead className="bg-slate-100 text-left">
            <tr><th className="p-2">Service</th><th className="p-2">Days</th><th className="p-2">Range</th></tr>
          </thead>
          <tbody>
            {calendars.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={3}>No calendars yet.</td></tr>}
            {calendars.map((c) => (
              <tr key={c.service_id} className="border-t border-slate-100">
                <td className="p-2 font-mono text-xs">{c.service_id}</td>
                <td className="p-2">{DAYS.filter((d) => c[d]).map((d) => d.slice(0, 3)).join(", ")}</td>
                <td className="p-2">{c.start_date} → {c.end_date}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
