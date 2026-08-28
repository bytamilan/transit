"use client";

import { useEffect, useState } from "react";
import { apiFetch, apiUpload, ApiError } from "@/lib/api";
import {
  Bus,
  Plus,
  UploadCloud,
  Trash2,
  AlertTriangle,
  CheckCircle2,
  Building2,
  Wrench,
  Search,
  Check,
  FileSpreadsheet,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";

type Depot = { id: string; name: string };
type Vehicle = {
  id: string;
  depot_id?: string;
  fleet_no: string;
  registration: string;
  capacity_class?: string;
  propulsion?: string;
  status: string;
  maintenance_hold: boolean;
};

const emptyForm = {
  fleet_no: "",
  registration: "",
  depot_id: "",
  capacity_class: "",
  propulsion: "",
  status: "active",
  maintenance_hold: false,
};

export default function VehiclesPage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [depots, setDepots] = useState<Depot[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [importReport, setImportReport] = useState<any[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [filterDepot, setFilterDepot] = useState("");
  const [showAddForm, setShowAddForm] = useState(false);

  async function load() {
    setLoading(true);
    try {
      const [v, d] = await Promise.all([
        apiFetch<{ items: Vehicle[] }>("/admin/vehicles"),
        apiFetch<{ items: Depot[] }>("/admin/depots"),
      ]);
      setVehicles(v.items ?? []);
      setDepots(d.items ?? []);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to load vehicles");
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
      await apiFetch("/admin/vehicles", {
        method: "POST",
        body: JSON.stringify({
          ...form,
          depot_id: form.depot_id || undefined,
          capacity_class: form.capacity_class || undefined,
          propulsion: form.propulsion || undefined,
        }),
      });
      setForm(emptyForm);
      setShowAddForm(false);
      setSuccess(`Vehicle ${form.fleet_no} saved successfully.`);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to save vehicle");
    }
  }

  async function handleDelete(id: string, fleetNo: string) {
    if (!confirm(`Delete vehicle #${fleetNo}? This action cannot be undone.`)) return;
    try {
      await apiFetch(`/admin/vehicles/${id}`, { method: "DELETE" });
      setSuccess(`Vehicle #${fleetNo} deleted.`);
      await load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "failed to delete vehicle");
    }
  }

  async function handleCSV(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const text = await file.text();
    try {
      const report = await apiUpload<{ rows: any[] }>("/admin/vehicles/import", text, "text/csv");
      setImportReport(report.rows);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "CSV import failed");
    } finally {
      e.target.value = "";
    }
  }

  const activeVehicles = vehicles.filter((v) => v.status === "active").length;
  const holdVehicles = vehicles.filter((v) => v.maintenance_hold).length;

  const filteredVehicles = vehicles.filter((v) => {
    const matchesSearch =
      !searchQuery.trim() ||
      v.fleet_no.toLowerCase().includes(searchQuery.toLowerCase()) ||
      v.registration.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (v.propulsion && v.propulsion.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesDepot = !filterDepot || v.depot_id === filterDepot;
    return matchesSearch && matchesDepot;
  });

  return (
    <div className="space-y-6">
      {/* Header & Metrics */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Fleet Management</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Vehicle registration, depot assignments, capacity classes, and maintenance holds.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <Button
            onClick={() => setShowAddForm(!showAddForm)}
            className="gap-1.5"
            size="sm"
          >
            <Plus className="size-4" />
            <span>{showAddForm ? "Close Form" : "Add Vehicle"}</span>
          </Button>
        </div>
      </div>

      {/* Metric Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Total Fleet</span>
            <Bus className="size-4 text-primary" />
          </div>
          <div className="mt-2 text-2xl font-bold">{vehicles.length}</div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Active Service</span>
            <CheckCircle2 className="size-4 text-emerald-600" />
          </div>
          <div className="mt-2 text-2xl font-bold text-emerald-600">{activeVehicles}</div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Maintenance Hold</span>
            <Wrench className="size-4 text-amber-600" />
          </div>
          <div className="mt-2 text-2xl font-bold text-amber-600">{holdVehicles}</div>
        </Card>

        <Card className="p-4">
          <div className="flex items-center justify-between text-muted-foreground text-xs font-medium">
            <span>Active Depots</span>
            <Building2 className="size-4 text-indigo-600" />
          </div>
          <div className="mt-2 text-2xl font-bold">{depots.length}</div>
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

      {/* Add Vehicle Form */}
      {showAddForm && (
        <Card className="border-primary/30 shadow-sm animate-in fade-in duration-200">
          <CardHeader>
            <CardTitle className="text-lg">Register New Vehicle</CardTitle>
            <CardDescription className="text-xs">
              Add a new vehicle to the fleet registry with technical specifications and depot binding.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Fleet No. *</label>
                  <Input
                    required
                    placeholder="e.g. 1042"
                    value={form.fleet_no}
                    onChange={(e) => setForm({ ...form, fleet_no: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Registration *</label>
                  <Input
                    required
                    placeholder="e.g. TN-01-AB-1234"
                    value={form.registration}
                    onChange={(e) => setForm({ ...form, registration: e.target.value })}
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
                  <label className="text-xs font-medium text-foreground block mb-1">Capacity Class</label>
                  <Input
                    placeholder="e.g. Standard, Articulated, Minibus"
                    value={form.capacity_class}
                    onChange={(e) => setForm({ ...form, capacity_class: e.target.value })}
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">Propulsion</label>
                  <Input
                    placeholder="e.g. Diesel, Electric, Hybrid, CNG"
                    value={form.propulsion}
                    onChange={(e) => setForm({ ...form, propulsion: e.target.value })}
                  />
                </div>

                <div className="flex items-center gap-2 pt-6">
                  <label className="flex items-center gap-2 text-xs font-medium cursor-pointer">
                    <input
                      type="checkbox"
                      checked={form.maintenance_hold}
                      onChange={(e) => setForm({ ...form, maintenance_hold: e.target.checked })}
                      className="size-4 rounded border-border text-primary focus:ring-primary"
                    />
                    <span>Place on Maintenance Hold</span>
                  </label>
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="outline" size="sm" onClick={() => setShowAddForm(false)}>
                  Cancel
                </Button>
                <Button type="submit" size="sm">
                  Save Vehicle
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* CSV Bulk Import Section */}
      <Card className="border-border/80">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <FileSpreadsheet className="size-4 text-primary" />
              <CardTitle className="text-sm font-semibold">Bulk Import Fleet via CSV</CardTitle>
            </div>
            <span className="text-[11px] text-muted-foreground">Header: fleet_no,registration,depot_id,capacity_class,propulsion,status,maintenance_hold</span>
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
              placeholder="Search fleet or registration..."
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
          Showing <span className="font-semibold text-foreground">{filteredVehicles.length}</span> of{" "}
          <span className="font-semibold text-foreground">{vehicles.length}</span> vehicles
        </div>
      </div>

      {/* Vehicles Table */}
      <div className="rounded-2xl border border-border/80 bg-card overflow-hidden shadow-xs">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow>
              <TableHead className="font-semibold">Fleet No.</TableHead>
              <TableHead className="font-semibold">Registration</TableHead>
              <TableHead className="font-semibold">Depot</TableHead>
              <TableHead className="font-semibold">Capacity / Propulsion</TableHead>
              <TableHead className="font-semibold">Status</TableHead>
              <TableHead className="font-semibold">Hold</TableHead>
              <TableHead className="text-right font-semibold">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="h-28 text-center text-muted-foreground">
                  Loading vehicles...
                </TableCell>
              </TableRow>
            ) : filteredVehicles.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="h-28 text-center text-muted-foreground">
                  No vehicles found.
                </TableCell>
              </TableRow>
            ) : (
              filteredVehicles.map((v) => (
                <TableRow key={v.id}>
                  <TableCell className="font-semibold">
                    <div className="flex items-center gap-2">
                      <div className="flex size-7 items-center justify-center rounded-lg bg-primary/10 text-primary font-bold text-xs">
                        <Bus className="size-3.5" />
                      </div>
                      <span>#{v.fleet_no}</span>
                    </div>
                  </TableCell>

                  <TableCell className="font-mono text-xs text-muted-foreground">
                    {v.registration}
                  </TableCell>

                  <TableCell>
                    {depots.find((d) => d.id === v.depot_id)?.name ?? (
                      <span className="text-muted-foreground text-xs">No Depot</span>
                    )}
                  </TableCell>

                  <TableCell className="text-xs text-muted-foreground">
                    {[v.capacity_class, v.propulsion].filter(Boolean).join(" • ") || "—"}
                  </TableCell>

                  <TableCell>
                    <Badge
                      variant={v.status === "active" ? "secondary" : "outline"}
                      className={
                        v.status === "active"
                          ? "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30"
                          : "text-muted-foreground"
                      }
                    >
                      {v.status}
                    </Badge>
                  </TableCell>

                  <TableCell>
                    {v.maintenance_hold ? (
                      <Badge variant="destructive" className="gap-1">
                        <Wrench className="size-2.5" /> Hold
                      </Badge>
                    ) : (
                      <span className="text-xs text-muted-foreground">—</span>
                    )}
                  </TableCell>

                  <TableCell className="text-right">
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      onClick={() => handleDelete(v.id, v.fleet_no)}
                      className="text-muted-foreground hover:text-destructive hover:bg-destructive/10"
                      title="Delete Vehicle"
                    >
                      <Trash2 className="size-4" />
                    </Button>
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
