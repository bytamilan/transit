"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { apiFetch, ApiError } from "@/lib/api";

type Trip = { trip_id: string; route_id: string; service_id: string; trip_headsign?: string; block_id?: string };
type StopTime = { stop_id: string; arrival_time: string; departure_time: string; stop_sequence: number };

const emptyTrip = { trip_id: "", service_id: "weekday", trip_headsign: "", block_id: "" };
const emptyStopTime: StopTime = { stop_id: "", arrival_time: "", departure_time: "", stop_sequence: 1 };

export default function RouteTripsPage() {
  const params = useParams<{ routeId: string }>();
  const routeId = decodeURIComponent(params.routeId);

  const [trips, setTrips] = useState<Trip[]>([]);
  const [tripForm, setTripForm] = useState(emptyTrip);
  const [selectedTrip, setSelectedTrip] = useState<string | null>(null);
  const [stopTimes, setStopTimes] = useState<StopTime[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function loadTrips() {
    try {
      const t = await apiFetch<{ items: Trip[] }>(`/admin/trips?route_id=${encodeURIComponent(routeId)}`);
      setTrips(t.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load trips");
    }
  }

  useEffect(() => {
    loadTrips();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [routeId]);

  async function loadStopTimes(tripId: string) {
    setSelectedTrip(tripId);
    try {
      const st = await apiFetch<{ items: StopTime[] }>(`/admin/trips/${encodeURIComponent(tripId)}/stop_times`);
      setStopTimes(st.items?.length ? st.items : [{ ...emptyStopTime }]);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load stop times");
    }
  }

  async function saveTrip(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await apiFetch("/admin/trips", {
        method: "POST",
        body: JSON.stringify({ ...tripForm, route_id: routeId, block_id: tripForm.block_id || undefined }),
      });
      setTripForm(emptyTrip);
      await loadTrips();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save trip");
    }
  }

  function updateStopTime(i: number, patch: Partial<StopTime>) {
    setStopTimes((rows) => rows.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));
  }

  async function saveStopTimes() {
    if (!selectedTrip) return;
    setError(null);
    try {
      const ordered = [...stopTimes]
        .sort((a, b) => a.stop_sequence - b.stop_sequence)
        .map((s) => ({ ...s, stop_sequence: Number(s.stop_sequence) }));
      await apiFetch(`/admin/trips/${encodeURIComponent(selectedTrip)}/stop_times`, {
        method: "PUT",
        body: JSON.stringify({ stop_times: ordered }),
      });
      await loadStopTimes(selectedTrip);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save stop times");
    }
  }

  return (
    <div className="max-w-4xl space-y-8">
      <div>
        <h1 className="text-2xl font-semibold">Route {routeId}</h1>
        <p className="mt-1 text-sm text-slate-600">Trips and stop sequences (GTFS &ldquo;HH:MM:SS&rdquo;, may exceed 24:00:00 for after-midnight service).</p>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      <form onSubmit={saveTrip} className="grid grid-cols-4 gap-3 rounded-lg border border-slate-200 bg-white p-4">
        <input required placeholder="trip_id" value={tripForm.trip_id}
          onChange={(e) => setTripForm({ ...tripForm, trip_id: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input required placeholder="service_id" value={tripForm.service_id}
          onChange={(e) => setTripForm({ ...tripForm, service_id: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input placeholder="Headsign" value={tripForm.trip_headsign}
          onChange={(e) => setTripForm({ ...tripForm, trip_headsign: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <input placeholder="block_id" value={tripForm.block_id}
          onChange={(e) => setTripForm({ ...tripForm, block_id: e.target.value })}
          className="rounded border border-slate-300 px-2 py-1.5 text-sm" />
        <button type="submit" className="col-span-4 rounded bg-brand px-3 py-2 text-sm font-medium text-white hover:bg-brand-light">
          Save trip
        </button>
      </form>

      <div className="flex gap-2">
        {trips.map((t) => (
          <button key={t.trip_id} onClick={() => loadStopTimes(t.trip_id)}
            className={`rounded border px-3 py-1.5 text-sm ${selectedTrip === t.trip_id ? "border-brand bg-brand text-white" : "border-slate-300"}`}>
            {t.trip_id}
          </button>
        ))}
      </div>

      {selectedTrip && (
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="font-medium">Stop sequence for {selectedTrip}</h2>
          <table className="mt-3 w-full text-sm">
            <thead className="text-left text-slate-500">
              <tr><th className="p-1">#</th><th className="p-1">Stop ID</th><th className="p-1">Arrival</th><th className="p-1">Departure</th><th /></tr>
            </thead>
            <tbody>
              {stopTimes.map((s, i) => (
                <tr key={i}>
                  <td className="p-1">
                    <input type="number" value={s.stop_sequence} onChange={(e) => updateStopTime(i, { stop_sequence: Number(e.target.value) })}
                      className="w-14 rounded border border-slate-300 px-1 py-1" />
                  </td>
                  <td className="p-1">
                    <input value={s.stop_id} onChange={(e) => updateStopTime(i, { stop_id: e.target.value })}
                      className="rounded border border-slate-300 px-1 py-1" />
                  </td>
                  <td className="p-1">
                    <input placeholder="HH:MM:SS" value={s.arrival_time} onChange={(e) => updateStopTime(i, { arrival_time: e.target.value })}
                      className="w-24 rounded border border-slate-300 px-1 py-1" />
                  </td>
                  <td className="p-1">
                    <input placeholder="HH:MM:SS" value={s.departure_time} onChange={(e) => updateStopTime(i, { departure_time: e.target.value })}
                      className="w-24 rounded border border-slate-300 px-1 py-1" />
                  </td>
                  <td className="p-1">
                    <button onClick={() => setStopTimes((rows) => rows.filter((_, idx) => idx !== i))} className="text-red-600">✕</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="mt-3 flex gap-2">
            <button
              onClick={() => setStopTimes((rows) => [...rows, { ...emptyStopTime, stop_sequence: rows.length + 1 }])}
              className="rounded border border-slate-300 px-3 py-1.5 text-sm"
            >
              Add stop
            </button>
            <button onClick={saveStopTimes} className="rounded bg-brand px-3 py-1.5 text-sm font-medium text-white hover:bg-brand-light">
              Save stop sequence
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
