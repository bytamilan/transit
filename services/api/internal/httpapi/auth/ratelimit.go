package auth

import (
	"sync"
	"time"
)

// TokenBucket is a per-key rate limiter with a configurable default,
// overridable per call — the mechanism api_keys.rate_limit_rpm plugs into
// (Phase 12: previously loaded but never actually consulted here, every
// key shared one global rate regardless of its own configured limit).
type TokenBucket struct {
	mu          sync.Mutex
	state       map[string]*bucket
	defaultRate float64 // tokens added per second
	defaultCap  float64 // maximum bucket capacity
}

// NewTokenBucket returns a rate limiter whose default allows rate tokens
// per second, with a burst of cap tokens — used for callers with no
// per-key override (rpm <= 0 in Allow).
func NewTokenBucket(rate, cap float64) *TokenBucket {
	return &TokenBucket{
		state:       make(map[string]*bucket),
		defaultRate: rate,
		defaultCap:  cap,
	}
}

// Allow consumes one token for key. rpm, when > 0, overrides the limiter's
// default with a per-key requests-per-minute budget — converted to a
// tokens/second refill rate, with burst capacity equal to a full minute's
// allowance. A key's rate/cap must stay consistent across calls (changing
// rpm for an existing key's bucket takes effect on refill, not
// retroactively — acceptable for a limit that rarely changes).
func (tb *TokenBucket) Allow(key string, rpm int) bool {
	rate, cap := tb.defaultRate, tb.defaultCap
	if rpm > 0 {
		rate = float64(rpm) / 60.0
		cap = float64(rpm)
	}

	tb.mu.Lock()
	defer tb.mu.Unlock()

	b, ok := tb.state[key]
	if !ok {
		b = &bucket{tokens: cap, last: time.Now()}
		tb.state[key] = b
	}

	now := time.Now()
	elapsed := now.Sub(b.last).Seconds()
	b.tokens = min(cap, b.tokens+elapsed*rate)
	b.last = now

	if b.tokens >= 1 {
		b.tokens--
		return true
	}
	return false
}

type bucket struct {
	tokens float64
	last   time.Time
}

func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}
