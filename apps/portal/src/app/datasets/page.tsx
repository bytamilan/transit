import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Datasets — Transit",
  description: "Open GTFS and GTFS-RT feeds published by agencies on this deployment.",
};

// Public, unauthenticated page — /v0/agencies is an unauthenticated API
// route, same trust boundary as the rest of /v0 (Phase 10).
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
    <main className="mx-auto max-w-3xl px-6 py-12">
      <h1 className="text-2xl font-semibold text-slate-900">Open datasets</h1>
      <p className="mt-2 text-sm text-slate-600">
        Standards-compliant GTFS and GTFS-RT feeds published by each agency on this deployment.
        Static schedules are rebuilt on a schedule; realtime feeds update continuously.
      </p>

      {error && (
        <p className="mt-6 rounded border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {error}
        </p>
      )}

      {!error && agencies.length === 0 && (
        <p className="mt-6 text-sm text-slate-500">No agencies are published yet.</p>
      )}

      <ul className="mt-8 space-y-6">
        {agencies.map((a) => (
          <li key={a.slug} className="rounded-lg border border-slate-200 bg-white p-5">
            <div className="flex items-baseline justify-between gap-4">
              <h2 className="text-lg font-medium text-slate-900">{a.name}</h2>
              <span className="text-xs text-slate-400">{a.timezone}</span>
            </div>

            {a.modes.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {a.modes.map((m) => (
                  <span
                    key={m}
                    className="rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-600"
                  >
                    {m}
                  </span>
                ))}
              </div>
            )}

            <dl className="mt-3 text-sm text-slate-600">
              <div className="flex gap-1">
                <dt className="font-medium text-slate-700">Licence:</dt>
                <dd>{a.license_spdx || "not specified"}</dd>
              </div>
              <div className="mt-1 flex gap-1">
                <dt className="font-medium text-slate-700">Attribution:</dt>
                <dd>{a.attribution || "not specified"}</dd>
              </div>
              {a.terms_url && (
                <div className="mt-1">
                  <a
                    href={a.terms_url}
                    className="text-brand underline"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Terms of use
                  </a>
                </div>
              )}
            </dl>

            {exporterBase ? (
              <div className="mt-4 flex flex-wrap gap-3 text-sm">
                <a
                  className="rounded border border-slate-300 px-3 py-1.5 font-medium text-slate-700 hover:bg-slate-50"
                  href={`${exporterBase}/${a.slug}/gtfs.zip`}
                >
                  Download GTFS.zip
                </a>
                <a
                  className="rounded border border-slate-300 px-3 py-1.5 font-medium text-slate-700 hover:bg-slate-50"
                  href={`${exporterBase}/${a.slug}/gtfs-rt/service-alerts`}
                >
                  GTFS-RT service alerts
                </a>
              </div>
            ) : (
              <p className="mt-4 text-xs text-slate-400">
                Feed downloads are unavailable — the exporter service isn&apos;t configured.
              </p>
            )}
          </li>
        ))}
      </ul>
    </main>
  );
}
