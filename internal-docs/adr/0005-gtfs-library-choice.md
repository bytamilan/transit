# ADR 0005: GTFS Library Choice

## Status
Accepted

## Context
Phase 3 needs to parse GTFS static archives and GTFS realtime protobuf feeds in
Go. We evaluated two options:

1. Write a custom GTFS parser on top of `encoding/csv` and the official
   GTFS-RT protobuf descriptors.
2. Re-use an existing open-source Go GTFS library.

## Decision
Use `github.com/OneBusAway/go-gtfs` for both static and realtime parsing.

- It provides CSV loading for static GTFS (`gtfs.Load` and `gtfs.LoadFromCSV`).
- It ships the official GTFS-RT protobuf bindings under its `proto` package.
- It is maintained by the OneBusAway community and is already a known dependency
  in the transit ecosystem.

We wrap the library in adapter packages (`gtfsstatic`, `gtfsrt`) that implement
our own `adapters.Adapter` interface. This keeps the upstream library replaceable
and lets us normalise fields into the canonical transit schema.

## Consequences
- Faster implementation: CSV parsing, zip handling and protobuf descriptors are
  provided by the library.
- Consistent with community standards: the library follows the official GTFS
  specification.
- Isolated coupling: adapters are the only packages that import the library.
- Limitation: the library returns `float32` for vehicle latitude/longitude, so
  our adapter casts to `float64` to match the canonical schema.

## Alternatives Considered
- **Custom parser**: gives full control but requires re-implementing CSV
  decoding, zip extraction and protobuf code generation.
- **Other libraries**: several exist but are either unmaintained or do not cover
  both static and realtime in one module.
