// Package ingest wires adapters together into a runnable scheduler.
package ingest

import (
	"fmt"
	"net/http"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/bytamilan/transit/services/api/internal/adapters/gtfsrt"
	"github.com/bytamilan/transit/services/api/internal/adapters/gtfsstatic"
)

// Registry maps adapter names to Adapter instances.
type Registry struct {
	adapters map[string]adapters.Adapter
}

// NewRegistry returns a registry populated with built-in adapters.
func NewRegistry(fetcher adapters.Fetcher) *Registry {
	if fetcher == nil {
		fetcher = &adapters.DefaultFetcher{Client: http.DefaultClient}
	}
	return &Registry{
		adapters: map[string]adapters.Adapter{
			gtfsstatic.Name: &gtfsstatic.Adapter{Fetcher: fetcher},
			gtfsrt.Name:     &gtfsrt.Adapter{Fetcher: fetcher},
		},
	}
}

// Register adds or overrides an adapter.
func (r *Registry) Register(name string, a adapters.Adapter) {
	r.adapters[name] = a
}

// Get returns the adapter for name, or an error if it is unknown.
func (r *Registry) Get(name string) (adapters.Adapter, error) {
	a, ok := r.adapters[name]
	if !ok {
		return nil, fmt.Errorf("unknown adapter %q", name)
	}
	return a, nil
}

// Names returns the registered adapter identifiers.
func (r *Registry) Names() []string {
	out := make([]string, 0, len(r.adapters))
	for n := range r.adapters {
		out = append(out, n)
	}
	return out
}
