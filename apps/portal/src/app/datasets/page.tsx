import type { Metadata } from "next";
import Link from "next/link";
import {
  Database,
  Download,
  Radio,
  Globe,
  Shield,
  FileText,
  ArrowLeft,
  ExternalLink,
  Bus,
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";

export const metadata: Metadata = {
  title: "Open Transit Datasets — Transit Portal",
  description: "Standards-compliant GTFS static schedules and GTFS-RT feeds published on this deployment.",
};

export const dynamic = "force-dynamic";

type DatasetAgency = {
  slug: string;
  name: string;
  timezone: string;
  modes: string[];
  license_spdx: string;
  attribution: string;
  terms_url?: string;
};

async function loadAgencies(): Promise<{ agencies: DatasetAgency[]; error?: string }> {
  const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL;
  if (!apiBase) {
    return { agencies: [], error: "NEXT_PUBLIC_API_BASE_URL is not configured." };
  }
  try {
    const res = await fetch(`${apiBase}/v0/agencies`, { cache: "no-store" });
    if (!res.ok) {
      return { agencies: [], error: `API returned ${res.status}` };
    }
    return { agencies: (await res.json()) as DatasetAgency[] };
  } catch {
    return { agencies: [], error: "Could not reach the Transit API." };
  }
}

export default async function DatasetsPage() {
  const { agencies, error } = await loadAgencies();
  const exporterBase = process.env.NEXT_PUBLIC_EXPORTER_BASE_URL;

  return (
    <main className="min-h-screen bg-background py-12 px-4 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-4xl space-y-8">
        {/* Navigation & Header */}
        <div className="space-y-3">
          <Link
            href="/admin"
            className="inline-flex items-center gap-1 text-xs font-semibold text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="size-3.5" />
            <span>Go to Admin Console</span>
          </Link>

          <div className="flex items-center gap-3">
            <div className="flex size-10 items-center justify-center rounded-xl bg-primary text-primary-foreground">
              <Database className="size-5" />
            </div>
            <div>
              <h1 className="text-3xl font-bold tracking-tight text-foreground">
                Open Transit Datasets
              </h1>
              <p className="mt-1 text-sm text-muted-foreground">
                Standards-compliant GTFS static schedules and GTFS-RT feeds published by agencies on this deployment.
              </p>
            </div>
          </div>
        </div>

        {error && (
          <Alert className="border-amber-500/30 bg-amber-50/50 text-amber-800 dark:text-amber-300">
            <AlertDescription className="text-xs">{error}</AlertDescription>
          </Alert>
        )}

        {!error && agencies.length === 0 && (
          <Card className="p-8 text-center text-muted-foreground">
            <Database className="size-8 mx-auto mb-2 text-muted-foreground/50" />
            <p className="text-sm font-medium">No transit agencies published yet.</p>
          </Card>
        )}

        {/* Agencies Grid */}
        <div className="grid grid-cols-1 gap-6">
          {agencies.map((a) => (
            <Card key={a.slug} className="border-border/80 shadow-xs">
              <CardHeader className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2 border-b border-border/60 pb-4">
                <div>
                  <CardTitle className="text-xl font-bold text-foreground">
                    {a.name}
                  </CardTitle>
                  <CardDescription className="text-xs font-mono mt-0.5">
                    Agency Slug: {a.slug} • Timezone: {a.timezone}
                  </CardDescription>
                </div>

                {a.modes.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 self-start">
                    {a.modes.map((m) => (
                      <Badge key={m} variant="secondary" className="capitalize text-[11px]">
                        {m}
                      </Badge>
                    ))}
                  </div>
                )}
              </CardHeader>

              <CardContent className="pt-4 space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                  <div className="space-y-1">
                    <span className="font-semibold text-muted-foreground uppercase text-[10px] tracking-wider block">
                      License
                    </span>
                    <span className="font-mono text-foreground">{a.license_spdx || "Not specified"}</span>
                  </div>

                  <div className="space-y-1">
                    <span className="font-semibold text-muted-foreground uppercase text-[10px] tracking-wider block">
                      Attribution
                    </span>
                    <span className="text-foreground">{a.attribution || "Not specified"}</span>
                  </div>
                </div>

                {a.terms_url && (
                  <div className="pt-1">
                    <a
                      href={a.terms_url}
                      target="_blank"
                      rel="noreferrer"
                      className="inline-flex items-center gap-1 text-xs font-semibold text-primary hover:underline"
                    >
                      <span>Agency Terms of Use</span>
                      <ExternalLink className="size-3" />
                    </a>
                  </div>
                )}

                {exporterBase ? (
                  <div className="pt-3 border-t border-border/60 flex flex-wrap gap-3">
                    <a
                      href={`${exporterBase}/${a.slug}/gtfs.zip`}
                      className="inline-flex items-center gap-1.5 rounded-xl border border-border/80 bg-card px-3.5 py-2 text-xs font-semibold text-foreground hover:bg-muted transition-colors shadow-2xs"
                    >
                      <Download className="size-3.5 text-primary" />
                      <span>Download GTFS.zip</span>
                    </a>

                    <a
                      href={`${exporterBase}/${a.slug}/gtfs-rt/service-alerts`}
                      className="inline-flex items-center gap-1.5 rounded-xl border border-border/80 bg-card px-3.5 py-2 text-xs font-semibold text-foreground hover:bg-muted transition-colors shadow-2xs"
                    >
                      <Radio className="size-3.5 text-rose-500" />
                      <span>GTFS-RT Service Alerts Feed</span>
                    </a>
                  </div>
                ) : (
                  <p className="text-xs text-muted-foreground pt-2 italic">
                    Feed downloads unavailable — exporter service not configured.
                  </p>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </main>
  );
}
