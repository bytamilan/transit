"use client";

import Link from "next/link";
import { Bus, ShieldCheck } from "lucide-react";
import { AdminNav } from "./admin-nav";
import SignOutButton from "@/app/admin/sign-out-button";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface AdminSidebarProps {
  user: {
    email?: string;
    roles: string[];
  };
}

export function AdminSidebar({ user }: AdminSidebarProps) {
  const initials = user.email
    ? user.email.slice(0, 2).toUpperCase()
    : "AD";

  return (
    <aside className="hidden md:flex md:w-64 md:flex-col md:fixed md:inset-y-0 z-30 border-r border-border/70 bg-card/95 backdrop-blur-md">
      {/* Brand Header */}
      <div className="flex h-16 items-center gap-3 border-b border-border/60 px-5">
        <Link href="/admin" className="flex items-center gap-2.5 font-bold tracking-tight text-foreground transition-opacity hover:opacity-90">
          <div className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm shadow-primary/25">
            <Bus className="size-5" />
          </div>
          <div className="flex flex-col">
            <span className="text-base font-bold leading-tight tracking-tight text-foreground">
              Transit
            </span>
            <span className="text-[10px] font-medium tracking-widest text-muted-foreground uppercase">
              Admin Console
            </span>
          </div>
        </Link>
      </div>

      {/* Navigation list */}
      <div className="flex-1 overflow-y-auto px-4 py-5 scrollbar-thin">
        <AdminNav />
      </div>

      {/* User footer card */}
      <div className="border-t border-border/60 p-4 bg-muted/20">
        <div className="flex items-center gap-3">
          <Avatar className="size-9 ring-1 ring-border shadow-2xs">
            <AvatarFallback className="bg-primary/15 font-semibold text-xs text-primary">
              {initials}
            </AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <p className="truncate text-xs font-semibold text-foreground">
              {user.email || "Operator"}
            </p>
            <div className="mt-0.5 flex flex-wrap gap-1">
              {user.roles.slice(0, 2).map((role) => (
                <Badge
                  key={role}
                  variant="outline"
                  className="px-1.5 py-0 text-[9px] font-medium tracking-tight text-muted-foreground border-border/80"
                >
                  <ShieldCheck className="size-2.5 mr-0.5 text-primary" />
                  {role.replace(/_/g, " ")}
                </Badge>
              ))}
              {user.roles.length > 2 && (
                <Badge
                  variant="outline"
                  className="px-1 py-0 text-[9px] text-muted-foreground"
                >
                  +{user.roles.length - 2}
                </Badge>
              )}
            </div>
          </div>
        </div>

        <div className="mt-3">
          <SignOutButton
            variant="outline"
            size="sm"
            className="w-full justify-center text-xs h-8 text-muted-foreground hover:text-destructive hover:border-destructive/30 hover:bg-destructive/10 transition-colors"
          />
        </div>
      </div>
    </aside>
  );
}
