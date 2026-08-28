"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { apiFetch, ApiError } from "@/lib/api";
import {
  ArrowLeft,
  Route as RouteIcon,
  Plus,
  Trash2,
  Check,
  AlertTriangle,
  Clock,
  MapPin,
  Save,
  Layers,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type Trip = {
  trip_id: string;
  route_id: string;
  service_id: string;
  trip_headsign?: string;
  block_id?: string;
};

type StopTime = {
  stop_id: string;
  arrival_time: string;
  departure_time: string;
  stop_sequence: number;
};

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
  const [success, setSuccess] = useState<string | null>(null);
  const [showAddTrip, setShowAddTrip] = useState(false);
  const [isSavingStops, setIsSavingStops] = useState(false);

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
    setError(null);
    setSuccess(null);
    try {
      const st = await apiFetch<{ items: StopTime[] }>(
        `/admin/trips/${encodeURIComponent(tripId)}/stop_times`
      );
      setStopTimes(st.items?.length ? st.items : [{ ...emptyStopTime }]);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load stop times");
    }
  }

  async function saveTrip(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    try {
      await apiFetch("/admin/trips", {
        method: "POST",
        body: JSON.stringify({
          ...tripForm,
          route_id: routeId,
          block_id: tripForm.block_id || undefined,
        }),
      });
      setTripForm(emptyTrip);
      setShowAddTrip(false);
      setSuccess(`Trip ${tripForm.trip_id} saved.`);
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
    setSuccess(null);
    setIsSavingStops(true);
    try {
      const ordered = [...stopTimes]
        .sort((a, b) => a.stop_sequence - b.stop_sequence)
        .map((s) => ({ ...s, stop_sequence: Number(s.stop_sequence) }));

      await apiFetch(`/admin/trips/${encodeURIComponent(selectedTrip)}/stop_times`, {
        method: "PUT",
        body: JSON.stringify({ stop_times: ordered }),
      });
      setSuccess(`Stop sequence for ${selectedTrip} updated successfully.`);
      await loadStopTimes(selectedTrip);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save stop times");
    } finally {
      setIsSavingStops(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* Back button & Route Header */}
      <div>
        <Link
          href="/admin/routes"
          className="inline-flex items-center gap-1 text-xs font-semibold text-muted-foreground hover:text-foreground mb-3 transition-colors"
        >
          <ArrowLeft className="size-3.5" />
          <span>Back to all routes</span>
        </Link>

        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex size-10 items-center justify-center rounded-xl bg-primary text-primary-foreground font-bold">
              <RouteIcon className="size-5" />
            </div>
            <div>
              <h1 className="text-2xl font-bold tracking-tight text-foreground">
                Route {routeId}
              </h1>
              <p className="text-xs text-muted-foreground">
                Scheduled trips and GTFS stop sequence timetables.
              </p>
            </div>
          </div>

          <Button
            size="sm"
            onClick={() => setShowAddTrip(!showAddTrip)}
            className="gap-1.5 self-start sm:self-auto"
          >
            <Plus className="size-4" />
            <span>{showAddTrip ? "Close Form" : "Add Trip"}</span>
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTriangle className="size-4" />
          <AlertTitle>Error</AlertTitle>
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {success && (
        <Alert className="border-emerald-500/30 bg-emerald-500/10 text-emerald-700 dark:text-emerald-400">
          <Check className="size-4" />
          <AlertDescription>{success}</AlertDescription>
        </Alert>
      )}

      {/* Add Trip Form */}
      {showAddTrip && (
        <Card className="border-primary/30 shadow-sm animate-in fade-in duration-200">
          <CardHeader>
            <CardTitle className="text-base">Create Route Trip</CardTitle>
            <CardDescription className="text-xs">
              Add a scheduled service trip for this route bound to a service calendar and block.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={saveTrip} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Trip ID *</label>
                  <Input
                    required
                    placeholder="e.g. T-101-01"
                    value={tripForm.trip_id}
                    onChange={(e) => setTripForm({ ...tripForm, trip_id: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Service ID *</label>
                  <Input
                    required
                    placeholder="e.g. weekday, weekend"
                    value={tripForm.service_id}
                    onChange={(e) => setTripForm({ ...tripForm, service_id: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Trip Headsign</label>
                  <Input
                    placeholder="e.g. Broadway / Downtown"
                    value={tripForm.trip_headsign}
                    onChange={(e) => setTripForm({ ...tripForm, trip_headsign: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Block ID (Roster)</label>
                  <Input
                    placeholder="e.g. B-101-M"
                    value={tripForm.block_id}
                    onChange={(e) => setTripForm({ ...tripForm, block_id: e.target.value })}
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="outline" size="sm" onClick={() => setShowAddTrip(false)}>
                  Cancel
                </Button>
                <Button type="submit" size="sm">
                  Save Trip
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Trips Selector Tabs */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground flex items-center gap-1.5">
            <Layers className="size-3.5 text-primary" />
            <span>Select Trip to Edit Stop Sequences ({trips.length})</span>
          </div>
        </div>

        {trips.length === 0 ? (
          <p className="text-xs text-muted-foreground p-4 bg-muted/20 rounded-xl">
            No trips configured for this route yet. Click &ldquo;Add Trip&rdquo; to create one.
          </p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {trips.map((t) => {
              const active = selectedTrip === t.trip_id;
              return (
                <button
                  key={t.trip_id}
                  onClick={() => loadStopTimes(t.trip_id)}
                  className={`flex flex-col items-start px-3.5 py-2 rounded-xl text-left border transition-all ${
                    active
                      ? "border-primary bg-primary text-primary-foreground shadow-xs"
                      : "border-border bg-card text-foreground hover:bg-muted"
                  }`}
                >
                  <span className="font-mono text-xs font-bold">{t.trip_id}</span>
                  <span className={`text-[10px] ${active ? "text-primary-foreground/80" : "text-muted-foreground"}`}>
                    {t.trip_headsign || t.service_id}
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {/* Stop Sequence Editor */}
      {selectedTrip && (
        <Card className="border-primary/20 shadow-sm animate-in fade-in duration-200">
          <CardHeader className="flex flex-row items-center justify-between pb-3">
            <div>
              <CardTitle className="text-base font-semibold">
                Stop Timetable for Trip <code className="font-mono text-primary">{selectedTrip}</code>
              </CardTitle>
              <CardDescription className="text-xs">
                GTFS time standard format &ldquo;HH:MM:SS&rdquo; (can exceed 24:00:00 for overnight runs).
              </CardDescription>
            </div>
          </CardHeader>

          <CardContent className="space-y-4">
            <div className="rounded-xl border border-border/80 overflow-x-auto">
              <table className="w-full text-xs">
                <thead className="bg-muted/50 text-left font-semibold text-muted-foreground">
                  <tr>
                    <th className="p-2.5 w-16">Seq #</th>
                    <th className="p-2.5">Stop ID</th>
                    <th className="p-2.5 w-32">Arrival Time</th>
                    <th className="p-2.5 w-32">Departure Time</th>
                    <th className="p-2.5 w-12 text-center"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/60">
                  {stopTimes.map((s, i) => (
                    <tr key={i} className="hover:bg-muted/20">
                      <td className="p-2">
                        <Input
                          type="number"
                          value={s.stop_sequence}
                          onChange={(e) => updateStopTime(i, { stop_sequence: Number(e.target.value) })}
                          className="h-8 text-xs font-mono w-16"
                        />
                      </td>

                      <td className="p-2">
                        <Input
                          placeholder="e.g. STOP_101"
                          value={s.stop_id}
                          onChange={(e) => updateStopTime(i, { stop_id: e.target.value })}
                          className="h-8 text-xs font-mono"
                        />
                      </td>

                      <td className="p-2">
                        <Input
                          placeholder="08:30:00"
                          value={s.arrival_time}
                          onChange={(e) => updateStopTime(i, { arrival_time: e.target.value })}
                          className="h-8 text-xs font-mono w-32"
                        />
                      </td>

                      <td className="p-2">
                        <Input
                          placeholder="08:31:00"
                          value={s.departure_time}
                          onChange={(e) => updateStopTime(i, { departure_time: e.target.value })}
                          className="h-8 text-xs font-mono w-32"
                        />
                      </td>

                      <td className="p-2 text-center">
                        <Button
                          variant="ghost"
                          size="icon-xs"
                          onClick={() => setStopTimes((rows) => rows.filter((_, idx) => idx !== i))}
                          className="text-muted-foreground hover:text-destructive"
                          title="Remove Stop"
                        >
                          <Trash2 className="size-3.5" />
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="flex items-center justify-between pt-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() =>
                  setStopTimes((rows) => [
                    ...rows,
                    { ...emptyStopTime, stop_sequence: rows.length + 1 },
                  ])
                }
                className="gap-1.5 text-xs"
              >
                <Plus className="size-3.5" />
                <span>Add Stop</span>
              </Button>

              <Button
                type="button"
                size="sm"
                onClick={saveStopTimes}
                disabled={isSavingStops}
                className="gap-1.5 text-xs"
              >
                <Save className="size-3.5" />
                <span>{isSavingStops ? "Saving Sequence..." : "Save Stop Sequence"}</span>
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
