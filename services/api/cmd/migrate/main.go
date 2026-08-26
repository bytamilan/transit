// Command migrate applies forward-only SQL migrations to the Transit database.
//
// Usage:
//
//	migrate up                 # apply all pending migrations
//	migrate reset              # drop and recreate the database (local dev only)
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/bytamilan/transit/services/api/internal/migrate"
	"github.com/jackc/pgx/v5/pgxpool"
)

const migrationsDir = "infra/supabase/migrations"

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: migrate up|reset")
		os.Exit(1)
	}
	cmd := os.Args[1]

	ctx := context.Background()

	switch cmd {
	case "up":
		if err := up(ctx); err != nil {
			log.Fatal(err)
		}
	case "reset":
		if err := reset(ctx); err != nil {
			log.Fatal(err)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", cmd)
		os.Exit(1)
	}
}

func up(ctx context.Context) error {
	migDir := migrationsDir
	if dir := os.Getenv("MIGRATIONS_DIR"); dir != "" {
		migDir = dir
	}
	migDir, err := filepath.Abs(migDir)
	if err != nil {
		return err
	}

	migs, err := migrate.Load(migDir)
	if err != nil {
		return err
	}
	if len(migs) == 0 {
		fmt.Println("no migrations to apply")
		return nil
	}

	pool := migrate.MustPool(ctx)
	defer pool.Close()

	if err := migrate.Up(ctx, pool, migs); err != nil {
		return err
	}

	fmt.Printf("applied %d migration(s)\n", len(migs))
	return nil
}

func reset(ctx context.Context) error {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		return fmt.Errorf("DATABASE_URL is required")
	}
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return err
	}
	db := cfg.ConnConfig.Database
	if db == "" {
		db = "postgres"
	}

	adminDSN := dsn
	// Swap the database name in a libpq DSN to connect to postgres.
	// This is intentionally simple; production reset is not supported.
	adminDSN = strings.ReplaceAll(adminDSN, fmt.Sprintf("dbname=%s", db), "dbname=postgres")

	if err := migrate.ResetForTest(ctx, adminDSN, db); err != nil {
		return err
	}
	fmt.Println("database reset")
	return nil
}
