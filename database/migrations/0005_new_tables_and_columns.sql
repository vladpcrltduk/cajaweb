-- Migration 0005: New tables and columns ported from SQL Anywhere schema update
--
-- Converted from SQL Anywhere 17 dialect to PostgreSQL 18:
--   - "DBA"."tablename"        → public schema (implicit)
--   - datetime DEFAULT timestamp → timestamp NOT NULL DEFAULT now()
--   - GRANT statements          → omitted (handled at DB level)
--
-- New tables:
--   sample_request_master
--   sample_request_detail        (quality created as char(8) — widened in 0004)
--   client_alternative_address
--   country_states_regions
--
-- New columns:
--   sub_contracts.prefinance_notes          varchar(512)
--   location.region_state                  char(4) + FK → country_states_regions
--   client.preferred_payment_instructions   char(4) + FK → payment_instruction
--
-- Note: client char(8) columns in new tables match current client.code.
--       They will be included in the client.code widening migration.
--
-- Safe to re-run: guarded by schema_migrations check.

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0005_new_tables_and_columns') THEN
        RAISE NOTICE 'Migration 0005 already applied, skipping.';
        RETURN;
    END IF;

    -- -------------------------------------------------------------------------
    -- TABLE: country_states_regions
    -- Created first — location.region_state FK depends on it.
    -- -------------------------------------------------------------------------

    CREATE TABLE country_states_regions (
        code          char(4)      NOT NULL,
        name          varchar(32)  NULL,
        longname      varchar(256) NULL,
        country       char(4)      NULL,
        last_modified timestamp    NOT NULL DEFAULT now(),
        CONSTRAINT country_states_regions_pkey PRIMARY KEY (code),
        CONSTRAINT fk_country_states_regions_country
            FOREIGN KEY (country) REFERENCES country(code)
    );

    -- -------------------------------------------------------------------------
    -- TABLE: sample_request_master
    -- -------------------------------------------------------------------------

    CREATE TABLE sample_request_master (
        request_date           date         NOT NULL,
        sequence_number        numeric(3,0) NOT NULL,
        client                 char(8)      NOT NULL,
        client_longname        varchar(1024) NULL,
        client_address_1       varchar(124) NULL,
        client_address_2       varchar(124) NULL,
        client_address_3       varchar(124) NULL,
        client_address_4       varchar(124) NULL,
        client_address_5       varchar(124) NULL,
        client_address_6       varchar(124) NULL,
        doc_type               char(4)      NULL,
        shipping_instructions  char(16)     NULL,
        notes                  varchar(1024) NULL,
        last_modified          timestamp    NOT NULL DEFAULT now(),
        CONSTRAINT sample_request_master_pkey
            PRIMARY KEY (request_date, sequence_number),
        CONSTRAINT fk_sample_request_master_client
            FOREIGN KEY (client) REFERENCES client(code),
        CONSTRAINT fk_sample_request_master_shipinst
            FOREIGN KEY (shipping_instructions) REFERENCES shipping_instructions(code),
        CONSTRAINT fk_sample_request_form
            FOREIGN KEY (doc_type) REFERENCES form(code)
    );

    -- -------------------------------------------------------------------------
    -- TABLE: sample_request_detail
    -- quality is char(8) — quality.code was widened from char(4) in migration 0004.
    -- -------------------------------------------------------------------------

    CREATE TABLE sample_request_detail (
        request_date        date         NOT NULL,
        sequence_number     numeric(3,0) NOT NULL,
        line_number         integer      NOT NULL,
        contno              char(10)     NOT NULL,
        split               char(3)      NOT NULL,
        shipment_id         char(10)     NOT NULL,
        quality             char(8)      NOT NULL,
        quality_longname    varchar(1024) NULL,
        quantity            numeric(10,4) NOT NULL,
        quantunit           char(4)      NOT NULL,
        sample_weight       numeric(10,4) NOT NULL,
        sample_weight_unit  char(4)      NOT NULL,
        container_number    varchar(128) NULL,
        marks2              varchar(128) NULL,
        warrant_number      varchar(128) NULL,
        warehouse           char(8)      NULL,
        notes               varchar(1024) NULL,
        last_modified       timestamp    NOT NULL DEFAULT now(),
        CONSTRAINT sample_request_detail_pkey
            PRIMARY KEY (request_date, sequence_number, line_number),
        CONSTRAINT fk_sample_request_detail_to_master
            FOREIGN KEY (request_date, sequence_number)
            REFERENCES sample_request_master(request_date, sequence_number),
        CONSTRAINT fk_sample_request_detail_sub_contracts
            FOREIGN KEY (contno, split) REFERENCES sub_contracts(contno, split),
        CONSTRAINT fk_sample_request_detail_shipment
            FOREIGN KEY (shipment_id) REFERENCES shipment(shipment_id),
        CONSTRAINT fk_sample_request_detail_quality
            FOREIGN KEY (quality) REFERENCES quality(code),
        CONSTRAINT fk_sample_request_detail_quantunit
            FOREIGN KEY (quantunit) REFERENCES unit(code),
        CONSTRAINT fk_sample_request_detail_unit
            FOREIGN KEY (sample_weight_unit) REFERENCES unit(code),
        CONSTRAINT fk_sample_request_detail_warehouse
            FOREIGN KEY (warehouse) REFERENCES client(code)
    );

    -- -------------------------------------------------------------------------
    -- TABLE: client_alternative_address
    -- -------------------------------------------------------------------------

    CREATE TABLE client_alternative_address (
        client           char(8)       NOT NULL,
        sequence_number  numeric(3,0)  NOT NULL,
        client_longname  varchar(1024) NULL,
        client_address_1 varchar(124)  NULL,
        client_address_2 varchar(124)  NULL,
        client_address_3 varchar(124)  NULL,
        client_address_4 varchar(124)  NULL,
        client_address_5 varchar(124)  NULL,
        client_address_6 varchar(124)  NULL,
        is_valid         char(1)       NULL,
        last_modified    timestamp     NOT NULL DEFAULT now(),
        CONSTRAINT client_alternative_address_pkey
            PRIMARY KEY (client, sequence_number),
        CONSTRAINT fk_client_alternative_address_client
            FOREIGN KEY (client) REFERENCES client(code)
    );

    -- -------------------------------------------------------------------------
    -- ALTER TABLE: sub_contracts — add prefinance_notes
    -- -------------------------------------------------------------------------

    ALTER TABLE sub_contracts
        ADD COLUMN IF NOT EXISTS prefinance_notes varchar(512) NULL;

    -- -------------------------------------------------------------------------
    -- ALTER TABLE: location — add region_state FK to country_states_regions
    -- -------------------------------------------------------------------------

    ALTER TABLE location
        ADD COLUMN IF NOT EXISTS region_state char(4) NULL;

    ALTER TABLE location
        ADD CONSTRAINT fk_location_region_state
        FOREIGN KEY (region_state) REFERENCES country_states_regions(code);

    -- -------------------------------------------------------------------------
    -- ALTER TABLE: client — add preferred_payment_instructions
    -- -------------------------------------------------------------------------

    ALTER TABLE client
        ADD COLUMN IF NOT EXISTS preferred_payment_instructions char(4) NULL;

    ALTER TABLE client
        ADD CONSTRAINT fk_client_preferred_payment_instructions
        FOREIGN KEY (preferred_payment_instructions) REFERENCES payment_instruction(code);

    -- -------------------------------------------------------------------------
    -- Record migration
    -- -------------------------------------------------------------------------

    INSERT INTO schema_migrations (script_name) VALUES ('0005_new_tables_and_columns');

    RAISE NOTICE 'Migration 0005 applied successfully.';
END $$;
