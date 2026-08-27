package auth

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/bytamilan/transit/services/api/internal/store/apikeys"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

// Config selects how the middleware verifies bearer tokens.
type Config struct {
	Mode     string // "hmac", "jwks", or "disabled" (only for local unit tests)
	HMAC     []byte // symmetric secret used when Mode == "hmac"
	JWKSURL  string // endpoint to fetch a JWKS from when Mode == "jwks"
	Issuer   string // JWT iss claim
	Audience string // JWT aud claim
}

// MiddlewareOption configures optional middleware behaviour.
type MiddlewareOption func(*Middleware)

// WithAPIKeyStore sets the API key store used for key authentication.
func WithAPIKeyStore(s *apikeys.Store) MiddlewareOption {
	return func(m *Middleware) { m.keys = s }
}

// WithRateLimiter sets the token-bucket rate limiter used for API keys.
func WithRateLimiter(tb *TokenBucket) MiddlewareOption {
	return func(m *Middleware) { m.limiter = tb }
}

// WithUsageRecorder overrides how usage events are recorded.
func WithUsageRecorder(fn func(ctx context.Context, keyID uuid.UUID, endpoint string, status, latencyMs int) error) MiddlewareOption {
	return func(m *Middleware) { m.recordUsage = fn }
}

// apiKeyLookup is the subset of *apikeys.Store the middleware needs —
// narrowed to an interface so apiKeyActor's rate-limit/quota logic can be
// unit-tested with a fake, without a live database.
type apiKeyLookup interface {
	Lookup(ctx context.Context, hash string) (*apikeys.Key, error)
	CountUsageSince(ctx context.Context, keyID uuid.UUID, since time.Time) (int, error)
}

// Middleware authenticates requests and stores an Actor in the request context.
type Middleware struct {
	cfg         Config
	db          *pgxpool.Pool
	set         jwk.Set
	keys        apiKeyLookup
	limiter     *TokenBucket
	recordUsage func(ctx context.Context, keyID uuid.UUID, endpoint string, status, latencyMs int) error
}

// NewMiddleware builds an authentication middleware. db may be nil when API-key
// authentication is not required.
func NewMiddleware(cfg Config, db *pgxpool.Pool, opts ...MiddlewareOption) (*Middleware, error) {
	m := &Middleware{cfg: cfg, db: db}
	for _, o := range opts {
		o(m)
	}
	if db != nil && m.keys == nil {
		m.keys = apikeys.New(db)
	}
	if db != nil && m.recordUsage == nil {
		m.recordUsage = apikeys.New(db).RecordUsage
	}
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

// Handler wraps next with authentication. API-key requests also get their
// usage recorded (Phase 12: usage_events existed since Phase 4 but nothing
// ever wrote to it from the request path — RecordUsage was configured on
// every Middleware but never called). Recording happens in a background
// goroutine after the response is written, so a slow usage-event insert
// never adds latency to the caller's request.
func (m *Middleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		actor := m.authenticate(ctx, r)

		if !actor.IsAPIKey || m.recordUsage == nil {
			next.ServeHTTP(w, r.WithContext(WithActor(ctx, actor)))
			return
		}

		started := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r.WithContext(WithActor(ctx, actor)))

		keyID, endpoint, status := actor.UserID, r.URL.Path, sw.status
		latencyMs := int(time.Since(started).Milliseconds())
		go func() {
			if err := m.recordUsage(context.Background(), keyID, endpoint, status, latencyMs); err != nil {
				slog.Error("auth: failed to record usage event", "key_id", keyID, "err", err)
			}
		}()
	})
}

// statusWriter captures the status code written by the handler, since
// http.ResponseWriter doesn't expose it after the fact.
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(status int) {
	w.status = status
	w.ResponseWriter.WriteHeader(status)
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
	if m.keys == nil {
		return Actor{}, false
	}
	if key == "" {
		return Actor{}, false
	}

	hash := apikeys.HashKey(key)
	k, err := m.keys.Lookup(ctx, hash)
	if err != nil {
		slog.Debug("auth: api key lookup failed", "err", err)
		return Actor{}, false
	}

	if m.limiter != nil {
		if !m.limiter.Allow(k.ID.String(), k.RateLimitRPM) {
			return Actor{}, false
		}
	}

	if k.QuotaDaily > 0 {
		used, err := m.keys.CountUsageSince(ctx, k.ID, apikeys.UsageWindowStart())
		if err != nil {
			// Fail closed on read errors would take down every API-key
			// caller on a transient DB hiccup for a feature whose whole
			// point is protecting against overuse, not availability — log
			// and let the request through instead.
			slog.Error("auth: failed to check daily quota, allowing request", "key_id", k.ID, "err", err)
		} else if used >= k.QuotaDaily {
			return Actor{}, false
		}
	}

	return Actor{
		UserID:   k.ID,
		AgencyID: k.AgencyID,
		Roles:    []string{"data_consumer"},
		IsAPIKey: true,
		Scopes:   k.Scopes,
	}, true
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
