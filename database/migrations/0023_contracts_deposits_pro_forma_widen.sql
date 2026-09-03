-- Migration 0023: widen contracts_deposits.pro_forma_invoice_number from char(10) to char(20)
-- No FK constraints or views reference this column.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE script_name = '0023_contracts_deposits_pro_forma_widen') THEN
    RAISE NOTICE 'Migration 0023 already applied, skipping.';
    RETURN;
  END IF;

  ALTER TABLE public.contracts_deposits ALTER COLUMN pro_forma_invoice_number TYPE char(20);

  INSERT INTO public.schema_migrations (script_name) VALUES ('0023_contracts_deposits_pro_forma_widen');
  RAISE NOTICE 'Migration 0023 applied successfully.';
END;
$$;
