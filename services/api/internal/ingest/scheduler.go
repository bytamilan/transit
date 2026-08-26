// Package ingest wires adapters together into a runnable scheduler.
package ingest

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/bytamilan/transit/services/api/internal/store/feeds"
	"github.com/google/uuid"
)

// Scheduler runs enabled feeds at their configured intervals.
type Scheduler struct {
	registry   *Registry
	reader     *feeds.Reader
	runs       *feeds.SyncRunWriter
	quarantine *feeds.QuarantineWriter
	reloadInterval time.Duration
	workers    sync.WaitGroup
	stop       chan struct{}
	mu         sync.Mutex
	running    bool
}

// Option configures a Scheduler.
type Option func(*Scheduler)

// WithReloadInterval sets the catalogue reload interval.
func WithReloadInterval(d time.Duration) Option {
	return func(s *Scheduler) {
		s.reloadInterval = d
	}
}

// NewScheduler builds a scheduler from its dependencies.
func NewScheduler(reg *Registry, reader *feeds.Reader, runs *feeds.SyncRunWriter, q *feeds.QuarantineWriter, opts ...Option) *Scheduler {
	s := &Scheduler{
		registry:       reg,
		reader:         reader,
		runs:           runs,
		quarantine:     q,
		reloadInterval: 5 * time.Minute,
		stop:           make(chan struct{}),
	}
	for _, o := range opts {
		o(s)
	}
	return s
}

// Start begins the scheduler. It loads feeds, starts per-feed realtime tickers,
// and reloads the catalogue at the configured interval.
func (s *Scheduler) Start(ctx context.Context) error {
	s.mu.Lock()
	if s.running {
		s.mu.Unlock()
		return fmt.Errorf("scheduler already running")
	}
	s.running = true
	s.stop = make(chan struct{})
	s.mu.Unlock()

	errCh := make(chan error, 1)
	s.workers.Add(1)
	go func() {
		defer s.workers.Done()
		errCh <- s.loop(ctx)
	}()

	return <-errCh
}

// Stop signals the scheduler to stop and waits for workers to finish.
func (s *Scheduler) Stop() {
	s.mu.Lock()
	if !s.running {
		s.mu.Unlock()
		return
	}
	s.running = false
	close(s.stop)
	s.mu.Unlock()
	s.workers.Wait()
}

func (s *Scheduler) loop(ctx context.Context) error {
	defer s.markStopped()

	// Initial load.
	if err := s.loadAndSchedule(ctx); err != nil {
		return err
	}

	reload := time.NewTicker(s.reloadInterval)
	defer reload.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-s.stop:
			return nil
		case <-reload.C:
			if err := s.loadAndSchedule(ctx); err != nil {
				slog.Error("feed catalogue reload failed", "err", err)
			}
		}
	}
}

func (s *Scheduler) loadAndSchedule(ctx context.Context) error {
	rows, err := s.reader.LoadEnabledFeeds(ctx)
	if err != nil {
		return err
	}
	for _, row := range rows {
		adapter, err := s.registry.Get(row.Adapter)
		if err != nil {
			slog.Error("unknown adapter in feed row", "feed_id", row.ID, "adapter", row.Adapter, "err", err)
			continue
		}
		s.scheduleFeed(ctx, adapter, row)
	}
	return nil
}

func (s *Scheduler) scheduleFeed(ctx context.Context, adapter adapters.Adapter, row feeds.FeedRow) {
	feed := adapters.AgencyFeed{
		ID:           row.ID.String(),
		AgencyID:     row.AgencyID.String(),
		Adapter:      row.Adapter,
		Name:         row.Name,
		StaticURL:    row.StaticURL,
		RealtimeURL:  row.RealtimeURL,
		Config:       row.Config,
		RateStrategy: row.RateStrategy,
	}

	caps := adapter.Capabilities()
	if caps.Realtime {
		interval := adapter.RateStrategy().IntervalSeconds
		if interval <= 0 {
			interval = 30
		}
		s.workers.Add(1)
		go func() {
			defer s.workers.Done()
			s.runRealtimeLoop(ctx, adapter, feed, time.Duration(interval)*time.Second)
		}()
		return
	}
	if caps.Static {
		s.workers.Add(1)
		go func() {
			defer s.workers.Done()
			s.runStatic(ctx, adapter, feed)
		}()
	}
}

func (s *Scheduler) runStatic(ctx context.Context, adapter adapters.Adapter, feed adapters.AgencyFeed) {
	started := time.Now().UTC()
	res, err := adapter.SyncStatic(ctx, feed)
	finished := time.Now().UTC()
	status := "success"
	if err != nil {
		status = "failed"
		if _, qerr := s.quarantine.Insert(ctx, feeds.QuarantineEntry{
			AgencyID: feedAgencyID(feed.AgencyID),
			FeedID:   feedID(feed.ID),
			Error:    err.Error(),
		}); qerr != nil {
			slog.Error("failed to quarantine static feed", "err", qerr)
		}
	} else if len(res.Diagnostics) > 0 {
		status = "partial"
	}

	upserted := res.Upserted
	unchanged := res.Unchanged
	_, _ = s.runs.Insert(ctx, feeds.Record{
		AgencyID:         feedAgencyID(feed.AgencyID),
		FeedID:           feedID(feed.ID),
		Adapter:          adapter.Name(),
		Kind:             "static",
		StartedAt:        started,
		FinishedAt:       finished,
		Status:           status,
		Diagnostics:      res.Diagnostics,
		RecordsUpserted:  &upserted,
		RecordsUnchanged: &unchanged,
		FeedVersion:      res.FeedVersion,
	})
}

func (s *Scheduler) runRealtimeLoop(ctx context.Context, adapter adapters.Adapter, feed adapters.AgencyFeed, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Run immediately, then on every tick.
	s.runRealtime(ctx, adapter, feed)
	for {
		select {
		case <-ctx.Done():
			return
		case <-s.stop:
			return
		case <-ticker.C:
			s.runRealtime(ctx, adapter, feed)
		}
	}
}

func (s *Scheduler) runRealtime(ctx context.Context, adapter adapters.Adapter, feed adapters.AgencyFeed) {
	started := time.Now().UTC()
	ch, err := adapter.PollRealtime(ctx, feed)
	finished := time.Now().UTC()
	status := "success"
	var diags []adapters.Diagnostic
	count := 0
	if err != nil {
		status = "failed"
		if _, qerr := s.quarantine.Insert(ctx, feeds.QuarantineEntry{
			AgencyID: feedAgencyID(feed.AgencyID),
			FeedID:   feedID(feed.ID),
			Error:    err.Error(),
		}); qerr != nil {
			slog.Error("failed to quarantine realtime feed", "err", qerr)
		}
	} else {
		for range ch {
			count++
		}
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityInfo,
			Entity:   "realtime",
			Message:  fmt.Sprintf("emitted %d messages", count),
		})
	}

	_, _ = s.runs.Insert(ctx, feeds.Record{
		AgencyID:        feedAgencyID(feed.AgencyID),
		FeedID:          feedID(feed.ID),
		Adapter:         adapter.Name(),
		Kind:            "realtime",
		StartedAt:       started,
		FinishedAt:      finished,
		Status:          status,
		Diagnostics:     diags,
		RecordsUpserted: &count,
	})
}

func (s *Scheduler) markStopped() {
	s.mu.Lock()
	s.running = false
	s.mu.Unlock()
}

func feedAgencyID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}

func feedID(s string) *uuid.UUID {
	id, err := uuid.Parse(s)
	if err != nil {
		return nil
	}
	return &id
}
