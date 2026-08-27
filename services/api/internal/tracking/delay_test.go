package tracking

import "testing"

func TestPropagateDelay_DecaysTowardZero(t *testing.T) {
	predicted := PropagateDelay(600, 4)
	if len(predicted) != 4 {
		t.Fatalf("expected 4 predictions, got %d", len(predicted))
	}
	for i := 1; i < len(predicted); i++ {
		if predicted[i] >= predicted[i-1] {
			t.Errorf("expected delay to keep decaying: predicted[%d]=%d not < predicted[%d]=%d", i, predicted[i], i-1, predicted[i-1])
		}
	}
	if predicted[0] >= 600 {
		t.Errorf("expected the first downstream prediction to be less than the current delay, got %d", predicted[0])
	}
}

func TestPropagateDelay_PreservesSignForEarlyVehicles(t *testing.T) {
	predicted := PropagateDelay(-120, 2)
	for _, d := range predicted {
		if d > 0 {
			t.Errorf("expected a running-early vehicle's predictions to stay non-positive, got %d", d)
		}
	}
}

func TestPropagateDelay_ZeroStopsAheadReturnsEmpty(t *testing.T) {
	if got := PropagateDelay(300, 0); len(got) != 0 {
		t.Fatalf("expected no predictions for 0 stops ahead, got %+v", got)
	}
}

func TestPropagateDelay_OnTimeStaysOnTime(t *testing.T) {
	predicted := PropagateDelay(0, 3)
	for _, d := range predicted {
		if d != 0 {
			t.Errorf("expected an on-time vehicle to stay predicted on-time, got %d", d)
		}
	}
}
