-- Migration 0024: widen delivery_order.delivery_order from char(8) to char(16)
-- delivery_order is the PK on delivery_order; delivery_order_lines.delivery_order is a FK child.
-- No views reference either table.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE script_name = '0024_delivery_order_widen') THEN
    RAISE NOTICE 'Migration 0024 already applied, skipping.';
    RETURN;
  END IF;

  -- STEP 1: Drop FK from child table
  ALTER TABLE public.delivery_order_lines DROP CONSTRAINT IF EXISTS fk_delordline_delorder;

  -- STEP 2: Widen columns
  ALTER TABLE public.delivery_order       ALTER COLUMN delivery_order TYPE char(16);
  ALTER TABLE public.delivery_order_lines ALTER COLUMN delivery_order TYPE char(16);

  -- STEP 3: Re-add FK
  ALTER TABLE public.delivery_order_lines
    ADD CONSTRAINT fk_delordline_delorder
      FOREIGN KEY (delivery_order)
      REFERENCES public.delivery_order(delivery_order);

  INSERT INTO public.schema_migrations (script_name) VALUES ('0024_delivery_order_widen');
  RAISE NOTICE 'Migration 0024 applied successfully.';
END;
$$;
