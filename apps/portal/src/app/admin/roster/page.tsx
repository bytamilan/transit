"use client";

import { useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import RecurringRosterForm from "./recurring-roster-form";
import {
  CalendarDays,
  Calendar,
  Users,
  Bus,
  Clock,
  AlertTriangle,
  Check,
  UserCheck,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  ShieldAlert,
  ArrowRightLeft,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type Block = { id: string; block_ref: string; service_date: string; trip_ids: string[] };
type Assignment = {
  id: string;
  block_id: string;
  driver_id: string;
  vehicle_id: string;
  service_date: string;
  status: string;
  handover_from_id?: string;
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
  const [assignForm, setAssignForm] = useState<{
    blockId: string;
    driverId: string;
    vehicleId: string;
  } | null>(null);
  const [conflicts, setConflicts] = useState<Conflict[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
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
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [serviceDate]);

  function shiftDate(days: number) {
    const d = new Date(serviceDate);
    d.setDate(d.getDate() + days);
    setServiceDate(d.toISOString().slice(0, 10));
  }

  async function submitAssign(blockId: string) {
    if (!assignForm) return;
    setConflicts(null);
    setError(null);
    setSuccess(null);
    try {
      await apiFetch("/admin/duty-assignments", {
        method: "POST",
        body: JSON.stringify({
          block_id: blockId,
          driver_id: assignForm.driverId,
          vehicle_id: assignForm.vehicleId,
          service_date: serviceDate,
        }),
      });
      setAssignForm(null);
      setSuccess("Duty assignment confirmed.");
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

  const isToday = serviceDate === todayISO();

  return (
    <div className="space-y-8">
      {/* Header with Date Navigator */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Duty Roster</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Schedule driver and vehicle assignments for daily service blocks.
          </p>
        </div>

        {/* Date Navigator Controls */}
        <div className="flex items-center gap-2 bg-card p-1.5 rounded-2xl border border-border/80 shadow-xs self-start sm:self-auto">
          <Button
            variant="ghost"
            size="icon-xs"
            onClick={() => shiftDate(-1)}
            aria-label="Previous day"
          >
            <ChevronLeft className="size-4" />
          </Button>

          <Input
            type="date"
            value={serviceDate}
            onChange={(e) => setServiceDate(e.target.value)}
            className="h-8 text-xs font-medium w-36 border-none shadow-none focus-visible:ring-1"
          />

          <Button
            variant="ghost"
            size="icon-xs"
            onClick={() => shiftDate(1)}
            aria-label="Next day"
          >
            <ChevronRight className="size-4" />
          </Button>

          {!isToday && (
            <Button
              variant="outline"
              size="xs"
              onClick={() => setServiceDate(todayISO())}
              className="text-[11px] h-7"
            >
              Today
            </Button>
          )}
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

      {conflicts && conflicts.length > 0 && (
        <Alert variant="destructive">
          <ShieldAlert className="size-4" />
          <AlertTitle>Assignment Blocked by Policy Conflicts</AlertTitle>
          <AlertDescription>
            <ul className="mt-1 list-disc pl-5 text-xs space-y-0.5">
              {conflicts.map((c, i) => (
                <li key={i}>{c.message}</li>
              ))}
            </ul>
          </AlertDescription>
        </Alert>
      )}

      {/* Unassigned Blocks Section */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Clock className="size-4 text-amber-600" />
            <h2 className="text-base font-bold text-foreground">
              Unassigned Service Blocks ({unassigned.length})
            </h2>
          </div>
          <span className="text-xs text-muted-foreground">Date: {serviceDate}</span>
        </div>

        {unassigned.length === 0 ? (
          <div className="rounded-2xl border border-emerald-500/30 bg-emerald-50/50 dark:bg-emerald-950/20 p-4 text-xs font-medium text-emerald-800 dark:text-emerald-300 flex items-center gap-2">
            <CheckCircle2 className="size-4 text-emerald-600 shrink-0" />
            <span>All service blocks on {serviceDate} have an assigned driver and vehicle.</span>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {unassigned.map((b) => {
              const isEditing = assignForm?.blockId === b.id;
              return (
                <Card key={b.id} className="p-4 border-border/80 shadow-xs">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-sm font-bold text-foreground">
                          {b.block_ref}
                        </span>
                        <Badge variant="outline" className="text-[10px]">
                          {b.trip_ids?.length || 0} trips
                        </Badge>
                      </div>
                      <p className="text-[11px] text-muted-foreground mt-0.5 truncate max-w-xs">
                        Trips: {b.trip_ids?.join(", ") || "No trips listed"}
                      </p>
                    </div>

                    <Button
                      size="xs"
                      variant={isEditing ? "outline" : "default"}
                      onClick={() => {
                        setAssignForm(
                          isEditing
                            ? null
                            : { blockId: b.id, driverId: "", vehicleId: "" }
                        );
                        setConflicts(null);
                      }}
                    >
                      {isEditing ? "Cancel" : "Assign Shift"}
                    </Button>
                  </div>

                  {isEditing && (
                    <div className="mt-3 pt-3 border-t border-border/60 space-y-2 animate-in fade-in">
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        <select
                          value={assignForm.driverId}
                          onChange={(e) =>
                            setAssignForm({ ...assignForm, driverId: e.target.value })
                          }
                          className="rounded-xl border border-border bg-background px-2.5 py-1.5 text-xs text-foreground focus:ring-2 focus:ring-primary h-8"
                        >
                          <option value="">Select Driver...</option>
                          {drivers.map((d) => (
                            <option key={d.user_id} value={d.user_id}>
                              {d.display_name ?? d.invite_email ?? d.user_id}
                            </option>
                          ))}
                        </select>

                        <select
                          value={assignForm.vehicleId}
                          onChange={(e) =>
                            setAssignForm({ ...assignForm, vehicleId: e.target.value })
                          }
                          className="rounded-xl border border-border bg-background px-2.5 py-1.5 text-xs text-foreground focus:ring-2 focus:ring-primary h-8"
                        >
                          <option value="">Select Vehicle...</option>
                          {vehicles.map((v) => (
                            <option key={v.id} value={v.id}>
                              Fleet #{v.fleet_no}
                            </option>
                          ))}
                        </select>
                      </div>

                      <Button
                        size="xs"
                        disabled={!assignForm.driverId || !assignForm.vehicleId}
                        onClick={() => submitAssign(b.id)}
                        className="w-full bg-emerald-600 hover:bg-emerald-700 text-white"
                      >
                        Confirm Assignment
                      </Button>
                    </div>
                  )}
                </Card>
              );
            })}
          </div>
        )}
      </div>

      {/* Assigned Duties Table */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="size-4 text-emerald-600" />
            <h2 className="text-base font-bold text-foreground">
              Confirmed Duties ({assignments.length})
            </h2>
          </div>
        </div>

        <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
          <Table>
            <TableHeader className="bg-muted/40">
              <TableRow>
                <TableHead className="font-semibold">Block Ref</TableHead>
                <TableHead className="font-semibold">Driver</TableHead>
                <TableHead className="font-semibold">Vehicle</TableHead>
                <TableHead className="font-semibold">Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={4} className="h-24 text-center text-muted-foreground">
                    Loading assignments...
                  </TableCell>
                </TableRow>
              ) : assignments.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="h-24 text-center text-muted-foreground">
                    No duties assigned for this date yet.
                  </TableCell>
                </TableRow>
              ) : (
                assignments.map((a) => (
                  <TableRow key={a.id}>
                    <TableCell className="font-mono text-xs font-medium">
                      {a.block_id.slice(0, 8)}
                    </TableCell>

                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Users className="size-3.5 text-muted-foreground" />
                        <span className="font-medium">{driverLabel(a.driver_id)}</span>
                      </div>
                    </TableCell>

                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Bus className="size-3.5 text-muted-foreground" />
                        <span>Fleet #{vehicleLabel(a.vehicle_id)}</span>
                      </div>
                    </TableCell>

                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Badge variant="secondary" className="capitalize text-xs">
                          {a.status}
                        </Badge>
                        {a.handover_from_id && (
                          <Badge variant="outline" className="gap-1 text-[10px] text-primary border-primary/30">
                            <ArrowRightLeft className="size-2.5" /> Handover
                          </Badge>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </div>

      {/* Recurring Roster Section */}
      <div className="pt-4 border-t border-border/80">
        <RecurringRosterForm drivers={drivers} vehicles={vehicles} onApplied={load} />
      </div>
    </div>
  );
}
