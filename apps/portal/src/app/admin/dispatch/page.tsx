"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import {
  Radio,
  RefreshCw,
  AlertTriangle,
  Users,
  Bus,
  Clock,
  Send,
  ArrowRightLeft,
  X,
  Search,
  Activity,
  MapPin,
  Gauge,
  UserCheck,
  ShieldAlert,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

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

function delayBadge(seconds?: number, offRoute?: boolean) {
  if (offRoute) {
    return (
      <Badge variant="destructive" className="gap-1">
        <AlertTriangle className="size-3" /> Off-route
      </Badge>
    );
  }
  if (seconds === undefined) {
    return <Badge variant="outline" className="text-muted-foreground">No data</Badge>;
  }
  if (seconds > 300) {
    return (
      <Badge variant="destructive" className="gap-1">
        <Clock className="size-3" /> +{Math.round(seconds / 60)} min late
      </Badge>
    );
  }
  if (seconds > 120) {
    return (
      <Badge variant="secondary" className="gap-1 bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30">
        <Clock className="size-3" /> +{Math.round(seconds / 60)} min late
      </Badge>
    );
  }
  return (
    <Badge variant="secondary" className="gap-1 bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30">
      On schedule
    </Badge>
  );
}

export default function DispatchPage() {
  const [vehicles, setVehicles] = useState<DispatchVehicle[]>([]);
  const [alerts, setAlerts] = useState<Alerts | null>(null);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [vehicleList, setVehicleList] = useState<Vehicle[]>([]);
  const [selected, setSelected] = useState<DispatchVehicle | null>(null);
  const [trace, setTrace] = useState<PingTraceEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  const load = useCallback(async (manual = false) => {
    if (manual) setIsRefreshing(true);
    try {
      const [v, a] = await Promise.all([
        apiFetch<{ items: DispatchVehicle[] }>("/admin/dispatch/vehicles"),
        apiFetch<Alerts>("/admin/dispatch/alerts"),
      ]);
      setVehicles(v.items ?? []);
      setAlerts(a);
      setError(null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load dispatch board");
    } finally {
      if (manual) setIsRefreshing(false);
    }
  }, []);

  useEffect(() => {
    load();
    apiFetch<{ items: Driver[] }>("/admin/drivers")
      .then((r) => setDrivers(r.items ?? []))
      .catch(() => {});
    apiFetch<{ items: Vehicle[] }>("/admin/vehicles")
      .then((r) => setVehicleList(r.items ?? []))
      .catch(() => {});

    const interval = setInterval(() => load(false), 10_000);
    return () => clearInterval(interval);
  }, [load]);

  async function openDetail(v: DispatchVehicle) {
    setSelected(v);
    setTrace(null);
    try {
      const res = await apiFetch<{ items: PingTraceEntry[] }>(
        `/admin/duty-assignments/${v.assignment_id}/pings`
      );
      setTrace(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load ping trace");
    }
  }

  const filteredVehicles = vehicles.filter((v) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      (v.fleet_no && v.fleet_no.toLowerCase().includes(q)) ||
      (v.driver_name && v.driver_name.toLowerCase().includes(q)) ||
      (v.trip_id && v.trip_id.toLowerCase().includes(q))
    );
  });

  return (
    <div className="space-y-6">
      {/* Header with Live Indicator and Manual Refresh */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold tracking-tight text-foreground">Live Dispatch Board</h1>
            <Badge variant="outline" className="gap-1.5 border-emerald-500/30 text-emerald-700 dark:text-emerald-400 bg-emerald-500/10">
              <span className="size-2 rounded-full bg-emerald-500 animate-pulse"></span>
              Auto-refreshing (10s)
            </Badge>
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            Monitoring active on-duty fleet telemetry, delays, and off-route anomalies.
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={() => load(true)}
          disabled={isRefreshing}
          className="gap-2 self-start sm:self-auto"
        >
          <RefreshCw className={`size-4 ${isRefreshing ? "animate-spin" : ""}`} />
          <span>Refresh Now</span>
        </Button>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTriangle className="size-4" />
          <AlertTitle>Dispatch Error</AlertTitle>
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Operational Alert Badges Grid */}
      {alerts && (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
          <AlertTile
            label="Unassigned Blocks"
            value={alerts.unassigned_blocks_today}
            warn={alerts.unassigned_blocks_today > 0}
            icon={Clock}
          />
          <AlertTile
            label="Licence Warnings"
            value={alerts.licence_warnings}
            warn={alerts.licence_warnings > 0}
            icon={UserCheck}
          />
          <AlertTile
            label="Licences Expired"
            value={alerts.licence_expired}
            warn={alerts.licence_expired > 0}
            isDanger={alerts.licence_expired > 0}
            icon={ShieldAlert}
          />
          <AlertTile
            label="Off-Route Vehicles"
            value={alerts.off_route_vehicles}
            warn={alerts.off_route_vehicles > 0}
            isDanger={alerts.off_route_vehicles > 0}
            icon={AlertTriangle}
          />
          <AlertTile
            label="Open Incidents"
            value={alerts.open_incidents}
            warn={alerts.open_incidents > 0}
            isDanger={alerts.open_incidents > 0}
            icon={Activity}
          />
        </div>
      )}

      {/* Search and Filter */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="relative w-full sm:w-80">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search fleet no, driver, or trip..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 h-9"
          />
        </div>
        <div className="text-xs text-muted-foreground self-end sm:self-auto">
          Showing <span className="font-semibold text-foreground">{filteredVehicles.length}</span> of{" "}
          <span className="font-semibold text-foreground">{vehicles.length}</span> active vehicles
        </div>
      </div>

      {/* Vehicles Table / Grid */}
      <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow>
              <TableHead className="font-semibold">Vehicle</TableHead>
              <TableHead className="font-semibold">Driver</TableHead>
              <TableHead className="font-semibold">Trip ID</TableHead>
              <TableHead className="font-semibold">Status / Delay</TableHead>
              <TableHead className="font-semibold">Occupancy</TableHead>
              <TableHead className="font-semibold">Last Ping</TableHead>
              <TableHead className="text-right font-semibold">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredVehicles.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="h-32 text-center text-muted-foreground">
                  <div className="flex flex-col items-center justify-center gap-1.5">
                    <Bus className="size-6 text-muted-foreground/50" />
                    <span>
                      {vehicles.length === 0
                        ? "No vehicles currently on duty."
                        : "No active vehicles match your search query."}
                    </span>
                  </div>
                </TableCell>
              </TableRow>
            ) : (
              filteredVehicles.map((v) => (
                <TableRow
                  key={v.assignment_id}
                  className={`transition-colors ${
                    v.off_route ? "bg-destructive/5 hover:bg-destructive/10" : ""
                  }`}
                >
                  <TableCell className="font-medium">
                    <div className="flex items-center gap-2">
                      <div className="flex size-7 items-center justify-center rounded-lg bg-primary/10 text-primary font-bold text-xs">
                        <Bus className="size-4" />
                      </div>
                      <span className="font-semibold">{v.fleet_no || v.vehicle_id.slice(0, 8)}</span>
                    </div>
                  </TableCell>

                  <TableCell>
                    <div className="flex items-center gap-2">
                      <Users className="size-3.5 text-muted-foreground" />
                      <span className="font-medium text-foreground">{v.driver_name ?? v.driver_id.slice(0, 8)}</span>
                    </div>
                  </TableCell>

                  <TableCell className="font-mono text-xs text-muted-foreground">
                    {v.trip_id || "—"}
                  </TableCell>

                  <TableCell>
                    {delayBadge(v.delay_seconds, v.off_route)}
                  </TableCell>

                  <TableCell>
                    {v.occupancy !== undefined ? (
                      <span className="inline-flex items-center rounded-md bg-muted px-2 py-0.5 text-xs font-medium">
                        {v.occupancy} riders
                      </span>
                    ) : (
                      <span className="text-muted-foreground text-xs">—</span>
                    )}
                  </TableCell>

                  <TableCell className="text-xs text-muted-foreground">
                    {new Date(v.ping_ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                  </TableCell>

                  <TableCell className="text-right">
                    <Button
                      variant={selected?.assignment_id === v.assignment_id ? "default" : "outline"}
                      size="sm"
                      onClick={() => openDetail(v)}
                      className="text-xs h-7"
                    >
                      Inspect & Dispatch
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {/* Vehicle DrillDown Drawer / Panel */}
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

function AlertTile({
  label,
  value,
  warn,
  isDanger,
  icon: Icon,
}: {
  label: string;
  value: number;
  warn: boolean;
  isDanger?: boolean;
  icon: React.ComponentType<{ className?: string }>;
}) {
  let style = "border-border/80 bg-card text-foreground";
  let iconStyle = "text-muted-foreground";

  if (isDanger) {
    style = "border-destructive/30 bg-destructive/5 text-destructive";
    iconStyle = "text-destructive";
  } else if (warn) {
    style = "border-amber-500/30 bg-amber-500/10 text-amber-800 dark:text-amber-300";
    iconStyle = "text-amber-600 dark:text-amber-400";
  }

  return (
    <Card className={`p-4 transition-all duration-150 ${style}`}>
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-muted-foreground">{label}</span>
        <Icon className={`size-4 ${iconStyle}`} />
      </div>
      <div className="mt-2 text-2xl font-bold tracking-tight">{value}</div>
    </Card>
  );
}

function VehicleDrillDown({
  vehicle,
  trace,
  drivers,
  vehicleList,
  onClose,
  onChanged,
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
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function sendMessage() {
    if (!message.trim()) return;
    try {
      await apiFetch(`/admin/duty-assignments/${vehicle.assignment_id}/message`, {
        method: "POST",
        body: JSON.stringify({ body: message }),
      });
      setMessage("");
      setStatus("Message dispatched to driver app.");
    } catch {
      setStatus("Failed to send message.");
    }
  }

  async function submitChange() {
    setConflicts(null);
    setStatus(null);
    if (!reassignDriver || !reassignVehicle) return;
    setIsSubmitting(true);
    try {
      await apiFetch(`/admin/duty-assignments/${vehicle.assignment_id}/${mode}`, {
        method: "POST",
        body: JSON.stringify({ driver_id: reassignDriver, vehicle_id: reassignVehicle }),
      });
      setStatus(
        mode === "reassign"
          ? "Reassigned successfully."
          : "Handed over successfully — a new duty assignment now covers the rest of the block."
      );
      onChanged();
    } catch (e) {
      if (e instanceof ApiError && e.status === 409) {
        setConflicts((e.body as any)?.conflicts ?? []);
      } else {
        setStatus(e instanceof ApiError ? e.message : "Failed to update assignment");
      }
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Card className="border-primary/30 shadow-md">
      <CardHeader className="flex flex-row items-center justify-between border-b border-border/60 pb-4">
        <div className="flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-xl bg-primary text-primary-foreground font-bold">
            <Bus className="size-5" />
          </div>
          <div>
            <CardTitle className="text-lg">
              Fleet #{vehicle.fleet_no || vehicle.vehicle_id.slice(0, 8)}
            </CardTitle>
            <CardDescription className="text-xs">
              Driver: {vehicle.driver_name ?? vehicle.driver_id} • Block: {vehicle.block_id.slice(0, 8)}
            </CardDescription>
          </div>
        </div>

        <Button variant="ghost" size="icon-sm" onClick={onClose} aria-label="Close panel">
          <X className="size-4" />
        </Button>
      </CardHeader>

      <CardContent className="pt-5 space-y-6">
        {status && (
          <Alert className="bg-primary/10 border-primary/30">
            <AlertDescription className="text-xs text-primary font-medium">{status}</AlertDescription>
          </Alert>
        )}

        {conflicts && conflicts.length > 0 && (
          <Alert variant="destructive">
            <AlertTriangle className="size-4" />
            <AlertTitle>Reassignment Conflict Detected</AlertTitle>
            <AlertDescription>
              <ul className="mt-1 list-disc pl-5 text-xs space-y-0.5">
                {conflicts.map((c, i) => (
                  <li key={i}>{c.message}</li>
                ))}
              </ul>
            </AlertDescription>
          </Alert>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left: Telemetry and Driver Message */}
          <div className="space-y-4">
            <div>
              <div className="flex items-center justify-between mb-2">
                <h3 className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-1.5">
                  <MapPin className="size-3.5 text-primary" />
                  Recent Ping Trace
                </h3>
                <span className="text-[11px] text-muted-foreground">Last 30 pings</span>
              </div>

              <div className="max-h-48 overflow-y-auto rounded-xl border border-border/80 text-xs">
                <table className="w-full">
                  <thead className="bg-muted/50 text-left text-muted-foreground font-semibold">
                    <tr>
                      <th className="p-2">Time</th>
                      <th className="p-2">Latitude</th>
                      <th className="p-2">Longitude</th>
                      <th className="p-2 text-right">Speed</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border/60">
                    {trace === null && (
                      <tr>
                        <td className="p-3 text-center text-muted-foreground" colSpan={4}>
                          Loading trace...
                        </td>
                      </tr>
                    )}
                    {trace?.length === 0 && (
                      <tr>
                        <td className="p-3 text-center text-muted-foreground" colSpan={4}>
                          No pings recorded for this assignment.
                        </td>
                      </tr>
                    )}
                    {trace?.slice(-30).reverse().map((p, i) => (
                      <tr key={i} className="hover:bg-muted/30">
                        <td className="p-2 font-mono">{new Date(p.ts).toLocaleTimeString()}</td>
                        <td className="p-2 font-mono">{p.lat.toFixed(5)}</td>
                        <td className="p-2 font-mono">{p.lon.toFixed(5)}</td>
                        <td className="p-2 text-right font-mono">
                          {p.speed ? `${(p.speed * 3.6).toFixed(0)} km/h` : "0 km/h"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Message Driver Box */}
            <div className="rounded-xl border border-border/80 p-3.5 bg-muted/20">
              <h3 className="text-xs font-bold uppercase tracking-wider text-muted-foreground mb-2 flex items-center gap-1.5">
                <Send className="size-3.5 text-primary" />
                Dispatch Direct Message
              </h3>
              <div className="flex gap-2">
                <Input
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Send dispatch advisory to driver app..."
                  className="text-xs h-9 bg-background"
                  onKeyDown={(e) => e.key === "Enter" && sendMessage()}
                />
                <Button size="sm" onClick={sendMessage} disabled={!message.trim()} className="gap-1 text-xs">
                  <Send className="size-3" /> Send
                </Button>
              </div>
            </div>
          </div>

          {/* Right: Reassignment / Handover */}
          <div className="rounded-xl border border-border/80 p-4 bg-muted/10 space-y-4">
            <div>
              <h3 className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-1.5">
                <ArrowRightLeft className="size-3.5 text-primary" />
                Reassign Duty or Handover
              </h3>
              <p className="text-xs text-muted-foreground mt-1">
                Perform an in-place driver/bus reassignment or execute a mid-block handover.
              </p>
            </div>

            {/* Mode selection buttons */}
            <div className="grid grid-cols-2 gap-2 bg-muted/40 p-1 rounded-xl">
              <button
                type="button"
                onClick={() => setMode("reassign")}
                className={`py-1.5 px-2 rounded-lg text-xs font-medium transition-all ${
                  mode === "reassign"
                    ? "bg-card text-foreground shadow-xs"
                    : "text-muted-foreground hover:text-foreground"
                }`}
              >
                Reassign in Place
              </button>
              <button
                type="button"
                onClick={() => setMode("handover")}
                className={`py-1.5 px-2 rounded-lg text-xs font-medium transition-all ${
                  mode === "handover"
                    ? "bg-card text-foreground shadow-xs"
                    : "text-muted-foreground hover:text-foreground"
                }`}
              >
                Handover (Vehicle Swap)
              </button>
            </div>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-medium text-foreground block mb-1">New Driver</label>
                <select
                  value={reassignDriver}
                  onChange={(e) => setReassignDriver(e.target.value)}
                  className="w-full rounded-xl border border-border bg-background px-3 py-2 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  <option value="">Select driver...</option>
                  {drivers.map((d) => (
                    <option key={d.user_id} value={d.user_id}>
                      {d.display_name ?? d.invite_email ?? d.user_id}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1">New Vehicle</label>
                <select
                  value={reassignVehicle}
                  onChange={(e) => setReassignVehicle(e.target.value)}
                  className="w-full rounded-xl border border-border bg-background px-3 py-2 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-primary"
                >
                  <option value="">Select vehicle...</option>
                  {vehicleList.map((v) => (
                    <option key={v.id} value={v.id}>
                      Fleet #{v.fleet_no}
                    </option>
                  ))}
                </select>
              </div>

              <Button
                onClick={submitChange}
                disabled={!reassignDriver || !reassignVehicle || isSubmitting}
                className="w-full mt-2"
                size="sm"
              >
                {isSubmitting ? "Applying Reassignment..." : "Apply Reassignment"}
              </Button>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
