import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ADMIN_ROLES, hasAnyRole, rolesFromAppMetadata } from "@/lib/rbac";
import SignOutButton from "./sign-out-button";

const NAV = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/vehicles", label: "Vehicles" },
  { href: "/admin/drivers", label: "Drivers" },
  { href: "/admin/routes", label: "Routes & timetables" },
  { href: "/admin/roster", label: "Duty roster" },
  { href: "/admin/dispatch", label: "Live dispatch" },
  { href: "/admin/incidents", label: "Incidents" },
  { href: "/admin/alerts", label: "Service alerts" },
];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const roles = rolesFromAppMetadata(user.app_metadata);
  if (!hasAnyRole(roles, ADMIN_ROLES)) {
    return (
      <main className="flex min-h-screen items-center justify-center p-8">
        <div className="max-w-md rounded-lg border border-red-200 bg-red-50 p-6 text-center">
          <h1 className="text-lg font-semibold text-red-800">Access restricted</h1>
          <p className="mt-2 text-sm text-red-700">
            Your account ({user.email}) doesn&apos;t hold a fleet_manager, dispatcher or agency_admin
            role. Ask an agency admin to grant one, then sign in again.
          </p>
          <div className="mt-4">
            <SignOutButton />
          </div>
        </div>
      </main>
    );
  }

  return (
    <div className="flex min-h-screen">
      <aside className="w-56 shrink-0 border-r border-slate-200 bg-white p-4">
        <div className="mb-6 text-lg font-semibold text-brand">Transit Admin</div>
        <nav className="space-y-1">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="block rounded px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="mt-8 border-t border-slate-200 pt-4 text-xs text-slate-500">
          <div className="truncate">{user.email}</div>
          <div className="mt-1">{roles.join(", ")}</div>
          <div className="mt-3">
            <SignOutButton />
          </div>
        </div>
      </aside>
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}
