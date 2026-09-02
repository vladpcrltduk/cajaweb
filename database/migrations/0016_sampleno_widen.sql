-- Migration 0016: Widen sampleno from char(10) to char(20)
-- Affects: sample_master, sample_detail, sample_analysis, contract_sample_link
-- 3 FK constraints; no views or functions.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0016_sampleno_widen') THEN
    RAISE NOTICE 'Migration 0016 already applied, skipping.';
    RETURN;
  END IF;

  -- ============================================================
  -- STEP 1: Drop FK constraints
  -- ============================================================
  ALTER TABLE public.sample_detail        DROP CONSTRAINT IF EXISTS sampleno;
  ALTER TABLE public.sample_analysis      DROP CONSTRAINT IF EXISTS fk_analysis_sample_detail;
  ALTER TABLE public.contract_sample_link DROP CONSTRAINT IF EXISTS sampleno;

  -- ============================================================
  -- STEP 2: Widen sampleno in all 4 tables
  -- ============================================================
  ALTER TABLE public.sample_master        ALTER COLUMN sampleno TYPE char(20);
  ALTER TABLE public.sample_detail        ALTER COLUMN sampleno TYPE char(20);
  ALTER TABLE public.sample_analysis      ALTER COLUMN sampleno TYPE char(20);
  ALTER TABLE public.contract_sample_link ALTER COLUMN sampleno TYPE char(20);

  -- ============================================================
  -- STEP 3: Re-add FK constraints
  -- ============================================================
  ALTER TABLE public.sample_detail
    ADD CONSTRAINT sampleno
      FOREIGN KEY (sampleno) REFERENCES public.sample_master(sampleno);

  ALTER TABLE public.sample_analysis
    ADD CONSTRAINT fk_analysis_sample_detail
      FOREIGN KEY (sampleno, samplelineno) REFERENCES public.sample_detail(sampleno, lineno);

  ALTER TABLE public.contract_sample_link
    ADD CONSTRAINT sampleno
      FOREIGN KEY (sampleno) REFERENCES public.sample_master(sampleno);

  INSERT INTO schema_migrations (script_name) VALUES ('0016_sampleno_widen');
  RAISE NOTICE 'Migration 0016 applied successfully.';
END;
$$;
