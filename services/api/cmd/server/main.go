// Command server is the Transit REST API entrypoint.
// Phase 2: liveness/readiness stay public; /admin/* routes sit behind JWT/API-key
// auth and table-driven RBAC — see docs/PHASE_PLAN.md Phase 2.
package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/handlers"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	addr := envOr("API_ADDR", ":8080")

	pool, err := openDB(envOr("DATABASE_URL", ""))
	if err != nil {
		slog.Error("failed to open database", "err", err)
		os.Exit(1)
	}

	authMW, err := auth.NewMiddleware(buildAuthConfig(), pool)
	if err != nil {
		slog.Error("failed to build auth middleware", "err", err)
		os.Exit(1)
	}

	admin := &handlers.Admin{Audit: audit.New(pool)}

	mux := http.NewServeMux()

	// Public probes (Phase 0).
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
	})

	// Authenticated admin surface (Phase 2).
	mux.Handle("GET /admin/health", authMW.Handler(http.HandlerFunc(admin.Health)))
	mux.Handle("GET /admin/audit/export", authMW.Handler(http.HandlerFunc(admin.ExportAudit)))

	slog.Info("transit api listening", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		slog.Error("server exited", "err", err)
		os.Exit(1)
	}
}

func openDB(dsn string) (*pgxpool.Pool, error) {
	if dsn == "" {
		slog.Warn("DATABASE_URL not set; API-key and audit features are disabled")
		return nil, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}

func buildAuthConfig() auth.Config {
	secret := os.Getenv("JWT_SECRET")
	if secret != "" {
		return auth.Config{
			Mode:     "hmac",
			HMAC:     []byte(secret),
			Issuer:   envOr("GOTRUE_JWT_ISSUER", envOr("API_EXTERNAL_URL", "http://localhost:8000/auth")),
			Audience: envOr("GOTRUE_JWT_AUD", "authenticated"),
		}
	}
	if jwks := os.Getenv("SUPABASE_JWT_JWKS_URL"); jwks != "" {
		return auth.Config{
			Mode:     "jwks",
			JWKSURL:  jwks,
			Issuer:   envOr("GOTRUE_JWT_ISSUER", envOr("API_EXTERNAL_URL", "http://localhost:8000/auth")),
			Audience: envOr("GOTRUE_JWT_AUD", "authenticated"),
		}
	}
	// Unsafe: only useful for local unit tests of the handler layer.
	slog.Warn("JWT_SECRET and SUPABASE_JWT_JWKS_URL both unset; auth middleware will parse but not verify tokens")
	return auth.Config{Mode: "disabled"}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
