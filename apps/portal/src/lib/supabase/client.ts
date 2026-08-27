import { createBrowserClient } from "@supabase/ssr";

// Browser-side Supabase client — used by client components (login form, the
// admin CRUD pages) to read the current session and its access token.
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
