"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { apiFetch, ApiError } from "@/lib/api";
import {
  Route as RouteIcon,
  CalendarDays,
  Plus,
  ArrowRight,
  AlertTriangle,
  Check,
  Calendar,
  Compass,
  Bus,
  Train,
  Ship,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type Route = {
  route_id: string;
  route_short_name?: string;
  route_long_name?: string;
  route_type: number;
};

type Calendar = {
  service_id: string;
  monday: boolean;
  tuesday: boolean;
  wednesday: boolean;
  thursday: boolean;
  friday: boolean;
  saturday: boolean;
  sunday: boolean;
  start_date: string;
  end_date: string;
};

const emptyRoute = { route_id: "", route_short_name: "", route_long_name: "", route_type: 3 };
const emptyCalendar = {
  service_id: "",
  monday: true,
  tuesday: true,
  wednesday: true,
  thursday: true,
  friday: true,
  saturday: false,
  sunday: false,
  start_date: "",
  end_date: "",
};
const DAYS: (keyof typeof emptyCalendar)[] = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
];

function routeTypeLabel(type: number) {
  switch (type) {
    case 0:
      return "Tram / Light Rail";
    case 1:
      return "Subway / Metro";
    case 2:
      return "Rail";
    case 3:
      return "Bus";
    case 4:
      return "Ferry";
    case 5:
      return "Cable Tram";
    case 6:
      return "Aerial Lift";
    case 7:
      return "Funicular";
    case 11:
      return "Trolleybus";
    case 12:
      return "Monorail";
    default:
      return `Type ${type}`;
  }
}

export default function RoutesPage() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [calendars, setCalendars] = useState<Calendar[]>([]);
  const [routeForm, setRouteForm] = useState(emptyRoute);
  const [calForm, setCalForm] = useState(emptyCalendar);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [showAddRoute, setShowAddRoute] = useState(false);
  const [showAddCalendar, setShowAddCalendar] = useState(false);

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
    setSuccess(null);
    try {
      await apiFetch("/admin/routes", { method: "POST", body: JSON.stringify(routeForm) });
      setRouteForm(emptyRoute);
      setShowAddRoute(false);
      setSuccess(`Route ${routeForm.route_id} created successfully.`);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save route");
    }
  }

  async function saveCalendar(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    try {
      await apiFetch("/admin/calendars", { method: "POST", body: JSON.stringify(calForm) });
      setCalForm(emptyCalendar);
      setShowAddCalendar(false);
      setSuccess(`Service calendar ${calForm.service_id} saved.`);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save calendar");
    }
  }

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Routes & Timetables</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Define canonical GTFS routes, service calendars, and manage trip stop sequences.
        </p>
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

      {/* Routes Section */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <RouteIcon className="size-5 text-primary" />
            <h2 className="text-lg font-bold text-foreground">Transit Routes ({routes.length})</h2>
          </div>
          <Button
            size="sm"
            onClick={() => setShowAddRoute(!showAddRoute)}
            className="gap-1.5"
          >
            <Plus className="size-4" />
            <span>{showAddRoute ? "Close Form" : "Create Route"}</span>
          </Button>
        </div>

        {/* Add Route Form */}
        {showAddRoute && (
          <Card className="border-primary/30 shadow-sm animate-in fade-in duration-200">
            <CardHeader>
              <CardTitle className="text-base">New GTFS Route</CardTitle>
              <CardDescription className="text-xs">
                Enter GTFS standard route identifiers, short code, and full route title.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={saveRoute} className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">Route ID *</label>
                    <Input
                      required
                      placeholder="e.g. 101, RED, M14"
                      value={routeForm.route_id}
                      onChange={(e) => setRouteForm({ ...routeForm, route_id: e.target.value })}
                    />
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">Short Name</label>
                    <Input
                      placeholder="e.g. 101"
                      value={routeForm.route_short_name}
                      onChange={(e) => setRouteForm({ ...routeForm, route_short_name: e.target.value })}
                    />
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">Long Name</label>
                    <Input
                      placeholder="e.g. Central - Broadway Express"
                      value={routeForm.route_long_name}
                      onChange={(e) => setRouteForm({ ...routeForm, route_long_name: e.target.value })}
                    />
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">GTFS Route Type</label>
                    <select
                      value={routeForm.route_type}
                      onChange={(e) => setRouteForm({ ...routeForm, route_type: Number(e.target.value) })}
                      className="w-full rounded-xl border border-border bg-background px-3 py-2 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-primary h-9"
                    >
                      <option value={3}>3 - Bus</option>
                      <option value={0}>0 - Tram / Light Rail</option>
                      <option value={1}>1 - Subway / Metro</option>
                      <option value={2}>2 - Rail</option>
                      <option value={4}>4 - Ferry</option>
                      <option value={11}>11 - Trolleybus</option>
                      <option value={12}>12 - Monorail</option>
                    </select>
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-2">
                  <Button type="button" variant="outline" size="sm" onClick={() => setShowAddRoute(false)}>
                    Cancel
                  </Button>
                  <Button type="submit" size="sm">
                    Save Route
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        {/* Routes Table */}
        <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
          <Table>
            <TableHeader className="bg-muted/40">
              <TableRow>
                <TableHead className="font-semibold">Route</TableHead>
                <TableHead className="font-semibold">Short Name</TableHead>
                <TableHead className="font-semibold">Long Name</TableHead>
                <TableHead className="font-semibold">Mode / Type</TableHead>
                <TableHead className="text-right font-semibold">Trips & Stops</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {routes.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="h-28 text-center text-muted-foreground">
                    No routes configured yet.
                  </TableCell>
                </TableRow>
              ) : (
                routes.map((r) => (
                  <TableRow key={r.route_id}>
                    <TableCell className="font-medium">
                      <div className="flex items-center gap-2">
                        <span className="inline-flex size-7 items-center justify-center rounded-lg bg-primary font-bold text-xs text-primary-foreground shadow-2xs">
                          {r.route_short_name || r.route_id.slice(0, 3)}
                        </span>
                        <span className="font-mono text-xs text-muted-foreground">{r.route_id}</span>
                      </div>
                    </TableCell>

                    <TableCell className="font-medium text-foreground">
                      {r.route_short_name ?? "—"}
                    </TableCell>

                    <TableCell className="text-muted-foreground">
                      {r.route_long_name ?? "—"}
                    </TableCell>

                    <TableCell>
                      <Badge variant="outline" className="text-xs">
                        {routeTypeLabel(r.route_type)}
                      </Badge>
                    </TableCell>

                    <TableCell className="text-right">
                      <Link
                        href={`/admin/routes/${encodeURIComponent(r.route_id)}`}
                        className="inline-flex items-center gap-1 text-xs font-semibold text-primary hover:underline"
                      >
                        <span>Manage Trips & Stops</span>
                        <ArrowRight className="size-3.5" />
                      </Link>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </div>

      {/* Service Calendars Section */}
      <div className="space-y-4 pt-4 border-t border-border/80">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CalendarDays className="size-5 text-primary" />
            <h2 className="text-lg font-bold text-foreground">Service Calendars ({calendars.length})</h2>
          </div>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setShowAddCalendar(!showAddCalendar)}
            className="gap-1.5"
          >
            <Plus className="size-4" />
            <span>{showAddCalendar ? "Close Form" : "New Calendar"}</span>
          </Button>
        </div>

        {/* Add Calendar Form */}
        {showAddCalendar && (
          <Card className="border-primary/30 shadow-sm animate-in fade-in duration-200">
            <CardHeader>
              <CardTitle className="text-base">New Service Calendar</CardTitle>
              <CardDescription className="text-xs">
                Define active days of the week and effective calendar date boundaries.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={saveCalendar} className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">Service ID *</label>
                    <Input
                      required
                      placeholder="e.g. weekday, weekend, holiday"
                      value={calForm.service_id}
                      onChange={(e) => setCalForm({ ...calForm, service_id: e.target.value })}
                    />
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">Start Date *</label>
                    <Input
                      required
                      type="date"
                      value={calForm.start_date}
                      onChange={(e) => setCalForm({ ...calForm, start_date: e.target.value })}
                    />
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">End Date *</label>
                    <Input
                      required
                      type="date"
                      value={calForm.end_date}
                      onChange={(e) => setCalForm({ ...calForm, end_date: e.target.value })}
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-2">Operating Days</label>
                  <div className="flex flex-wrap gap-2">
                    {DAYS.map((d) => (
                      <label
                        key={d}
                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-medium cursor-pointer transition-all ${
                          calForm[d]
                            ? "bg-primary text-primary-foreground border-primary"
                            : "bg-muted text-muted-foreground border-border"
                        }`}
                      >
                        <input
                          type="checkbox"
                          checked={calForm[d] as boolean}
                          onChange={(e) => setCalForm({ ...calForm, [d]: e.target.checked })}
                          className="hidden"
                        />
                        <span className="capitalize">{d.slice(0, 3)}</span>
                      </label>
                    ))}
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-2">
                  <Button type="button" variant="outline" size="sm" onClick={() => setShowAddCalendar(false)}>
                    Cancel
                  </Button>
                  <Button type="submit" size="sm">
                    Save Calendar
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        {/* Calendars Table */}
        <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
          <Table>
            <TableHeader className="bg-muted/40">
              <TableRow>
                <TableHead className="font-semibold">Service ID</TableHead>
                <TableHead className="font-semibold">Active Days</TableHead>
                <TableHead className="font-semibold">Effective Range</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {calendars.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={3} className="h-24 text-center text-muted-foreground">
                    No service calendars configured yet.
                  </TableCell>
                </TableRow>
              ) : (
                calendars.map((c) => (
                  <TableRow key={c.service_id}>
                    <TableCell className="font-mono font-medium text-xs">
                      {c.service_id}
                    </TableCell>

                    <TableCell>
                      <div className="flex flex-wrap gap-1">
                        {DAYS.map((d) => (
                          <span
                            key={d}
                            className={`px-1.5 py-0.5 rounded text-[10px] font-semibold uppercase ${
                              c[d]
                                ? "bg-primary/15 text-primary"
                                : "bg-muted text-muted-foreground/40"
                            }`}
                          >
                            {d.slice(0, 2)}
                          </span>
                        ))}
                      </div>
                    </TableCell>

                    <TableCell className="text-xs text-muted-foreground font-mono">
                      {c.start_date} → {c.end_date}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </div>
    </div>
  );
}
