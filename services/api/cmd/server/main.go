// Command server is the Transit REST API entrypoint.
// Phase 0: liveness/readiness only — see docs/BUILD_PROMPT.md §11.
package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
)

func main() {
	addr := envOr("API_ADDR", ":8080")

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
	})

	slog.Info("transit api listening", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		slog.Error("server exited", "err", err)
		os.Exit(1)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
