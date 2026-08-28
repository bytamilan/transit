"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import {
  KeyRound,
  Plus,
  Copy,
  Check,
  AlertTriangle,
  Activity,
  ShieldCheck,
  Clock,
  Trash2,
  Lock,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type APIKey = {
  id: string;
  label: string;
  scopes: string[];
  rate_limit_rpm: number;
  quota_daily: number;
  created_at: string;
  revoked_at?: string;
};

type DailyUsage = {
  day: string;
  requests: number;
  error_count: number;
  avg_latency_ms: number;
};

const emptyForm = { label: "", scopes: "data:read", rate_limit_rpm: 60, quota_daily: 10000 };

export default function APIKeysPage() {
  const [keys, setKeys] = useState<APIKey[]>([]);
  const [usage, setUsage] = useState<DailyUsage[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [newKey, setNewKey] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [k, u] = await Promise.all([
        apiFetch<{ items: APIKey[] }>("/admin/api-keys"),
        apiFetch<{ items: DailyUsage[] }>("/admin/api-keys/usage?days=30"),
      ]);
      setKeys(k.items ?? []);
      setUsage(u.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load API keys");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setNewKey(null);
    setCopied(false);
    try {
      const res = await apiFetch<{ id: string; key: string }>("/admin/api-keys", {
        method: "POST",
        body: JSON.stringify({
          label: form.label,
          scopes: form.scopes.split(",").map((s) => s.trim()).filter(Boolean),
          rate_limit_rpm: Number(form.rate_limit_rpm),
          quota_daily: Number(form.quota_daily),
        }),
      });
      setNewKey(res.key);
      setForm(emptyForm);
      setShowCreateForm(false);
      setSuccess("API key generated successfully.");
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to create API key");
    }
  }

  async function revoke(id: string) {
    if (!confirm("Revoke this API key? Requests using it will start failing immediately.")) return;
    setError(null);
    setSuccess(null);
    try {
      await apiFetch(`/admin/api-keys/${id}`, { method: "DELETE" });
      setSuccess("API key revoked.");
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to revoke API key");
    }
  }

  function copyKeyToClipboard() {
    if (!newKey) return;
    navigator.clipboard.writeText(newKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 3000);
  }

  const maxRequests = Math.max(1, ...usage.map((u) => u.requests));
  const total30dRequests = usage.reduce((acc, u) => acc + u.requests, 0);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">API Access Keys</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Provision scoped integration tokens for data consumers with per-minute rate limits and daily quotas.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <Button
            size="sm"
            onClick={() => setShowCreateForm(!showCreateForm)}
            className="gap-1.5"
          >
            <Plus className="size-4" />
            <span>{showCreateForm ? "Close Form" : "Generate Key"}</span>
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

      {/* Secret Key Alert / Reveal Banner */}
      {newKey && (
        <Card className="border-amber-500/40 bg-amber-50/50 dark:bg-amber-950/20 shadow-md animate-in fade-in">
          <CardHeader className="pb-2">
            <div className="flex items-center gap-2 text-amber-900 dark:text-amber-300 font-semibold text-sm">
              <Lock className="size-4 text-amber-600" />
              <span>Copy Your Secret API Key Now</span>
            </div>
            <CardDescription className="text-xs text-amber-800 dark:text-amber-400">
              For security, this token will not be shown again. Store it in a secure environment.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center gap-2">
              <code className="flex-1 font-mono text-xs p-2.5 rounded-xl border border-amber-300 dark:border-amber-800 bg-background break-all">
                {newKey}
              </code>
              <Button
                size="sm"
                variant="outline"
                onClick={copyKeyToClipboard}
                className="gap-1.5 shrink-0 border-amber-300 hover:bg-amber-100"
              >
                {copied ? <Check className="size-4 text-emerald-600" /> : <Copy className="size-4" />}
                <span>{copied ? "Copied!" : "Copy Key"}</span>
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Create Key Form */}
      {showCreateForm && (
        <Card className="border-primary/30 shadow-sm animate-in fade-in duration-200">
          <CardHeader>
            <CardTitle className="text-base font-semibold">Generate New API Key</CardTitle>
            <CardDescription className="text-xs">
              Define token label, authorized scopes, and server-enforced traffic throttling.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleCreate} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Key Label *</label>
                  <Input
                    required
                    placeholder="e.g. City Dashboard Partner"
                    value={form.label}
                    onChange={(e) => setForm({ ...form, label: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Scopes (comma-separated)
                  </label>
                  <Input
                    placeholder="e.g. data:read, telemetry:read"
                    value={form.scopes}
                    onChange={(e) => setForm({ ...form, scopes: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Rate Limit (Req / Min)
                  </label>
                  <Input
                    type="number"
                    min={1}
                    value={form.rate_limit_rpm}
                    onChange={(e) => setForm({ ...form, rate_limit_rpm: Number(e.target.value) })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Daily Request Quota (0 = unlimited)
                  </label>
                  <Input
                    type="number"
                    min={0}
                    value={form.quota_daily}
                    onChange={(e) => setForm({ ...form, quota_daily: Number(e.target.value) })}
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="outline" size="sm" onClick={() => setShowCreateForm(false)}>
                  Cancel
                </Button>
                <Button type="submit" size="sm">
                  Create Token
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* 30-Day Usage Visualizer */}
      <Card className="border-border/80 shadow-xs">
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Activity className="size-4 text-primary" />
              <CardTitle className="text-sm font-semibold">API Traffic (Last 30 Days)</CardTitle>
            </div>
            <span className="text-xs font-semibold text-muted-foreground">
              Total: {total30dRequests.toLocaleString()} requests
            </span>
          </div>
        </CardHeader>
        <CardContent>
          {usage.length === 0 ? (
            <p className="text-xs text-muted-foreground py-6 text-center">
              No API requests recorded in the last 30 days.
            </p>
          ) : (
            <div className="space-y-2">
              <div className="flex h-32 items-end gap-1 rounded-xl border border-border/70 bg-muted/20 p-3">
                {usage.map((u) => {
                  const heightPercent = Math.max(4, (u.requests / maxRequests) * 100);
                  return (
                    <div
                      key={u.day}
                      className="group relative flex-1 h-full flex items-end justify-center"
                    >
                      <div
                        className={`w-full rounded-t-sm transition-all ${
                          u.error_count > 0 ? "bg-amber-500 hover:bg-amber-600" : "bg-primary/70 hover:bg-primary"
                        }`}
                        style={{ height: `${heightPercent}%` }}
                      />
                      {/* Tooltip on hover */}
                      <div className="absolute bottom-full mb-2 hidden group-hover:flex flex-col items-center pointer-events-none z-10">
                        <div className="bg-popover text-popover-foreground text-[10px] font-mono px-2 py-1 rounded shadow-md whitespace-nowrap border border-border">
                          <div>{u.day}</div>
                          <div>{u.requests} reqs • {u.error_count} err</div>
                          <div>{Math.round(u.avg_latency_ms || 0)}ms latency</div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
              <div className="flex items-center justify-between text-[10px] text-muted-foreground font-mono px-1">
                <span>{usage[0]?.day}</span>
                <span>{usage[usage.length - 1]?.day}</span>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Keys Table */}
      <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow>
              <TableHead className="font-semibold">Key Label</TableHead>
              <TableHead className="font-semibold">Authorized Scopes</TableHead>
              <TableHead className="font-semibold">Rate Limit</TableHead>
              <TableHead className="font-semibold">Daily Quota</TableHead>
              <TableHead className="font-semibold">Status</TableHead>
              <TableHead className="text-right font-semibold">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={6} className="h-28 text-center text-muted-foreground">
                  Loading keys...
                </TableCell>
              </TableRow>
            ) : keys.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="h-28 text-center text-muted-foreground">
                  No API access tokens created yet.
                </TableCell>
              </TableRow>
            ) : (
              keys.map((k) => (
                <TableRow key={k.id} className={k.revoked_at ? "opacity-60" : ""}>
                  <TableCell className="font-medium">
                    <div className="flex items-center gap-2">
                      <KeyRound className="size-3.5 text-primary" />
                      <span className="font-semibold text-foreground">{k.label}</span>
                    </div>
                  </TableCell>

                  <TableCell>
                    <div className="flex flex-wrap gap-1">
                      {k.scopes.map((s) => (
                        <Badge key={s} variant="outline" className="text-[10px] font-mono">
                          {s}
                        </Badge>
                      ))}
                    </div>
                  </TableCell>

                  <TableCell className="font-mono text-xs">
                    {k.rate_limit_rpm} req/min
                  </TableCell>

                  <TableCell className="font-mono text-xs">
                    {k.quota_daily === 0 ? (
                      <span className="text-muted-foreground">Unlimited</span>
                    ) : (
                      `${k.quota_daily.toLocaleString()} / day`
                    )}
                  </TableCell>

                  <TableCell>
                    {k.revoked_at ? (
                      <Badge variant="destructive" className="text-[10px]">
                        Revoked
                      </Badge>
                    ) : (
                      <Badge variant="secondary" className="bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30 text-[10px]">
                        Active
                      </Badge>
                    )}
                  </TableCell>

                  <TableCell className="text-right">
                    {!k.revoked_at && (
                      <Button
                        size="xs"
                        variant="ghost"
                        onClick={() => revoke(k.id)}
                        className="text-muted-foreground hover:text-destructive hover:bg-destructive/10"
                      >
                        <Trash2 className="size-3.5 mr-1" /> Revoke
                      </Button>
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
