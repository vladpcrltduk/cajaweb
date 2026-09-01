-- Migration 0002: Add password_hash to security_users
--
-- Replaces the old SQL Anywhere per-user database authentication model.
-- Passwords will be hashed using BCrypt in the application layer.
-- The column is nullable initially to allow existing rows to remain intact;
-- users will be prompted to set a new password on first web login.

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0002_security_users_password_hash') THEN
        RAISE NOTICE 'Migration 0002 already applied, skipping.';
        RETURN;
    END IF;

    ALTER TABLE security_users
        ADD COLUMN password_hash varchar(256) NULL;

    INSERT INTO schema_migrations (script_name) VALUES ('0002_security_users_password_hash');

    RAISE NOTICE 'Migration 0002 applied successfully.';
END $$;
