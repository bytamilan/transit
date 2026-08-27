package auth

import (
	"testing"
	"time"
)

func TestTokenBucket_AllowsUpToCapacityThenBlocks(t *testing.T) {
	tb := NewTokenBucket(1, 3) // 1 token/sec, burst of 3
	key := "key-a"

	for i := 0; i < 3; i++ {
		if !tb.Allow(key, 0) {
			t.Fatalf("request %d: expected allow (within burst capacity)", i)
		}
	}
	if tb.Allow(key, 0) {
		t.Error("expected the 4th immediate request to be denied (bucket exhausted)")
	}
}

func TestTokenBucket_PerKeyOverrideIsIndependentOfDefault(t *testing.T) {
	// Default is very restrictive (1 token total); a key with its own
	// higher rpm should not be limited by the default.
	tb := NewTokenBucket(0, 1)

	generous := "generous-key"
	for i := 0; i < 10; i++ {
		if !tb.Allow(generous, 600) { // 600 rpm = 10/sec, burst 600
			t.Fatalf("request %d: expected a 600rpm key to allow 10 rapid requests", i)
		}
	}

	restricted := "default-key"
	if !tb.Allow(restricted, 0) {
		t.Fatal("expected the first request on the default bucket to be allowed")
	}
	if tb.Allow(restricted, 0) {
		t.Error("expected a second immediate request on a 1-capacity default bucket to be denied")
	}
}

func TestTokenBucket_DifferentKeysAreIndependent(t *testing.T) {
	tb := NewTokenBucket(1, 1)
	if !tb.Allow("a", 0) {
		t.Fatal("expected key a's first request to be allowed")
	}
	if !tb.Allow("b", 0) {
		t.Error("expected key b's first request to be allowed independently of key a's bucket")
	}
}

func TestTokenBucket_RefillsOverTime(t *testing.T) {
	tb := NewTokenBucket(0, 1)
	key := "refill-key"
	if !tb.Allow(key, 120) { // 120 rpm = 2/sec, burst 120
		t.Fatal("expected first request to be allowed")
	}
	// Manually age the bucket's last-refill time so the next Allow call
	// sees elapsed time without a real sleep.
	tb.mu.Lock()
	tb.state[key].last = time.Now().Add(-time.Second)
	tb.mu.Unlock()

	if !tb.Allow(key, 120) {
		t.Error("expected a request one second later to be allowed after refill")
	}
}
