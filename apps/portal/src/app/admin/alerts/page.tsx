"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import {
  Megaphone,
  Plus,
  Trash2,
  Check,
  AlertTriangle,
  Clock,
  Radio,
  Globe2,
  Route as RouteIcon,
  MapPin,
  CheckCircle2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type ServiceAlert = {
  id: string;
  cause: string;
  effect: string;
  header_text: Record<string, string>;
  description_text: Record<string, string>;
  url?: Record<string, string>;
  informed_routes: string[];
  informed_stops: string[];
  active_from: string;
  active_until?: string;
  resolved_at?: string;
};

const CAUSES = [
  "unknown_cause",
  "other_cause",
  "technical_problem",
  "strike",
  "demonstration",
  "accident",
  "holiday",
  "weather",
  "maintenance",
  "construction",
  "police_activity",
  "medical_emergency",
];

const EFFECTS = [
  "no_service",
  "reduced_service",
  "significant_delays",
  "detour",
  "additional_service",
  "modified_service",
  "other_effect",
  "unknown_effect",
  "stop_moved",
  "no_effect",
  "accessibility_issue",
];

const emptyForm = {
  cause: "accident",
  effect: "detour",
  headerEn: "",
  descriptionEn: "",
  secondLocale: "",
  headerSecond: "",
  descriptionSecond: "",
  informedRoutes: "",
  informedStops: "",
  activeUntil: "",
};

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<ServiceAlert[]>([]);
  const [showAll, setShowAll] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiFetch<{ items: ServiceAlert[] }>(`/admin/alerts?active=${!showAll}`);
      setAlerts(res.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load alerts");
    } finally {
      setLoading(false);
    }
  }, [showAll]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    if (!form.headerEn.trim()) {
      setError("An English header title is required.");
      return;
    }
    const header_text: Record<string, string> = { en: form.headerEn };
    const description_text: Record<string, string> = {};
    if (form.descriptionEn.trim()) description_text.en = form.descriptionEn;
    if (form.secondLocale.trim() && form.headerSecond.trim()) {
      header_text[form.secondLocale.trim()] = form.headerSecond;
      if (form.descriptionSecond.trim()) description_text[form.secondLocale.trim()] = form.descriptionSecond;
    }

    try {
      await apiFetch("/admin/alerts", {
        method: "POST",
        body: JSON.stringify({
          cause: form.cause,
          effect: form.effect,
          header_text,
          description_text,
          informed_routes: form.informedRoutes.split(",").map((s) => s.trim()).filter(Boolean),
          informed_stops: form.informedStops.split(",").map((s) => s.trim()).filter(Boolean),
          active_until: form.activeUntil ? new Date(form.activeUntil).toISOString() : undefined,
        }),
      });
      setForm(emptyForm);
      setShowCreateForm(false);
      setSuccess("Service alert published to GTFS-RT feed and rider app.");
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to create alert");
    }
  }

  async function resolve(id: string) {
    setError(null);
    setSuccess(null);
    try {
      await apiFetch(`/admin/alerts/${id}/resolve`, { method: "POST" });
      setSuccess("Alert resolved.");
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to resolve alert");
    }
  }

  async function remove(id: string) {
    if (!confirm("Delete this alert permanently?")) return;
    setError(null);
    setSuccess(null);
    try {
      await apiFetch(`/admin/alerts/${id}`, { method: "DELETE" });
      setSuccess("Alert deleted.");
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to delete alert");
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Service Alerts</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Broadcast service disruptions and advisories to GTFS-RT feeds and the rider mobile app.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <Button
            size="sm"
            onClick={() => setShowCreateForm(!showCreateForm)}
            className="gap-1.5"
          >
            <Plus className="size-4" />
            <span>{showCreateForm ? "Close Form" : "Publish Alert"}</span>
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

      {/* Create Alert Form */}
      {showCreateForm && (
        <Card className="border-primary/30 shadow-sm animate-in fade-in duration-200">
          <CardHeader>
            <CardTitle className="text-base font-semibold">Publish New Advisory</CardTitle>
            <CardDescription className="text-xs">
              Configure disruption cause, service effect, multilingual text, and affected routes or stops.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Disruption Cause</label>
                  <select
                    value={form.cause}
                    onChange={(e) => setForm({ ...form, cause: e.target.value })}
                    className="w-full rounded-xl border border-border bg-background px-3 py-2 text-xs text-foreground capitalize focus:ring-2 focus:ring-primary h-9"
                  >
                    {CAUSES.map((c) => (
                      <option key={c} value={c}>
                        {c.replace(/_/g, " ")}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Service Effect</label>
                  <select
                    value={form.effect}
                    onChange={(e) => setForm({ ...form, effect: e.target.value })}
                    className="w-full rounded-xl border border-border bg-background px-3 py-2 text-xs text-foreground capitalize focus:ring-2 focus:ring-primary h-9"
                  >
                    {EFFECTS.map((e) => (
                      <option key={e} value={e}>
                        {e.replace(/_/g, " ")}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Primary English Content */}
              <div className="space-y-3 rounded-xl border border-border/70 p-3.5 bg-muted/10">
                <div className="flex items-center gap-1.5 text-xs font-semibold text-foreground">
                  <Globe2 className="size-3.5 text-primary" />
                  <span>Primary Language (English)</span>
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Header Title *</label>
                  <Input
                    required
                    placeholder="e.g. Route 12 detoured due to downtown road construction"
                    value={form.headerEn}
                    onChange={(e) => setForm({ ...form, headerEn: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Description (Optional)</label>
                  <Textarea
                    placeholder="Detailed advisory and alternate transfer recommendations..."
                    rows={2}
                    value={form.descriptionEn}
                    onChange={(e) => setForm({ ...form, descriptionEn: e.target.value })}
                    className="text-xs"
                  />
                </div>
              </div>

              {/* Optional Second Locale */}
              <div className="space-y-3 rounded-xl border border-border/70 p-3.5 bg-muted/10">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-xs font-semibold text-foreground">
                    <Globe2 className="size-3.5 text-primary" />
                    <span>Second Language (Optional, e.g. ta, es, fr)</span>
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">Locale Code</label>
                    <Input
                      placeholder="e.g. ta"
                      value={form.secondLocale}
                      onChange={(e) => setForm({ ...form, secondLocale: e.target.value })}
                    />
                  </div>
                  <div className="sm:col-span-3">
                    <label className="text-xs font-medium text-foreground block mb-1">Header in Second Language</label>
                    <Input
                      placeholder="Advisory header in second language..."
                      value={form.headerSecond}
                      onChange={(e) => setForm({ ...form, headerSecond: e.target.value })}
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Description in Second Language</label>
                  <Textarea
                    placeholder="Advisory details in second language..."
                    rows={2}
                    value={form.descriptionSecond}
                    onChange={(e) => setForm({ ...form, descriptionSecond: e.target.value })}
                    className="text-xs"
                  />
                </div>
              </div>

              {/* Affected Entities & Timing */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Informed Routes (comma-separated)
                  </label>
                  <Input
                    placeholder="Leave blank for agency-wide"
                    value={form.informedRoutes}
                    onChange={(e) => setForm({ ...form, informedRoutes: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Informed Stops (comma-separated)
                  </label>
                  <Input
                    placeholder="e.g. STOP_10, STOP_12"
                    value={form.informedStops}
                    onChange={(e) => setForm({ ...form, informedStops: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Active Until (Optional)
                  </label>
                  <Input
                    type="datetime-local"
                    value={form.activeUntil}
                    onChange={(e) => setForm({ ...form, activeUntil: e.target.value })}
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="outline" size="sm" onClick={() => setShowCreateForm(false)}>
                  Cancel
                </Button>
                <Button type="submit" size="sm">
                  Publish Alert
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Alerts Table Header and Filter */}
      <div className="flex items-center justify-between">
        <h2 className="text-base font-bold text-foreground">
          Published Advisories ({alerts.length})
        </h2>
        <label className="flex items-center gap-2 text-xs font-medium cursor-pointer bg-card px-3 py-1.5 rounded-xl border border-border/80 shadow-xs">
          <input
            type="checkbox"
            checked={showAll}
            onChange={(e) => setShowAll(e.target.checked)}
            className="size-4 rounded border-border text-primary focus:ring-primary"
          />
          <span>Include Resolved & Expired</span>
        </label>
      </div>

      {/* Alerts Table */}
      <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow>
              <TableHead className="font-semibold">Advisory Header</TableHead>
              <TableHead className="font-semibold">Cause</TableHead>
              <TableHead className="font-semibold">Effect</TableHead>
              <TableHead className="font-semibold">Applies To</TableHead>
              <TableHead className="font-semibold">Status</TableHead>
              <TableHead className="text-right font-semibold">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={6} className="h-28 text-center text-muted-foreground">
                  Loading alerts...
                </TableCell>
              </TableRow>
            ) : alerts.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="h-28 text-center text-muted-foreground">
                  No active service alerts published.
                </TableCell>
              </TableRow>
            ) : (
              alerts.map((a) => (
                <TableRow key={a.id}>
                  <TableCell className="max-w-xs">
                    <div className="font-medium text-foreground">
                      {a.header_text.en ?? Object.values(a.header_text)[0]}
                    </div>
                    {a.description_text?.en && (
                      <p className="text-xs text-muted-foreground line-clamp-1 mt-0.5">
                        {a.description_text.en}
                      </p>
                    )}
                  </TableCell>

                  <TableCell>
                    <Badge variant="outline" className="capitalize text-xs">
                      {a.cause.replace(/_/g, " ")}
                    </Badge>
                  </TableCell>

                  <TableCell>
                    <Badge variant="secondary" className="capitalize text-xs bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30">
                      {a.effect.replace(/_/g, " ")}
                    </Badge>
                  </TableCell>

                  <TableCell className="text-xs text-muted-foreground">
                    {a.informed_routes.length === 0 && a.informed_stops.length === 0 ? (
                      <span className="font-medium text-foreground">Agency-wide</span>
                    ) : (
                      <div className="flex flex-wrap gap-1">
                        {a.informed_routes.map((r) => (
                          <Badge key={r} variant="outline" className="text-[10px] font-mono">
                            route:{r}
                          </Badge>
                        ))}
                        {a.informed_stops.map((s) => (
                          <Badge key={s} variant="outline" className="text-[10px] font-mono">
                            stop:{s}
                          </Badge>
                        ))}
                      </div>
                    )}
                  </TableCell>

                  <TableCell>
                    {a.resolved_at ? (
                      <Badge variant="outline" className="text-muted-foreground text-[10px]">
                        Resolved
                      </Badge>
                    ) : (
                      <Badge variant="secondary" className="bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30 text-[10px]">
                        Active
                      </Badge>
                    )}
                  </TableCell>

                  <TableCell className="text-right">
                    <div className="flex items-center justify-end gap-1.5">
                      {!a.resolved_at && (
                        <Button
                          variant="outline"
                          size="xs"
                          onClick={() => resolve(a.id)}
                          className="text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50 text-[11px]"
                        >
                          Resolve
                        </Button>
                      )}
                      <Button
                        variant="ghost"
                        size="icon-xs"
                        onClick={() => remove(a.id)}
                        className="text-muted-foreground hover:text-destructive hover:bg-destructive/10"
                        title="Delete Alert"
                      >
                        <Trash2 className="size-3.5" />
                      </Button>
                    </div>
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
