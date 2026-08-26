package auth

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
	"golang.org/x/crypto/bcrypt"
)

// Config selects how the middleware verifies bearer tokens.
type Config struct {
	Mode     string // "hmac", "jwks", or "disabled" (only for local unit tests)
	HMAC     []byte // symmetric secret used when Mode == "hmac"
	JWKSURL  string // endpoint to fetch a JWKS from when Mode == "jwks"
	Issuer   string // JWT iss claim
	Audience string // JWT aud claim
}

// Middleware authenticates requests and stores an Actor in the request context.
type Middleware struct {
	cfg Config
	db  *pgxpool.Pool
	set jwk.Set
}

// NewMiddleware builds an authentication middleware. db may be nil when API-key
// authentication is not required.
func NewMiddleware(cfg Config, db *pgxpool.Pool) (*Middleware, error) {
	m := &Middleware{cfg: cfg, db: db}
	switch cfg.Mode {
	case "hmac":
		if len(cfg.HMAC) == 0 {
			return nil, fmt.Errorf("auth: HMAC mode requires a non-empty JWT secret")
		}
	case "jwks":
		if cfg.JWKSURL == "" {
			return nil, fmt.Errorf("auth: JWKS mode requires JWKSURL")
		}
		set, err := jwk.Fetch(context.Background(), cfg.JWKSURL)
		if err != nil {
			return nil, fmt.Errorf("auth: fetch JWKS: %w", err)
		}
		m.set = set
	case "disabled":
		// intentionally insecure; useful for unit tests that drive the middleware
		// with pre-signed tokens and no real verifier.
	default:
		return nil, fmt.Errorf("auth: unknown mode %q", cfg.Mode)
	}
	return m, nil
}

// Handler wraps next with authentication.
func (m *Middleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		actor := m.authenticate(ctx, r)
		next.ServeHTTP(w, r.WithContext(WithActor(ctx, actor)))
	})
}

func (m *Middleware) authenticate(ctx context.Context, r *http.Request) Actor {
	ip := parseIP(r)

	// API keys take precedence if present. They are intended for data-consumer
	// integrations, not interactive users.
	if key := strings.TrimSpace(r.Header.Get("X-API-Key")); key != "" {
		actor, ok := m.apiKeyActor(ctx, key)
		if ok {
			actor.IP = ip
			return actor
		}
		// An invalid key is treated as anonymous so the handler can decide
		// whether to 401. We preserve the IP for audit logging.
		return Actor{IP: ip}
	}

	// Bearer JWT issued by Supabase Auth (GoTrue).
	authHeader := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if strings.HasPrefix(authHeader, prefix) {
		token := strings.TrimSpace(strings.TrimPrefix(authHeader, prefix))
		actor, err := m.jwtActor(ctx, token)
		if err != nil {
			slog.Debug("auth: JWT verification failed", "err", err)
			return Actor{IP: ip}
		}
		actor.IP = ip
		return actor
	}

	return Actor{IP: ip}
}

func (m *Middleware) jwtActor(ctx context.Context, token string) (Actor, error) {
	var a Actor

	var parseOpts []jwt.ParseOption
	switch m.cfg.Mode {
	case "hmac":
		key, err := jwk.FromRaw(m.cfg.HMAC)
		if err != nil {
			return a, fmt.Errorf("build hmac key: %w", err)
		}
		parseOpts = append(parseOpts, jwt.WithKey(jwa.HS256, key))
	case "jwks":
		parseOpts = append(parseOpts, jwt.WithKeySet(m.set))
	case "disabled":
		// Parse without verification. NEVER use in production.
		parseOpts = append(parseOpts, jwt.WithVerify(false))
	}

	if m.cfg.Issuer != "" {
		parseOpts = append(parseOpts, jwt.WithIssuer(m.cfg.Issuer))
	}
	if m.cfg.Audience != "" {
		parseOpts = append(parseOpts, jwt.WithAudience(m.cfg.Audience))
	}

	tok, err := jwt.ParseString(token, parseOpts...)
	if err != nil {
		return a, fmt.Errorf("parse jwt: %w", err)
	}

	if sub := tok.Subject(); sub != "" {
		uid, err := uuid.Parse(sub)
		if err == nil {
			a.UserID = uid
		}
	}

	if v, ok := tok.Get("agency_id"); ok {
		if s, ok2 := v.(string); ok2 {
			if aid, err := uuid.Parse(s); err == nil {
				a.AgencyID = aid
			}
		}
	}

	if v, ok := tok.Get("roles"); ok {
		a.Roles = toStringSlice(v)
	}

	if v, ok := tok.Get("depot_id"); ok {
		if s, ok2 := v.(string); ok2 {
			if did, err := uuid.Parse(s); err == nil {
				a.DepotID = &did
			}
		}
	}

	// Anon tokens from GoTrue have role == "anon"; everything else is treated
	// as authenticated. We preserve "anon" in the role list so downstream
	// RBAC can reason about unauthenticated callers.
	if tok.Audience() != nil && len(tok.Audience()) == 0 {
		_ = tok.Audience()
	}
	if len(a.Roles) == 0 {
		a.Roles = []string{"anon"}
	}
	return a, nil
}

func (m *Middleware) apiKeyActor(ctx context.Context, key string) (Actor, bool) {
	if m.db == nil {
		return Actor{}, false
	}
	if key == "" {
		return Actor{}, false
	}

	// API keys are stored as bcrypt hashes. We look up all rows for the key's
	// prefix and compare hashes. This is intentionally simple for Phase 2;
	// Phase 4 will add a key ID prefix and token-bucket rate limiting.
	rows, err := m.db.Query(ctx, `
		SELECT id, agency_id, key_hash, scopes
		FROM api_keys
		WHERE key_hash <> ''
	`)
	if err != nil {
		slog.Debug("auth: api key lookup failed", "err", err)
		return Actor{}, false
	}
	defer rows.Close()

	for rows.Next() {
		var id uuid.UUID
		var agencyID uuid.UUID
		var hash string
		var scopes []string
		if err := rows.Scan(&id, &agencyID, &hash, &scopes); err != nil {
			continue
		}
		if bcrypt.CompareHashAndPassword([]byte(hash), []byte(key)) == nil {
			return Actor{
				UserID:   id,
				AgencyID: agencyID,
				Roles:    []string{"data_consumer"},
				IsAPIKey: true,
				Scopes:   scopes,
			}, true
		}
	}
	return Actor{}, false
}

func parseIP(r *http.Request) net.IP {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		if ip := net.ParseIP(strings.TrimSpace(parts[0])); ip != nil {
			return ip
		}
	}
	host, _, _ := net.SplitHostPort(r.RemoteAddr)
	if host == "" {
		host = r.RemoteAddr
	}
	return net.ParseIP(host)
}

func toStringSlice(v any) []string {
	switch xs := v.(type) {
	case []string:
		return xs
	case []any:
		out := make([]string, 0, len(xs))
		for _, e := range xs {
			if s, ok := e.(string); ok {
				out = append(out, s)
			}
		}
		return out
	case string:
		return []string{xs}
	}
	return nil
}
