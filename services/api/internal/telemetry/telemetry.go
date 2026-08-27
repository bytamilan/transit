// Package telemetry wires OpenTelemetry tracing for every Transit binary
// (Phase 12 — brief §12 observability). Every binary calls Setup once at
// startup; the returned shutdown func flushes buffered spans on exit.
//
// Structured logging (the other half of "structured logs, ... dashboards
// and alerting rules") isn't this package's job — every binary already
// logs via slog.NewJSONHandler since Phase 2, unchanged here.
package telemetry

import (
	"context"
	"fmt"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/exporters/stdout/stdouttrace"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"
)

// Setup configures the global TracerProvider for serviceName. If
// OTEL_EXPORTER_OTLP_ENDPOINT is set, spans are exported via OTLP/HTTP to
// that collector — the expected production path (deploy/observability/
// documents a reference collector + Grafana/Tempo stack). Otherwise spans
// are written to stdout as JSON: useful for local `make dev` runs to see
// that tracing is actually wired, without standing up a collector.
//
// Call the returned shutdown func before the process exits (a deferred
// call from main is enough) so buffered spans are flushed rather than
// silently dropped.
func Setup(ctx context.Context, serviceName string) (shutdown func(context.Context) error, err error) {
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion(envOr("SERVICE_VERSION", "dev")),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("build otel resource: %w", err)
	}

	exporter, err := buildExporter(ctx)
	if err != nil {
		return nil, fmt.Errorf("build otel exporter: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(samplingRatio()))),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{},
	))

	return tp.Shutdown, nil
}

// Tracer returns a named tracer from the global TracerProvider — call
// after Setup. Handlers/adapters that want their own spans (e.g. a sync
// run, a batch export) use this rather than reaching into otel directly,
// so every call site is grep-able back to this package.
func Tracer(name string) trace.Tracer {
	return otel.Tracer(name)
}

func buildExporter(ctx context.Context) (sdktrace.SpanExporter, error) {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		return stdouttrace.New(stdouttrace.WithPrettyPrint())
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	return otlptracehttp.New(ctx, otlptracehttp.WithEndpointURL(endpoint))
}

// samplingRatio reads OTEL_TRACES_SAMPLER_ARG (a float in [0,1]), default
// 1.0 (sample everything) — fine at this codebase's traffic scale; a real
// high-volume deployment would lower this via env var, not a code change.
func samplingRatio() float64 {
	v := os.Getenv("OTEL_TRACES_SAMPLER_ARG")
	if v == "" {
		return 1.0
	}
	var ratio float64
	if _, err := fmt.Sscanf(v, "%f", &ratio); err != nil || ratio < 0 || ratio > 1 {
		return 1.0
	}
	return ratio
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
