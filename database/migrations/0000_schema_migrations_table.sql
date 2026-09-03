-- Migration tracking table.
-- Run this once before any other migration scripts.

CREATE TABLE IF NOT EXISTS schema_migrations (
    id          serial          PRIMARY KEY,
    script_name text            NOT NULL UNIQUE,
    applied_at  timestamptz     NOT NULL DEFAULT now()
);
