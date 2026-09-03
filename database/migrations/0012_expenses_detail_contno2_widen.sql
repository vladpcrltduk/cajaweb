-- Migration 0012: Widen expenses_detail.contno2 from char(10) to char(20)
-- No FK constraints, views, or functions reference this column.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0012_expenses_detail_contno2_widen') THEN
    RAISE NOTICE 'Migration 0012 already applied, skipping.';
    RETURN;
  END IF;

  ALTER TABLE public.expenses_detail ALTER COLUMN contno2 TYPE char(20);

  INSERT INTO schema_migrations (script_name) VALUES ('0012_expenses_detail_contno2_widen');
  RAISE NOTICE 'Migration 0012 applied successfully.';
END;
$$;
