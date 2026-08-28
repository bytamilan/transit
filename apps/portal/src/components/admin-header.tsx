"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, Bus, Radio, Bell } from "lucide-react";
import { AdminNav } from "./admin-nav";
import SignOutButton from "@/app/admin/sign-out-button";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface AdminHeaderProps {
  user: {
    email?: string;
    roles: string[];
  };
}

const PAGE_TITLES: Record<string, { title: string; category?: string }> = {
  "/admin": { title: "Overview", category: "Operations" },
  "/admin/dispatch": { title: "Live Dispatch", category: "Operations" },
  "/admin/roster": { title: "Duty Roster", category: "Operations" },
  "/admin/incidents": { title: "Incidents", category: "Operations" },
  "/admin/vehicles": { title: "Vehicles", category: "Fleet & Network" },
  "/admin/drivers": { title: "Drivers", category: "Fleet & Network" },
  "/admin/routes": { title: "Routes & Timetables", category: "Fleet & Network" },
  "/admin/alerts": { title: "Service Alerts", category: "Communications" },
  "/admin/api-keys": { title: "API Keys", category: "Communications" },
};

export function AdminHeader({ user }: AdminHeaderProps) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  // Derive title from pathname
  let current = PAGE_TITLES[pathname];
  if (!current) {
    if (pathname.startsWith("/admin/routes/")) {
      const routeId = pathname.replace("/admin/routes/", "");
      current = { title: `Route ${decodeURIComponent(routeId)}`, category: "Routes & Timetables" };
    } else {
      current = { title: "Admin Console" };
    }
  }

  const initials = user.email ? user.email.slice(0, 2).toUpperCase() : "AD";

  return (
    <header className="sticky top-0 z-20 flex h-16 w-full items-center justify-between border-b border-border/70 bg-background/80 px-4 sm:px-6 backdrop-blur-md">
      {/* Left side: Mobile menu toggle + breadcrumb title */}
      <div className="flex items-center gap-3">
        {/* Mobile menu sheet trigger */}
        <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
          <SheetTrigger
            render={
              <Button
                variant="ghost"
                size="icon-sm"
                className="md:hidden text-muted-foreground hover:text-foreground"
                aria-label="Open mobile navigation menu"
              />
            }
          >
            <Menu className="size-5" />
          </SheetTrigger>

          <SheetContent side="left" className="w-[280px] p-0 flex flex-col justify-between">
            <div>
              <SheetHeader className="border-b border-border/60 p-4">
                <SheetTitle className="flex items-center gap-2.5">
                  <div className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
                    <Bus className="size-4" />
                  </div>
                  <span className="font-bold text-base tracking-tight text-foreground">Transit Admin</span>
                </SheetTitle>
              </SheetHeader>
              <div className="p-4 overflow-y-auto max-h-[calc(100vh-140px)]">
                <AdminNav onItemClick={() => setMobileOpen(false)} />
              </div>
            </div>

            <div className="border-t border-border/60 p-4 bg-muted/20">
              <div className="flex items-center gap-2 mb-3">
                <Avatar className="size-8">
                  <AvatarFallback className="text-xs bg-primary/15 text-primary">{initials}</AvatarFallback>
                </Avatar>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-xs font-medium text-foreground">{user.email}</p>
                  <p className="truncate text-[10px] text-muted-foreground">{user.roles.join(", ")}</p>
                </div>
              </div>
              <SignOutButton
                variant="outline"
                size="sm"
                className="w-full justify-center text-xs"
              />
            </div>
          </SheetContent>
        </Sheet>

        {/* Mobile brand text */}
        <Link href="/admin" className="flex md:hidden items-center gap-2">
          <div className="flex size-7 items-center justify-center rounded-lg bg-primary text-primary-foreground">
            <Bus className="size-3.5" />
          </div>
          <span className="font-bold text-sm text-foreground">Transit</span>
        </Link>

        {/* Desktop Breadcrumbs / Title */}
        <div className="hidden md:flex items-center gap-2 text-sm">
          {current.category && (
            <>
              <span className="text-muted-foreground">{current.category}</span>
              <span className="text-muted-foreground/40 font-mono">/</span>
            </>
          )}
          <span className="font-semibold text-foreground">{current.title}</span>
        </div>
      </div>

      {/* Right side: Live System Status & Quick Actions */}
      <div className="flex items-center gap-3">
        {/* Live status badge */}
        <div className="flex items-center gap-1.5 rounded-full border border-emerald-500/20 bg-emerald-50/50 dark:bg-emerald-950/20 px-2.5 py-1 text-xs font-medium text-emerald-700 dark:text-emerald-400">
          <span className="relative flex size-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75"></span>
            <span className="relative inline-flex size-2 rounded-full bg-emerald-500"></span>
          </span>
          <span className="hidden sm:inline">Dispatch System Online</span>
          <span className="sm:hidden">Online</span>
        </div>

        {/* Quick link to alerts */}
        <Link
          href="/admin/alerts"
          className="relative inline-flex size-8 items-center justify-center rounded-lg text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          title="Service Alerts"
        >
          <Bell className="size-4" />
        </Link>

        {/* User avatar on header */}
        <div className="hidden sm:flex items-center gap-2 pl-2 border-l border-border/60">
          <Avatar className="size-8 ring-1 ring-border">
            <AvatarFallback className="bg-primary/10 text-xs font-semibold text-primary">
              {initials}
            </AvatarFallback>
          </Avatar>
        </div>
      </div>
    </header>
  );
}
