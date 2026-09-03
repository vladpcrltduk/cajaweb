-- Migration 0020: widen expenses_summary.expense_number from char(10) to char(20)
-- expense_number is part of the composite PK on expenses_summary
-- Affects tables: expenses_summary, expenses_abandoned_options_premium, expenses_breakdown,
--                 expenses_detail, expenses_payments, expenses_settlements,
--                 invoice_history, reserves_expenses
-- FK constraints: fk_expbdown_expinvc, fk_expdetl_expinvc,
--                 fk_exppay_expinvc, fk_reserves_expenses_to_expenses
-- Dependent views: bal_anal_view, expenses_month_end_reports_view,
--                  expenses_view, forecast_report_outbooked_p_expenses_view,
--                  invoice_allocation_detail_view, invoices_posted_view, invoices_view

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE script_name = '0020_expense_number_widen') THEN
    RAISE NOTICE 'Migration 0020 already applied, skipping.';
    RETURN;
  END IF;

  -- STEP 1: Drop all views that reference expenses_summary
  DROP VIEW IF EXISTS public.bal_anal_view                              CASCADE;
  DROP VIEW IF EXISTS public.expenses_month_end_reports_view           CASCADE;
  DROP VIEW IF EXISTS public.expenses_view                             CASCADE;
  DROP VIEW IF EXISTS public.forecast_report_outbooked_p_expenses_view CASCADE;
  DROP VIEW IF EXISTS public.invoice_allocation_detail_view            CASCADE;
  DROP VIEW IF EXISTS public.invoices_posted_view                      CASCADE;
  DROP VIEW IF EXISTS public.invoices_view                             CASCADE;

  -- STEP 2: Drop FK constraints
  ALTER TABLE public.expenses_breakdown DROP CONSTRAINT IF EXISTS fk_expbdown_expinvc;
  ALTER TABLE public.expenses_detail    DROP CONSTRAINT IF EXISTS fk_expdetl_expinvc;
  ALTER TABLE public.expenses_payments  DROP CONSTRAINT IF EXISTS fk_exppay_expinvc;
  ALTER TABLE public.reserves_expenses  DROP CONSTRAINT IF EXISTS fk_reserves_expenses_to_expenses;

  -- STEP 3: Widen columns
  ALTER TABLE public.expenses_summary                    ALTER COLUMN expense_number TYPE char(20);
  ALTER TABLE public.expenses_abandoned_options_premium  ALTER COLUMN expense_number TYPE char(20);
  ALTER TABLE public.expenses_breakdown                  ALTER COLUMN expense_number TYPE char(20);
  ALTER TABLE public.expenses_detail                     ALTER COLUMN expense_number TYPE char(20);
  ALTER TABLE public.expenses_payments                   ALTER COLUMN expense_number TYPE char(20);
  ALTER TABLE public.expenses_settlements                ALTER COLUMN expense_number TYPE char(20);
  ALTER TABLE public.invoice_history                     ALTER COLUMN expense_number TYPE char(20);
  ALTER TABLE public.reserves_expenses                   ALTER COLUMN expense_number TYPE char(20);

  -- STEP 4: Re-add FK constraints
  ALTER TABLE public.expenses_breakdown
    ADD CONSTRAINT fk_expbdown_expinvc
      FOREIGN KEY (client, expense_number)
      REFERENCES public.expenses_summary(client, expense_number);

  ALTER TABLE public.expenses_detail
    ADD CONSTRAINT fk_expdetl_expinvc
      FOREIGN KEY (client, expense_number)
      REFERENCES public.expenses_summary(client, expense_number)
      ON UPDATE CASCADE;

  ALTER TABLE public.expenses_payments
    ADD CONSTRAINT fk_exppay_expinvc
      FOREIGN KEY (client, expense_number)
      REFERENCES public.expenses_summary(client, expense_number);

  ALTER TABLE public.reserves_expenses
    ADD CONSTRAINT fk_reserves_expenses_to_expenses
      FOREIGN KEY (client, expense_number)
      REFERENCES public.expenses_summary(client, expense_number)
      ON UPDATE CASCADE ON DELETE CASCADE;

  -- STEP 5: Record migration
  INSERT INTO public.schema_migrations (script_name) VALUES ('0020_expense_number_widen');
  RAISE NOTICE 'Migration 0020 applied successfully.';
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


CREATE OR REPLACE VIEW public.expenses_month_end_reports_view AS
 SELECT '01'::text AS order_flag,
    'Expense Invoice:'::text AS order_label,
    allocation.allocation_reference,
    allocation.company AS allocation_company,
    allocation.pcentre AS allocation_pcentre,
    allocation.commodity AS allocation_commodity,
        CASE
            WHEN allocation.commodity = 'CC'::bpchar THEN 'Cocoa'::bpchar
            ELSE COALESCE(expenses_detail.commodity, allocation.commodity_type)
        END AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM allocation_history
          WHERE allocation_history.allocation_reference = allocation.allocation_reference AND allocation_history.hist_type = 'AN'::bpchar) AS allocation_date,
    ( SELECT sum(sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM allocated_contracts a_c,
            sub_contracts s_c,
            master_contracts m_c
          WHERE a_c.allocation_reference = allocated_contracts.allocation_reference AND s_c.contno = a_c.contno AND a_c.split = s_c.split AND s_c.contno = m_c.contno AND m_c.contract_type = 'S'::bpchar) AS allocation_total_sales_quantity,
    sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0::numeric THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    allocated_contracts.contno,
    allocated_contracts.split,
    master_contracts.priceterm,
    master_contracts.contdate AS contract_date,
        CASE
            WHEN master_contracts.contract_type = 'P'::bpchar THEN 'PURCHASE'::text
            ELSE 'SALES'::text
        END AS contract_type_label,
    sub_contracts.client AS contract_client,
    '-1'::integer::numeric * (( SELECT sum(sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM allocated_contracts a_c,
            sub_contracts s_c,
            master_contracts m_c
          WHERE a_c.allocation_reference = allocated_contracts.allocation_reference AND s_c.contno = a_c.contno AND a_c.split = s_c.split AND s_c.contno = m_c.contno AND m_c.contract_type = 'S'::bpchar)) AS allocated_quantity,
    expenses_summary.expense_note_type AS expense_journal,
    expenses_summary.expense_number,
    expenses_summary.client AS expense_client,
    expenses_summary.description AS expense_description,
    expenses_detail.expense_type,
    sp_allocation_retrieve_sales_priceterms(allocation.allocation_reference) AS sales_priceterm,
    expenses_detail.description AS expense_text,
    expenses_detail.nominal_account AS expense_nominal,
    expenses_summary.currency AS expense_currency,
        CASE
            WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
            ELSE expenses_detail.linevalue * '-1'::integer::numeric
        END AS expense_value,
    expenses_detail.quantity,
    expenses_summary.posted_date,
    expenses_summary.house_rate AS expenses_house_rate,
        CASE
            WHEN currency.ratetype = 'D'::bpchar THEN
            CASE
                WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                ELSE expenses_detail.linevalue * '-1'::integer::numeric
            END / expenses_summary.house_rate
            ELSE
            CASE
                WHEN expenses_summary.posted_ledref IS NULL THEN 0::numeric
                ELSE expenses_detail.linevalue * '-1'::integer::numeric
            END * expenses_summary.house_rate
        END AS base_expense_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
        CASE
            WHEN sp_curr_getunderlying(sub_contracts.currency) = params.base_currency THEN sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor
   FROM allocation
     JOIN allocated_contracts ON allocation.allocation_reference = allocated_contracts.allocation_reference
     JOIN sub_contracts ON sub_contracts.contno = allocated_contracts.contno AND sub_contracts.split = allocated_contracts.split
     JOIN master_contracts ON sub_contracts.contno = master_contracts.contno
     JOIN expenses_detail ON expenses_detail.contno = sub_contracts.contno AND expenses_detail.split = sub_contracts.split AND expenses_detail.allocation_reference = allocation.allocation_reference
     JOIN expenses_summary ON expenses_summary.expense_number = expenses_detail.expense_number AND expenses_summary.client = expenses_detail.client
     JOIN currency ON expenses_summary.currency = currency.code
     CROSS JOIN params
UNION ALL
 SELECT '02'::text AS order_flag,
    'Final Invoice:'::text AS order_label,
    allocation.allocation_reference,
    allocation.company AS allocation_company,
    allocation.pcentre AS allocation_pcentre,
    allocation.commodity AS allocation_commodity,
        CASE
            WHEN allocation.commodity = 'CC'::bpchar THEN 'Cocoa'::bpchar
            ELSE allocation.commodity_type
        END AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM allocation_history
          WHERE allocation_history.allocation_reference = allocation.allocation_reference AND allocation_history.hist_type = 'AN'::bpchar) AS allocation_date,
    ( SELECT sum(sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM allocated_contracts a_c,
            sub_contracts s_c,
            master_contracts m_c
          WHERE a_c.allocation_reference = allocated_contracts.allocation_reference AND s_c.contno = a_c.contno AND a_c.split = s_c.split AND s_c.contno = m_c.contno AND m_c.contract_type = 'S'::bpchar) AS allocation_total_sales_quantity,
    sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0::numeric THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    allocated_contracts.contno,
    allocated_contracts.split,
    master_contracts.priceterm,
    master_contracts.contdate AS contract_date,
        CASE
            WHEN master_contracts.contract_type = 'P'::bpchar THEN 'PURCHASE'::text
            ELSE 'SALES'::text
        END AS contract_type_label,
    sub_contracts.client AS contract_client,
    '-1'::integer::numeric * (( SELECT sum(sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM allocated_contracts a_c,
            sub_contracts s_c,
            master_contracts m_c
          WHERE a_c.allocation_reference = allocated_contracts.allocation_reference AND s_c.contno = a_c.contno AND a_c.split = s_c.split AND s_c.contno = m_c.contno AND m_c.contract_type = 'S'::bpchar)) AS allocated_quantity,
    final_invoice.final_invoice_journal AS expense_journal,
    final_invoice.final_invoice_number AS expense_number,
    final_invoice.client AS expense_client,
    final_invoice.notes AS expense_description,
    'FINV'::bpchar AS expense_type,
    sp_allocation_retrieve_sales_priceterms(allocation.allocation_reference) AS sales_priceterm,
    'Final Invoice for invoice '::text || final_invoice.invoice_number::text AS expense_text,
    final_invoice_details_2.nomcode AS expense_nominal,
    final_invoice.invoice_currency AS expense_currency,
        CASE
            WHEN final_invoice.posted_ledref IS NULL THEN 0::numeric
            ELSE final_invoice_details_2.net_due_partial
        END AS expense_value,
    final_invoice_details_2.invoiced_quantity AS quantity,
    final_invoice.posted_date,
    final_invoice.house_rate AS expenses_house_rate,
        CASE
            WHEN currency.ratetype = 'D'::bpchar THEN
            CASE
                WHEN final_invoice.posted_ledref IS NULL THEN 0::numeric
                ELSE final_invoice_details_2.net_due_partial
            END / final_invoice.house_rate
            ELSE
            CASE
                WHEN final_invoice.posted_ledref IS NULL THEN 0::numeric
                ELSE final_invoice_details_2.net_due_partial
            END * final_invoice.house_rate
        END AS base_expense_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
        CASE
            WHEN sp_curr_getunderlying(sub_contracts.currency) = params.base_currency THEN sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor
   FROM allocation
     JOIN allocated_contracts ON allocation.allocation_reference = allocated_contracts.allocation_reference
     JOIN sub_contracts ON sub_contracts.contno = allocated_contracts.contno AND sub_contracts.split = allocated_contracts.split
     JOIN master_contracts ON sub_contracts.contno = master_contracts.contno
     JOIN final_invoice_details_2 ON final_invoice_details_2.contno = sub_contracts.contno AND final_invoice_details_2.split = sub_contracts.split AND final_invoice_details_2.allocation_reference = allocation.allocation_reference
     JOIN final_invoice ON final_invoice.invoice_number = final_invoice_details_2.invoice_number AND final_invoice.invoice_type = final_invoice_details_2.invoice_type AND final_invoice.client = final_invoice_details_2.client
     JOIN currency ON final_invoice.invoice_currency = currency.code
     CROSS JOIN params;;


CREATE OR REPLACE VIEW public.expenses_view AS
 SELECT params.systemdate,
    params.coname AS our_name,
    params.colongname AS our_longname,
    params.invoice_end_clause,
    clause.longname AS invoice_end_clause_longname,
        CASE
            WHEN company.addr1 IS NULL THEN ''::character varying
            ELSE company.addr1
        END AS our_addr1,
        CASE
            WHEN company.addr2 IS NULL THEN ''::character varying
            ELSE company.addr2
        END AS our_addr2,
        CASE
            WHEN company.addr3 IS NULL THEN ''::character varying
            ELSE company.addr3
        END AS our_addr3,
        CASE
            WHEN company.addr4 IS NULL THEN ''::character varying
            ELSE company.addr4
        END AS our_addr4,
        CASE
            WHEN company.addr5 IS NULL THEN ''::character varying
            ELSE company.addr5
        END AS our_addr5,
        CASE
            WHEN company.addr6 IS NULL THEN ''::character varying
            ELSE company.addr6
        END AS our_addr6,
        CASE
            WHEN company.vatno IS NULL THEN ''::character varying
            ELSE company.vatno
        END AS our_vatno,
        CASE
            WHEN company.regno IS NULL THEN ''::character varying
            ELSE company.regno
        END AS our_regno,
    client.name AS client_name,
    client.longname AS client_longname,
        CASE
            WHEN client.addr1 IS NULL THEN ''::character varying
            ELSE client.addr1
        END AS client_addr1,
        CASE
            WHEN client.addr2 IS NULL THEN ''::character varying
            ELSE client.addr2
        END AS client_addr2,
        CASE
            WHEN client.addr3 IS NULL THEN ''::character varying
            ELSE client.addr3
        END AS client_addr3,
        CASE
            WHEN client.addr4 IS NULL THEN ''::character varying
            ELSE client.addr4
        END AS client_addr4,
        CASE
            WHEN client.addr5 IS NULL THEN ''::character varying
            ELSE client.addr5
        END AS client_addr5,
        CASE
            WHEN client.addr6 IS NULL THEN ''::character varying
            ELSE client.addr6
        END AS client_addr6,
        CASE
            WHEN client.vatno IS NULL THEN ''::character varying
            ELSE client.vatno
        END AS client_vatno,
    expenses_summary.allocation_reference,
    expenses_summary.client,
    expenses_summary.expense_number,
    expenses_summary.expense_date,
    expenses_summary.company,
    expenses_summary.pcentre,
    expenses_summary.commodity,
    expenses_summary.commodtype,
    expenses_summary.origin,
    expenses_summary.expense_type AS expense_inv_type,
    expenses_summary.due_date,
    expenses_summary.posted_date,
    expenses_summary.posted_ledref,
    expenses_summary.total_value,
    expenses_summary.currency,
    expenses_summary.payment_instruction,
    payment_instruction.name AS payinstruct_name,
    payment_instruction.longname AS payinstruct_longname,
    expenses_summary.crdrind,
    expenses_summary.description,
    expenses_summary.pay_amount,
    expenses_summary.pay_date,
    expenses_summary.pay_ledref,
    expenses_detail.expense_type,
    reserves_types.name AS reserve_name,
    reserves_types.longname AS reserve_longname,
    expenses_detail.crdrindicator,
    expenses_detail.amount_indicator,
    expenses_detail.amount,
    expenses_detail.currency AS exp_currency,
    expenses_detail.price_unit,
    expenses_detail.exchange_rate,
    expenses_detail.nominal_account,
    expenses_detail.description AS det_description,
    expenses_detail.linevalue
   FROM params
     CROSS JOIN expenses_summary
     CROSS JOIN expenses_detail
     LEFT JOIN clause ON params.invoice_end_clause = clause.code
     LEFT JOIN reserves_types ON expenses_detail.expense_type = reserves_types.code
     LEFT JOIN client ON expenses_summary.client = client.code
     LEFT JOIN payment_instruction ON expenses_summary.payment_instruction = payment_instruction.code
     LEFT JOIN company ON expenses_summary.company = company.code
  WHERE expenses_summary.client = expenses_detail.client AND expenses_summary.expense_number = expenses_detail.expense_number;;


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


CREATE OR REPLACE VIEW public.invoice_allocation_detail_view AS
 SELECT '1'::text AS invtyp,
    a.allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    NULL::bpchar AS crdrnum,
    NULL::text AS crdrclnt,
    a.invoice_currency AS invcurr,
    a.invoice_value AS invamt,
    a.total_tonnage AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM invoice a
  WHERE a.invoice_type = 'P'::bpchar OR a.invoice_type = 'S'::bpchar
UNION
 SELECT '2'::text AS invtyp,
    ( SELECT b.allocation_reference
           FROM invoice b
          WHERE b.invoice_type = a.invoice_type AND b.client = a.client AND b.invoice_number = a.invoice_number) AS allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    a.final_invoice_number AS crdrnum,
    NULL::text AS crdrclnt,
    a.invoice_currency AS invcurr,
    a.net_due AS invamt,
    NULL::numeric AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM final_invoice a
UNION
 SELECT '3'::text AS invtyp,
    a.allocation_reference,
    NULL::bpchar AS invpors,
    a.expense_number AS invnum,
    a.expense_date AS invdate,
    a.client AS invclnt,
    NULL::bpchar AS crdrnum,
    NULL::text AS crdrclnt,
    a.currency AS invcurr,
    a.total_value AS invamt,
    NULL::numeric AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM expenses_summary a
UNION
 SELECT '4'::text AS invtyp,
    ( SELECT b.allocation_reference
           FROM invoice b
          WHERE b.invoice_type = a.invoice_type AND b.client = a.client AND b.invoice_number = a.invoice_number) AS allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    a.crdr_number AS crdrnum,
    a.crdr_client AS crdrclnt,
    a.currency AS invcurr,
    a.total_value AS invamt,
    NULL::numeric AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM creditdebit_note a
UNION
 SELECT '5'::text AS invtyp,
    a.allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    NULL::bpchar AS crdrnum,
    NULL::text AS crdrclnt,
    a.invoice_currency AS invcurr,
    a.invoice_value AS invamt,
    a.total_tonnage AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM invoice a
  WHERE a.invoice_type = 'W'::bpchar;;


CREATE OR REPLACE VIEW public.invoices_posted_view AS
 SELECT invoice.invoice_number AS inv_no,
    '1. Provisional Invoices'::text AS inv_flag,
        CASE
            WHEN invoice.invoice_type = 'P'::bpchar THEN 'Purchases'::text
            ELSE
            CASE
                WHEN invoice.invoice_type = 'S'::bpchar THEN 'Sales'::text
                ELSE 'Washouts'::text
            END
        END AS inv_type,
    invoice.client AS inv_client,
    invoice.invoice_date AS inv_date,
    invoice.due_date AS inv_due_date,
    invoice.commodity,
    invoice.commodity_type,
    invoice.origin,
    invoice.quality,
    invoice.invoice_value AS inv_value,
    invoice.invoice_currency AS inv_currency
   FROM invoice
  WHERE invoice.posted_ledref IS NOT NULL
UNION
 SELECT final_invoice.invoice_number AS inv_no,
    '2. Final Invoices'::text AS inv_flag,
        CASE
            WHEN final_invoice.invoice_type = 'P'::bpchar THEN 'Purchases'::text
            ELSE 'Sales'::text
        END AS inv_type,
    final_invoice.client AS inv_client,
    final_invoice.invoice_date AS inv_date,
    final_invoice.due_date AS inv_due_date,
    final_invoice.commodity,
    final_invoice.commodity_type,
    final_invoice.origin,
    ' '::bpchar AS quality,
    final_invoice.net_due AS inv_value,
    final_invoice.invoice_currency AS inv_currency
   FROM final_invoice
  WHERE final_invoice.posted_ledref IS NOT NULL
UNION
 SELECT creditdebit_note.crdr_number AS inv_no,
    '3. Credit/Debit Notes'::text AS inv_flag,
        CASE
            WHEN creditdebit_note.invoice_type = 'P'::bpchar THEN 'Purchases'::text
            ELSE
            CASE
                WHEN creditdebit_note.invoice_type = 'S'::bpchar THEN 'Sales'::text
                ELSE 'Washouts'::text
            END
        END AS inv_type,
    creditdebit_note.client AS inv_client,
    creditdebit_note.invoice_date AS inv_date,
    creditdebit_note.due_date AS inv_due_date,
    creditdebit_note.commodity,
    creditdebit_note.commodtype AS commodity_type,
    creditdebit_note.origin,
    ' '::bpchar AS quality,
    creditdebit_note.total_value AS inv_value,
    creditdebit_note.currency AS inv_currency
   FROM creditdebit_note
  WHERE creditdebit_note.posted_ledref IS NOT NULL
UNION
 SELECT expenses_summary.expense_number AS inv_no,
    '4. Expense Notes'::text AS inv_flag,
    ' '::text AS inv_type,
    expenses_summary.client AS inv_client,
    expenses_summary.expense_date AS inv_date,
    expenses_summary.due_date AS inv_due_date,
    expenses_summary.commodity,
    expenses_summary.commodtype AS commodity_type,
    expenses_summary.origin,
    ' '::bpchar AS quality,
    expenses_summary.total_value AS inv_value,
    expenses_summary.currency AS inv_currency
   FROM expenses_summary
  WHERE expenses_summary.posted_ledref IS NOT NULL;;


CREATE OR REPLACE VIEW public.invoices_view AS
 SELECT 'Provisional'::text AS type,
    invoice.company,
    invoice.pcentre,
    invoice.commodity,
    invoice.commodity_type,
    invoice.origin,
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.invoice_date,
    invoice.client,
    client.longname,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.description,
        CASE
            WHEN invoice.posted_ledref IS NULL THEN 'N'::text
            ELSE 'Y'::text
        END AS posted
   FROM invoice,
    client
  WHERE invoice.client = client.code
UNION ALL
 SELECT 'Final'::text AS type,
    final_invoice.company,
    final_invoice.pcentre,
    final_invoice.commodity,
    final_invoice.commodity_type,
    final_invoice.origin,
    final_invoice.invoice_number,
    final_invoice.invoice_type,
    final_invoice.invoice_date,
    final_invoice.client,
    client.longname,
    final_invoice.net_due AS invoice_value,
    final_invoice.invoice_currency,
    final_invoice.description,
        CASE
            WHEN final_invoice.posted_ledref IS NULL THEN 'N'::text
            ELSE 'Y'::text
        END AS posted
   FROM final_invoice,
    client
  WHERE final_invoice.client = client.code
UNION ALL
 SELECT 'Expense'::text AS type,
    expenses_summary.company,
    expenses_summary.pcentre,
    expenses_summary.commodity,
    expenses_summary.commodtype AS commodity_type,
    expenses_summary.origin,
    expenses_summary.expense_number AS invoice_number,
    expenses_summary.expense_type AS invoice_type,
    expenses_summary.expense_date AS invoice_date,
    expenses_summary.client,
    client.longname,
    expenses_summary.total_value AS invoice_value,
    expenses_summary.currency AS invoice_currency,
    expenses_summary.description,
        CASE
            WHEN expenses_summary.posted_ledref IS NULL THEN 'N'::text
            ELSE 'Y'::text
        END AS posted
   FROM expenses_summary,
    client
  WHERE expenses_summary.client = client.code
UNION ALL
 SELECT 'Cr/Dr Note '::text AS type,
    creditdebit_note.company,
    creditdebit_note.pcentre,
    creditdebit_note.commodity,
    creditdebit_note.commodtype AS commodity_type,
    creditdebit_note.origin,
    creditdebit_note.invoice_number,
    creditdebit_note.invoice_type,
    creditdebit_note.invoice_date,
    creditdebit_note.client,
    client.longname,
    creditdebit_note.total_value AS invoice_value,
    creditdebit_note.currency AS invoice_currency,
    creditdebit_note.description,
        CASE
            WHEN creditdebit_note.posted_ledref IS NULL THEN 'N'::text
            ELSE 'Y'::text
        END AS posted
   FROM creditdebit_note,
    client
  WHERE creditdebit_note.client = client.code;;


