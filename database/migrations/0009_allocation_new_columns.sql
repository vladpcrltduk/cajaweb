DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0009_allocation_new_columns') THEN
    RAISE NOTICE 'Migration 0009 already applied, skipping.';
    RETURN;
  END IF;

  ALTER TABLE public.allocation
    ADD COLUMN is_stock_allocation char(1) NOT NULL DEFAULT 'N'
      CONSTRAINT chk_allocation_is_stock_allocation CHECK (is_stock_allocation IN ('Y', 'N')),
    ADD COLUMN is_allocation_fixed char(1) NOT NULL DEFAULT 'N'
      CONSTRAINT chk_allocation_is_allocation_fixed CHECK (is_allocation_fixed IN ('Y', 'N'));

  INSERT INTO schema_migrations (script_name) VALUES ('0009_allocation_new_columns');
  RAISE NOTICE 'Migration 0009 applied successfully.';
END;
$$;
