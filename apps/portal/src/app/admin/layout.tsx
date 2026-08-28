import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ADMIN_ROLES, hasAnyRole, rolesFromAppMetadata } from "@/lib/rbac";
import { AdminSidebar } from "@/components/admin-sidebar";
import { AdminHeader } from "@/components/admin-header";
import SignOutButton from "./sign-out-button";
import { ShieldAlert } from "lucide-react";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";

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
      <main className="flex min-h-screen items-center justify-center p-4 bg-muted/30">
        <Card className="max-w-md w-full border-destructive/30 shadow-lg">
          <CardHeader className="text-center pb-2">
            <div className="mx-auto flex size-12 items-center justify-center rounded-full bg-destructive/10 text-destructive mb-2">
              <ShieldAlert className="size-6" />
            </div>
            <CardTitle className="text-xl text-destructive">Access Restricted</CardTitle>
            <CardDescription className="text-sm">
              Your account doesn&apos;t hold an operator role.
            </CardDescription>
          </CardHeader>
          <CardContent className="text-center text-sm text-muted-foreground">
            <p>
              Signed in as <span className="font-semibold text-foreground">{user.email}</span>.
            </p>
            <p className="mt-2 text-xs">
              Required roles: <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-foreground">fleet_manager</code>,{" "}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-foreground">dispatcher</code>, or{" "}
              <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-foreground">agency_admin</code>.
            </p>
            <p className="mt-2 text-xs">
              Please contact your agency administrator to grant operator permissions, then sign in again.
            </p>
          </CardContent>
          <CardFooter className="flex justify-center pt-2">
            <SignOutButton variant="destructive" />
          </CardFooter>
        </Card>
      </main>
    );
  }

  const userInfo = {
    email: user.email,
    roles,
  };

  return (
    <div className="min-h-screen bg-background flex flex-col md:flex-row">
      {/* Desktop fixed sidebar */}
      <AdminSidebar user={userInfo} />

      {/* Main content area */}
      <div className="flex-1 flex flex-col md:pl-64 min-w-0">
        <AdminHeader user={userInfo} />
        <main className="flex-1 px-4 sm:px-6 lg:px-8 py-6 max-w-7xl w-full mx-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
