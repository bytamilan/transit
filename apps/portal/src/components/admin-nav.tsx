"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Radio,
  CalendarDays,
  AlertOctagon,
  Bus,
  Users,
  Route as RouteIcon,
  Megaphone,
  KeyRound,
  Database,
  ExternalLink,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";

export interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  badge?: string;
  badgeVariant?: "default" | "secondary" | "destructive" | "outline";
  exact?: boolean;
}

export interface NavSection {
  title: string;
  items: NavItem[];
}

export const NAV_SECTIONS: NavSection[] = [
  {
    title: "Operations",
    items: [
      { href: "/admin", label: "Overview", icon: LayoutDashboard, exact: true },
      {
        href: "/admin/dispatch",
        label: "Live Dispatch",
        icon: Radio,
        badge: "Live",
        badgeVariant: "default",
      },
      { href: "/admin/roster", label: "Duty Roster", icon: CalendarDays },
      { href: "/admin/incidents", label: "Incidents", icon: AlertOctagon },
    ],
  },
  {
    title: "Fleet & Network",
    items: [
      { href: "/admin/vehicles", label: "Vehicles", icon: Bus },
      { href: "/admin/drivers", label: "Drivers", icon: Users },
      { href: "/admin/routes", label: "Routes & Timetables", icon: RouteIcon },
    ],
  },
  {
    title: "Communications & Security",
    items: [
      { href: "/admin/alerts", label: "Service Alerts", icon: Megaphone },
      { href: "/admin/api-keys", label: "API Keys", icon: KeyRound },
    ],
  },
];

interface AdminNavProps {
  onItemClick?: () => void;
  className?: string;
}

export function AdminNav({ onItemClick, className }: AdminNavProps) {
  const pathname = usePathname();

  function isItemActive(item: NavItem) {
    if (item.exact) {
      return pathname === item.href;
    }
    return pathname === item.href || pathname.startsWith(`${item.href}/`);
  }

  return (
    <nav className={cn("space-y-6", className)}>
      {NAV_SECTIONS.map((section) => (
        <div key={section.title} className="space-y-1">
          <div className="px-3 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground/80">
            {section.title}
          </div>
          <div className="space-y-0.5 pt-1">
            {section.items.map((item) => {
              const active = isItemActive(item);
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={onItemClick}
                  className={cn(
                    "group relative flex items-center justify-between gap-3 rounded-xl px-3 py-2 text-sm font-medium transition-all duration-150",
                    active
                      ? "bg-primary/10 text-primary font-semibold shadow-xs"
                      : "text-muted-foreground hover:bg-muted hover:text-foreground"
                  )}
                >
                  <div className="flex items-center gap-3">
                    <Icon
                      className={cn(
                        "size-4 shrink-0 transition-transform duration-150 group-hover:scale-105",
                        active ? "text-primary" : "text-muted-foreground group-hover:text-foreground"
                      )}
                    />
                    <span>{item.label}</span>
                  </div>

                  {item.badge && (
                    <span
                      className={cn(
                        "inline-flex items-center rounded-full px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide",
                        active
                          ? "bg-primary text-primary-foreground"
                          : "bg-primary/15 text-primary"
                      )}
                    >
                      {item.badge}
                    </span>
                  )}
                </Link>
              );
            })}
          </div>
        </div>
      ))}

      <div className="pt-2">
        <div className="px-3 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground/80">
          Public Resources
        </div>
        <div className="pt-1">
          <Link
            href="/datasets"
            target="_blank"
            rel="noreferrer"
            className="group flex items-center justify-between rounded-xl px-3 py-2 text-sm font-medium text-muted-foreground transition-all hover:bg-muted hover:text-foreground"
          >
            <div className="flex items-center gap-3">
              <Database className="size-4 shrink-0 text-muted-foreground group-hover:text-foreground" />
              <span>Public Datasets</span>
            </div>
            <ExternalLink className="size-3.5 text-muted-foreground/60 group-hover:text-foreground" />
          </Link>
        </div>
      </div>
    </nav>
  );
}
