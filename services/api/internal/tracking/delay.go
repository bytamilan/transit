package tracking

import "math"

// defaultDecayPerStop is how much of the current delay is expected to carry
// forward to each subsequent stop — a vehicle running late tends to recover
// some schedule over time (shorter dwell, favourable lights), so the
// predicted delay decays geometrically rather than propagating unchanged
// forever.
const defaultDecayPerStop = 0.85

// PropagateDelay predicts delay (seconds) at each of stopsAhead downstream
// stops that haven't been reached yet, given the most recently measured
// delay at the vehicle's current position. Used for live TripUpdate
// predictions on an in-progress trip — stops already resolved by
// ReplayBlock have a measured delay and don't need this.
func PropagateDelay(currentDelaySeconds int, stopsAhead int) []int {
	if stopsAhead <= 0 {
		return nil
	}
	out := make([]int, stopsAhead)
	delay := float64(currentDelaySeconds)
	for i := 0; i < stopsAhead; i++ {
		delay *= defaultDecayPerStop
		out[i] = int(math.Round(delay))
	}
	return out
}
