// Package migrate applies numbered SQL migration files to a Postgres database.
// It is a tiny forward-only runner used by cmd/migrate and the test harness.
package migrate

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var migrationFileRe = regexp.MustCompile(`^(\d{4})_[^.]+\.sql$`)

// Migration holds parsed metadata for a single migration file.
type Migration struct {
	Version int
	Name    string
	Path    string
	SQL     string
}

// Load reads migration files from dir and returns them sorted by version.
func Load(dir string) ([]Migration, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read migration dir: %w", err)
	}

	var migs []Migration
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		match := migrationFileRe.FindStringSubmatch(entry.Name())
		if match == nil {
			continue
		}
		var version int
		if _, err := fmt.Sscanf(match[1], "%04d", &version); err != nil {
			return nil, fmt.Errorf("parse version from %s: %w", entry.Name(), err)
		}
		path := filepath.Join(dir, entry.Name())
		sql, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("read migration %s: %w", entry.Name(), err)
		}
		migs = append(migs, Migration{
			Version: version,
			Name:    entry.Name(),
			Path:    path,
			SQL:     string(sql),
		})
	}

	sort.Slice(migs, func(i, j int) bool { return migs[i].Version < migs[j].Version })

	// Detect gaps / duplicates.
	seen := make(map[int]struct{})
	for _, m := range migs {
		if _, ok := seen[m.Version]; ok {
			return nil, fmt.Errorf("duplicate migration version %04d", m.Version)
		}
		seen[m.Version] = struct{}{}
	}
	for i, m := range migs {
		if i > 0 && m.Version != migs[i-1].Version+1 {
			return nil, fmt.Errorf("migration version gap between %04d and %04d", migs[i-1].Version, m.Version)
		}
	}

	return migs, nil
}

// Up applies all pending migrations in a single transaction per migration.
func Up(ctx context.Context, pool *pgxpool.Pool, migs []Migration) error {
	if _, err := pool.Exec(ctx, ensureMigrationsTableSQL); err != nil {
		return fmt.Errorf("create schema_migrations table: %w", err)
	}

	for _, m := range migs {
		var applied bool
		if err := pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM transit.schema_migrations WHERE version = $1)", m.Version).Scan(&applied); err != nil {
			return fmt.Errorf("check migration %04d: %w", m.Version, err)
		}
		if applied {
			continue
		}

		if err := apply(ctx, pool, m); err != nil {
			return fmt.Errorf("apply migration %04d: %w", m.Version, err)
		}
	}
	return nil
}

func apply(ctx context.Context, pool *pgxpool.Pool, m Migration) error {
	// We intentionally run each migration in its own transaction. If a
	// migration contains transaction control statements, pgx will error; keep
	// migrations as plain DDL/DML blocks.
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, m.SQL); err != nil {
		return fmt.Errorf("exec: %w", err)
	}
	if _, err := tx.Exec(ctx, "INSERT INTO transit.schema_migrations (version, name) VALUES ($1, $2)", m.Version, m.Name); err != nil {
		return fmt.Errorf("record migration: %w", err)
	}
	return tx.Commit(ctx)
}

const ensureMigrationsTableSQL = `
CREATE SCHEMA IF NOT EXISTS transit;
SET search_path TO transit, public, extensions, auth;
CREATE TABLE IF NOT EXISTS schema_migrations (
    version integer PRIMARY KEY,
    name text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);
`

// MustPool returns a pool from DATABASE_URL or panics.
func MustPool(ctx context.Context) *pgxpool.Pool {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		panic("DATABASE_URL is required")
	}
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		panic(fmt.Sprintf("parse DATABASE_URL: %v", err))
	}
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		panic(fmt.Sprintf("connect to database: %v", err))
	}
	return pool
}

// ConnString returns a libpq-style connection string, escaping values safely.
func ConnString(host, db, user, password string, port int) string {
	parts := []string{
		fmt.Sprintf("host=%s", maybeQuote(host)),
		fmt.Sprintf("port=%d", port),
		fmt.Sprintf("dbname=%s", maybeQuote(db)),
		fmt.Sprintf("user=%s", maybeQuote(user)),
	}
	if password != "" {
		parts = append(parts, fmt.Sprintf("password=%s", maybeQuote(password)))
	}
	parts = append(parts, "sslmode=disable")
	return strings.Join(parts, " ")
}

func maybeQuote(s string) string {
	if s == "" {
		return "''"
	}
	if strings.ContainsAny(s, " \\ '") {
		return "'" + strings.ReplaceAll(s, "'", "\\'") + "'"
	}
	return s
}

// ResetForTest drops and recreates the database named db on the admin connection.
// It is meant only for the local test harness.
func ResetForTest(ctx context.Context, adminDSN, db string) error {
	cfg, err := pgx.ParseConfig(adminDSN)
	if err != nil {
		return err
	}
	cfg.Database = "postgres"
	conn, err := pgx.ConnectConfig(ctx, cfg)
	if err != nil {
		return err
	}
	defer conn.Close(ctx)

	// Terminate existing connections to the target database.
	if _, err := conn.Exec(ctx, "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()", db); err != nil {
		return fmt.Errorf("terminate connections: %w", err)
	}
	if _, err := conn.Exec(ctx, "DROP DATABASE IF EXISTS \""+strings.ReplaceAll(db, "\"", "\"\"")+"\""); err != nil {
		return fmt.Errorf("drop database: %w", err)
	}
	if _, err := conn.Exec(ctx, "CREATE DATABASE \""+strings.ReplaceAll(db, "\"", "\"\"")+"\""); err != nil {
		return fmt.Errorf("create database: %w", err)
	}
	return nil
}
