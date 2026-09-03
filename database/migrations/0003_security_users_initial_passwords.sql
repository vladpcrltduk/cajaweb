-- Migration 0003: Set initial BCrypt password hash for all existing users
--
-- Sets password to "caja" for all users who have no password hash yet.
-- Uses pgcrypto extension for BCrypt hashing (compatible with BCrypt.Net).
-- Users should be required to change this on first login.

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0003_security_users_initial_passwords') THEN
        RAISE NOTICE 'Migration 0003 already applied, skipping.';
        RETURN;
    END IF;

    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    UPDATE security_users
        SET password_hash = crypt('caja', gen_salt('bf', 12))
        WHERE password_hash IS NULL;

    RAISE NOTICE 'Updated % user(s) with initial password hash.',
        (SELECT COUNT(*) FROM security_users WHERE password_hash IS NOT NULL);

    INSERT INTO schema_migrations (script_name) VALUES ('0003_security_users_initial_passwords');

    RAISE NOTICE 'Migration 0003 applied successfully.';
END $$;
