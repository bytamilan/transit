"use client";

import { useEffect, useState } from "react";
import { apiFetch, apiUpload, ApiError } from "@/lib/api";
import {
  Users,
  UserPlus,
  Building2,
  AlertTriangle,
  CheckCircle2,
  ShieldAlert,
  ShieldCheck,
  Search,
  Check,
  FileSpreadsheet,
  UploadCloud,
  Mail,
  Phone,
  Calendar,
  PowerOff,
  RefreshCw,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type Depot = { id: string; name: string };
type Driver = {
  user_id: string;
  depot_id?: string;
  display_name?: string;
  invite_email?: string;
  invite_phone?: string;
  licence_expires_on?: string;
  status: string;
  licence_warning: boolean;
  licence_expired: boolean;
};

const emptyForm = {
  email: "",
  phone: "",
  display_name: "",
  depot_id: "",
  licence_number: "",
  licence_expires_on: "",
};

export default function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [depots, setDepots] = useState<Depot[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [importReport, setImportReport] = useState<any[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [filterDepot, setFilterDepot] = useState("");
  const [showInviteForm, setShowInviteForm] = useState(false);

  async function load() {
    setLoading(true);
    try {
      const [d, dep] = await Promise.all([
        apiFetch<{ items: Driver[] }>("/admin/drivers"),
        apiFetch<{ items: Depot[] }>("/admin/depots"),
      ]);
      setDrivers(d.items ?? []);
      setDepots(dep.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load drivers");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    try {
      await apiFetch("/admin/drivers", {
        method: "POST",
        body: JSON.stringify({
          ...form,
          depot_id: form.depot_id || undefined,
          display_name: form.display_name || undefined,
          licence_number: form.licence_number || undefined,
          licence_expires_on: form.licence_expires_on || undefined,
        }),
      });
      setForm(emptyForm);
      setShowInviteForm(false);
      setSuccess("Driver invitation saved successfully.");
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to invite driver");
    }
  }

  async function setStatus(id: string, action: "suspend" | "reactivate") {
    setError(null);
    setSuccess(null);
    try {
      await apiFetch(`/admin/drivers/${id}/${action}`, { method: "POST" });
      setSuccess(`Driver ${action === "suspend" ? "suspended" : "reactivated"}.`);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : `failed to ${action} driver`);
    }
  }

  async function handleCSV(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const text = await file.text();
    try {
      const report = await apiUpload<{ rows: any[] }>("/admin/drivers/import", text, "text/csv");
      setImportReport(report.rows);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "CSV import failed");
    } finally {
      e.target.value = "";
    }
  }

  const activeDrivers = drivers.filter((d) => d.status === "active").length;
  const warningDrivers = drivers.filter((d) => d.licence_warning && !d.licence_expired).length;
  const expiredDrivers = drivers.filter((d) => d.licence_expired).length;

  const filteredDrivers = drivers.filter((d) => {
    const matchesSearch =
      !searchQuery.trim() ||
      (d.display_name && d.display_name.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (d.invite_email && d.invite_email.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (d.invite_phone && d.invite_phone.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesDepot = !filterDepot || d.depot_id === filterDepot;
    return matchesSearch && matchesDepot;
  });

  return (
    <div className="space-y-6">
      {/* Header & Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Driver Workforce</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Onboard drivers, assign depot bases, and track 30-day automated licence compliance.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <Button
            onClick={() => setShowInviteForm(!showInviteForm)}
            className="gap-1.5"
            size="sm"
          >
            <UserPlus className="size-4" />
            <span>{showInviteForm ? "Close Form" : "Invite Driver"}</span>
          </Button>
        </div>
      </div>

      {/* Workforce Metrics */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Total Drivers</span>
            <Users className="size-4 text-primary" />
          </div>
          <div className="mt-2 text-2xl font-bold">{drivers.length}</div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Active Status</span>
            <CheckCircle2 className="size-4 text-emerald-600" />
          </div>
          <div className="mt-2 text-2xl font-bold text-emerald-600">{activeDrivers}</div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Expiring Soon (&lt;30d)</span>
            <ShieldAlert className="size-4 text-amber-600" />
          </div>
          <div className="mt-2 text-2xl font-bold text-amber-600">{warningDrivers}</div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Licence Expired</span>
            <AlertTriangle className="size-4 text-destructive" />
          </div>
          <div className="mt-2 text-2xl font-bold text-destructive">{expiredDrivers}</div>
        </Card>
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

      {/* Invite Driver Form */}
      {showInviteForm && (
        <Card className="border-primary/30 shadow-sm animate-in fade-in duration-200">
          <CardHeader>
            <CardTitle className="text-lg">Invite & Register Driver</CardTitle>
            <CardDescription className="text-xs">
              Create an operator account invitation with contact details and driver licence credentials.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Email Address</label>
                  <Input
                    type="email"
                    placeholder="driver@agency.transit"
                    value={form.email}
                    onChange={(e) => setForm({ ...form, email: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Phone Number</label>
                  <Input
                    type="tel"
                    placeholder="+1 555-0199"
                    value={form.phone}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Full Name</label>
                  <Input
                    placeholder="e.g. John Doe"
                    value={form.display_name}
                    onChange={(e) => setForm({ ...form, display_name: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Assigned Depot</label>
                  <select
                    value={form.depot_id}
                    onChange={(e) => setForm({ ...form, depot_id: e.target.value })}
                    className="w-full rounded-xl border border-border bg-background px-3 py-2 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-primary h-9"
                  >
                    <option value="">No Depot Assigned</option>
                    {depots.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Licence Number</label>
                  <Input
                    placeholder="DL-8392019"
                    value={form.licence_number}
                    onChange={(e) => setForm({ ...form, licence_number: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Licence Expiry Date</label>
                  <Input
                    type="date"
                    value={form.licence_expires_on}
                    onChange={(e) => setForm({ ...form, licence_expires_on: e.target.value })}
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="outline" size="sm" onClick={() => setShowInviteForm(false)}>
                  Cancel
                </Button>
                <Button type="submit" size="sm">
                  Send Driver Invite
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* CSV Bulk Import */}
      <Card className="border-border/80">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <FileSpreadsheet className="size-4 text-primary" />
              <CardTitle className="text-sm font-semibold">Bulk Import Drivers via CSV</CardTitle>
            </div>
            <span className="text-[11px] text-muted-foreground">Header: email,phone,display_name,depot_id,licence_number,licence_expires_on</span>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col sm:flex-row items-center gap-3">
            <label className="flex-1 flex items-center justify-center gap-2 rounded-xl border border-dashed border-border/80 bg-muted/20 px-4 py-3 text-xs text-muted-foreground cursor-pointer hover:bg-muted/40 transition-colors w-full">
              <UploadCloud className="size-4 text-primary" />
              <span>Choose CSV file or drag & drop</span>
              <input type="file" accept=".csv,text/csv" onChange={handleCSV} className="hidden" />
            </label>
          </div>

          {importReport && (
            <div className="mt-3 max-h-36 overflow-y-auto rounded-xl border border-border/60 p-2 bg-muted/20 text-xs">
              <div className="font-semibold mb-1 text-foreground">Import Results:</div>
              <ul className="space-y-0.5 font-mono">
                {importReport.map((row, i) => (
                  <li key={i} className={row.status === "error" ? "text-destructive" : "text-emerald-600"}>
                    Row {row.row} ({row.key}): {row.status} {row.error ? `— ${row.error}` : ""}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="flex flex-col sm:flex-row items-center gap-2 w-full sm:w-auto">
          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search by name, email, phone..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 h-9"
            />
          </div>

          <select
            value={filterDepot}
            onChange={(e) => setFilterDepot(e.target.value)}
            className="w-full sm:w-44 rounded-xl border border-border bg-background px-3 py-2 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-primary h-9"
          >
            <option value="">All Depots</option>
            {depots.map((d) => (
              <option key={d.id} value={d.id}>
                {d.name}
              </option>
            ))}
          </select>
        </div>

        <div className="text-xs text-muted-foreground self-end sm:self-auto">
          Showing <span className="font-semibold text-foreground">{filteredDrivers.length}</span> of{" "}
          <span className="font-semibold text-foreground">{drivers.length}</span> drivers
        </div>
      </div>

      {/* Drivers Table */}
      <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow>
              <TableHead className="font-semibold">Driver</TableHead>
              <TableHead className="font-semibold">Contact Info</TableHead>
              <TableHead className="font-semibold">Depot</TableHead>
              <TableHead className="font-semibold">Licence Expiry</TableHead>
              <TableHead className="font-semibold">Status</TableHead>
              <TableHead className="text-right font-semibold">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={6} className="h-28 text-center text-muted-foreground">
                  Loading drivers...
                </TableCell>
              </TableRow>
            ) : filteredDrivers.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="h-28 text-center text-muted-foreground">
                  No drivers found.
                </TableCell>
              </TableRow>
            ) : (
              filteredDrivers.map((d) => (
                <TableRow key={d.user_id}>
                  <TableCell className="font-medium">
                    <div className="flex items-center gap-2">
                      <div className="flex size-7 items-center justify-center rounded-lg bg-primary/10 text-primary font-bold text-xs">
                        <Users className="size-3.5" />
                      </div>
                      <span className="font-semibold">{d.display_name ?? "Pending Invite"}</span>
                    </div>
                  </TableCell>

                  <TableCell className="text-xs text-muted-foreground">
                    <div className="space-y-0.5">
                      {d.invite_email && (
                        <div className="flex items-center gap-1.5">
                          <Mail className="size-3 text-muted-foreground/70" />
                          <span>{d.invite_email}</span>
                        </div>
                      )}
                      {d.invite_phone && (
                        <div className="flex items-center gap-1.5">
                          <Phone className="size-3 text-muted-foreground/70" />
                          <span>{d.invite_phone}</span>
                        </div>
                      )}
                      {!d.invite_email && !d.invite_phone && <span>—</span>}
                    </div>
                  </TableCell>

                  <TableCell>
                    {depots.find((x) => x.id === d.depot_id)?.name ?? (
                      <span className="text-muted-foreground text-xs">No Depot</span>
                    )}
                  </TableCell>

                  <TableCell>
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-mono">{d.licence_expires_on ?? "—"}</span>
                      {d.licence_expired && (
                        <Badge variant="destructive" className="text-[10px] gap-1">
                          <AlertTriangle className="size-2.5" /> Expired
                        </Badge>
                      )}
                      {!d.licence_expired && d.licence_warning && (
                        <Badge variant="secondary" className="text-[10px] bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30 gap-1">
                          <ShieldAlert className="size-2.5" /> Expiring Soon
                        </Badge>
                      )}
                      {!d.licence_expired && !d.licence_warning && d.licence_expires_on && (
                        <Badge variant="outline" className="text-[10px] text-emerald-600 border-emerald-500/30 bg-emerald-50/50 dark:bg-emerald-950/20">
                          Valid
                        </Badge>
                      )}
                    </div>
                  </TableCell>

                  <TableCell>
                    <Badge
                      variant={d.status === "active" ? "secondary" : "outline"}
                      className={
                        d.status === "active"
                          ? "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30"
                          : "text-muted-foreground"
                      }
                    >
                      {d.status}
                    </Badge>
                  </TableCell>

                  <TableCell className="text-right">
                    {d.status === "suspended" ? (
                      <Button
                        variant="outline"
                        size="xs"
                        onClick={() => setStatus(d.user_id, "reactivate")}
                        className="text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50"
                      >
                        <RefreshCw className="size-3 mr-1" /> Reactivate
                      </Button>
                    ) : (
                      <Button
                        variant="ghost"
                        size="xs"
                        onClick={() => setStatus(d.user_id, "suspend")}
                        className="text-muted-foreground hover:text-destructive hover:bg-destructive/10"
                      >
                        <PowerOff className="size-3 mr-1" /> Suspend
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
