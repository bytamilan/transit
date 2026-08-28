"use client";

import { useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import {
  CalendarDays,
  Plus,
  Trash2,
  AlertTriangle,
  CheckCircle2,
  RotateCw,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type Driver = { user_id: string; display_name?: string; invite_email?: string };
type Vehicle = { id: string; fleet_no: string };
type Entry = {
  weekday: string;
  block_ref: string;
  trip_ids: string;
  driver_id: string;
  vehicle_id: string;
};
type ExpandRow = {
  service_date: string;
  block_ref: string;
  assignment_id?: string;
  conflicts?: { kind: string; message: string }[];
};

const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
const emptyEntry: Entry = {
  weekday: "monday",
  block_ref: "",
  trip_ids: "",
  driver_id: "",
  vehicle_id: "",
};

export default function RecurringRosterForm({
  drivers,
  vehicles,
  onApplied,
}: {
  drivers: Driver[];
  vehicles: Vehicle[];
  onApplied: () => void;
}) {
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [entries, setEntries] = useState<Entry[]>([{ ...emptyEntry }]);
  const [rows, setRows] = useState<ExpandRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isApplying, setIsApplying] = useState(false);

  function updateEntry(i: number, patch: Partial<Entry>) {
    setEntries((rows) => rows.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsApplying(true);
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
    } finally {
      setIsApplying(false);
    }
  }

  return (
    <Card className="border-border/80 shadow-xs">
      <CardHeader>
        <div className="flex items-center gap-2">
          <CalendarDays className="size-4 text-primary" />
          <CardTitle className="text-base font-semibold">Recurring Duty Template</CardTitle>
        </div>
        <CardDescription className="text-xs">
          Apply a weekly shift pattern across a date range. Blocks are generated automatically for matching weekdays.
        </CardDescription>
      </CardHeader>

      <CardContent className="space-y-4">
        {error && (
          <Alert variant="destructive">
            <AlertTriangle className="size-4" />
            <AlertTitle>Error</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        <form onSubmit={submit} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-md">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1">From Date *</label>
              <Input
                required
                type="date"
                value={from}
                onChange={(e) => setFrom(e.target.value)}
                className="h-9 text-xs"
              />
            </div>
            <div>
              <label className="text-xs font-medium text-foreground block mb-1">To Date *</label>
              <Input
                required
                type="date"
                value={to}
                onChange={(e) => setTo(e.target.value)}
                className="h-9 text-xs"
              />
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-xs font-semibold text-foreground uppercase tracking-wider block">
              Pattern Entries ({entries.length})
            </label>

            {entries.map((entry, i) => (
              <div
                key={i}
                className="grid grid-cols-1 sm:grid-cols-6 gap-2 p-2.5 rounded-xl border border-border/70 bg-muted/20 items-center"
              >
                <select
                  value={entry.weekday}
                  onChange={(e) => updateEntry(i, { weekday: e.target.value })}
                  className="rounded-xl border border-border bg-background px-2.5 py-1.5 text-xs text-foreground capitalize h-8"
                >
                  {WEEKDAYS.map((d) => (
                    <option key={d} value={d}>
                      {d}
                    </option>
                  ))}
                </select>

                <Input
                  required
                  placeholder="Block ref (e.g. B-01)"
                  value={entry.block_ref}
                  onChange={(e) => updateEntry(i, { block_ref: e.target.value })}
                  className="h-8 text-xs font-mono"
                />

                <Input
                  required
                  placeholder="Trip IDs (comma-separated)"
                  value={entry.trip_ids}
                  onChange={(e) => updateEntry(i, { trip_ids: e.target.value })}
                  className="h-8 text-xs font-mono"
                />

                <select
                  required
                  value={entry.driver_id}
                  onChange={(e) => updateEntry(i, { driver_id: e.target.value })}
                  className="rounded-xl border border-border bg-background px-2.5 py-1.5 text-xs text-foreground h-8"
                >
                  <option value="">Select Driver...</option>
                  {drivers.map((d) => (
                    <option key={d.user_id} value={d.user_id}>
                      {d.display_name ?? d.invite_email ?? d.user_id}
                    </option>
                  ))}
                </select>

                <select
                  required
                  value={entry.vehicle_id}
                  onChange={(e) => updateEntry(i, { vehicle_id: e.target.value })}
                  className="rounded-xl border border-border bg-background px-2.5 py-1.5 text-xs text-foreground h-8"
                >
                  <option value="">Select Vehicle...</option>
                  {vehicles.map((v) => (
                    <option key={v.id} value={v.id}>
                      Fleet #{v.fleet_no}
                    </option>
                  ))}
                </select>

                <div className="flex justify-end">
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon-xs"
                    onClick={() => setEntries((rows) => rows.filter((_, idx) => idx !== i))}
                    className="text-muted-foreground hover:text-destructive"
                    title="Remove Entry"
                  >
                    <Trash2 className="size-3.5" />
                  </Button>
                </div>
              </div>
            ))}
          </div>

          <div className="flex items-center justify-between pt-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setEntries((rows) => [...rows, { ...emptyEntry }])}
              className="gap-1 text-xs"
            >
              <Plus className="size-3.5" /> Add Pattern Row
            </Button>

            <Button type="submit" size="sm" disabled={isApplying} className="gap-1.5 text-xs">
              <RotateCw className={`size-3.5 ${isApplying ? "animate-spin" : ""}`} />
              <span>{isApplying ? "Expanding Roster..." : "Apply Weekly Pattern"}</span>
            </Button>
          </div>
        </form>

        {rows && (
          <div className="mt-4 rounded-xl border border-border/80 p-4 bg-muted/20 space-y-2 animate-in fade-in">
            <div className="flex items-center gap-2 text-xs font-semibold">
              <CheckCircle2 className="size-4 text-emerald-600" />
              <span>
                {rows.filter((r) => r.assignment_id).length} shifts assigned,{" "}
                {rows.filter((r) => !r.assignment_id).length} skipped due to conflicts
              </span>
            </div>

            <ul className="max-h-44 space-y-1 overflow-y-auto text-xs font-mono">
              {rows.map((r, i) => (
                <li
                  key={i}
                  className={`p-1.5 rounded ${
                    r.assignment_id
                      ? "text-emerald-700 dark:text-emerald-400 bg-emerald-500/10"
                      : "text-amber-800 dark:text-amber-300 bg-amber-500/10"
                  }`}
                >
                  <span className="font-semibold">{r.service_date}</span> — {r.block_ref}:{" "}
                  {r.assignment_id
                    ? "Assigned"
                    : (r.conflicts ?? []).map((c) => c.message).join("; ")}
                </li>
              ))}
            </ul>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
