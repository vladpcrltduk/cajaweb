-- Migration 0022: widen reference fields on accdetail
-- accdetail_contno:               char(10) -> char(20)
-- accdetail_allocation_reference: char(10) -> char(20)
-- accdetail_invoice_number:       char(10) -> char(20)
-- accdetail_final_invoice_number: char(10) -> char(20)
-- accdetail_cr_dr_number:         char(10) -> char(20)
-- accdetail_expense_number:       char(10) -> char(20)
-- No FK constraints involve these columns.
-- Dependent views: bal_anal_view, clt_accbals_view, clt_accbals_view_no_pcentre,
--                  forecast_report_outbooked_p_expenses_view, ledlist_distinct_view,
--                  leds_view, nom_accbals_view

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE script_name = '0022_accdetail_fields_widen') THEN
    RAISE NOTICE 'Migration 0022 already applied, skipping.';
    RETURN;
  END IF;

  -- STEP 1: Drop all views that reference accdetail
  DROP VIEW IF EXISTS public.bal_anal_view                              CASCADE;
  DROP VIEW IF EXISTS public.clt_accbals_view                          CASCADE;
  DROP VIEW IF EXISTS public.clt_accbals_view_no_pcentre               CASCADE;
  DROP VIEW IF EXISTS public.forecast_report_outbooked_p_expenses_view CASCADE;
  DROP VIEW IF EXISTS public.ledlist_distinct_view                      CASCADE;
  DROP VIEW IF EXISTS public.leds_view                                  CASCADE;
  DROP VIEW IF EXISTS public.nom_accbals_view                           CASCADE;

  -- STEP 2: Widen columns
  ALTER TABLE public.accdetail ALTER COLUMN accdetail_contno               TYPE char(20);
  ALTER TABLE public.accdetail ALTER COLUMN accdetail_allocation_reference TYPE char(20);
  ALTER TABLE public.accdetail ALTER COLUMN accdetail_invoice_number       TYPE char(20);
  ALTER TABLE public.accdetail ALTER COLUMN accdetail_final_invoice_number TYPE char(20);
  ALTER TABLE public.accdetail ALTER COLUMN accdetail_cr_dr_number         TYPE char(20);
  ALTER TABLE public.accdetail ALTER COLUMN accdetail_expense_number       TYPE char(20);

  -- STEP 3: Record migration
  INSERT INTO public.schema_migrations (script_name) VALUES ('0022_accdetail_fields_widen');
  RAISE NOTICE 'Migration 0022 applied successfully.';
END;
$$;

CREATE OR REPLACE VIEW public.bal_anal_view AS
 WITH base AS (
         SELECT 'NV Group Sopex SA'::text AS database_company,
            accdetail.accperiod,
            accdetail.ledgernum,
            accsummary.leddate AS entry_date,
                CASE
                    WHEN accdetail.accdetail_final_invoice_number IS NOT NULL THEN ( SELECT final_invoice.posted_date
                       FROM final_invoice
                      WHERE final_invoice.final_invoice_number = accdetail.accdetail_final_invoice_number AND final_invoice.posted_ledref = accdetail.ledgernum)
                    WHEN accdetail.accdetail_invoice_number IS NOT NULL AND accdetail.accdetail_final_invoice_number IS NULL THEN ( SELECT invoice.posted_date
                       FROM invoice
                      WHERE invoice.invoice_number = accdetail.accdetail_invoice_number AND invoice.posted_ledref = accdetail.ledgernum)
                    WHEN accdetail.accdetail_expense_number IS NOT NULL THEN ( SELECT expenses_summary.posted_date
                       FROM expenses_summary
                      WHERE expenses_summary.expense_number = accdetail.accdetail_expense_number AND expenses_summary.posted_ledref = accdetail.ledgernum)
                    ELSE NULL::date
                END AS posted_date_temp,
            accsummary.company,
            COALESCE(
                CASE
                    WHEN accdetail.accdetail_expense_number IS NOT NULL THEN ( SELECT expenses_summary.expense_note_type
                       FROM expenses_summary
                      WHERE expenses_summary.expense_number = accdetail.accdetail_expense_number AND expenses_summary.client = accsummary.an_client AND expenses_summary.posted_ledref = accdetail.ledgernum)
                    ELSE NULL::bpchar
                END, 'ALL_JOURNALS'::bpchar) AS temporary_postings_journal,
            accdetail.ledamt AS original_amount,
            accdetail.house_rate,
                CASE
                    WHEN currency.ratetype = 'M'::bpchar THEN accdetail.ledamt * accdetail.house_rate
                    ELSE accdetail.ledamt / accdetail.house_rate
                END AS base_amount,
            accdetail.comments AS description,
            accdetail.accdetail_invoice_number AS invoice_number,
            accdetail.accdetail_final_invoice_number AS final_invoice_number,
            accdetail.accdetail_expense_number AS expense_number,
            accdetail.accdetail_reserves_type AS expense_type,
            accsummary.prov_inv_no AS navision_invoice_number,
            accdetail.accdetail_allocation_reference AS allocation_reference,
            allocation.commodity_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            accdetail.nominal
           FROM accsummary
             CROSS JOIN currency
             JOIN accdetail ON accsummary.accperiod = accdetail.accperiod AND accsummary.ledgernum = accdetail.ledgernum
             LEFT JOIN allocation ON accdetail.accdetail_allocation_reference = allocation.allocation_reference
          WHERE accdetail.currency = currency.code AND (accdetail.accdetail_invoice_flag = ANY (ARRAY['PI'::bpchar, 'PF'::bpchar, 'EXP'::bpchar, 'SI'::bpchar, 'SF'::bpchar]))
        ), with_posted_date AS (
         SELECT base.database_company,
            base.accperiod,
            base.ledgernum,
            base.entry_date,
            base.posted_date_temp,
            base.company,
            base.temporary_postings_journal,
            base.original_amount,
            base.house_rate,
            base.base_amount,
            base.description,
            base.invoice_number,
            base.final_invoice_number,
            base.expense_number,
            base.expense_type,
            base.navision_invoice_number,
            base.allocation_reference,
            base.commodity_type,
            base.allocation_completed,
            base.allocation_completed_date,
            base.nominal,
            COALESCE(base.posted_date_temp, base.entry_date) AS posted_date
           FROM base
        ), with_journal AS (
         SELECT with_posted_date.database_company,
            with_posted_date.accperiod,
            with_posted_date.ledgernum,
            with_posted_date.entry_date,
            with_posted_date.posted_date_temp,
            with_posted_date.company,
            with_posted_date.temporary_postings_journal,
            with_posted_date.original_amount,
            with_posted_date.house_rate,
            with_posted_date.base_amount,
            with_posted_date.description,
            with_posted_date.invoice_number,
            with_posted_date.final_invoice_number,
            with_posted_date.expense_number,
            with_posted_date.expense_type,
            with_posted_date.navision_invoice_number,
            with_posted_date.allocation_reference,
            with_posted_date.commodity_type,
            with_posted_date.allocation_completed,
            with_posted_date.allocation_completed_date,
            with_posted_date.nominal,
            with_posted_date.posted_date,
                CASE
                    WHEN with_posted_date.temporary_postings_journal = '490'::bpchar THEN 'Futures'::text
                    ELSE 'Physical'::text
                END AS posting_journal
           FROM with_posted_date
        )
 SELECT with_journal.database_company,
    with_journal.accperiod,
    with_journal.ledgernum,
    with_journal.entry_date,
    with_journal.posted_date_temp,
    with_journal.posted_date,
    with_journal.company,
    '60'::text AS nominal_order_flag,
    with_journal.temporary_postings_journal,
    with_journal.posting_journal,
    with_journal.original_amount,
    with_journal.house_rate,
    with_journal.base_amount,
    with_journal.description,
    with_journal.invoice_number,
    with_journal.final_invoice_number,
    with_journal.expense_number,
    with_journal.expense_type,
    with_journal.navision_invoice_number,
    with_journal.allocation_reference,
    with_journal.commodity_type,
    with_journal.allocation_completed,
    with_journal.allocation_completed_date
   FROM with_journal
  WHERE with_journal.nominal ~~ '60%'::text
UNION ALL
 SELECT with_journal.database_company,
    with_journal.accperiod,
    with_journal.ledgernum,
    with_journal.entry_date,
    with_journal.posted_date_temp,
    with_journal.posted_date,
    with_journal.company,
    '70'::text AS nominal_order_flag,
    with_journal.temporary_postings_journal,
    with_journal.posting_journal,
    with_journal.original_amount,
    with_journal.house_rate,
    with_journal.base_amount,
    with_journal.description,
    with_journal.invoice_number,
    with_journal.final_invoice_number,
    with_journal.expense_number,
    with_journal.expense_type,
    with_journal.navision_invoice_number,
    with_journal.allocation_reference,
    with_journal.commodity_type,
    with_journal.allocation_completed,
    with_journal.allocation_completed_date
   FROM with_journal
  WHERE with_journal.nominal ~~ '70%'::text;;


CREATE OR REPLACE VIEW public.clt_accbals_view AS
 SELECT accsummary.company,
    accsummary.pcentre,
    accdetail.client,
    accdetail.currency,
    sum(accdetail.ledamt) AS balance
   FROM accsummary,
    accdetail
  WHERE accsummary.accperiod = accdetail.accperiod AND accsummary.ledgernum = accdetail.ledgernum AND accdetail.client IS NOT NULL
  GROUP BY accsummary.company, accsummary.pcentre, accdetail.client, accdetail.currency;;


CREATE OR REPLACE VIEW public.clt_accbals_view_no_pcentre AS
 SELECT accsummary.company,
    accdetail.client,
    accdetail.currency,
    sum(accdetail.ledamt) AS balance
   FROM accsummary,
    accdetail
  WHERE accsummary.accperiod = accdetail.accperiod AND accsummary.ledgernum = accdetail.ledgernum AND accdetail.client IS NOT NULL
  GROUP BY accsummary.company, accdetail.client, accdetail.currency;;


CREATE OR REPLACE VIEW public.forecast_report_outbooked_p_expenses_view AS
 SELECT '02'::text AS order_flag,
    'P Contract:'::text AS order_label,
    allocation.allocation_reference,
    accsummary.company AS allocation_company,
    accsummary.pcentre AS allocation_pcentre,
    accsummary.an_commodity AS allocation_commodity,
    accsummary.an_commodtype AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM allocation_history
          WHERE allocation_history.allocation_reference = allocation.allocation_reference AND allocation_history.hist_type = 'AN'::bpchar) AS allocation_date,
    ( SELECT sum(sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM allocated_contracts a_c,
            sub_contracts s_c,
            master_contracts m_c
          WHERE allocated_contracts.allocation_reference = a_c.allocation_reference AND s_c.contno = a_c.contno AND a_c.split = s_c.split AND s_c.contno = m_c.contno AND m_c.contract_type = 'S'::bpchar) AS allocation_total_sales_quantity,
    sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0::numeric THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    accdetail.accdetail_contno AS contno,
    accdetail.accdetail_split AS split,
    master_contracts.priceterm,
    master_contracts.contdate AS record_date,
    sub_contracts.client AS contract_client,
    '-1'::integer::numeric * sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM allocated_contracts a_c
          WHERE a_c.allocation_reference = a_c.allocation_reference AND allocated_contracts.contno = a_c.contno AND a_c.split = sub_contracts.split AND master_contracts.contract_type = 'S'::bpchar), sub_contracts.quantunit, 'MT'::bpchar) AS allocated_quantity,
        CASE
            WHEN sub_contracts.price_fixing = 'Y'::bpchar THEN sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END AS price_curr_unit,
    sub_contracts.currency,
    sub_contracts.priceunit,
        CASE
            WHEN sub_contracts.price_fixing = 'Y'::bpchar THEN sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END * ('-1'::integer::numeric * sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM allocated_contracts a_c
          WHERE a_c.allocation_reference = a_c.allocation_reference AND allocated_contracts.contno = a_c.contno AND a_c.split = sub_contracts.split AND master_contracts.contract_type = 'S'::bpchar), sub_contracts.quantunit, 'MT'::bpchar)) AS total_forecast,
        CASE
            WHEN sp_curr_getunderlying(sub_contracts.currency) = params.base_currency THEN sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END *
        CASE
            WHEN sub_contracts.price_fixing = 'Y'::bpchar THEN sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END * ('-1'::integer::numeric * sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM allocated_contracts a_c
          WHERE a_c.allocation_reference = a_c.allocation_reference AND allocated_contracts.contno = a_c.contno AND a_c.split = sub_contracts.split AND master_contracts.contract_type = 'S'::bpchar), sub_contracts.quantunit, 'MT'::bpchar)) AS total_forecast_base_curr,
    'Purch Expenses:'::text AS invoice_heading,
    '04'::text AS invoice_order,
    expenses_summary.expense_note_type AS invoice_flag,
    expenses_summary.expense_number::text || ' (OUTB)'::text AS invoice_number,
    accsummary.leddate AS invoice_date,
    expenses_summary.client AS invoice_client,
    (expenses_detail.description::text || '                   '::text) || accdetail.ledgernum::text AS invoice_text,
    NULL::numeric AS invoiced_quantity,
    NULL::text AS invoice_unit_price,
    accdetail.currency AS invoice_currency,
    NULL::text AS invoice_priceunit,
    accdetail.ledamt AS invoice_value,
        CASE
            WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
            ELSE accdetail.ledamt
        END AS signed_invoice_value,
    accsummary.leddate AS posted_date,
        CASE
            WHEN currency.ratetype = 'D'::bpchar THEN
            CASE
                WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                ELSE accdetail.ledamt
            END / expenses_summary.house_rate
            ELSE
            CASE
                WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                ELSE accdetail.ledamt
            END * expenses_summary.house_rate
        END AS posted_invoice_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
    expenses_summary.house_rate AS invoice_house_rate,
        CASE
            WHEN sp_curr_getunderlying(sub_contracts.currency) = params.base_currency THEN sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor,
    0 AS manual_outb_expense_amount,
    expenses_detail.charges_line::text AS merged_line_splitter,
    allocation.suggest_completed,
    ( SELECT string_agg(DISTINCT s_c.origin::text, ' '::text) AS string_agg
           FROM sub_contracts s_c,
            allocated_contracts a_c
          WHERE a_c.allocation_reference = allocation.allocation_reference AND a_c.contno = s_c.contno AND a_c.split = s_c.split) AS origin
   FROM accsummary
     JOIN accdetail ON accsummary.accperiod = accdetail.accperiod AND accsummary.ledgernum = accdetail.ledgernum
     JOIN allocation ON allocation.allocation_reference = accdetail.accdetail_allocation_reference
     JOIN allocated_contracts ON allocation.allocation_reference = allocated_contracts.allocation_reference AND allocated_contracts.contno = accdetail.accdetail_contno AND allocated_contracts.split = accdetail.accdetail_split
     JOIN sub_contracts ON sub_contracts.contno = allocated_contracts.contno AND sub_contracts.split = allocated_contracts.split AND sub_contracts.contno = accdetail.accdetail_contno AND sub_contracts.split = accdetail.accdetail_split
     JOIN master_contracts ON sub_contracts.contno = master_contracts.contno
     JOIN expenses_summary ON accdetail.accdetail_expense_number = expenses_summary.expense_number AND accsummary.an_client = expenses_summary.client
     JOIN expenses_detail ON expenses_summary.expense_number = expenses_detail.expense_number AND expenses_summary.client = expenses_detail.client AND expenses_detail.charges_line = accdetail.accdetail_charges_line AND expenses_detail.expense_type = accdetail.accdetail_reserves_type AND expenses_detail.contno = sub_contracts.contno AND expenses_detail.split = sub_contracts.split
     JOIN currency ON expenses_summary.currency = currency.code
     CROSS JOIN params
  WHERE accdetail.accdetail_invoice_flag = 'EXP'::bpchar AND master_contracts.contract_type = 'P'::bpchar AND (accdetail.nominal ~~ '6%'::text OR accdetail.nominal ~~ '7%'::text) AND accdetail.caja_project = 'OUTB'::bpchar AND allocation.allocation_reference !~~ '81200%'::text
UNION ALL
 SELECT '02'::text AS order_flag,
    'P Contract:'::text AS order_label,
    allocation.allocation_reference,
    allocation.company AS allocation_company,
    allocation.pcentre AS allocation_pcentre,
    allocation.commodity AS allocation_commodity,
    COALESCE(expenses_detail.commodity, allocation.commodity_type) AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM allocation_history
          WHERE allocation_history.allocation_reference = allocation.allocation_reference AND allocation_history.hist_type = 'AN'::bpchar) AS allocation_date,
    ( SELECT sum(sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM allocated_contracts a_c,
            sub_contracts s_c,
            master_contracts m_c
          WHERE allocated_contracts.allocation_reference = a_c.allocation_reference AND s_c.contno = a_c.contno AND a_c.split = s_c.split AND s_c.contno = m_c.contno AND m_c.contract_type = 'S'::bpchar) AS allocation_total_sales_quantity,
    sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0::numeric THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    sub_contracts.contno,
    sub_contracts.split,
    master_contracts.priceterm,
    master_contracts.contdate AS record_date,
    sub_contracts.client AS contract_client,
    '-1'::integer::numeric * sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM allocated_contracts a_c
          WHERE allocated_contracts.allocation_reference = a_c.allocation_reference AND allocated_contracts.contno = a_c.contno AND a_c.split = sub_contracts.split AND master_contracts.contract_type = 'S'::bpchar), sub_contracts.quantunit, 'MT'::bpchar) AS allocated_quantity,
        CASE
            WHEN sub_contracts.price_fixing = 'Y'::bpchar THEN sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END AS price_curr_unit,
    sub_contracts.currency,
    sub_contracts.priceunit,
        CASE
            WHEN sub_contracts.price_fixing = 'Y'::bpchar THEN sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END * ('-1'::integer::numeric * sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM allocated_contracts a_c
          WHERE allocated_contracts.allocation_reference = a_c.allocation_reference AND allocated_contracts.contno = a_c.contno AND a_c.split = sub_contracts.split AND master_contracts.contract_type = 'S'::bpchar), sub_contracts.quantunit, 'MT'::bpchar)) AS total_forecast,
        CASE
            WHEN sp_curr_getunderlying(sub_contracts.currency) = params.base_currency THEN sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END *
        CASE
            WHEN sub_contracts.price_fixing = 'Y'::bpchar THEN sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END * ('-1'::integer::numeric * sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM allocated_contracts a_c
          WHERE allocated_contracts.allocation_reference = a_c.allocation_reference AND allocated_contracts.contno = a_c.contno AND a_c.split = sub_contracts.split AND master_contracts.contract_type = 'S'::bpchar), sub_contracts.quantunit, 'MT'::bpchar)) AS total_forecast_base_curr,
    'Purch Expenses:'::text AS invoice_heading,
    '05'::text AS invoice_order,
    expenses_summary.expense_note_type AS invoice_flag,
    expenses_summary.expense_number AS invoice_number,
    expenses_summary.posted_date AS invoice_date,
    expenses_summary.client AS invoice_client,
    expenses_detail.description AS invoice_text,
    '-1'::integer::numeric * expenses_detail.quantity AS invoiced_quantity,
    NULL::text AS invoice_unit_price,
    expenses_detail.currency AS invoice_currency,
    NULL::text AS invoice_priceunit,
        CASE
            WHEN expenses_detail.nominal_account ~~ '6%'::text OR expenses_detail.nominal_account ~~ '7%'::text THEN '-1'::integer::numeric * expenses_detail.linevalue
            ELSE sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
        END AS invoice_value,
        CASE
            WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
            ELSE
            CASE
                WHEN expenses_detail.nominal_account ~~ '6%'::text OR expenses_detail.nominal_account ~~ '7%'::text THEN '-1'::integer::numeric * expenses_detail.linevalue
                ELSE sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
            END
        END AS signed_invoice_value,
    expenses_summary.posted_date,
        CASE
            WHEN currency.ratetype = 'D'::bpchar THEN
            CASE
                WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                ELSE
                CASE
                    WHEN expenses_detail.nominal_account ~~ '6%'::text OR expenses_detail.nominal_account ~~ '7%'::text THEN '-1'::integer::numeric * expenses_detail.linevalue
                    ELSE sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                END
            END / expenses_summary.house_rate
            ELSE
            CASE
                WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                ELSE
                CASE
                    WHEN expenses_detail.nominal_account ~~ '6%'::text OR expenses_detail.nominal_account ~~ '7%'::text THEN '-1'::integer::numeric * expenses_detail.linevalue
                    ELSE sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                END
            END * expenses_summary.house_rate
        END AS posted_invoice_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
    expenses_summary.house_rate AS invoice_house_rate,
        CASE
            WHEN sp_curr_getunderlying(sub_contracts.currency) = params.base_currency THEN sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor,
        CASE
            WHEN expenses_detail.nominal_account = '60002'::bpchar THEN
            CASE
                WHEN currency.ratetype = 'D'::bpchar THEN
                CASE
                    WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                    ELSE
                    CASE
                        WHEN expenses_detail.nominal_account ~~ '6%'::text OR expenses_detail.nominal_account ~~ '7%'::text THEN '-1'::integer::numeric * expenses_detail.linevalue
                        ELSE sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                    END
                END / expenses_summary.house_rate
                ELSE
                CASE
                    WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                    ELSE
                    CASE
                        WHEN expenses_detail.nominal_account ~~ '6%'::text OR expenses_detail.nominal_account ~~ '7%'::text THEN '-1'::integer::numeric * expenses_detail.linevalue
                        ELSE sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                    END
                END * expenses_summary.house_rate
            END
            ELSE 0::numeric
        END AS manual_outb_expense_amount,
    expenses_detail.charges_line::text AS merged_line_splitter,
    allocation.suggest_completed,
    ( SELECT string_agg(DISTINCT s_c.origin::text, ' '::text) AS string_agg
           FROM sub_contracts s_c,
            allocated_contracts a_c
          WHERE a_c.allocation_reference = allocation.allocation_reference AND a_c.contno = s_c.contno AND a_c.split = s_c.split) AS origin
   FROM allocation
     JOIN allocated_contracts ON allocation.allocation_reference = allocated_contracts.allocation_reference
     JOIN expenses_detail ON allocated_contracts.contno = expenses_detail.contno AND allocated_contracts.split = expenses_detail.split AND allocated_contracts.allocation_reference = expenses_detail.allocation_reference
     JOIN expenses_summary ON expenses_detail.expense_number = expenses_summary.expense_number AND expenses_detail.client = expenses_summary.client
     JOIN currency ON expenses_summary.currency = currency.code
     JOIN sub_contracts ON sub_contracts.contno = allocated_contracts.contno AND sub_contracts.split = allocated_contracts.split
     JOIN master_contracts ON sub_contracts.contno = master_contracts.contno
     CROSS JOIN params
  WHERE master_contracts.contract_type = 'P'::bpchar AND (expenses_detail.nominal_account ~~ '6%'::text OR expenses_detail.nominal_account ~~ '7%'::text) AND expenses_detail.nominal_account <> '60130'::bpchar;;


CREATE OR REPLACE VIEW public.ledlist_distinct_view AS
 SELECT DISTINCT ledgernum,
    nominal,
    client,
    currency
   FROM accdetail;;


CREATE OR REPLACE VIEW public.leds_view AS
 SELECT accsummary.accperiod,
    accsummary.ledgernum,
    accsummary.leddate,
    accsummary.journals,
    accsummary.pcentre,
    accsummary.company,
    accsummary.project,
    accsummary.duedate,
    accsummary.refno,
    accsummary.analysis1,
    accsummary.analysis2,
    accsummary.analysis3,
    accsummary.analysis4,
    accsummary.analysis5,
    accsummary.sett_batchref,
    accsummary.system_generated,
    accsummary.userid,
    accsummary.histdate,
    accsummary.histtime,
    accsummary.reversed,
    accdetail.linenum,
    accdetail.currency,
    accdetail.client,
    accdetail.nominal,
    accdetail.ledamt,
    accdetail.vatcode,
    accdetail.comments,
    accdetail.matchref,
    accdetail.exported,
    sp_cr_or_dr(accdetail.ledamt, 'C'::bpchar) AS creditamt,
    sp_cr_or_dr(accdetail.ledamt, 'D'::bpchar) AS debitamt,
    sp_c_or_d(accdetail.ledamt) AS crind,
    acctypes.type,
    accdetail.house_rate,
    nomcodes.longname AS nominalname,
    nomcodes.isdebtlist,
    nomcodes.preventfxreval,
    nomcodes.preventpost,
    accsummary.an_client,
    accsummary.an_commodity,
    accsummary.an_commodtype,
    accsummary.an_origin,
    accsummary.an_futconts,
    accsummary.an_prompt,
    accsummary.an_tradetype,
    accsummary.an_series,
    accsummary.an_allocref,
    accsummary.an_invtype,
    accsummary.an_conttype,
    accsummary.an_vessel,
        CASE
            WHEN currency.ratetype = 'M'::bpchar THEN accdetail.ledamt * accdetail.house_rate
            ELSE accdetail.ledamt / accdetail.house_rate
        END AS base_amt,
    accdetail.subsidiary
   FROM accsummary,
    accdetail,
    nomcodes,
    acctypes,
    currency
  WHERE accsummary.ledgernum = accdetail.ledgernum AND accsummary.accperiod = accdetail.accperiod AND nomcodes.code = accdetail.nominal AND currency.code = accdetail.currency AND acctypes.accnt_type = nomcodes.accnt_type;;


CREATE OR REPLACE VIEW public.nom_accbals_view AS
 SELECT accsummary.company,
    accsummary.pcentre,
    accdetail.nominal,
    accdetail.currency,
    sum(accdetail.ledamt) AS balance
   FROM accsummary,
    accdetail
  WHERE accsummary.accperiod = accdetail.accperiod AND accsummary.ledgernum = accdetail.ledgernum AND accdetail.client IS NULL
  GROUP BY accsummary.company, accsummary.pcentre, accdetail.currency, accdetail.nominal;;


