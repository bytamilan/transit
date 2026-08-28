"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { LogOut, Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";

interface SignOutButtonProps {
  variant?: "default" | "outline" | "ghost" | "destructive" | "secondary";
  size?: "default" | "sm" | "xs" | "icon" | "icon-sm";
  className?: string;
  showIcon?: boolean;
}

export default function SignOutButton({
  variant = "ghost",
  size = "sm",
  className,
  showIcon = true,
}: SignOutButtonProps) {
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleSignOut() {
    try {
      setLoading(true);
      const supabase = createClient();
      await supabase.auth.signOut();
      router.push("/login");
      router.refresh();
    } catch {
      setLoading(false);
    }
  }

  return (
    <Button
      variant={variant}
      size={size}
      onClick={handleSignOut}
      disabled={loading}
      className={className}
      title="Sign out of Transit Admin"
    >
      {loading ? (
        <Loader2 className="size-4 animate-spin text-muted-foreground" />
      ) : showIcon ? (
        <LogOut className="size-4" />
      ) : null}
      <span>{loading ? "Signing out..." : "Sign out"}</span>
    </Button>
  );
}
