# ADR 0002: GTFS stop_times use `interval` for after-midnight service

## Status
Accepted — Phase 1

## Context
GTFS `stop_times.txt` expresses arrival and departure as elapsed time since noon
minus 12 hours, written `HH:MM:SS`. Values can exceed 24:00:00 for services that
run past midnight (e.g. `25:30:00`). Storing these as `time` would truncate or
reject values above `23:59:59`. Storing as `timestamptz` is wrong because there
is no date component and the value is relative to the service day.

## Decision
Store `stop_times.arrival_time` and `stop_times.departure_time` as `interval`.
This preserves any number of hours, minutes and seconds exactly as authored in
the feed. Application code converts the interval to a wall-clock timestamp by:

1. Taking the scheduled service date at noon in the agency's IANA timezone.
2. Subtracting 12 hours to reach the GTFS "noon-minus-twelve" origin.
3. Adding the interval value.

Example for `service_date = 2026-01-15` and `arrival_time = '25:30:00'` in
`Asia/Singapore`:

```
2026-01-15 12:00:00+08 - 12 hours + 25 hours 30 minutes
= 2026-01-16 13:30:00+08
```

All agency timezone conversions use `timestamptz` internally and convert to the
agency timezone only at presentation.

## Consequences
- After-midnight schedules are stored losslessly.
- Queries that sort or filter by time-of-day need to compute the wall-clock
  timestamp, so hot read paths should use a generated/computed column or a
  function-based index if performance becomes an issue.
- DST transitions are handled by the IANA timezone conversion, not by naive
  `time` arithmetic.

## References
- GTFS Schedule Reference — `stop_times.txt`, `arrival_time` and `departure_time`
  semantics.
