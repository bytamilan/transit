package telemetry

import (
	"context"
	"os"
	"testing"
)

func TestSetup_StdoutExporterWhenNoOTLPEndpoint(t *testing.T) {
	os.Unsetenv("OTEL_EXPORTER_OTLP_ENDPOINT")

	shutdown, err := Setup(context.Background(), "test-service")
	if err != nil {
		t.Fatalf("Setup: %v", err)
	}
	if shutdown == nil {
		t.Fatal("expected a non-nil shutdown func")
	}
	if err := shutdown(context.Background()); err != nil {
		t.Errorf("shutdown: %v", err)
	}
}

func TestSetup_TracerIsUsable(t *testing.T) {
	os.Unsetenv("OTEL_EXPORTER_OTLP_ENDPOINT")

	shutdown, err := Setup(context.Background(), "test-service")
	if err != nil {
		t.Fatalf("Setup: %v", err)
	}
	defer shutdown(context.Background())

	_, span := Tracer("test").Start(context.Background(), "test-span")
	span.End()
}

func TestSamplingRatio_DefaultsToOneWhenUnset(t *testing.T) {
	os.Unsetenv("OTEL_TRACES_SAMPLER_ARG")
	if got := samplingRatio(); got != 1.0 {
		t.Errorf("samplingRatio() = %v, want 1.0", got)
	}
}

func TestSamplingRatio_ParsesValidValue(t *testing.T) {
	t.Setenv("OTEL_TRACES_SAMPLER_ARG", "0.25")
	if got := samplingRatio(); got != 0.25 {
		t.Errorf("samplingRatio() = %v, want 0.25", got)
	}
}

func TestSamplingRatio_FallsBackOnInvalidValue(t *testing.T) {
	t.Setenv("OTEL_TRACES_SAMPLER_ARG", "not-a-number")
	if got := samplingRatio(); got != 1.0 {
		t.Errorf("samplingRatio() = %v, want 1.0 (fallback)", got)
	}
}

func TestSamplingRatio_FallsBackOnOutOfRangeValue(t *testing.T) {
	t.Setenv("OTEL_TRACES_SAMPLER_ARG", "1.5")
	if got := samplingRatio(); got != 1.0 {
		t.Errorf("samplingRatio() = %v, want 1.0 (fallback for out-of-range)", got)
	}
}
