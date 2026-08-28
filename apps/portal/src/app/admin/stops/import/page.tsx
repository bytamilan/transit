"use client";

import { useMemo, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import { MapView, type MapMarker } from "@/components/map-view";
import {
  MapPin,
  DownloadCloud,
  AlertTriangle,
  Check,
  Loader2,
  MousePointerSquareDashed,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type PreviewStop = {
  stop_id: string;
  name: string;
  ref: string;
  lat: number;
  lon: number;
  wheelchair_boarding: 0 | 1 | 2;
  platform_code: string;
  status: "new" | "existing";
  existing_stop_id: string;
};

type StopRow = PreviewStop & { included: boolean };

type ImportRow = { stop_id: string; status: "ok" | "error"; message?: string };

const WHEELCHAIR_LABELS: Record<number, string> = {
  0: "0 — Unknown",
  1: "1 — Accessible",
  2: "2 — Not accessible",
};

export default function StopImportPage() {
  const [bbox, setBbox] = useState({ south: "", west: "", north: "", east: "" });
  const [rows, setRows] = useState<StopRow[] | null>(null);
  const [report, setReport] = useState<ImportRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [fetching, setFetching] = useState(false);
  const [importing, setImporting] = useState(false);
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  const markers: MapMarker[] = useMemo(
    () =>
      (rows ?? []).map((r) => ({
        id: r.stop_id,
        lat: r.lat,
        lon: r.lon,
        kind: r.stop_id === hoveredId ? "selected" : r.status,
      })),
    [rows, hoveredId]
  );

  const selectedCount = (rows ?? []).filter((r) => r.included).length;

  function updateRow(stopId: string, patch: Partial<StopRow>) {
    setRows((prev) => prev?.map((r) => (r.stop_id === stopId ? { ...r, ...patch } : r)) ?? null);
  }

  async function fetchPreview() {
    setError(null);
    setSuccess(null);
    setReport(null);
    const south = parseFloat(bbox.south);
    const west = parseFloat(bbox.west);
    const north = parseFloat(bbox.north);
    const east = parseFloat(bbox.east);
    if ([south, west, north, east].some((v) => Number.isNaN(v))) {
      setError("Enter all four bounding-box coordinates (shift-drag on the map or type them).");
      return;
    }
    setFetching(true);
    try {
      const res = await apiFetch<{ items: PreviewStop[] }>("/admin/stops/import/osm/preview", {
        method: "POST",
        body: JSON.stringify({ south, west, north, east }),
      });
      const items = res.items ?? [];
      setRows(items.map((s) => ({ ...s, included: s.status === "new" })));
      if (items.length === 0) {
        setSuccess("OpenStreetMap returned no bus stops inside that area.");
      }
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to fetch OSM preview");
    } finally {
      setFetching(false);
    }
  }

  async function commitImport() {
    if (!rows) return;
    setError(null);
    setSuccess(null);
    setReport(null);
    const stops = rows
      .filter((r) => r.included)
      .map(({ stop_id, name, ref, lat, lon, wheelchair_boarding, platform_code }) => ({
        stop_id,
        name,
        ref,
        lat,
        lon,
        wheelchair_boarding,
        platform_code,
      }));
    if (stops.length === 0) {
      setError("Select at least one stop to import.");
      return;
    }
    setImporting(true);
    try {
      const res = await apiFetch<{ rows: ImportRow[]; imported: number }>("/admin/stops/import/osm", {
        method: "POST",
        body: JSON.stringify({ stops }),
      });
      setReport(res.rows ?? []);
      setSuccess(`Imported ${res.imported} stop${res.imported === 1 ? "" : "s"} from OpenStreetMap.`);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "stop import failed");
    } finally {
      setImporting(false);
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Import Stops from OpenStreetMap</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Draw an area on the map, review and edit the stops OSM knows about, then import your selection.
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

      {/* Step 1 — choose area */}
      <Card className="border-border/80">
        <CardHeader className="pb-3">
          <div className="flex items-center gap-2">
            <MousePointerSquareDashed className="size-4 text-primary" />
            <CardTitle className="text-sm font-semibold">1. Choose an area</CardTitle>
          </div>
          <CardDescription className="text-xs">
            Hold <kbd className="rounded bg-muted px-1 py-0.5 font-mono text-[10px]">Shift</kbd> and drag on the
            map to draw a bounding box, or type the coordinates below.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <MapView
            markers={markers}
            onBBoxChange={(south, west, north, east) =>
              setBbox({
                south: south.toFixed(6),
                west: west.toFixed(6),
                north: north.toFixed(6),
                east: east.toFixed(6),
              })
            }
          />

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {(["south", "west", "north", "east"] as const).map((key) => (
              <div key={key}>
                <label className="text-xs font-medium text-foreground block mb-1 capitalize">{key}</label>
                <Input
                  type="number"
                  step="any"
                  placeholder={key === "south" || key === "north" ? "e.g. 51.49" : "e.g. -0.12"}
                  value={bbox[key]}
                  onChange={(e) => setBbox({ ...bbox, [key]: e.target.value })}
                />
              </div>
            ))}
          </div>

          <div className="flex justify-end">
            <Button onClick={fetchPreview} disabled={fetching} size="sm" className="gap-1.5">
              {fetching ? <Loader2 className="size-4 animate-spin" /> : <DownloadCloud className="size-4" />}
              <span>{fetching ? "Fetching..." : "Fetch from OpenStreetMap"}</span>
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Step 2 — review & edit */}
      {rows && rows.length > 0 && (
        <Card className="border-border/80">
          <CardHeader className="pb-3">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
              <div className="flex items-center gap-2">
                <MapPin className="size-4 text-primary" />
                <CardTitle className="text-sm font-semibold">
                  2. Review &amp; edit — {rows.length} stop{rows.length === 1 ? "" : "s"} found
                </CardTitle>
              </div>
              <div className="flex items-center gap-3 text-[11px] text-muted-foreground">
                <span className="inline-flex items-center gap-1.5">
                  <span className="size-2.5 rounded-full bg-emerald-500" /> New
                </span>
                <span className="inline-flex items-center gap-1.5">
                  <span className="size-2.5 rounded-full bg-amber-500" /> Already exists
                </span>
              </div>
            </div>
            <CardDescription className="text-xs">
              Existing stops are excluded by default. Tick the rows you want to import; names, refs and
              accessibility flags are editable.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
              <div className="max-h-96 overflow-y-auto">
                <Table>
                  <TableHeader className="bg-muted/40 sticky top-0">
                    <TableRow>
                      <TableHead className="font-semibold w-10">Include</TableHead>
                      <TableHead className="font-semibold">Name</TableHead>
                      <TableHead className="font-semibold">Ref</TableHead>
                      <TableHead className="font-semibold">Platform</TableHead>
                      <TableHead className="font-semibold">Wheelchair</TableHead>
                      <TableHead className="font-semibold">Location</TableHead>
                      <TableHead className="font-semibold">Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {rows.map((r) => (
                      <TableRow
                        key={r.stop_id}
                        onMouseEnter={() => setHoveredId(r.stop_id)}
                        onMouseLeave={() => setHoveredId(null)}
                        className={r.included ? undefined : "opacity-60"}
                      >
                        <TableCell>
                          <Checkbox
                            checked={r.included}
                            onCheckedChange={(checked) => updateRow(r.stop_id, { included: checked === true })}
                            aria-label={`Include ${r.name}`}
                          />
                        </TableCell>
                        <TableCell className="min-w-48">
                          <Input
                            value={r.name}
                            onChange={(e) => updateRow(r.stop_id, { name: e.target.value })}
                            className="h-8 text-xs"
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            value={r.ref}
                            onChange={(e) => updateRow(r.stop_id, { ref: e.target.value })}
                            className="h-8 w-20 text-xs"
                          />
                        </TableCell>
                        <TableCell>
                          <Input
                            value={r.platform_code}
                            onChange={(e) => updateRow(r.stop_id, { platform_code: e.target.value })}
                            className="h-8 w-20 text-xs"
                          />
                        </TableCell>
                        <TableCell>
                          <select
                            value={r.wheelchair_boarding}
                            onChange={(e) =>
                              updateRow(r.stop_id, {
                                wheelchair_boarding: Number(e.target.value) as 0 | 1 | 2,
                              })
                            }
                            className="w-36 rounded-xl border border-border bg-background px-2 py-1.5 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-primary"
                          >
                            {[0, 1, 2].map((v) => (
                              <option key={v} value={v}>
                                {WHEELCHAIR_LABELS[v]}
                              </option>
                            ))}
                          </select>
                        </TableCell>
                        <TableCell className="text-xs font-mono text-muted-foreground whitespace-nowrap">
                          {r.lat.toFixed(6)}, {r.lon.toFixed(6)}
                        </TableCell>
                        <TableCell>
                          {r.status === "new" ? (
                            <Badge
                              variant="outline"
                              className="text-[10px] text-emerald-600 border-emerald-500/30 bg-emerald-50/50 dark:bg-emerald-950/20"
                            >
                              New
                            </Badge>
                          ) : (
                            <Badge
                              variant="secondary"
                              className="text-[10px] bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30"
                              title={`Existing stop: ${r.existing_stop_id}`}
                            >
                              Exists
                            </Badge>
                          )}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </div>

            <div className="flex items-center justify-between">
              <span className="text-xs text-muted-foreground">
                <span className="font-semibold text-foreground">{selectedCount}</span> of{" "}
                <span className="font-semibold text-foreground">{rows.length}</span> selected
              </span>
              <Button onClick={commitImport} disabled={importing || selectedCount === 0} size="sm" className="gap-1.5">
                {importing ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />}
                <span>{importing ? "Importing..." : `Import ${selectedCount} selected stop${selectedCount === 1 ? "" : "s"}`}</span>
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Step 3 — report */}
      {report && (
        <Card className="border-border/80">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-semibold">3. Import results</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="max-h-48 overflow-y-auto rounded-xl border border-border/60 p-2 bg-muted/20 text-xs">
              <ul className="space-y-0.5 font-mono">
                {report.map((row, i) => (
                  <li key={i} className={row.status === "error" ? "text-destructive" : "text-emerald-600"}>
                    {row.stop_id}: {row.status}
                    {row.message ? ` — ${row.message}` : ""}
                  </li>
                ))}
              </ul>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
