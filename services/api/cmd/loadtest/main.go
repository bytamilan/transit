// Command loadtest is a minimal HTTP load generator for Phase 12's
// "load test: pings ingestion at target fleet scale, GTFS-RT fan-out,
// portal concurrency; publish results" task.
//
// It was never run against a live target in this sandbox — no Docker, no
// running services/api instance all session (see docs/PHASE_PLAN.md Phase
// 12). This is the tool an operator runs once a real deployment exists,
// not a set of published numbers.
//
// Usage:
//
//	loadtest -url http://localhost:8080/v0/agencies/demo-metro/stops \
//	         -concurrency 50 -duration 30s
//
//	# POST with a body and auth header, e.g. simulating driver ping ingestion:
//	loadtest -url http://localhost:8080/driver/pings -method POST \
//	         -body-file pings.json -header "Authorization: Bearer $JWT" \
//	         -concurrency 200 -duration 60s
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"time"
)

type headerFlag []string

func (h *headerFlag) String() string { return strings.Join(*h, ",") }
func (h *headerFlag) Set(v string) error {
	*h = append(*h, v)
	return nil
}

func main() {
	url := flag.String("url", "", "target URL (required)")
	method := flag.String("method", "GET", "HTTP method")
	bodyFile := flag.String("body-file", "", "path to a file to send as the request body")
	concurrency := flag.Int("concurrency", 10, "number of concurrent workers")
	duration := flag.Duration("duration", 30*time.Second, "how long to run")
	rps := flag.Int("rps", 0, "target requests/second across all workers (0 = unlimited, workers run flat out)")
	timeout := flag.Duration("timeout", 10*time.Second, "per-request timeout")
	outFile := flag.String("out", "", "write the JSON report here in addition to stdout (optional)")
	var headers headerFlag
	flag.Var(&headers, "header", "extra request header, \"Key: Value\" (repeatable)")
	flag.Parse()

	if *url == "" {
		fmt.Fprintln(os.Stderr, "loadtest: -url is required")
		os.Exit(1)
	}

	var body []byte
	if *bodyFile != "" {
		var err error
		body, err = os.ReadFile(*bodyFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "loadtest: read body file: %v\n", err)
			os.Exit(1)
		}
	}

	parsedHeaders := map[string]string{}
	for _, h := range headers {
		parts := strings.SplitN(h, ":", 2)
		if len(parts) != 2 {
			fmt.Fprintf(os.Stderr, "loadtest: invalid -header %q, want \"Key: Value\"\n", h)
			os.Exit(1)
		}
		parsedHeaders[strings.TrimSpace(parts[0])] = strings.TrimSpace(parts[1])
	}

	report := run(runConfig{
		url: *url, method: *method, body: body, headers: parsedHeaders,
		concurrency: *concurrency, duration: *duration, rps: *rps, timeout: *timeout,
	})

	out, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "loadtest: marshal report: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(out))
	if *outFile != "" {
		if err := os.WriteFile(*outFile, out, 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "loadtest: write report file: %v\n", err)
			os.Exit(1)
		}
	}
}

type runConfig struct {
	url         string
	method      string
	body        []byte
	headers     map[string]string
	concurrency int
	duration    time.Duration
	rps         int
	timeout     time.Duration
}

// Report is the load test's published result — the artifact Phase 12's
// task asks to "publish", once someone runs this against a real target.
type Report struct {
	URL              string        `json:"url"`
	Method           string        `json:"method"`
	Concurrency      int           `json:"concurrency"`
	DurationSeconds  float64       `json:"duration_seconds"`
	TotalRequests    int64         `json:"total_requests"`
	SuccessCount     int64         `json:"success_count"`
	ErrorCount       int64         `json:"error_count"`
	RequestsPerSec   float64       `json:"requests_per_sec"`
	LatencyP50Ms     float64       `json:"latency_p50_ms"`
	LatencyP95Ms     float64       `json:"latency_p95_ms"`
	LatencyP99Ms     float64       `json:"latency_p99_ms"`
	LatencyMaxMs     float64       `json:"latency_max_ms"`
	StatusCodeCounts map[int]int64 `json:"status_code_counts"`
}

func run(cfg runConfig) Report {
	client := &http.Client{Timeout: cfg.timeout}
	ctx, cancel := context.WithTimeout(context.Background(), cfg.duration)
	defer cancel()

	var (
		mu                sync.Mutex
		latencies         []time.Duration
		statusCodes       = map[int]int64{}
		successes, errors int64
	)

	var throttle <-chan time.Time
	if cfg.rps > 0 {
		ticker := time.NewTicker(time.Second / time.Duration(cfg.rps))
		defer ticker.Stop()
		throttle = ticker.C
	}

	var wg sync.WaitGroup
	for i := 0; i < cfg.concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				select {
				case <-ctx.Done():
					return
				default:
				}
				if throttle != nil {
					select {
					case <-throttle:
					case <-ctx.Done():
						return
					}
				}

				started := time.Now()
				status, err := doRequest(ctx, client, cfg)
				elapsed := time.Since(started)

				mu.Lock()
				latencies = append(latencies, elapsed)
				if err != nil || status >= 400 {
					errors++
				} else {
					successes++
				}
				if status > 0 {
					statusCodes[status]++
				}
				mu.Unlock()
			}
		}()
	}
	wg.Wait()

	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	total := int64(len(latencies))

	return Report{
		URL: cfg.url, Method: cfg.method, Concurrency: cfg.concurrency,
		DurationSeconds: cfg.duration.Seconds(), TotalRequests: total,
		SuccessCount: successes, ErrorCount: errors,
		RequestsPerSec:   float64(total) / cfg.duration.Seconds(),
		LatencyP50Ms:     percentileMs(latencies, 0.50),
		LatencyP95Ms:     percentileMs(latencies, 0.95),
		LatencyP99Ms:     percentileMs(latencies, 0.99),
		LatencyMaxMs:     maxMs(latencies),
		StatusCodeCounts: statusCodes,
	}
}

func doRequest(ctx context.Context, client *http.Client, cfg runConfig) (status int, err error) {
	var bodyReader io.Reader
	if len(cfg.body) > 0 {
		bodyReader = bytes.NewReader(cfg.body)
	}
	req, err := http.NewRequestWithContext(ctx, cfg.method, cfg.url, bodyReader)
	if err != nil {
		return 0, err
	}
	for k, v := range cfg.headers {
		req.Header.Set(k, v)
	}
	if len(cfg.body) > 0 && req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	return resp.StatusCode, nil
}

func percentileMs(sorted []time.Duration, p float64) float64 {
	if len(sorted) == 0 {
		return 0
	}
	idx := int(p * float64(len(sorted)))
	if idx >= len(sorted) {
		idx = len(sorted) - 1
	}
	return float64(sorted[idx].Microseconds()) / 1000.0
}

func maxMs(sorted []time.Duration) float64 {
	if len(sorted) == 0 {
		return 0
	}
	return float64(sorted[len(sorted)-1].Microseconds()) / 1000.0
}
