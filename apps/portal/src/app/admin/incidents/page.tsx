"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import {
  AlertOctagon,
  CheckCircle2,
  Clock,
  AlertTriangle,
  Check,
  Filter,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type Incident = {
  id: string;
  assignment_id?: string;
  kind: string;
  note?: string;
  ts: string;
  resolved_at?: string;
};

function incidentKindBadge(kind: string) {
  switch (kind.toLowerCase()) {
    case "breakdown":
    case "mechanical":
      return <Badge variant="destructive" className="capitalize">{kind}</Badge>;
    case "accident":
    case "collision":
      return <Badge variant="destructive" className="capitalize font-bold">{kind}</Badge>;
    case "medical":
      return <Badge variant="destructive" className="capitalize">{kind}</Badge>;
    case "delay":
    case "traffic":
      return <Badge variant="secondary" className="bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30 capitalize">{kind}</Badge>;
    default:
      return <Badge variant="outline" className="capitalize">{kind}</Badge>;
  }
}

export default function IncidentsPage() {
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [openOnly, setOpenOnly] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiFetch<{ items: Incident[] }>(`/admin/incidents?open=${openOnly}`);
      setIncidents(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load incidents");
    } finally {
      setLoading(false);
    }
  }, [openOnly]);

  useEffect(() => {
    load();
  }, [load]);

  async function resolve(id: string) {
    setError(null);
    setSuccess(null);
    try {
      await apiFetch(`/admin/incidents/${id}/resolve`, { method: "POST" });
      setSuccess("Incident marked as resolved.");
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to resolve incident");
    }
  }

  const openCount = incidents.filter((i) => !i.resolved_at).length;

  return (
    <div className="space-y-6">
      {/* Header & Filter */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Incident Log</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Driver-reported safety anomalies, mechanical faults, and delay notices from the road.
          </p>
        </div>

        <div className="flex items-center gap-3 self-start sm:self-auto">
          <label className="flex items-center gap-2 text-xs font-medium cursor-pointer bg-card px-3 py-1.5 rounded-xl border border-border/80 shadow-xs">
            <input
              type="checkbox"
              checked={openOnly}
              onChange={(e) => setOpenOnly(e.target.checked)}
              className="size-4 rounded border-border text-primary focus:ring-primary"
            />
            <span>Show Open Incidents Only</span>
          </label>
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

      {/* Incidents Table */}
      <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow>
              <TableHead className="font-semibold">Timestamp</TableHead>
              <TableHead className="font-semibold">Incident Type</TableHead>
              <TableHead className="font-semibold">Driver Note / Description</TableHead>
              <TableHead className="font-semibold">Status</TableHead>
              <TableHead className="text-right font-semibold">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={5} className="h-28 text-center text-muted-foreground">
                  Loading incidents...
                </TableCell>
              </TableRow>
            ) : incidents.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="h-28 text-center text-muted-foreground">
                  <div className="flex flex-col items-center justify-center gap-1">
                    <CheckCircle2 className="size-5 text-emerald-600" />
                    <span>No active incidents reported.</span>
                  </div>
                </TableCell>
              </TableRow>
            ) : (
              incidents.map((inc) => (
                <TableRow
                  key={inc.id}
                  className={!inc.resolved_at ? "bg-amber-500/5 hover:bg-amber-500/10" : ""}
                >
                  <TableCell className="text-xs text-muted-foreground font-mono">
                    <div className="flex items-center gap-1.5">
                      <Clock className="size-3.5 text-muted-foreground/60" />
                      <span>{new Date(inc.ts).toLocaleString()}</span>
                    </div>
                  </TableCell>

                  <TableCell>{incidentKindBadge(inc.kind)}</TableCell>

                  <TableCell className="max-w-md">
                    <span className="text-xs font-medium text-foreground">
                      {inc.note || <span className="text-muted-foreground italic">No note provided</span>}
                    </span>
                  </TableCell>

                  <TableCell>
                    {inc.resolved_at ? (
                      <Badge variant="outline" className="text-emerald-600 border-emerald-500/30 bg-emerald-50/50 dark:bg-emerald-950/20 text-[10px]">
                        Resolved
                      </Badge>
                    ) : (
                      <Badge variant="secondary" className="bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30 text-[10px]">
                        Open / Needs Triage
                      </Badge>
                    )}
                  </TableCell>

                  <TableCell className="text-right">
                    {!inc.resolved_at ? (
                      <Button
                        size="xs"
                        variant="outline"
                        onClick={() => resolve(inc.id)}
                        className="text-xs text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50"
                      >
                        <Check className="size-3 mr-1" /> Mark Resolved
                      </Button>
                    ) : (
                      <span className="text-xs text-muted-foreground">—</span>
                    )}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
