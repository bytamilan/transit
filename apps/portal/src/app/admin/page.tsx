import Link from "next/link";
import {
  Radio,
  CalendarDays,
  AlertOctagon,
  Bus,
  Users,
  Route as RouteIcon,
  Megaphone,
  KeyRound,
  Database,
  ArrowRight,
  ShieldCheck,
  Activity,
  CheckCircle2,
  Clock,
} from "lucide-react";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function AdminOverviewPage() {
  const todayFormatted = new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date());

  const MODULES = [
    {
      title: "Live Dispatch",
      description: "Real-time telemetry, off-route detection, driver communication and dynamic reassignments.",
      href: "/admin/dispatch",
      icon: Radio,
      badge: "Realtime",
      badgeColor: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30",
      accent: "from-emerald-500/10 to-transparent",
    },
    {
      title: "Duty Roster",
      description: "Assign drivers and vehicles to daily service blocks. Automatically detects overlaps and license conflicts.",
      href: "/admin/roster",
      icon: CalendarDays,
      badge: "Daily Scheduling",
      badgeColor: "bg-blue-500/15 text-blue-700 dark:text-blue-400 border-blue-500/30",
      accent: "from-blue-500/10 to-transparent",
    },
    {
      title: "Incidents & Reports",
      description: "Triage one-tap driver safety and breakdown reports. Resolve and log active disruptions.",
      href: "/admin/incidents",
      icon: AlertOctagon,
      badge: "Safety",
      badgeColor: "bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30",
      accent: "from-amber-500/10 to-transparent",
    },
    {
      title: "Vehicles & Fleet",
      description: "Manage registrations, depot assignments, capacity classes, propulsion, and maintenance holds.",
      href: "/admin/vehicles",
      icon: Bus,
      badge: "Fleet",
      badgeColor: "bg-indigo-500/15 text-indigo-700 dark:text-indigo-400 border-indigo-500/30",
      accent: "from-indigo-500/10 to-transparent",
    },
    {
      title: "Driver Workforce",
      description: "Driver onboardings, depot affiliations, and automated 30-day license expiry tracking.",
      href: "/admin/drivers",
      icon: Users,
      badge: "Compliance",
      badgeColor: "bg-purple-500/15 text-purple-700 dark:text-purple-400 border-purple-500/30",
      accent: "from-purple-500/10 to-transparent",
    },
    {
      title: "Routes & Timetables",
      description: "Configure GTFS routes, service calendars, trip sequences, and canonical timetable data.",
      href: "/admin/routes",
      icon: RouteIcon,
      badge: "GTFS Spec",
      badgeColor: "bg-cyan-500/15 text-cyan-700 dark:text-cyan-400 border-cyan-500/30",
      accent: "from-cyan-500/10 to-transparent",
    },
    {
      title: "Service Alerts",
      description: "Broadcast multi-lingual service advisories directly to rider applications and GTFS-RT feeds.",
      href: "/admin/alerts",
      icon: Megaphone,
      badge: "Rider Broadcast",
      badgeColor: "bg-rose-500/15 text-rose-700 dark:text-rose-400 border-rose-500/30",
      accent: "from-rose-500/10 to-transparent",
    },
    {
      title: "API Keys & Integrations",
      description: "Provision scoped API tokens with server-enforced rate limits and daily request quotas.",
      href: "/admin/api-keys",
      icon: KeyRound,
      badge: "Security",
      badgeColor: "bg-slate-500/15 text-slate-700 dark:text-slate-400 border-slate-500/30",
      accent: "from-slate-500/10 to-transparent",
    },
  ];

  return (
    <div className="space-y-8">
      {/* Hero Welcome Header */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-foreground">
            Operations Overview
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Manage agency fleet, driver duty rosters, live telemetry, and GTFS transit feeds.
          </p>
        </div>
        <div className="flex items-center gap-2 text-xs font-medium text-muted-foreground bg-muted/50 rounded-xl px-3 py-1.5 border border-border/60 self-start sm:self-auto">
          <Clock className="size-3.5 text-primary" />
          <span>{todayFormatted}</span>
        </div>
      </div>

      {/* Quick Status Highlights */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="p-4 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">System Engine</span>
            <span className="flex size-2 rounded-full bg-emerald-500"></span>
          </div>
          <div className="mt-2 text-lg font-bold tracking-tight">Active & Healthy</div>
          <div className="mt-1 text-xs text-muted-foreground flex items-center gap-1">
            <CheckCircle2 className="size-3 text-emerald-500" />
            GTFS-RT Feeds streaming
          </div>
        </Card>

        <Card className="p-4 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">Live Dispatch</span>
            <Activity className="size-4 text-primary" />
          </div>
          <div className="mt-2 text-lg font-bold tracking-tight">Telemetry Auto-Sync</div>
          <div className="mt-1 text-xs text-muted-foreground">
            Pings polled every 10s
          </div>
        </Card>

        <Card className="p-4 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">Compliance Guard</span>
            <ShieldCheck className="size-4 text-primary" />
          </div>
          <div className="mt-2 text-lg font-bold tracking-tight">Licence Verification</div>
          <div className="mt-1 text-xs text-muted-foreground">
            30-day auto-warning rule
          </div>
        </Card>

        <Card className="p-4 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">Audit & Governance</span>
            <Database className="size-4 text-primary" />
          </div>
          <div className="mt-2 text-lg font-bold tracking-tight">Append-Only Logs</div>
          <div className="mt-1 text-xs text-muted-foreground">
            Every administrative mutation recorded
          </div>
        </Card>
      </div>

      {/* Main Operations Grid */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold tracking-tight text-foreground">
            Management Modules
          </h2>
          <span className="text-xs text-muted-foreground">8 Modules Available</span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {MODULES.map((m) => {
            const Icon = m.icon;
            return (
              <Link
                key={m.href}
                href={m.href}
                className="group relative flex flex-col justify-between rounded-2xl border border-border/80 bg-card p-5 shadow-xs transition-all duration-200 hover:-translate-y-0.5 hover:shadow-md hover:border-primary/40"
              >
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex size-10 items-center justify-center rounded-xl bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                      <Icon className="size-5" />
                    </div>
                    <Badge variant="outline" className={`text-[10px] px-2 py-0.5 ${m.badgeColor}`}>
                      {m.badge}
                    </Badge>
                  </div>

                  <h3 className="text-base font-semibold text-foreground group-hover:text-primary transition-colors">
                    {m.title}
                  </h3>
                  <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground line-clamp-2">
                    {m.description}
                  </p>
                </div>

                <div className="mt-4 flex items-center gap-1 text-xs font-semibold text-primary">
                  <span>Open console</span>
                  <ArrowRight className="size-3.5 transition-transform duration-200 group-hover:translate-x-1" />
                </div>
              </Link>
            );
          })}
        </div>
      </div>
    </div>
  );
}
