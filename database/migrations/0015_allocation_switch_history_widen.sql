-- Migration 0015: Correct column widths in allocation_switch_history
-- Widens alloc_ref and contno columns to char(20).
-- Corrects from_stock_split and to_stock_split from char(10) to char(3)
-- (table is empty; no FK constraints, views, or functions reference it).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0015_allocation_switch_history_widen') THEN
    RAISE NOTICE 'Migration 0015 already applied, skipping.';
    RETURN;
  END IF;

  ALTER TABLE public.allocation_switch_history ALTER COLUMN from_alloc_ref    TYPE char(20);
  ALTER TABLE public.allocation_switch_history ALTER COLUMN from_sale_contno  TYPE char(20);
  ALTER TABLE public.allocation_switch_history ALTER COLUMN from_stock_contno TYPE char(20);
  ALTER TABLE public.allocation_switch_history ALTER COLUMN from_stock_split  TYPE char(3);
  ALTER TABLE public.allocation_switch_history ALTER COLUMN to_alloc_ref      TYPE char(20);
  ALTER TABLE public.allocation_switch_history ALTER COLUMN to_sale_contno    TYPE char(20);
  ALTER TABLE public.allocation_switch_history ALTER COLUMN to_stock_contno   TYPE char(20);
  ALTER TABLE public.allocation_switch_history ALTER COLUMN to_stock_split    TYPE char(3);

  INSERT INTO schema_migrations (script_name) VALUES ('0015_allocation_switch_history_widen');
  RAISE NOTICE 'Migration 0015 applied successfully.';
END;
$$;
