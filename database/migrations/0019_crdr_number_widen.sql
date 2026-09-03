-- Migration 0019: widen creditdebit_note.crdr_number from char(10) to char(20)
-- crdr_number is part of the composite PK on creditdebit_note
-- Affects tables: creditdebit_note, crdr_note_details, crdr_note_payments,
--                 invoice_history, logistics_invoice_reminders, reserves_crdr
-- FK constraints: fk_crdrdet_crdrnote, fk_crdrpaym_crdrnote,
--                 fk_logistics_invoice_reminders_creditdebit_note, fk_reserves_crdr_crdr
-- Views: crdrnote_view, invoice_allocation_detail_view, invoices_posted_view, invoices_view

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE script_name = '0019_crdr_number_widen') THEN
    RAISE NOTICE 'Migration 0019 already applied, skipping.';
    RETURN;
  END IF;

  -- STEP 1: Drop dependent views
  DROP VIEW IF EXISTS public.crdrnote_view                 CASCADE;
  DROP VIEW IF EXISTS public.invoice_allocation_detail_view CASCADE;
  DROP VIEW IF EXISTS public.invoices_posted_view          CASCADE;
  DROP VIEW IF EXISTS public.invoices_view                 CASCADE;

  -- STEP 2: Drop FK constraints
  ALTER TABLE public.crdr_note_details           DROP CONSTRAINT IF EXISTS fk_crdrdet_crdrnote;
  ALTER TABLE public.crdr_note_payments          DROP CONSTRAINT IF EXISTS fk_crdrpaym_crdrnote;
  ALTER TABLE public.logistics_invoice_reminders DROP CONSTRAINT IF EXISTS fk_logistics_invoice_reminders_creditdebit_note;
  ALTER TABLE public.reserves_crdr               DROP CONSTRAINT IF EXISTS fk_reserves_crdr_crdr;

  -- STEP 3: Widen columns
  ALTER TABLE public.creditdebit_note            ALTER COLUMN crdr_number TYPE char(20);
  ALTER TABLE public.crdr_note_details           ALTER COLUMN crdr_number TYPE char(20);
  ALTER TABLE public.crdr_note_payments          ALTER COLUMN crdr_number TYPE char(20);
  ALTER TABLE public.invoice_history             ALTER COLUMN crdr_number TYPE char(20);
  ALTER TABLE public.logistics_invoice_reminders ALTER COLUMN crdr_number TYPE char(20);
  ALTER TABLE public.reserves_crdr               ALTER COLUMN crdr_number TYPE char(20);

  -- STEP 4: Re-add FK constraints
  ALTER TABLE public.crdr_note_details
    ADD CONSTRAINT fk_crdrdet_crdrnote
      FOREIGN KEY (invoice_type, client, invoice_number, crdr_number)
      REFERENCES public.creditdebit_note(invoice_type, client, invoice_number, crdr_number);

  ALTER TABLE public.crdr_note_payments
    ADD CONSTRAINT fk_crdrpaym_crdrnote
      FOREIGN KEY (invoice_type, client, invoice_number, crdr_number)
      REFERENCES public.creditdebit_note(invoice_type, client, invoice_number, crdr_number);

  ALTER TABLE public.logistics_invoice_reminders
    ADD CONSTRAINT fk_logistics_invoice_reminders_creditdebit_note
      FOREIGN KEY (provisional_invoice_type, provisional_invoice_client, provisional_invoice_number, crdr_number)
      REFERENCES public.creditdebit_note(invoice_type, client, invoice_number, crdr_number)
      ON DELETE SET NULL;

  ALTER TABLE public.reserves_crdr
    ADD CONSTRAINT fk_reserves_crdr_crdr
      FOREIGN KEY (invoice_type, client, invoice_number, crdr_number)
      REFERENCES public.creditdebit_note(invoice_type, client, invoice_number, crdr_number)
      ON UPDATE CASCADE ON DELETE CASCADE;

  -- STEP 5: Record migration
  INSERT INTO public.schema_migrations (script_name) VALUES ('0019_crdr_number_widen');
  RAISE NOTICE 'Migration 0019 applied successfully.';
END;
$$;

CREATE OR REPLACE VIEW public.crdrnote_view AS
 SELECT params.systemdate,
    params.coname AS our_name,
    params.colongname AS our_longname,
        CASE
            WHEN params.coaddr1 IS NULL THEN ''::character varying
            ELSE params.coaddr1
        END AS our_addr1,
        CASE
            WHEN params.coaddr2 IS NULL THEN ''::character varying
            ELSE params.coaddr2
        END AS our_addr2,
        CASE
            WHEN params.coaddr3 IS NULL THEN ''::character varying
            ELSE params.coaddr3
        END AS our_addr3,
        CASE
            WHEN params.coaddr4 IS NULL THEN ''::character varying
            ELSE params.coaddr4
        END AS our_addr4,
        CASE
            WHEN params.coaddr5 IS NULL THEN ''::character varying
            ELSE params.coaddr5
        END AS our_addr5,
        CASE
            WHEN params.coaddr6 IS NULL THEN ''::character varying
            ELSE params.coaddr6
        END AS our_addr6,
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
    ( SELECT invoice.allocation_reference
           FROM invoice
          WHERE creditdebit_note.invoice_type = invoice.invoice_type AND creditdebit_note.client = invoice.client AND creditdebit_note.invoice_number = invoice.invoice_number) AS allocation_reference,
    creditdebit_note.invoice_type,
    creditdebit_note.client,
    creditdebit_note.invoice_number,
    creditdebit_note.crdr_number,
    creditdebit_note.crdr_client,
    creditdebit_note.invoice_date,
    creditdebit_note.company,
    creditdebit_note.pcentre,
    creditdebit_note.commodity,
    creditdebit_note.commodtype,
    creditdebit_note.origin,
    creditdebit_note.due_date,
    creditdebit_note.posted_date,
    creditdebit_note.posted_ledref,
    creditdebit_note.total_value,
    creditdebit_note.currency,
    creditdebit_note.payment_instruction,
    payment_instruction.name AS payinstruct_name,
    payment_instruction.longname AS payinstruct_longname,
    creditdebit_note.crdrind,
    creditdebit_note.description,
    creditdebit_note.pay_amount,
    creditdebit_note.pay_date,
    creditdebit_note.pay_ledref,
    crdr_note_details.charges_line,
    crdr_note_details.expenses_type,
    reserves_types.name AS reserve_name,
    reserves_types.longname AS reserve_longname,
    crdr_note_details.crdrindicator,
    crdr_note_details.amount,
    crdr_note_details.currency AS exp_curr,
    crdr_note_details.exchange_rate AS exrate,
        CASE
            WHEN crdr_note_details.exchange_rate <> 0::numeric AND crdr_note_details.exchange_rate IS NOT NULL THEN crdr_note_details.exchange_rate * crdr_note_details.amount
            ELSE crdr_note_details.amount
        END AS cp_crdr_curramt,
    crdr_note_details.nominal_account,
    crdr_note_details.description AS det_description,
    crdr_note_details.amount_indicator,
    crdr_note_details.linevalue,
    crdr_note_details.price_unit
   FROM params,
    creditdebit_note,
    crdr_note_details,
    client,
    payment_instruction,
    reserves_types
  WHERE creditdebit_note.invoice_type = crdr_note_details.invoice_type AND creditdebit_note.client = crdr_note_details.client AND creditdebit_note.invoice_number = crdr_note_details.invoice_number AND creditdebit_note.crdr_number = crdr_note_details.crdr_number AND crdr_note_details.expenses_type = reserves_types.code AND creditdebit_note.client = client.code AND creditdebit_note.payment_instruction = payment_instruction.code;;


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


