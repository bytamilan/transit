"use client";

import { useCallback, useEffect, useState } from "react";
import { apiFetch, ApiError } from "@/lib/api";

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
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [k, u] = await Promise.all([
        apiFetch<{ items: APIKey[] }>("/admin/api-keys"),
        apiFetch<{ items: DailyUsage[] }>("/admin/api-keys/usage?days=30"),
      ]);
      setKeys(k.items ?? []);
      setUsage(u.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load API keys");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setNewKey(null);
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
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to create API key");
    }
  }

  async function revoke(id: string) {
    if (!confirm("Revoke this API key? Requests using it will start failing immediately.")) return;
    await apiFetch(`/admin/api-keys/${id}`, { method: "DELETE" });
    await load();
  }

  const maxRequests = Math.max(1, ...usage.map((u) => u.requests));

  return (
    <div className="max-w-4xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">API keys</h1>
        <p className="mt-1 text-sm text-slate-600">
          Data-consumer integrations authenticate with an <code>X-API-Key</code> header. Each key has its
          own rate limit (requests/minute) and daily quota, enforced server-side.
        </p>
      </div>

      {error && <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      {newKey && (
        <div className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm">
          <p className="font-medium text-amber-900">
            Copy this key now — it won&apos;t be shown again.
          </p>
          <code className="mt-2 block break-all rounded bg-white p-2 text-xs">{newKey}</code>
        </div>
      )}

      <form onSubmit={handleCreate} className="space-y-3 rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="font-medium">New API key</h2>
        <div className="grid grid-cols-3 gap-3">
          <label className="text-sm">
            Label
            <input value={form.label} onChange={(e) => setForm({ ...form, label: e.target.value })} className="mt-1 block w-full rounded border-slate-300" placeholder="Partner integration" required />
          </label>
          <label className="text-sm">
            Scopes (comma-separated)
            <input value={form.scopes} onChange={(e) => setForm({ ...form, scopes: e.target.value })} className="mt-1 block w-full rounded border-slate-300" />
          </label>
          <label className="text-sm">
            Rate limit (req/min)
            <input type="number" min={1} value={form.rate_limit_rpm} onChange={(e) => setForm({ ...form, rate_limit_rpm: Number(e.target.value) })} className="mt-1 block w-full rounded border-slate-300" />
          </label>
        </div>
        <label className="block text-sm">
          Daily quota (0 = unlimited)
          <input type="number" min={0} value={form.quota_daily} onChange={(e) => setForm({ ...form, quota_daily: Number(e.target.value) })} className="mt-1 block w-56 rounded border-slate-300" />
        </label>
        <button type="submit" className="rounded bg-brand px-4 py-2 text-sm font-medium text-white hover:opacity-90">
          Create key
        </button>
      </form>

      <div>
        <h2 className="mb-2 font-medium">Usage, last 30 days</h2>
        {usage.length === 0 ? (
          <p className="text-sm text-slate-500">No usage recorded yet.</p>
        ) : (
          <div className="flex h-32 items-end gap-1 rounded-lg border border-slate-200 bg-white p-3">
            {usage.map((u) => (
              <div key={u.day} className="group relative flex-1" title={`${u.day}: ${u.requests} requests, ${u.error_count} errors`}>
                <div
                  className="w-full rounded-t bg-brand/70 group-hover:bg-brand"
                  style={{ height: `${Math.max(2, (u.requests / maxRequests) * 100)}%` }}
                />
              </div>
            ))}
          </div>
        )}
      </div>

      <table className="w-full overflow-hidden rounded-lg border border-slate-200 bg-white text-sm">
        <thead className="bg-slate-100 text-left">
          <tr><th className="p-2">Label</th><th className="p-2">Scopes</th><th className="p-2">Rate limit</th><th className="p-2">Daily quota</th><th className="p-2">Status</th><th className="p-2"></th></tr>
        </thead>
        <tbody>
          {keys.length === 0 && <tr><td className="p-3 text-slate-500" colSpan={6}>No API keys yet.</td></tr>}
          {keys.map((k) => (
            <tr key={k.id} className="border-t border-slate-100">
              <td className="p-2">{k.label}</td>
              <td className="p-2 text-xs">{k.scopes.join(", ")}</td>
              <td className="p-2">{k.rate_limit_rpm}/min</td>
              <td className="p-2">{k.quota_daily === 0 ? "Unlimited" : k.quota_daily.toLocaleString()}</td>
              <td className="p-2">{k.revoked_at ? "Revoked" : "Active"}</td>
              <td className="p-2 text-right">
                {!k.revoked_at && (
                  <button onClick={() => revoke(k.id)} className="text-red-600 hover:underline">Revoke</button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
