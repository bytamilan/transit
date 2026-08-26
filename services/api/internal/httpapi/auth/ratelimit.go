package auth

import (
	"sync"
	"time"
)

// TokenBucket is a per-key rate limiter.
type TokenBucket struct {
	mu    sync.Mutex
	state map[string]*bucket
	rate  float64 // tokens added per second
	cap   float64 // maximum bucket capacity
}

// NewTokenBucket returns a rate limiter that allows rate tokens per second,
// with a burst of cap tokens.
func NewTokenBucket(rate, cap float64) *TokenBucket {
	return &TokenBucket{
		state: make(map[string]*bucket),
		rate:  rate,
		cap:   cap,
	}
}

// Allow consumes one token for key. It returns true when the request is allowed.
func (tb *TokenBucket) Allow(key string) bool {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	b, ok := tb.state[key]
	if !ok {
		b = &bucket{tokens: tb.cap, last: time.Now()}
		tb.state[key] = b
	}

	now := time.Now()
	elapsed := now.Sub(b.last).Seconds()
	b.tokens = min(tb.cap, b.tokens+elapsed*tb.rate)
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
