-- Migration 0001: security_users surrogate key
--
-- Changes:
--   - Adds system_user_id (serial) as new primary key on security_users
--   - Renames name -> username and widens to varchar(128)
--   - Renames description -> user_full_name and widens to varchar(128)
--   - Adds system_user_id (integer FK) to all 19 referencing tables,
--     populated from the existing username-based FK columns
--   - Drops old username-based FK constraints from referencing tables
--   - Drops the old primary key constraint on security_users.name
--
-- Safe to re-run: wrapped in a guard check against schema_migrations.

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0001_security_users_surrogate_key') THEN
        RAISE NOTICE 'Migration 0001 already applied, skipping.';
        RETURN;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 1: Drop all FK constraints on referencing tables first
    --         (required before we can drop the PK on security_users)
    -- -------------------------------------------------------------------------

    ALTER TABLE contracts_deposits         DROP CONSTRAINT IF EXISTS fk_contracts_deposits_user;
    ALTER TABLE doc_logging                DROP CONSTRAINT IF EXISTS fk_doc_logging_security_users;
    ALTER TABLE dw_user_custom_datawindows DROP CONSTRAINT IF EXISTS fk_dw_user_custom_datawindows_security_users;
    ALTER TABLE invoice_return             DROP CONSTRAINT IF EXISTS fk_invoice_return_security_users;
    ALTER TABLE master_contracts           DROP CONSTRAINT IF EXISTS fk_master_contracts_cancelled_user;
    ALTER TABLE release_note               DROP CONSTRAINT IF EXISTS fk_release_note_security_users;
    ALTER TABLE security_groupings         DROP CONSTRAINT IF EXISTS security_groupings_group;
    ALTER TABLE security_groupings         DROP CONSTRAINT IF EXISTS security_groupings_user;
    ALTER TABLE security_info              DROP CONSTRAINT IF EXISTS security_info_users;
    ALTER TABLE stock_quantity_adjustments DROP CONSTRAINT IF EXISTS fk_stock_quantity_adjustments_security_users;
    ALTER TABLE stocks_movement_history    DROP CONSTRAINT IF EXISTS fk_stocks_movement_history_security_users;
    ALTER TABLE terminal_arbitrages        DROP CONSTRAINT IF EXISTS fk_terminal_arbitrages_user_id;
    ALTER TABLE user_companies             DROP CONSTRAINT IF EXISTS fk_usercompanies_username;
    ALTER TABLE user_defaults              DROP CONSTRAINT IF EXISTS fk_userdefs_user_name;
    ALTER TABLE user_favourite_reports     DROP CONSTRAINT IF EXISTS fk_userfav_securityusers;
    ALTER TABLE user_notifications         DROP CONSTRAINT IF EXISTS fk_usernotifications_user_name;
    ALTER TABLE user_parameters            DROP CONSTRAINT IF EXISTS fk_userparameters_user_name;
    ALTER TABLE user_params                DROP CONSTRAINT IF EXISTS fk_userparams_user_name;
    ALTER TABLE user_reports               DROP CONSTRAINT IF EXISTS fk_userreports_user_name;

    -- -------------------------------------------------------------------------
    -- STEP 2: Add system_user_id serial to security_users,
    --         drop old PK, add new PK on system_user_id
    -- -------------------------------------------------------------------------

    ALTER TABLE security_users ADD COLUMN system_user_id serial;

    ALTER TABLE security_users DROP CONSTRAINT IF EXISTS security_users_pkey;

    ALTER TABLE security_users
        ADD CONSTRAINT security_users_pkey PRIMARY KEY (system_user_id);

    -- -------------------------------------------------------------------------
    -- STEP 3: Add system_user_id FK columns to all 19 referencing tables
    --         and populate them by joining on the current username value
    -- -------------------------------------------------------------------------

    ALTER TABLE contracts_deposits ADD COLUMN system_user_id integer;
    UPDATE contracts_deposits t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.entered_by_user;

    ALTER TABLE doc_logging ADD COLUMN system_user_id integer;
    UPDATE doc_logging t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.username;

    ALTER TABLE dw_user_custom_datawindows ADD COLUMN system_user_id integer;
    UPDATE dw_user_custom_datawindows t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_id;

    ALTER TABLE invoice_return ADD COLUMN system_user_id integer;
    UPDATE invoice_return t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_id;

    ALTER TABLE master_contracts ADD COLUMN system_user_id integer;
    UPDATE master_contracts t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.cancelled_user;

    ALTER TABLE release_note ADD COLUMN system_user_id integer;
    UPDATE release_note t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_id;

    ALTER TABLE security_groupings ADD COLUMN system_user_id integer;
    UPDATE security_groupings t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE security_info ADD COLUMN system_user_id integer;
    UPDATE security_info t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE stock_quantity_adjustments ADD COLUMN system_user_id integer;
    UPDATE stock_quantity_adjustments t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_id;

    ALTER TABLE stocks_movement_history ADD COLUMN system_user_id integer;
    UPDATE stocks_movement_history t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_id;

    ALTER TABLE terminal_arbitrages ADD COLUMN system_user_id integer;
    UPDATE terminal_arbitrages t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_id;

    ALTER TABLE user_companies ADD COLUMN system_user_id integer;
    UPDATE user_companies t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE user_defaults ADD COLUMN system_user_id integer;
    UPDATE user_defaults t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE user_favourite_reports ADD COLUMN system_user_id integer;
    UPDATE user_favourite_reports t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE user_notifications ADD COLUMN system_user_id integer;
    UPDATE user_notifications t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE user_parameters ADD COLUMN system_user_id integer;
    UPDATE user_parameters t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE user_params ADD COLUMN system_user_id integer;
    UPDATE user_params t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    ALTER TABLE user_reports ADD COLUMN system_user_id integer;
    UPDATE user_reports t
        SET system_user_id = su.system_user_id
        FROM security_users su WHERE su.name = t.user_name;

    -- -------------------------------------------------------------------------
    -- STEP 4: Add new FK constraints pointing at security_users.system_user_id
    -- -------------------------------------------------------------------------

    ALTER TABLE contracts_deposits         ADD CONSTRAINT contracts_deposits_system_user_id_fkey         FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE doc_logging                ADD CONSTRAINT doc_logging_system_user_id_fkey                FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE dw_user_custom_datawindows ADD CONSTRAINT dw_user_custom_datawindows_system_user_id_fkey FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE invoice_return             ADD CONSTRAINT invoice_return_system_user_id_fkey             FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE master_contracts           ADD CONSTRAINT master_contracts_system_user_id_fkey           FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE release_note               ADD CONSTRAINT release_note_system_user_id_fkey               FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE security_groupings         ADD CONSTRAINT security_groupings_system_user_id_fkey         FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE security_info              ADD CONSTRAINT security_info_system_user_id_fkey              FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE stock_quantity_adjustments ADD CONSTRAINT stock_quantity_adjustments_system_user_id_fkey FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE stocks_movement_history    ADD CONSTRAINT stocks_movement_history_system_user_id_fkey    FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE terminal_arbitrages        ADD CONSTRAINT terminal_arbitrages_system_user_id_fkey        FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE user_companies             ADD CONSTRAINT user_companies_system_user_id_fkey             FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE user_defaults              ADD CONSTRAINT user_defaults_system_user_id_fkey              FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE user_favourite_reports     ADD CONSTRAINT user_favourite_reports_system_user_id_fkey     FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE user_notifications         ADD CONSTRAINT user_notifications_system_user_id_fkey         FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE user_parameters            ADD CONSTRAINT user_parameters_system_user_id_fkey            FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE user_params                ADD CONSTRAINT user_params_system_user_id_fkey                FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);
    ALTER TABLE user_reports               ADD CONSTRAINT user_reports_system_user_id_fkey               FOREIGN KEY (system_user_id) REFERENCES security_users(system_user_id);

    -- -------------------------------------------------------------------------
    -- STEP 5: Rename and widen columns on security_users
    -- -------------------------------------------------------------------------

    ALTER TABLE security_users RENAME COLUMN name TO username;
    ALTER TABLE security_users ALTER COLUMN username TYPE varchar(128);
    ALTER TABLE security_users ADD CONSTRAINT security_users_username_key UNIQUE (username);

    ALTER TABLE security_users RENAME COLUMN description TO user_full_name;
    ALTER TABLE security_users ALTER COLUMN user_full_name TYPE varchar(128);

    -- -------------------------------------------------------------------------
    -- STEP 6: Record this migration as applied
    -- -------------------------------------------------------------------------

    INSERT INTO schema_migrations (script_name) VALUES ('0001_security_users_surrogate_key');

    RAISE NOTICE 'Migration 0001 applied successfully.';
END $$;
