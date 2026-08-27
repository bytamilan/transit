import { createClient } from "@/lib/supabase/client";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL!;

export class ApiError extends Error {
  status: number;
  body: unknown;
  constructor(status: number, body: unknown) {
    super(typeof body === "object" && body && "error" in body ? String((body as any).error) : `request failed with ${status}`);
    this.status = status;
    this.body = body;
  }
}

// apiFetch calls the Go admin API with the signed-in user's Supabase access
// token as a bearer credential — the portal never talks to Postgres
// directly. Every admin mutation is re-authorised server-side regardless of
// what this client sends.
export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const supabase = createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  const headers = new Headers(init?.headers);
  headers.set("Content-Type", headers.get("Content-Type") ?? "application/json");
  if (session?.access_token) {
    headers.set("Authorization", `Bearer ${session.access_token}`);
  }

  const res = await fetch(`${API_BASE_URL}${path}`, { ...init, headers });
  const isJSON = res.headers.get("Content-Type")?.includes("application/json");
  const body = isJSON ? await res.json().catch(() => undefined) : undefined;

  if (!res.ok) {
    throw new ApiError(res.status, body);
  }
  return body as T;
}

// apiUpload posts a raw body (e.g. CSV text) with an explicit content type,
// bypassing the JSON default in apiFetch.
export async function apiUpload<T>(path: string, body: string, contentType: string): Promise<T> {
  return apiFetch<T>(path, { method: "POST", body, headers: { "Content-Type": contentType } });
}
