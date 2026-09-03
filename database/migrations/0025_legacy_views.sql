-- Migration 0025: create legacy views not included in the initial migration
-- Views are added incrementally as converted from SAP Anywhere SQL.
-- The schema_migrations record is inserted at the bottom once all views are complete.

-- ============================================================
-- View 1: account_overview_view
-- Source: dba.Account_Overview_View
-- Shows accounting journals from accsummary + accdetail with
-- peripheral data. Two UNIONs:
--   Part 1: standard entries, expense detail line breakdown
--   Part 2: alternative client nominal code entries
-- ============================================================

CREATE OR REPLACE VIEW public.account_overview_view AS

SELECT
    to_char(accsummary.leddate, 'YYYYMM') || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    to_char(accsummary.leddate, 'YYYY')                                                  AS expense_year,
    to_char(accsummary.leddate, 'MM')                                                    AS this_expense_month,
    date_trunc('month', accsummary.leddate)::date                                        AS this_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '35 days')::date                 AS next_month_some_day,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'YYYY')        AS next_month_year,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'MM')          AS next_month_month,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month')::date                 AS next_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month' - INTERVAL '1 day')::date AS this_month_last_day,
    to_char(accsummary.leddate, 'YYYY-MM')                                               AS period,
    accsummary.company,
    accsummary.leddate,
    CASE
        WHEN expenses_summary.expense_note_type IS NULL THEN
            CASE
                WHEN accsummary.fin_inv_no IS NOT NULL THEN
                    (SELECT MIN(final_invoice.final_invoice_journal)
                     FROM public.final_invoice
                     WHERE final_invoice.final_invoice_number = accsummary.fin_inv_no)
                ELSE
                    CASE WHEN accsummary.prov_inv_no IS NOT NULL THEN
                        CASE WHEN accsummary.an_invtype = 'P' THEN '210' ELSE '310' END
                    ELSE NULL END
            END
        ELSE expenses_summary.expense_note_type::text
    END AS journal,
    accdetail.nominal,
    COALESCE(expenses_summary.expense_number, accsummary.fin_inv_no, accsummary.prov_inv_no, accsummary.ledgernum) AS document_number,
    COALESCE(expenses_detail.description, expenses_summary.description, accdetail.comments) AS description,
    CASE WHEN accdetail.ledamt < 0 THEN accdetail.ledamt * -1 ELSE 0 END AS debit_amount_currency,
    CASE WHEN accdetail.ledamt > 0 THEN accdetail.ledamt * -1 ELSE 0 END AS credit_amount_currency,
    accdetail.currency,
    COALESCE(expenses_summary.client, accdetail.client) AS client,
    expenses_summary.due_date,
    CASE WHEN currency.ratetype = 'D'
         THEN accdetail.ledamt / accdetail.house_rate * -1
         ELSE accdetail.ledamt * accdetail.house_rate * -1
    END AS usd_amount,
    accdetail.accdetail_allocation_reference AS alloc_ref,
    accdetail.accdetail_contno               AS contno,
    accdetail.accdetail_split                AS split,
    (SELECT master_contracts.contract_type FROM public.master_contracts
     WHERE master_contracts.contno = accdetail.accdetail_contno) AS contract_type,
    allocation.commodity,
    allocation.commodity_type,
    allocation.origin,
    (SELECT master_contracts.quality FROM public.master_contracts
     WHERE master_contracts.contno = accdetail.accdetail_contno) AS quality,
    client.country AS client_country,
    CASE WHEN accsummary.prov_inv_no IS NOT NULL AND accsummary.fin_inv_no IS NULL THEN
        public.sp_sopex_get_sum_invoice_details_2_quantity_linevalue(
            'Q',
            accsummary.prov_inv_no,
            (SELECT master_contracts.contract_type FROM public.master_contracts
             WHERE master_contracts.contno = accdetail.accdetail_contno),
            accsummary.an_client,
            accdetail.accdetail_allocation_reference,
            accdetail.accdetail_contno,
            accdetail.accdetail_split
        )
    ELSE NULL END AS invoice_tonnage

FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod  = accdetail.accperiod
    AND accsummary.ledgernum  = accdetail.ledgernum
JOIN public.currency
    ON  accdetail.currency    = currency.code
LEFT JOIN public.expenses_summary
    ON  accsummary.ledgernum  = expenses_summary.posted_ledref
    AND accsummary.exp_inv_no = expenses_summary.expense_number
    AND accsummary.an_client  = expenses_summary.client
LEFT JOIN public.client
    ON  accsummary.an_client  = client.code
LEFT JOIN public.expenses_detail
    ON  expenses_summary.expense_number = expenses_detail.expense_number
    AND expenses_summary.client         = expenses_detail.client
LEFT JOIN public.allocation
    ON  accdetail.accdetail_allocation_reference = allocation.allocation_reference
LEFT JOIN public.sub_contracts
    ON  accdetail.accdetail_contno = sub_contracts.contno
    AND accdetail.accdetail_split  = sub_contracts.split
WHERE
    (expenses_detail.expense_number   IS NULL OR expenses_detail.expense_number   = accdetail.accdetail_expense_number) AND
    (expenses_detail.expense_type     IS NULL OR expenses_detail.expense_type     = accdetail.accdetail_reserves_type) AND
    (expenses_detail.charges_line     IS NULL OR expenses_detail.charges_line     = accdetail.accdetail_charges_line) AND
    (expenses_detail.nominal_account  IS NULL OR expenses_detail.nominal_account  = accdetail.nominal)

UNION ALL

SELECT
    accsummary.ledgernum AS cajano,
    to_char(accsummary.leddate, 'YYYY')                                                  AS expense_year,
    to_char(accsummary.leddate, 'MM')                                                    AS this_expense_month,
    date_trunc('month', accsummary.leddate)::date                                        AS this_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '35 days')::date                 AS next_month_some_day,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'YYYY')        AS next_month_year,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'MM')          AS next_month_month,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month')::date                 AS next_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month' - INTERVAL '1 day')::date AS this_month_last_day,
    to_char(accsummary.leddate, 'YYYY-MM')                                               AS period,
    accsummary.company,
    accsummary.leddate,
    CASE
        WHEN expenses_summary.expense_note_type IS NULL THEN
            CASE
                WHEN accsummary.fin_inv_no IS NOT NULL THEN
                    (SELECT MIN(final_invoice.final_invoice_journal)
                     FROM public.final_invoice
                     WHERE final_invoice.final_invoice_number = accsummary.fin_inv_no)
                ELSE
                    CASE WHEN accsummary.prov_inv_no IS NOT NULL THEN
                        CASE WHEN accsummary.an_invtype = 'P' THEN '210' ELSE '310' END
                    ELSE NULL END
            END
        ELSE expenses_summary.expense_note_type::text
    END AS journal,
    expenses_summary.alternative_client_nomcode AS nominal,
    COALESCE(expenses_summary.expense_number, accsummary.fin_inv_no, accsummary.prov_inv_no, accsummary.ledgernum) AS document_number,
    COALESCE(expenses_summary.description, accdetail.comments) AS description,
    CASE WHEN accdetail.ledamt < 0 THEN accdetail.ledamt * -1 ELSE 0 END AS debit_amount_currency,
    CASE WHEN accdetail.ledamt > 0 THEN accdetail.ledamt * -1 ELSE 0 END AS credit_amount_currency,
    accdetail.currency,
    COALESCE(expenses_summary.client, accdetail.client) AS client,
    expenses_summary.due_date,
    CASE WHEN currency.ratetype = 'D'
         THEN accdetail.ledamt / accdetail.house_rate * -1
         ELSE accdetail.ledamt * accdetail.house_rate * -1
    END AS usd_amount,
    NULL AS alloc_ref,
    NULL AS contno,
    NULL AS split,
    NULL AS contract_type,
    expenses_summary.commodity,
    expenses_summary.commodtype AS commodity_type,
    expenses_summary.origin,
    NULL AS quality,
    client.country AS client_country,
    NULL AS invoice_tonnage

FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod  = accdetail.accperiod
    AND accsummary.ledgernum  = accdetail.ledgernum
JOIN public.currency
    ON  accdetail.currency    = currency.code
LEFT JOIN public.expenses_summary
    ON  accsummary.ledgernum  = expenses_summary.posted_ledref
    AND accsummary.exp_inv_no = expenses_summary.expense_number
    AND accsummary.an_client  = expenses_summary.client
LEFT JOIN public.client
    ON  expenses_summary.client = client.code
WHERE
    accdetail.nominal = expenses_summary.alternative_client_nomcode AND
    accdetail.client  = expenses_summary.client;

-- ============================================================
-- View 2: accounts_60_70_overview
-- Source: dba.Accounts_60_70_Overview
-- Same structure as account_overview_view but filtered to rows
-- where accdetail.nominal starts with '60' or '70'.
-- Simpler journal column (no fin_inv_no fallback), no
-- master_contracts/client/sub_contracts joins; allocation is
-- an inner join (required by the WHERE condition).
-- ============================================================

CREATE OR REPLACE VIEW public.accounts_60_70_overview AS

SELECT
    to_char(accsummary.leddate, 'YYYY')                                                  AS entry_year,
    to_char(accsummary.leddate, 'MM')                                                    AS this_entry_month,
    date_trunc('month', accsummary.leddate)::date                                        AS this_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '35 days')::date                 AS next_month_some_day,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'YYYY')        AS next_month_year,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'MM')          AS next_month_month,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month')::date                 AS next_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month' - INTERVAL '1 day')::date AS this_month_last_day,
    to_char(accsummary.leddate, 'YYYY-MM')                                               AS period,
    accsummary.company,
    accsummary.leddate,
    expenses_summary.expense_note_type                                                   AS journal,
    accdetail.nominal,
    COALESCE(expenses_summary.expense_number, accsummary.prov_inv_no, accsummary.ledgernum) AS document_number,
    COALESCE(expenses_detail.description, expenses_summary.description, accdetail.comments) AS description,
    CASE WHEN accdetail.ledamt < 0 THEN accdetail.ledamt * -1 ELSE 0 END                AS debit_amount_currency,
    CASE WHEN accdetail.ledamt > 0 THEN accdetail.ledamt * -1 ELSE 0 END                AS credit_amount_currency,
    accdetail.currency,
    COALESCE(expenses_summary.client, accdetail.client)                                  AS client,
    expenses_summary.due_date,
    CASE WHEN currency.ratetype = 'D'
         THEN accdetail.ledamt / accdetail.house_rate * -1
         ELSE accdetail.ledamt * accdetail.house_rate * -1
    END AS usd_amount,
    accdetail.accdetail_allocation_reference AS alloc_ref,
    accdetail.accdetail_contno               AS contno,
    accdetail.accdetail_split                AS split,
    allocation.allocation_reference          AS alloc_ref_2,
    allocation.commodity_type                AS commod_type,
    allocation.allocation_completed,
    public.sp_allocation_check_if_only_stock(allocation.allocation_completed) AS stock_allocation

FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod  = accdetail.accperiod
    AND accsummary.ledgernum  = accdetail.ledgernum
JOIN public.currency
    ON  accdetail.currency    = currency.code
JOIN public.allocation
    ON  accdetail.accdetail_allocation_reference = allocation.allocation_reference
LEFT JOIN public.expenses_summary
    ON  accsummary.ledgernum  = expenses_summary.posted_ledref
    AND accsummary.exp_inv_no = expenses_summary.expense_number
    AND accsummary.an_client  = expenses_summary.client
LEFT JOIN public.expenses_detail
    ON  expenses_summary.expense_number = expenses_detail.expense_number
    AND expenses_summary.client         = expenses_detail.client
WHERE
    (expenses_detail.expense_number  IS NULL OR expenses_detail.expense_number  = accdetail.accdetail_expense_number) AND
    (expenses_detail.expense_type    IS NULL OR expenses_detail.expense_type    = accdetail.accdetail_reserves_type) AND
    (expenses_detail.charges_line    IS NULL OR expenses_detail.charges_line    = accdetail.accdetail_charges_line) AND
    (expenses_detail.nominal_account IS NULL OR expenses_detail.nominal_account = accdetail.nominal) AND
    (accdetail.nominal LIKE '60%' OR accdetail.nominal LIKE '70%')

UNION ALL

SELECT
    to_char(accsummary.leddate, 'YYYY')                                                  AS entry_year,
    to_char(accsummary.leddate, 'MM')                                                    AS this_entry_month,
    date_trunc('month', accsummary.leddate)::date                                        AS this_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '35 days')::date                 AS next_month_some_day,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'YYYY')        AS next_month_year,
    to_char(date_trunc('month', accsummary.leddate) + INTERVAL '35 days', 'MM')          AS next_month_month,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month')::date                 AS next_month_first_day,
    (date_trunc('month', accsummary.leddate) + INTERVAL '1 month' - INTERVAL '1 day')::date AS this_month_last_day,
    to_char(accsummary.leddate, 'YYYY-MM')                                               AS period,
    accsummary.company,
    accsummary.leddate,
    expenses_summary.expense_note_type                                                   AS journal,
    expenses_summary.alternative_client_nomcode                                          AS nominal,
    COALESCE(expenses_summary.expense_number, accsummary.prov_inv_no, accsummary.ledgernum) AS document_number,
    COALESCE(expenses_summary.description, accdetail.comments)                           AS description,
    CASE WHEN accdetail.ledamt < 0 THEN accdetail.ledamt * -1 ELSE 0 END                AS debit_amount_currency,
    CASE WHEN accdetail.ledamt > 0 THEN accdetail.ledamt * -1 ELSE 0 END                AS credit_amount_currency,
    accdetail.currency,
    COALESCE(expenses_summary.client, accdetail.client)                                  AS client,
    expenses_summary.due_date,
    CASE WHEN currency.ratetype = 'D'
         THEN accdetail.ledamt / accdetail.house_rate * -1
         ELSE accdetail.ledamt * accdetail.house_rate * -1
    END AS usd_amount,
    allocation.allocation_reference AS alloc_ref,
    NULL                            AS contno,
    NULL                            AS split,
    allocation.allocation_reference AS alloc_ref_2,
    allocation.commodity_type       AS commod_type,
    allocation.allocation_completed,
    public.sp_allocation_check_if_only_stock(allocation.allocation_completed) AS stock_allocation

FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod  = accdetail.accperiod
    AND accsummary.ledgernum  = accdetail.ledgernum
JOIN public.currency
    ON  accdetail.currency    = currency.code
JOIN public.allocation
    ON  accdetail.accdetail_allocation_reference = allocation.allocation_reference
LEFT JOIN public.expenses_summary
    ON  accsummary.ledgernum  = expenses_summary.posted_ledref
    AND accsummary.exp_inv_no = expenses_summary.expense_number
    AND accsummary.an_client  = expenses_summary.client
WHERE
    accdetail.nominal = expenses_summary.alternative_client_nomcode AND
    accdetail.client  = expenses_summary.client AND
    (accdetail.nominal LIKE '60%' OR accdetail.nominal LIKE '70%');

-- ============================================================
-- View 3: allocations_closed_but_unfixed
-- Source: dba.allocations_closed_but_unfixed
-- Two UNIONs over the same base: rows where the allocation is
-- closed (allocation_closed='Y') but not fully fixed
-- (allocation_fixed='N').
--   Part 1 CLOSED_FIXED:   fixed > 0,                openqnt = fixed
--   Part 2 CLOSED_UNFIXED: allocated_unfixed_qty > 0, openqnt = allocated_unfixed_qty
-- CTE required because SAP Anywhere allowed alias references
-- within SELECT and in WHERE; PostgreSQL does not.
-- Note: sub_contracts joined on contno only (not split) —
-- preserved from original.
-- ============================================================

CREATE OR REPLACE VIEW public.allocations_closed_but_unfixed AS
WITH base AS (
    SELECT
        alloc_contracts_view.allocation_reference,
        master_contracts.company,
        sub_contracts.pcentre,
        master_contracts.commodity,
        master_contracts.commodtype,
        sub_contracts.origin,
        sub_contracts.quality,
        sub_contracts.valuedin,
        sub_contracts.price_fixing,
        public.sp_prompt_month(sub_contracts.valuedin)                      AS valuedin_str,
        alloc_contracts_view.contno,
        alloc_contracts_view.split,
        alloc_contracts_view.quantity                                        AS allocated_quantity,
        CASE WHEN sub_contracts.price_fixing = 'N' THEN
            alloc_contracts_view.quantity
        ELSE
            COALESCE(
                (SELECT SUM(f.fixed_qty)
                 FROM public.phys_fixes AS f
                 WHERE f.contno = alloc_contracts_view.contno
                   AND f.split  = alloc_contracts_view.split),
                0)
        END                                                                  AS fixed,
        COALESCE(
            (SELECT SUM(invoice_details_2.positional_quantity)
             FROM public.invoice_details_2
             WHERE invoice_details_2.contno                = alloc_contracts_view.contno
               AND invoice_details_2.split                 = alloc_contracts_view.split
               AND invoice_details_2.allocation_reference  = alloc_contracts_view.allocation_reference),
            0)                                                               AS invoiced_allocated_quantity,
        COALESCE(
            (SELECT SUM(stocks.quantity)
             FROM public.stocks
             WHERE stocks.contno                = alloc_contracts_view.contno
               AND stocks.split                 = alloc_contracts_view.split
               AND stocks.allocation_reference  = alloc_contracts_view.allocation_reference),
            0)                                                               AS invoiced_allocated_stocks_quantity,
        master_contracts.contract_type,
        public.sp_is_allocation_fully_fixed(alloc_contracts_view.allocation_reference)  AS allocation_fixed,
        public.sp_is_allocation_fully_closed(alloc_contracts_view.allocation_reference) AS allocation_closed
    FROM public.alloc_contracts_view
    JOIN public.master_contracts ON alloc_contracts_view.contno = master_contracts.contno
    JOIN public.sub_contracts    ON master_contracts.contno     = sub_contracts.contno
)
SELECT
    allocation_reference,
    company,
    pcentre,
    commodity,
    commodtype,
    origin,
    quality,
    valuedin,
    price_fixing,
    valuedin_str,
    contno,
    split,
    allocated_quantity,
    fixed,
    allocated_quantity - fixed                                               AS allocated_unfixed_quantity,
    invoiced_allocated_quantity,
    allocated_quantity - invoiced_allocated_quantity                        AS allocated_open_quantity,
    invoiced_allocated_stocks_quantity,
    CASE WHEN contract_type = 'P' THEN
        (allocated_quantity - invoiced_allocated_quantity) + invoiced_allocated_stocks_quantity
    ELSE
        (allocated_quantity - invoiced_allocated_quantity)
    END                                                                      AS true_openqnt,
    fixed                                                                    AS openqnt,
    'CLOSED_FIXED'                                                           AS closed_fixed_unfixed_flag,
    allocation_fixed,
    allocation_closed
FROM base
WHERE fixed > 0
  AND allocation_fixed  = 'N'
  AND allocation_closed = 'Y'

UNION ALL

SELECT
    allocation_reference,
    company,
    pcentre,
    commodity,
    commodtype,
    origin,
    quality,
    valuedin,
    price_fixing,
    valuedin_str,
    contno,
    split,
    allocated_quantity,
    fixed,
    allocated_quantity - fixed                                               AS allocated_unfixed_quantity,
    invoiced_allocated_quantity,
    allocated_quantity - invoiced_allocated_quantity                        AS allocated_open_quantity,
    invoiced_allocated_stocks_quantity,
    CASE WHEN contract_type = 'P' THEN
        (allocated_quantity - invoiced_allocated_quantity) + invoiced_allocated_stocks_quantity
    ELSE
        (allocated_quantity - invoiced_allocated_quantity)
    END                                                                      AS true_openqnt,
    allocated_quantity - fixed                                               AS openqnt,
    'CLOSED_UNFIXED'                                                         AS closed_fixed_unfixed_flag,
    allocation_fixed,
    allocation_closed
FROM base
WHERE (allocated_quantity - fixed) > 0
  AND allocation_fixed  = 'N'
  AND allocation_closed = 'Y'

ORDER BY 1 ASC;

-- ============================================================
-- View 4: detailed_stock_report_view
-- Source: dba.detailed_stock_report_view
-- Underlying view for Detailed Stock Report.
-- Four UNIONs:
--   Part 1: P-Invoice postings on 34% accounts (grouped)
--   Part 2: Invoice charge lines on 34% accounts
--   Part 3: Final Purchase Invoice postings on 34% accounts (grouped)
--   Part 4: Expense postings on 34% accounts
-- SAP Anywhere allowed alias references within SELECT and in
-- GROUP BY. Each UNION member is wrapped in a derived subquery
-- to resolve those references before grouping.
-- '//' comments removed; '--' commented-out clauses preserved.
-- ============================================================

CREATE OR REPLACE VIEW public.detailed_stock_report_view AS

-- Part 1: Purchase Invoice postings (PI flag, no charges line)
SELECT
    1                                                                         AS order_flag,
    s.ledgernum,
    MIN(s.accdetail_contno)                                                   AS accdetail_contno,
    MIN(s.accdetail_split)                                                    AS accdetail_split,
    s.client,
    s.an_tonnage                                                              AS original_tonnage,
    s.unquantity,
    s.quantity,
    s.is_there_stock,
    s.unitprice,
    s.contract_average_fix_price,
    s.sub_currency                                                            AS currency,
    s.priceunit,
    MIN(s.nominal)                                                            AS nominal,
    s.journal_book_number,
    s.an_client,
    s.leddate,
    CASE WHEN s.journals = 'OUTB' THEN
        s.prov_inv_no || ' (for P Inv: ' || s.analysis1 || ')'
    WHEN s.journals = 'RTRN' THEN
        s.analysis1 || ' (RETURN of ' || s.prov_inv_no || ')'
    ELSE
        MIN(s.accdetail_invoice_number) || s.unfixed_reversed_invoice_number_marker
    END                                                                       AS invoice_number,
    ''                                                                        AS expense_number,
    MIN(s.accdetail_currency)                                                 AS accdetail_currency,
    SUM(s.ledamt) * -1                                                        AS ledamt,
    MIN(s.house_rate)                                                         AS house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND((SUM(s.ledamt) * -1) * MIN(s.house_rate), 2)
         ELSE ROUND((SUM(s.ledamt) * -1) / MIN(s.house_rate), 2)
    END                                                                       AS base_amount,
    s.quantity_tonnage,
    s.quantity_tonnage                                                        AS quantity_tonnage_shown,
    s.base_currency,
    CASE WHEN s.journal_book_number = 'OUTB'
         THEN s.accsummary_contno || '-' || s.accsummary_split
         ELSE '' END                                                          AS sales_contract,
    CASE WHEN s.journal_book_number = 'OUTB'
         THEN s.an_allocref ELSE '' END                                      AS sales_allocation_reference,
    s.analysis1                                                              AS outbooking_purchase_invoice_number,
    s.company,
    s.commodity,
    s.commodtype,
    s.quality,
    s.contdate,
    s.mc_contno                                                              AS contno,
    s.unfixed_reversed_invoice_number_marker,
    s.amenddate
FROM (
    SELECT
        accsummary.ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        sub_contracts.client,
        accsummary.an_tonnage,
        public.sp_convert_qty(sub_contracts.unquantity, sub_contracts.quantunit, params.base_unit)          AS unquantity,
        public.sp_convert_qty(
            (SELECT SUM(stocks.quantity) FROM public.stocks
             WHERE stocks.contno = sub_contracts.contno AND stocks.split = sub_contracts.split),
            sub_contracts.quantunit, params.base_unit)                                                      AS quantity,
        CASE WHEN public.sp_convert_qty(
            (SELECT SUM(stocks.quantity) FROM public.stocks
             WHERE stocks.contno = sub_contracts.contno AND stocks.split = sub_contracts.split),
            sub_contracts.quantunit, params.base_unit) IS NULL THEN 'N' ELSE 'Y' END                        AS is_there_stock,
        sub_contracts.unitprice,
        public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)                               AS contract_average_fix_price,
        sub_contracts.currency                                                                              AS sub_currency,
        sub_contracts.priceunit,
        accdetail.nominal,
        CASE WHEN accsummary.journals = 'OUTB' THEN 'OUTB' ELSE '210' END                                  AS journal_book_number,
        accsummary.an_client,
        accsummary.leddate,
        accsummary.prov_inv_no,
        accsummary.analysis1,
        accsummary.contno                                                                                   AS accsummary_contno,
        accsummary.split                                                                                    AS accsummary_split,
        accsummary.an_allocref,
        accsummary.journals,
        accdetail.accdetail_invoice_number,
        accdetail.currency                                                                                  AS accdetail_currency,
        accdetail.ledamt,
        accdetail.house_rate,
        currency.ratetype,
        params.base_currency,
        master_contracts.company,
        master_contracts.commodity,
        master_contracts.commodtype,
        master_contracts.quality,
        master_contracts.contdate,
        master_contracts.contno                                                                             AS mc_contno,
        master_contracts.amenddate,
        CASE WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice'
             THEN ' (Reversed Unfixed Prov)' ELSE '' END                                                   AS unfixed_reversed_invoice_number_marker,
        CASE WHEN accsummary.journals = 'OUTB' OR accsummary.journals = 'RTRN' THEN
            accsummary.an_tonnage
        WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice' THEN
            -1 * accsummary.an_tonnage
        ELSE
            public.sp_convert_qty(
                (SELECT SUM(invoice_details_2.invoiced_quantity)
                 FROM public.invoice
                 JOIN public.invoice_details_2
                     ON invoice.invoice_number  = invoice_details_2.invoice_number
                    AND invoice.invoice_type    = invoice_details_2.invoice_type
                    AND invoice.client          = invoice_details_2.client
                 WHERE invoice.posted_ledref           = accsummary.ledgernum
                   AND invoice_details_2.contno        = sub_contracts.contno
                   AND invoice_details_2.split         = sub_contracts.split
                   AND invoice_details_2.nomcode LIKE '34%'),
                sub_contracts.quantunit, 'MT')
        END                                                                                                AS quantity_tonnage
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.phys_avail
        ON  sub_contracts.contno = phys_avail.contno
        AND sub_contracts.split  = phys_avail.split
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accdetail.accdetail_invoice_flag = 'PI'
        AND accsummary.prov_inv_no IS NOT NULL AND accsummary.exp_inv_no IS NULL
        AND accdetail.accdetail_charges_line IS NULL
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s
GROUP BY
    s.ledgernum, s.client, s.an_tonnage, s.unquantity, s.quantity, s.is_there_stock,
    s.unitprice, s.contract_average_fix_price, s.sub_currency, s.priceunit,
    s.journal_book_number, s.an_client, s.leddate, s.prov_inv_no, s.analysis1,
    s.accsummary_contno, s.accsummary_split, s.an_allocref, s.journals, s.ratetype,
    s.quantity_tonnage, s.base_currency, s.company, s.commodity, s.commodtype,
    s.quality, s.contdate, s.mc_contno, s.unfixed_reversed_invoice_number_marker, s.amenddate

UNION ALL

-- Part 2: Invoice charge lines (PI flag, accdetail_reserves_type not null)
SELECT
    2                                                                         AS order_flag,
    s.ledgernum,
    s.accdetail_contno,
    s.accdetail_split,
    s.client,
    0::numeric                                                                AS original_tonnage,
    0::numeric                                                                AS unquantity,
    0::numeric                                                                AS quantity,
    'Y'                                                                       AS is_there_stock,
    s.unitprice,
    s.contract_average_fix_price,
    s.sub_currency                                                            AS currency,
    s.priceunit,
    s.nominal,
    s.journal_book_number,
    s.an_client,
    s.leddate,
    s.accdetail_invoice_number || ' ' || s.accdetail_reserves_type || ' Invoice charge' AS invoice_number,
    ''                                                                        AS expense_number,
    s.accdetail_currency,
    s.ledamt * -1                                                             AS ledamt,
    s.house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND((s.ledamt * -1) * s.house_rate, 2)
         ELSE ROUND((s.ledamt * -1) / s.house_rate, 2)
    END                                                                       AS base_amount,
    0::numeric                                                                AS quantity_tonnage,
    0::numeric                                                                AS quantity_tonnage_shown,
    s.base_currency,
    CASE WHEN s.journal_book_number = 'OUTB'
         THEN s.accsummary_contno || '-' || s.accsummary_split
         ELSE '' END                                                          AS sales_contract,
    CASE WHEN s.journal_book_number = 'OUTB'
         THEN s.an_allocref ELSE '' END                                      AS sales_allocation_reference,
    s.analysis1                                                              AS outbooking_purchase_invoice_number,
    s.company,
    s.commodity,
    s.commodtype,
    s.quality,
    s.contdate,
    s.mc_contno                                                              AS contno,
    s.unfixed_reversed_invoice_number_marker,
    s.amenddate
FROM (
    SELECT
        accsummary.ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        sub_contracts.client,
        sub_contracts.unitprice,
        public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)                               AS contract_average_fix_price,
        sub_contracts.currency                                                                              AS sub_currency,
        sub_contracts.priceunit,
        accdetail.nominal,
        CASE WHEN accsummary.journals = 'OUTB' THEN 'OUTB' ELSE '210' END                                  AS journal_book_number,
        accsummary.an_client,
        accsummary.leddate,
        accdetail.accdetail_invoice_number,
        accdetail.accdetail_reserves_type,
        accdetail.currency                                                                                  AS accdetail_currency,
        accdetail.ledamt,
        accdetail.house_rate,
        currency.ratetype,
        params.base_currency,
        accsummary.contno                                                                                   AS accsummary_contno,
        accsummary.split                                                                                    AS accsummary_split,
        accsummary.an_allocref,
        accsummary.analysis1,
        master_contracts.company,
        master_contracts.commodity,
        master_contracts.commodtype,
        master_contracts.quality,
        master_contracts.contdate,
        master_contracts.contno                                                                             AS mc_contno,
        master_contracts.amenddate,
        CASE WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice'
             THEN ' (Reversed Unfixed Prov)' ELSE '' END                                                   AS unfixed_reversed_invoice_number_marker
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accsummary.journals IN ('INVC', 'OUTB')
        AND accdetail.accdetail_invoice_flag    = 'PI'
        AND accdetail.accdetail_invoice_number  IS NOT NULL
        AND accdetail.accdetail_reserves_type   IS NOT NULL
        AND accsummary.prov_inv_no IS NOT NULL AND accsummary.exp_inv_no IS NULL
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s

UNION ALL

-- Part 3: Final Purchase Invoice postings (FI/PF flag)
SELECT
    3                                                                         AS order_flag,
    s.ledgernum,
    MIN(s.accdetail_contno)                                                   AS accdetail_contno,
    MIN(s.accdetail_split)                                                    AS accdetail_split,
    s.client,
    s.an_tonnage                                                              AS original_tonnage,
    s.unquantity,
    s.quantity,
    s.is_there_stock,
    s.unitprice,
    s.contract_average_fix_price,
    s.sub_currency                                                            AS currency,
    s.priceunit,
    MIN(s.nominal)                                                            AS nominal,
    s.journal_book_number,
    s.an_client,
    s.leddate,
    CASE WHEN s.journals = 'OUTB' THEN
        s.fin_inv_no || ' (for F Inv: ' || s.fin_inv_no || ')'
    ELSE
        s.fin_inv_no || ' (Fin for P Inv: ' || s.prov_inv_no || ')'
    END                                                                       AS invoice_number,
    ''                                                                        AS expense_number,
    MIN(s.accdetail_currency)                                                 AS accdetail_currency,
    SUM(s.ledamt) * -1                                                        AS ledamt,
    MIN(s.house_rate)                                                         AS house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND((SUM(s.ledamt) * -1) * MIN(s.house_rate), 2)
         ELSE ROUND((SUM(s.ledamt) * -1) / MIN(s.house_rate), 2)
    END                                                                       AS base_amount,
    s.quantity_tonnage,
    s.quantity_tonnage                                                        AS quantity_tonnage_shown,
    s.base_currency,
    ''                                                                        AS sales_contract,
    ''                                                                        AS sales_allocation_reference,
    s.analysis5                                                              AS outbooking_purchase_invoice_number,
    s.company,
    s.commodity,
    s.commodtype,
    s.quality,
    s.contdate,
    s.mc_contno                                                              AS contno,
    s.unfixed_reversed_invoice_number_marker,
    s.amenddate
FROM (
    SELECT
        accsummary.ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        sub_contracts.client,
        accsummary.an_tonnage,
        public.sp_convert_qty(sub_contracts.unquantity, sub_contracts.quantunit, params.base_unit)          AS unquantity,
        public.sp_convert_qty(
            (SELECT SUM(stocks.quantity) FROM public.stocks
             WHERE stocks.contno = sub_contracts.contno AND stocks.split = sub_contracts.split),
            sub_contracts.quantunit, params.base_unit)                                                      AS quantity,
        CASE WHEN public.sp_convert_qty(
            (SELECT SUM(stocks.quantity) FROM public.stocks
             WHERE stocks.contno = sub_contracts.contno AND stocks.split = sub_contracts.split),
            sub_contracts.quantunit, params.base_unit) IS NULL THEN 'N' ELSE 'Y' END                        AS is_there_stock,
        sub_contracts.unitprice,
        public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)                               AS contract_average_fix_price,
        sub_contracts.currency                                                                              AS sub_currency,
        sub_contracts.priceunit,
        accdetail.nominal,
        CASE WHEN accsummary.journals = 'OUTB' THEN 'OUTB' ELSE '210' END                                  AS journal_book_number,
        accsummary.an_client,
        accsummary.leddate,
        accsummary.prov_inv_no,
        accsummary.fin_inv_no,
        accsummary.analysis5,
        accsummary.journals,
        accdetail.currency                                                                                  AS accdetail_currency,
        accdetail.ledamt,
        accdetail.house_rate,
        currency.ratetype,
        params.base_currency,
        master_contracts.company,
        master_contracts.commodity,
        master_contracts.commodtype,
        master_contracts.quality,
        master_contracts.contdate,
        master_contracts.contno                                                                             AS mc_contno,
        master_contracts.amenddate,
        CASE WHEN accsummary.journals = 'OUTB' THEN '' ELSE ' (Final Invoice)' END                         AS unfixed_reversed_invoice_number_marker,
        CASE WHEN accsummary.journals = 'OUTB' THEN
            accsummary.an_tonnage
        WHEN RIGHT(LEFT(accsummary.prov_inv_no, 5), 3) = '206' THEN
            (SELECT SUM(final_invoice_details_2.invoiced_quantity)
             FROM public.final_invoice_details_2
             WHERE final_invoice_details_2.invoice_number = accsummary.prov_inv_no)
        ELSE
            0.00
        END                                                                                                AS quantity_tonnage
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.phys_avail
        ON  sub_contracts.contno = phys_avail.contno
        AND sub_contracts.split  = phys_avail.split
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accdetail.accdetail_invoice_flag IN ('FI', 'PF')
        AND accsummary.fin_inv_no IS NOT NULL AND accsummary.exp_inv_no IS NULL
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s
GROUP BY
    s.ledgernum, s.client, s.an_tonnage, s.unquantity, s.quantity, s.is_there_stock,
    s.unitprice, s.contract_average_fix_price, s.sub_currency, s.priceunit,
    s.journal_book_number, s.an_client, s.leddate, s.prov_inv_no, s.fin_inv_no,
    s.analysis5, s.journals, s.ratetype, s.quantity_tonnage, s.base_currency,
    s.company, s.commodity, s.commodtype, s.quality, s.contdate, s.mc_contno,
    s.unfixed_reversed_invoice_number_marker, s.amenddate

UNION ALL

-- Part 4: Expense postings on 34% accounts
SELECT
    4                                                                         AS order_flag,
    s.accdetail_ledgernum                                                     AS ledgernum,
    s.accdetail_contno,
    s.accdetail_split,
    s.client,
    s.original_tonnage,
    s.unquantity,
    s.quantity,
    s.is_there_stock,
    s.unitprice,
    s.contract_average_fix_price,
    s.sub_currency                                                            AS currency,
    s.priceunit,
    s.nominal,
    s.journal_book_number,
    s.an_client,
    s.leddate,
    ''                                                                        AS invoice_number,
    s.expense_number,
    s.accdetail_currency,
    s.ledamt * -1                                                             AS ledamt,
    s.house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND((s.ledamt * -1) * s.house_rate, 2)
         ELSE ROUND((s.ledamt * -1) / s.house_rate, 2)
    END                                                                       AS base_amount,
    s.quantity_tonnage,
    s.quantity_tonnage                                                        AS quantity_tonnage_shown,
    s.base_currency,
    CASE WHEN s.journal_book_number = 'OUTB'
         THEN s.accsummary_contno || '-' || s.accsummary_split
         ELSE '' END                                                          AS sales_contract,
    CASE WHEN s.journal_book_number = 'OUTB'
         THEN s.an_allocref ELSE '' END                                      AS sales_allocation_reference,
    s.analysis1                                                              AS outbooking_purchase_invoice_number,
    s.company,
    s.commodity,
    s.commodtype,
    s.quality,
    s.contdate,
    s.mc_contno                                                              AS contno,
    ''                                                                        AS unfixed_reversed_invoice_number_marker,
    s.amenddate
FROM (
    SELECT
        accdetail.ledgernum                                                                                 AS accdetail_ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        sub_contracts.client,
        public.sp_convert_qty(sub_contracts.orgunquant, sub_contracts.quantunit, params.base_unit)          AS original_tonnage,
        public.sp_convert_qty(sub_contracts.unquantity, sub_contracts.quantunit, params.base_unit)          AS unquantity,
        public.sp_convert_qty(
            (SELECT SUM(stocks.quantity) FROM public.stocks
             WHERE stocks.contno = sub_contracts.contno AND stocks.split = sub_contracts.split),
            sub_contracts.quantunit, params.base_unit)                                                      AS quantity,
        CASE WHEN public.sp_convert_qty(
            (SELECT SUM(stocks.quantity) FROM public.stocks
             WHERE stocks.contno = sub_contracts.contno AND stocks.split = sub_contracts.split),
            sub_contracts.quantunit, params.base_unit) IS NULL THEN 'N' ELSE 'Y' END                        AS is_there_stock,
        sub_contracts.unitprice,
        public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)                               AS contract_average_fix_price,
        sub_contracts.currency                                                                              AS sub_currency,
        sub_contracts.priceunit,
        accdetail.nominal,
        CASE WHEN accsummary.journals = 'OUTB' THEN 'OUTB'
             WHEN accdetail.accdetail_invoice_flag = 'EXP' THEN
                 (SELECT expenses_summary.expense_note_type FROM public.expenses_summary
                  WHERE expenses_summary.expense_number = accdetail.accdetail_expense_number
                    AND expenses_summary.posted_ledref  = accdetail.ledgernum)
             ELSE '210'
        END                                                                                                AS journal_book_number,
        accsummary.an_client,
        accsummary.leddate,
        accdetail.accdetail_expense_number,
        accdetail.accdetail_charges_line,
        accdetail.accdetail_reserves_type,
        accdetail.currency                                                                                  AS accdetail_currency,
        accdetail.ledamt,
        accdetail.house_rate,
        currency.ratetype,
        params.base_currency,
        accsummary.contno                                                                                   AS accsummary_contno,
        accsummary.split                                                                                    AS accsummary_split,
        accsummary.an_allocref,
        accsummary.analysis1,
        accsummary.journals,
        accsummary.reversed,
        accdetail.comments,
        master_contracts.company,
        master_contracts.commodity,
        master_contracts.commodtype,
        master_contracts.quality,
        master_contracts.contdate,
        master_contracts.contno                                                                             AS mc_contno,
        master_contracts.amenddate,
        CASE WHEN accsummary.journals = 'OUTB' THEN
            accdetail.accdetail_expense_number || ' (for P Inv: ' || accsummary.analysis1 || ')'
        ELSE
            accdetail.accdetail_expense_number || ' (for P Inv: ' ||
            COALESCE(
                (SELECT MIN(expenses_detail.purchase_invoice_number)
                 FROM public.expenses_detail
                 WHERE expenses_detail.expense_number = accdetail.accdetail_expense_number
                   AND expenses_detail.client         = accsummary.an_client
                   AND expenses_detail.charges_line   = accdetail.accdetail_charges_line
                   AND expenses_detail.expense_type   = accdetail.accdetail_reserves_type),
                '') || ')'
        END                                                                                                AS expense_number,
        CASE WHEN accsummary.reversed = 'Y' AND LEFT(accdetail.comments, 11) = 'Reversal of' THEN
            COALESCE(
                (SELECT MIN(expenses_detail.quantity) FROM public.expenses_detail
                 WHERE expenses_detail.expense_number = accdetail.accdetail_expense_number
                   AND expenses_detail.client         = accsummary.an_client
                   AND expenses_detail.charges_line   = accdetail.accdetail_charges_line
                   AND expenses_detail.expense_type   = 'OUTB'),
                0) * -1
        ELSE
            COALESCE(
                (SELECT MIN(expenses_detail.quantity) FROM public.expenses_detail
                 WHERE expenses_detail.expense_number = accdetail.accdetail_expense_number
                   AND expenses_detail.client         = accsummary.an_client
                   AND expenses_detail.charges_line   = accdetail.accdetail_charges_line
                   AND expenses_detail.expense_type   = 'OUTB'),
                0)
        END                                                                                                AS quantity_tonnage
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.phys_avail
        ON  sub_contracts.contno = phys_avail.contno
        AND sub_contracts.split  = phys_avail.split
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accdetail.accdetail_invoice_flag = 'EXP'
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s;

-- ============================================================
-- View 5: detailed_stock_report_view_slim
-- Source: dba.detailed_stock_report_view_slim
-- Lighter variant of detailed_stock_report_view: no GROUP BY,
-- no phys_avail join, no sp_phys_avefixprice/sp_convert_qty
-- for stock qty. Adds total_check_ledamt, original_purchase_
-- invoice_number, entry_description_flag columns.
-- Part 1 quantity_tonnage has forward alias refs to both
-- unfixed_reversed_invoice_number_marker and total_check_ledamt;
-- resolved via derived subquery.
-- ============================================================

CREATE OR REPLACE VIEW public.detailed_stock_report_view_slim AS

-- Part 1: Purchase Invoice postings (PI flag, no charges line)
SELECT
    1                                                                         AS order_flag,
    s.ledgernum,
    s.accdetail_contno,
    s.accdetail_split,
    s.company,
    s.an_client,
    s.nominal,
    s.client,
    s.commodtype,
    s.origin,
    s.leddate,
    CASE WHEN s.journals = 'OUTB' THEN
        s.prov_inv_no || ' (for P Inv: ' || s.analysis1 || ')'
    WHEN s.journals = 'RTRN' THEN
        s.analysis1 || ' (RETURN of ' || s.prov_inv_no || ')'
    ELSE
        s.accdetail_invoice_number
    END                                                                       AS invoice_number,
    CASE WHEN s.journals = 'OUTB' THEN s.analysis1
         WHEN s.journals = 'RTRN' THEN s.prov_inv_no
         ELSE s.accdetail_invoice_number
    END                                                                       AS original_purchase_invoice_number,
    ''                                                                        AS expense_number,
    s.accdetail_currency,
    CASE WHEN s.journals = 'OUTB' OR s.journals = 'RTRN' THEN
        s.an_tonnage
    WHEN s.unfixed_reversed_invoice_number_marker = ' (Reversed Unfixed Prov)' THEN
        -1 * s.an_tonnage
    ELSE
        ABS(s.ledamt / s.total_check_ledamt) *
        public.sp_convert_qty(
            (SELECT SUM(invoice_details_2.invoiced_quantity)
             FROM public.invoice
             JOIN public.invoice_details_2
                 ON invoice.invoice_number = invoice_details_2.invoice_number
                AND invoice.invoice_type   = invoice_details_2.invoice_type
                AND invoice.client         = invoice_details_2.client
             WHERE invoice.posted_ledref          = s.ledgernum
               AND invoice_details_2.contno        = s.accdetail_contno
               AND invoice_details_2.split         = s.accdetail_split
               AND invoice_details_2.nomcode LIKE '34%'),
            s.quantunit, 'MT')
    END                                                                       AS quantity_tonnage,
    CASE WHEN s.journals = 'OUTB' OR s.journals = 'RTRN' THEN
        s.an_tonnage
    WHEN s.unfixed_reversed_invoice_number_marker = ' (Reversed Unfixed Prov)' THEN
        -1 * s.an_tonnage
    ELSE
        ABS(s.ledamt / s.total_check_ledamt) *
        public.sp_convert_qty(
            (SELECT SUM(invoice_details_2.invoiced_quantity)
             FROM public.invoice
             JOIN public.invoice_details_2
                 ON invoice.invoice_number = invoice_details_2.invoice_number
                AND invoice.invoice_type   = invoice_details_2.invoice_type
                AND invoice.client         = invoice_details_2.client
             WHERE invoice.posted_ledref          = s.ledgernum
               AND invoice_details_2.contno        = s.accdetail_contno
               AND invoice_details_2.split         = s.accdetail_split
               AND invoice_details_2.nomcode LIKE '34%'),
            s.quantunit, 'MT')
    END                                                                       AS quantity_tonnage_shown,
    s.ledamt,
    s.house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND(s.ledamt * s.house_rate, 2)
         ELSE ROUND(s.ledamt / s.house_rate, 2)
    END                                                                       AS base_amount,
    s.unfixed_reversed_invoice_number_marker,
    s.total_check_ledamt,
    s.amenddate,
    'STOCK'                                                                   AS entry_description_flag,
    s.base_currency
FROM (
    SELECT
        accsummary.ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        accsummary.company,
        accsummary.an_client,
        accdetail.nominal,
        master_contracts.client,
        master_contracts.commodtype,
        master_contracts.origin,
        accsummary.leddate,
        accsummary.journals,
        accsummary.prov_inv_no,
        accsummary.analysis1,
        accsummary.an_tonnage,
        accdetail.accdetail_invoice_number,
        accdetail.currency                                                    AS accdetail_currency,
        accdetail.ledamt * -1                                                 AS ledamt,
        accdetail.house_rate,
        currency.ratetype,
        sub_contracts.quantunit,
        master_contracts.amenddate,
        params.base_currency,
        CASE WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice'
             THEN ' (Reversed Unfixed Prov)' ELSE '' END                     AS unfixed_reversed_invoice_number_marker,
        (SELECT SUM(acc_det_temp.ledamt)
         FROM public.accdetail AS acc_det_temp
         WHERE acc_det_temp.accperiod             = accdetail.accperiod
           AND acc_det_temp.ledgernum             = accdetail.ledgernum
           AND acc_det_temp.client                IS NULL
           AND acc_det_temp.accdetail_invoice_flag = 'PI'
           AND acc_det_temp.accdetail_charges_line IS NULL
           AND acc_det_temp.accdetail_contno      = accdetail.accdetail_contno
           AND acc_det_temp.accdetail_split       = accdetail.accdetail_split
           AND acc_det_temp.nominal LIKE '34%' AND acc_det_temp.nominal <> '34999')
                                                                             AS total_check_ledamt
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accdetail.accdetail_invoice_flag = 'PI'
        AND accsummary.prov_inv_no IS NOT NULL AND accsummary.exp_inv_no IS NULL
        AND accdetail.accdetail_charges_line IS NULL
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s

UNION ALL

-- Part 2: Invoice charge lines
SELECT
    2                                                                         AS order_flag,
    s.ledgernum,
    s.accdetail_contno,
    s.accdetail_split,
    s.company,
    s.an_client,
    s.nominal,
    s.client,
    s.commodtype,
    s.origin,
    s.leddate,
    s.accdetail_invoice_number || ' ' || s.accdetail_reserves_type || ' Invoice charge' AS invoice_number,
    s.accdetail_invoice_number                                                AS original_purchase_invoice_number,
    ''                                                                        AS expense_number,
    s.accdetail_currency,
    0::numeric                                                                AS quantity_tonnage,
    0::numeric                                                                AS quantity_tonnage_shown,
    s.ledamt,
    s.house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND(s.ledamt * s.house_rate, 2)
         ELSE ROUND(s.ledamt / s.house_rate, 2)
    END                                                                       AS base_amount,
    s.unfixed_reversed_invoice_number_marker,
    NULL::numeric                                                             AS total_check_ledamt,
    s.amenddate,
    'CHARGE'                                                                  AS entry_description_flag,
    s.base_currency
FROM (
    SELECT
        accsummary.ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        accsummary.company,
        accsummary.an_client,
        accdetail.nominal,
        master_contracts.client,
        master_contracts.commodtype,
        master_contracts.origin,
        accsummary.leddate,
        accdetail.accdetail_invoice_number,
        accdetail.accdetail_reserves_type,
        accdetail.currency                                                    AS accdetail_currency,
        accdetail.ledamt * -1                                                 AS ledamt,
        accdetail.house_rate,
        currency.ratetype,
        master_contracts.amenddate,
        params.base_currency,
        CASE WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice'
             THEN ' (Reversed Unfixed Prov)' ELSE '' END                     AS unfixed_reversed_invoice_number_marker
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accdetail.accdetail_invoice_flag   = 'PI'
        AND accdetail.accdetail_invoice_number IS NOT NULL
        AND accdetail.accdetail_reserves_type  IS NOT NULL
        AND accsummary.prov_inv_no IS NOT NULL AND accsummary.exp_inv_no IS NULL
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s

UNION ALL

-- Part 3: Final Purchase Invoice postings (FI/PF flag)
SELECT
    3                                                                         AS order_flag,
    s.ledgernum,
    s.accdetail_contno,
    s.accdetail_split,
    s.company,
    s.an_client,
    s.nominal,
    s.client,
    s.commodtype,
    s.origin,
    s.leddate,
    CASE WHEN s.journals = 'OUTB' THEN
        s.fin_inv_no || ' (for F Inv: ' || s.fin_inv_no || ')'
    ELSE
        s.fin_inv_no || ' (Fin for P Inv: ' || s.prov_inv_no || ')'
    END                                                                       AS invoice_number,
    s.prov_inv_no                                                             AS original_purchase_invoice_number,
    ''                                                                        AS expense_number,
    s.accdetail_currency,
    s.quantity_tonnage,
    s.quantity_tonnage                                                        AS quantity_tonnage_shown,
    s.ledamt,
    s.house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND(s.ledamt * s.house_rate, 2)
         ELSE ROUND(s.ledamt / s.house_rate, 2)
    END                                                                       AS base_amount,
    s.unfixed_reversed_invoice_number_marker,
    NULL::numeric                                                             AS total_check_ledamt,
    s.amenddate,
    'STOCK'                                                                   AS entry_description_flag,
    s.base_currency
FROM (
    SELECT
        accsummary.ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        accsummary.company,
        accsummary.an_client,
        accdetail.nominal,
        master_contracts.client,
        master_contracts.commodtype,
        master_contracts.origin,
        accsummary.leddate,
        accsummary.journals,
        accsummary.prov_inv_no,
        accsummary.fin_inv_no,
        accdetail.currency                                                    AS accdetail_currency,
        accdetail.ledamt * -1                                                 AS ledamt,
        accdetail.house_rate,
        currency.ratetype,
        master_contracts.amenddate,
        params.base_currency,
        CASE WHEN accsummary.journals = 'OUTB' THEN '' ELSE ' (Final Invoice)' END
                                                                             AS unfixed_reversed_invoice_number_marker,
        CASE WHEN accsummary.journals = 'OUTB' THEN
            accsummary.an_tonnage
        WHEN RIGHT(LEFT(accsummary.prov_inv_no, 5), 3) = '206' THEN
            (SELECT SUM(final_invoice_details_2.invoiced_quantity)
             FROM public.final_invoice_details_2
             WHERE final_invoice_details_2.invoice_number = accsummary.prov_inv_no)
        ELSE
            0.00
        END                                                                  AS quantity_tonnage
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accdetail.accdetail_invoice_flag IN ('FI', 'PF')
        AND accsummary.fin_inv_no IS NOT NULL AND accsummary.exp_inv_no IS NULL
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s

UNION ALL

-- Part 4: Expense postings
SELECT
    4                                                                         AS order_flag,
    s.accdetail_ledgernum                                                     AS ledgernum,
    s.accdetail_contno,
    s.accdetail_split,
    s.company,
    s.an_client,
    s.nominal,
    s.client,
    s.commodtype,
    s.origin,
    s.leddate,
    ''                                                                        AS invoice_number,
    s.original_purchase_invoice_number,
    s.expense_number,
    s.accdetail_currency,
    s.quantity_tonnage,
    s.quantity_tonnage                                                        AS quantity_tonnage_shown,
    s.ledamt,
    s.house_rate,
    CASE WHEN s.ratetype = 'M'
         THEN ROUND(s.ledamt * s.house_rate, 2)
         ELSE ROUND(s.ledamt / s.house_rate, 2)
    END                                                                       AS base_amount,
    ''                                                                        AS unfixed_reversed_invoice_number_marker,
    NULL::numeric                                                             AS total_check_ledamt,
    s.amenddate,
    CASE WHEN s.accdetail_reserves_type = 'OUTB' THEN 'STOCK' ELSE 'EXPENSE' END AS entry_description_flag,
    s.base_currency
FROM (
    SELECT
        accdetail.ledgernum                                                   AS accdetail_ledgernum,
        accdetail.accdetail_contno,
        accdetail.accdetail_split,
        accsummary.company,
        accsummary.an_client,
        accdetail.nominal,
        master_contracts.client,
        master_contracts.commodtype,
        master_contracts.origin,
        accsummary.leddate,
        accdetail.currency                                                    AS accdetail_currency,
        accdetail.ledamt * -1                                                 AS ledamt,
        accdetail.house_rate,
        currency.ratetype,
        accdetail.accdetail_reserves_type,
        accdetail.accdetail_expense_number,
        accdetail.accdetail_charges_line,
        accsummary.reversed,
        accdetail.comments,
        master_contracts.amenddate,
        params.base_currency,
        (SELECT MIN(expenses_detail.purchase_invoice_number)
         FROM public.expenses_detail
         WHERE expenses_detail.expense_number = accdetail.accdetail_expense_number
           AND expenses_detail.client         = accsummary.an_client
           AND expenses_detail.charges_line   = accdetail.accdetail_charges_line)
                                                                             AS original_purchase_invoice_number,
        COALESCE(accdetail.accdetail_expense_number, '')                     AS expense_number,
        CASE WHEN accsummary.reversed = 'Y' AND LEFT(accdetail.comments, 11) = 'Reversal of' THEN
            COALESCE(
                (SELECT MIN(expenses_detail.quantity) FROM public.expenses_detail
                 WHERE expenses_detail.expense_number = accdetail.accdetail_expense_number
                   AND expenses_detail.client         = accsummary.an_client
                   AND expenses_detail.charges_line   = accdetail.accdetail_charges_line
                   AND expenses_detail.expense_type   = 'OUTB'),
                0) * -1
        ELSE
            COALESCE(
                (SELECT MIN(expenses_detail.quantity) FROM public.expenses_detail
                 WHERE expenses_detail.expense_number = accdetail.accdetail_expense_number
                   AND expenses_detail.client         = accsummary.an_client
                   AND expenses_detail.charges_line   = accdetail.accdetail_charges_line
                   AND expenses_detail.expense_type   = 'OUTB'),
                0)
        END                                                                  AS quantity_tonnage
    FROM public.accsummary
    JOIN public.accdetail
        ON  accsummary.accperiod = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
    JOIN public.sub_contracts
        ON  accdetail.accdetail_contno = sub_contracts.contno
        AND accdetail.accdetail_split  = sub_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.currency ON accdetail.currency = currency.code
    CROSS JOIN public.params
    WHERE
        master_contracts.contract_type = 'P'
        AND accdetail.accdetail_invoice_flag = 'EXP'
        AND accdetail.nominal LIKE '34%' AND accdetail.nominal <> '34999'
) AS s;

-- ============================================================
-- View 6: fixes_view
-- Source: dba.fixes_view
-- Joins sub_contracts -> fixes, master_contracts, params,
-- two client aliases, futures_contract, two unit aliases,
-- company; LEFT JOINs reserves and broker client.
-- Conversions:
--   IFNULL(val,'',val+' ') -> COALESCE(val||' ','')
--   'fixed' alias ref in 'unfixed' -> inline subquery
--   PFPOSITION/PFCONTRACT -> lowercase
-- ============================================================

CREATE OR REPLACE VIEW public.fixes_view AS
SELECT
    master_contracts.company,
    sub_contracts.contno,
    sub_contracts.split,
    params.systemdate,
    reserves.clientref                                                        AS broker_clientref,
    client_a.code                                                             AS broker_code,
    client_a.longname                                                         AS broker_longname,
    client_a.fax                                                              AS broker_fax,
    client_b.code                                                             AS client_code,
    client_b.longname                                                         AS client_longname,
    client_b.fax                                                              AS client_fax,
    client_b.country                                                          AS client_country,
    COALESCE(client_b.firstnames1 || ' ', '') || COALESCE(client_b.contact1, '') AS client_contact,
    fixes.fixdate,
    fixes.quantity,
    fixes.tprice,
    fixes.diffmktfxrate,
    fixes.unitprice,
    fixes.fixid,
    fixes.notes,
    master_contracts.contdate,
    master_contracts.contract_type,
    master_contracts.clientref,
    futures_contract.name                                                     AS futures_contract_name,
    public.sp_long_month(public.sp_prompt_month(sub_contracts.pfposition))   AS pos_month,
    sub_contracts.pfdiffer,
    public.sp_pfdifftype(sub_contracts.pfdifftype)                           AS pfdiffertype_name,
    sub_contracts.currency,
    sub_contracts.client,
    unit_a.longname_plural                                                    AS priceunit_name,
    unit_b.longname_plural                                                    AS fixesunit_name,
    (SELECT SUM(fixes_sum.fixed_qty) FROM public.phys_fixes AS fixes_sum
     WHERE fixes_sum.contno = sub_contracts.contno
       AND fixes_sum.split  = sub_contracts.split)                           AS fixed,
    sub_contracts.orgunquant -
    (SELECT SUM(fixes_sum.fixed_qty) FROM public.phys_fixes AS fixes_sum
     WHERE fixes_sum.contno = sub_contracts.contno
       AND fixes_sum.split  = sub_contracts.split)                           AS unfixed,
    company.longname                                                          AS company_longname
FROM public.sub_contracts
LEFT JOIN public.reserves
    ON  sub_contracts.contno = reserves.contno
    AND sub_contracts.split  = reserves.split
    AND reserves.reserve     = 'COMM'
LEFT JOIN public.client AS client_a ON reserves.client = client_a.code
JOIN public.fixes
    ON  sub_contracts.contno = fixes.contno
    AND sub_contracts.split  = fixes.split
JOIN public.master_contracts ON master_contracts.contno = sub_contracts.contno
JOIN public.client AS client_b ON sub_contracts.client = client_b.code
JOIN public.futures_contract ON sub_contracts.pfcontract = futures_contract.code
JOIN public.unit AS unit_a ON sub_contracts.priceunit = unit_a.code
JOIN public.unit AS unit_b ON fixes.quantunit = unit_b.code
JOIN public.company ON master_contracts.company = company.code
CROSS JOIN public.params;

-- ============================================================
-- View 7: forecast_report_view_stocks_assigned_to_sales_invoice
-- Source: dba.forecast_report_view_stocks_assigned_to_sales_invoice
-- CTE resolves original_final_invoice_number alias used by
-- final_unit_price CASE expression (alias-in-same-SELECT).
-- Conversions:
--   if/then/else/endif -> CASE WHEN/THEN/ELSE/END
--   list(distinct(...)) -> string_agg(DISTINCT ...::text, ',')
--   GROUP BY aliases -> original column expressions
--   ORDER BY removed (not permitted in PG views)
--   stocks.quantity, sales_invoice_stocks.stock_quantity removed
--   from GROUP BY - they appear only inside SUM(...) aggregate
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_report_view_stocks_assigned_to_sales_invoice AS
WITH base AS (
    SELECT
        stocks.allocation_reference,
        stocks.contno,
        stocks.split,
        stocks.original_invoice_number,
        stocks.original_client,
        stocks.original_invoice_type,
        original_purchase_invoice.posted_date           AS invoice_date,
        original_purchase_invoice.posted_ledref,
        original_purchase_invoice.invoice_value,
        original_purchase_invoice.invoice_currency,
        original_purchase_invoice.house_rate,
        original_purchase_invoice.unfixed_prov_ledref,
        (SELECT MIN(fi.final_invoice_number)
         FROM public.final_invoice fi
         WHERE fi.invoice_number = stocks.original_invoice_number
           AND fi.invoice_type   = stocks.original_invoice_type
           AND fi.client         = stocks.original_client)  AS original_final_invoice_number,
        stocks.quantity,
        sales_invoice_stocks.stock_quantity,
        sales_invoice_stocks.invoice_number              AS sis_invoice_number
    FROM public.stocks
    LEFT JOIN public.invoice_stocks AS sales_invoice_stocks
        ON  stocks.contno   = sales_invoice_stocks.contno
        AND stocks.split    = sales_invoice_stocks.split
        AND stocks.stock_id = sales_invoice_stocks.stock_id
        AND sales_invoice_stocks.invoice_type = 'S'
    JOIN public.invoice AS original_purchase_invoice
        ON  original_purchase_invoice.invoice_number = stocks.original_invoice_number
        AND original_purchase_invoice.invoice_type   = stocks.original_invoice_type
        AND original_purchase_invoice.client         = stocks.original_client
)
SELECT
    b.allocation_reference,
    b.contno,
    b.split,
    b.original_invoice_number,
    b.original_client                                           AS original_invoice_client,
    b.original_invoice_type,
    b.invoice_date,
    b.invoice_date                                              AS posted_date,
    b.posted_ledref,
    (SELECT COUNT(id2.linevalue)
     FROM public.invoice_details_2 id2
     WHERE id2.invoice_number = b.original_invoice_number
       AND id2.client         = b.original_client
       AND id2.invoice_type   = b.original_invoice_type)       AS number_of_invoice_details_lines,
    b.invoice_value,
    b.invoice_currency,
    b.house_rate,
    (SELECT MIN(id2.unit_price)
     FROM public.invoice_details_2 id2
     WHERE id2.invoice_number = b.original_invoice_number
       AND id2.client         = b.original_client
       AND id2.invoice_type   = b.original_invoice_type)       AS unit_price,
    (SELECT MIN(id2.nomcode)
     FROM public.invoice_details_2 id2
     WHERE id2.invoice_number = b.original_invoice_number
       AND id2.client         = b.original_client
       AND id2.invoice_type   = b.original_invoice_type)       AS nomcode,
    b.unfixed_prov_ledref,
    b.original_final_invoice_number,
    CASE WHEN b.original_final_invoice_number IS NOT NULL
         THEN (SELECT MIN(fid2.unit_price)
               FROM public.final_invoice_details_2 fid2
               WHERE fid2.invoice_number = b.original_invoice_number
                 AND fid2.client         = b.original_client
                 AND fid2.invoice_type   = b.original_invoice_type
                 AND fid2.contno         = b.contno
                 AND fid2.split          = b.split)
         ELSE NULL
    END                                                         AS final_unit_price,
    SUM(CASE WHEN b.stock_quantity IS NOT NULL
             THEN b.stock_quantity
             ELSE b.quantity END)                              AS total_stock_assigned,
    string_agg(DISTINCT b.sis_invoice_number::text, ',')       AS sales_invoice_number,
    (SELECT string_agg(DISTINCT sid2.invoice_number::text, ',')
     FROM public.invoice_details_2 sid2
     WHERE sid2.invoice_type         = 'S'
       AND sid2.allocation_reference = b.allocation_reference) AS allocations_sales_invoice_numbers
FROM base b
GROUP BY
    b.allocation_reference,
    b.contno,
    b.split,
    b.original_invoice_number,
    b.original_client,
    b.original_invoice_type,
    b.invoice_date,
    b.posted_ledref,
    b.invoice_value,
    b.invoice_currency,
    b.house_rate,
    b.unfixed_prov_ledref,
    b.original_final_invoice_number;

-- ============================================================
-- View 8: forecast_report_view_final_invoices_with_outbooking
-- Source: dba.forecast_report_view_final_invoices_with_outbooking
-- 3 UNION ALL sections. Each section uses a derived subquery
-- to resolve alias chains (total_forecast -> total_forecast_base_curr,
-- signed_invoice_value -> posted_invoice_value).
-- Conversions:
--   if/then/else/endif -> CASE WHEN/THEN/ELSE/END
--   list(distinct(...)) -> string_agg(DISTINCT ...::text, ' ')
--   string(x) -> x::text
--   isnull(a,b) -> COALESCE(a,b)
--   ifnull(v,null,x) -> CASE WHEN v IS NULL THEN NULL ELSE x END
--   today() -> CURRENT_DATE
--   Stock_Allocation_Check alias in WHERE -> inline function call
--   Section 3 column order corrected to match Section 1
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_report_view_final_invoices_with_outbooking AS

-- ---- Section 1: Final purchase invoices (via final_invoice_details_2) ----
SELECT
    s1.order_flag,
    s1.order_label,
    s1.allocation_reference,
    s1.allocation_company,
    s1.alliocation_pcentre,
    s1.allocation_commodity,
    s1.allocation_commodity_type,
    s1.allocation_date,
    s1.allocation_total_sales_quantity,
    s1.allocation_total_unfixed,
    s1.allocation_fixed_flag,
    s1.contno,
    s1.split,
    s1.priceterm,
    s1.record_date,
    s1.contract_client,
    s1.allocated_quantity,
    s1.price_curr_unit,
    s1.currency,
    s1.priceunit,
    s1.total_forecast,
    CASE WHEN s1.currency LIKE 'US%'
         THEN s1.total_forecast
         ELSE s1.ccf * s1.total_forecast END                  AS total_forecast_base_curr,
    s1.invoice_heading,
    s1.invoice_order,
    s1.invoice_flag,
    s1.invoice_number,
    s1.invoice_date,
    s1.invoice_client,
    s1.invoice_text,
    s1.invoiced_quantity,
    s1.invoice_unit_price,
    s1.invoice_currency,
    s1.invoice_priceunit,
    s1.invoice_value,
    s1.signed_invoice_value,
    s1.posted_date,
    CASE WHEN s1.ratetype = 'D'
         THEN s1.signed_invoice_value / s1.invoice_house_rate
         ELSE s1.signed_invoice_value * s1.invoice_house_rate END AS posted_invoice_value,
    s1.contract_type,
    s1.allocation_completed,
    s1.allocation_completed_date,
    s1.invoice_house_rate,
    s1.ccf                                                    AS contract_currency_to_basecurr_conversion_factor,
    s1.stock_allocation_check,
    s1.final_invoice_number,
    s1.final_invoice_exists,
    s1.manual_outb_expense_amount,
    s1.merged_line_splitter,
    s1.suggest_completed,
    s1.origin
FROM (
    SELECT
        '02'::text                                            AS order_flag,
        'P Contract:'::text                                   AS order_label,
        allocation.allocation_reference,
        allocation.company                                    AS allocation_company,
        allocation.pcentre                                    AS alliocation_pcentre,
        allocation.commodity                                  AS allocation_commodity,
        allocation.commodity_type                             AS allocation_commodity_type,
        (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
         WHERE ah.allocation_reference = allocation.allocation_reference
           AND ah.hist_type = 'AN')                          AS allocation_date,
        (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
         FROM public.allocated_contracts a_c,
              public.sub_contracts s_c,
              public.master_contracts m_c
         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
           AND s_c.contno = a_c.contno
           AND a_c.split = s_c.split
           AND s_c.contno = m_c.contno
           AND m_c.contract_type = 'S')                      AS allocation_total_sales_quantity,
        public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE WHEN public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0
             THEN 'Unfixed'::text ELSE 'Fixed'::text END     AS allocation_fixed_flag,
        sub_contracts.contno,
        sub_contracts.split,
        master_contracts.priceterm,
        master_contracts.contdate                            AS record_date,
        sub_contracts.client                                 AS contract_client,
        -1 * public.sp_convert_qty(
            (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND allocated_contracts.contno = a_c.contno
               AND a_c.split = sub_contracts.split
               AND master_contracts.contract_type = 'P'),
            sub_contracts.quantunit, 'MT')                   AS allocated_quantity,
        CASE WHEN sub_contracts.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
             ELSE sub_contracts.unitprice END                 AS price_curr_unit,
        sub_contracts.currency,
        sub_contracts.priceunit,
        -- total_forecast: USC (cents) gets 0.01 factor; all other currencies identical non-USC branch
        CASE WHEN sub_contracts.currency = 'USC'
             THEN (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit) * 0.01)
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
             ELSE (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit))
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
        END                                                  AS total_forecast,
        CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
             THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
             ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END                                                  AS ccf,
        'Final P Invoices:'::text                            AS invoice_heading,
        '03'::text                                           AS invoice_order,
        '210'::text                                          AS invoice_flag,
        final_invoice.final_invoice_number::text             AS invoice_number,
        final_invoice.posted_date                            AS invoice_date,
        final_invoice.client::text                           AS invoice_client,
        CASE WHEN final_invoice.final_invoice_number IS NULL
             THEN NULL ELSE 'Final Invoice'::text END        AS invoice_text,
        NULL::numeric                                        AS invoiced_quantity,
        final_invoice_details_2.unit_price::text             AS invoice_unit_price,
        sub_contracts.currency                               AS invoice_currency,
        sub_contracts.priceunit::text                        AS invoice_priceunit,
        final_invoice_details_2.net_due_partial              AS invoice_value,
        CASE WHEN final_invoice_details_2.nomcode LIKE '6%'
             THEN CASE WHEN final_invoice.posted_ledref IS NOT NULL
                       THEN final_invoice_details_2.net_due_partial
                       ELSE 0 END
             ELSE NULL END                                   AS signed_invoice_value,
        COALESCE(final_invoice.posted_date, master_contracts.contdate) AS posted_date,
        currency.ratetype,
        final_invoice.house_rate                             AS invoice_house_rate,
        master_contracts.contract_type,
        allocation.allocation_completed,
        allocation.allocation_completed_date,
        public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) AS stock_allocation_check,
        NULL::text                                           AS final_invoice_number,
        NULL::text                                           AS final_invoice_exists,
        0::numeric                                           AS manual_outb_expense_amount,
        NULL::text                                           AS merged_line_splitter,
        allocation.suggest_completed,
        (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
         FROM public.sub_contracts s_c,
              public.allocated_contracts a_c
         WHERE a_c.allocation_reference = allocation.allocation_reference
           AND a_c.contno = s_c.contno
           AND a_c.split = s_c.split)                        AS origin
    FROM public.allocation
    JOIN public.allocated_contracts
        ON allocation.allocation_reference = allocated_contracts.allocation_reference
    JOIN public.final_invoice_details_2
        ON allocated_contracts.contno            = final_invoice_details_2.contno
        AND allocated_contracts.split            = final_invoice_details_2.split
        AND allocated_contracts.allocation_reference = final_invoice_details_2.allocation_reference
    JOIN public.final_invoice
        ON final_invoice_details_2.invoice_number = final_invoice.invoice_number
        AND final_invoice_details_2.client        = final_invoice.client
        AND final_invoice_details_2.invoice_type  = final_invoice.invoice_type
    JOIN public.currency ON final_invoice.invoice_currency = currency.code
    JOIN public.sub_contracts
        ON sub_contracts.contno = allocated_contracts.contno
        AND sub_contracts.split = allocated_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    CROSS JOIN public.params
    WHERE master_contracts.contract_type = 'P'
      AND public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) = 'N'
      AND LEFT(RIGHT(final_invoice.invoice_number::text, 8), 3) <> '206'
) s1

UNION ALL

-- ---- Section 2: Stock outbooking purchase lines (PI flag, OUTB, invoice number matched) ----
SELECT
    s2.order_flag,
    s2.order_label,
    s2.allocation_reference,
    s2.allocation_company,
    s2.alliocation_pcentre,
    s2.allocation_commodity,
    s2.allocation_commodity_type,
    s2.allocation_date,
    s2.allocation_total_sales_quantity,
    s2.allocation_total_unfixed,
    s2.allocation_fixed_flag,
    s2.contno,
    s2.split,
    s2.priceterm,
    s2.record_date,
    s2.contract_client,
    s2.allocated_quantity,
    s2.price_curr_unit,
    s2.currency,
    s2.priceunit,
    s2.total_forecast,
    CASE WHEN s2.currency LIKE 'US%'
         THEN s2.total_forecast
         ELSE s2.ccf * s2.total_forecast END                  AS total_forecast_base_curr,
    s2.invoice_heading,
    s2.invoice_order,
    s2.invoice_flag,
    s2.invoice_number,
    s2.invoice_date,
    s2.invoice_client,
    s2.invoice_text,
    s2.invoiced_quantity,
    s2.invoice_unit_price,
    s2.invoice_currency,
    s2.invoice_priceunit,
    s2.invoice_value,
    s2.signed_invoice_value,
    s2.posted_date,
    CASE WHEN s2.ratetype = 'D'
         THEN s2.signed_invoice_value / s2.frv_house_rate
         ELSE s2.signed_invoice_value * s2.frv_house_rate END AS posted_invoice_value,
    s2.contract_type,
    s2.allocation_completed,
    s2.allocation_completed_date,
    s2.invoice_house_rate,
    s2.ccf                                                    AS contract_currency_to_basecurr_conversion_factor,
    s2.stock_allocation_check,
    s2.final_invoice_number,
    s2.final_invoice_exists,
    s2.manual_outb_expense_amount,
    s2.merged_line_splitter,
    s2.suggest_completed,
    s2.origin
FROM (
    SELECT
        '02'::text                                            AS order_flag,
        'P Contract:'::text                                   AS order_label,
        allocation.allocation_reference,
        allocation.company                                    AS allocation_company,
        allocation.pcentre                                    AS alliocation_pcentre,
        allocation.commodity                                  AS allocation_commodity,
        allocation.commodity_type                             AS allocation_commodity_type,
        (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
         WHERE ah.allocation_reference = allocation.allocation_reference
           AND ah.hist_type = 'AN')                          AS allocation_date,
        (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
         FROM public.allocated_contracts a_c,
              public.sub_contracts s_c,
              public.master_contracts m_c
         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
           AND s_c.contno = a_c.contno
           AND a_c.split = s_c.split
           AND s_c.contno = m_c.contno
           AND m_c.contract_type = 'S')                      AS allocation_total_sales_quantity,
        public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE WHEN public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0
             THEN 'Unfixed'::text ELSE 'Fixed'::text END     AS allocation_fixed_flag,
        sub_contracts.contno,
        sub_contracts.split,
        master_contracts.priceterm,
        master_contracts.contdate                            AS record_date,
        sub_contracts.client                                 AS contract_client,
        -1 * public.sp_convert_qty(
            (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND allocated_contracts.contno = a_c.contno
               AND a_c.split = sub_contracts.split
               AND master_contracts.contract_type = 'P'),
            sub_contracts.quantunit, 'MT')                   AS allocated_quantity,
        CASE WHEN sub_contracts.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
             ELSE sub_contracts.unitprice END                 AS price_curr_unit,
        sub_contracts.currency,
        sub_contracts.priceunit,
        CASE WHEN sub_contracts.currency = 'USC'
             THEN (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit) * 0.01)
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
             ELSE (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit))
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
        END                                                  AS total_forecast,
        CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
             THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
             ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END                                                  AS ccf,
        'Purch Invoices:'::text                              AS invoice_heading,
        '02'::text                                           AS invoice_order,
        '210'::text                                          AS invoice_flag,
        frv.original_invoice_number::text                    AS invoice_number,
        NULL::date                                           AS invoice_date,
        'STK OUTB'::text                                     AS invoice_client,
        'Stock outbooking         ' || accdetail.ledgernum::text AS invoice_text,
        accsummary.an_tonnage                                AS invoiced_quantity,
        NULL::text                                           AS invoice_unit_price,
        NULL::bpchar                                         AS invoice_currency,
        NULL::text                                           AS invoice_priceunit,
        accdetail.ledamt                                     AS invoice_value,
        accdetail.ledamt                                     AS signed_invoice_value,
        accsummary.leddate                                   AS posted_date,
        currency.ratetype,
        frv.house_rate                                       AS frv_house_rate,
        accdetail.house_rate                                 AS invoice_house_rate,
        master_contracts.contract_type,
        allocation.allocation_completed,
        allocation.allocation_completed_date,
        public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) AS stock_allocation_check,
        NULL::text                                           AS final_invoice_number,
        NULL::text                                           AS final_invoice_exists,
        0::numeric                                           AS manual_outb_expense_amount,
        accdetail.linenum::text                              AS merged_line_splitter,
        allocation.suggest_completed,
        (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
         FROM public.sub_contracts s_c,
              public.allocated_contracts a_c
         WHERE a_c.allocation_reference = allocation.allocation_reference
           AND a_c.contno = s_c.contno
           AND a_c.split = s_c.split)                        AS origin
    FROM public.allocation
    JOIN public.allocated_contracts
        ON allocation.allocation_reference = allocated_contracts.allocation_reference
    JOIN public.sub_contracts
        ON sub_contracts.contno = allocated_contracts.contno
        AND sub_contracts.split = allocated_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.forecast_report_view_stocks_assigned_to_sales_invoice frv
        ON allocated_contracts.contno            = frv.contno
        AND allocated_contracts.split            = frv.split
        AND allocated_contracts.allocation_reference = frv.allocation_reference
--    AND frv.unfixed_prov_ledref IS NULL
    JOIN public.accdetail
        ON accdetail.caja_project              = 'OUTB'
        AND accdetail.accdetail_contno         = sub_contracts.contno
        AND accdetail.accdetail_split          = sub_contracts.split
        AND accdetail.accdetail_invoice_flag   = 'PI'
        AND accdetail.accdetail_invoice_number IS NOT NULL
        AND accdetail.accdetail_invoice_number = frv.original_invoice_number
        AND accdetail.accdetail_allocation_reference = allocation.allocation_reference
    JOIN public.accsummary
        ON accsummary.accperiod  = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
--    AND (accsummary.reversed = '' OR accsummary.reversed IS NULL)
    JOIN public.currency ON currency.code = accdetail.currency
    CROSS JOIN public.params
    WHERE master_contracts.contract_type = 'P'
      AND public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) = 'N'
      AND accdetail.nominal LIKE '6%'
      AND LEFT(RIGHT(frv.original_invoice_number::text, 8), 3) <> '206'
) s2

UNION ALL

-- ---- Section 3: Stock outbooking lines where unfixed_prov_ledref exists (final invoice case) ----
SELECT
    s3.order_flag,
    s3.order_label,
    s3.allocation_reference,
    s3.allocation_company,
    s3.alliocation_pcentre,
    s3.allocation_commodity,
    s3.allocation_commodity_type,
    s3.allocation_date,
    s3.allocation_total_sales_quantity,
    s3.allocation_total_unfixed,
    s3.allocation_fixed_flag,
    s3.contno,
    s3.split,
    s3.priceterm,
    s3.record_date,
    s3.contract_client,
    s3.allocated_quantity,
    s3.price_curr_unit,
    s3.currency,
    s3.priceunit,
    s3.price_curr_unit * s3.allocated_quantity            AS total_forecast,
    s3.ccf * (s3.price_curr_unit * s3.allocated_quantity) AS total_forecast_base_curr,
    s3.invoice_heading,
    s3.invoice_order,
    s3.invoice_flag,
    s3.invoice_number,
    s3.invoice_date,
    s3.invoice_client,
    s3.invoice_text,
    s3.invoiced_quantity,
    s3.invoice_unit_price,
    s3.invoice_currency,
    s3.invoice_priceunit,
    s3.invoice_value,
    s3.signed_invoice_value,
    s3.posted_date,
    CASE WHEN s3.ratetype = 'D'
         THEN s3.signed_invoice_value / s3.invoice_house_rate
         ELSE s3.signed_invoice_value * s3.invoice_house_rate END AS posted_invoice_value,
    s3.contract_type,
    s3.allocation_completed,
    s3.allocation_completed_date,
    s3.invoice_house_rate,
    s3.ccf                                                AS contract_currency_to_basecurr_conversion_factor,
    s3.stock_allocation_check,
    s3.final_invoice_number,
    s3.final_invoice_exists,
    s3.manual_outb_expense_amount,
    s3.merged_line_splitter,
    s3.suggest_completed,
    s3.origin
FROM (
    SELECT
        '02'::text                                            AS order_flag,
        'P Contract:'::text                                   AS order_label,
        allocation.allocation_reference,
        allocation.company                                    AS allocation_company,
        allocation.pcentre                                    AS alliocation_pcentre,
        allocation.commodity                                  AS allocation_commodity,
        allocation.commodity_type                             AS allocation_commodity_type,
        (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
         WHERE ah.allocation_reference = allocation.allocation_reference
           AND ah.hist_type = 'AN')                          AS allocation_date,
        (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
         FROM public.allocated_contracts a_c,
              public.sub_contracts s_c,
              public.master_contracts m_c
         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
           AND s_c.contno = a_c.contno
           AND a_c.split = s_c.split
           AND s_c.contno = m_c.contno
           AND m_c.contract_type = 'S')                      AS allocation_total_sales_quantity,
        public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE WHEN public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0
             THEN 'Unfixed'::text ELSE 'Fixed'::text END     AS allocation_fixed_flag,
        sub_contracts.contno,
        sub_contracts.split,
        master_contracts.priceterm,
        master_contracts.contdate                            AS record_date,
        sub_contracts.client                                 AS contract_client,
        -1 * public.sp_convert_qty(
            (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND allocated_contracts.contno = a_c.contno
               AND a_c.split = sub_contracts.split
               AND master_contracts.contract_type = 'P'),
            sub_contracts.quantunit, 'MT')                   AS allocated_quantity,
        CASE WHEN sub_contracts.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
             ELSE sub_contracts.unitprice END                 AS price_curr_unit,
        sub_contracts.currency,
        sub_contracts.priceunit,
        CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
             THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
             ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END                                                  AS ccf,
        'Final P Invoices:'::text                            AS invoice_heading,
        '07'::text                                           AS invoice_order,
        '210'::text                                          AS invoice_flag,
        NULL::text                                           AS invoice_number,
        NULL::date                                           AS invoice_date,
        NULL::text                                           AS invoice_client,
        'Stock outbooking'::text                             AS invoice_text,
        accsummary.an_tonnage                                AS invoiced_quantity,
        NULL::text                                           AS invoice_unit_price,
        NULL::bpchar                                         AS invoice_currency,
        NULL::text                                           AS invoice_priceunit,
        accdetail.ledamt                                     AS invoice_value,
        accdetail.ledamt                                     AS signed_invoice_value,
        accsummary.leddate                                   AS posted_date,
        currency.ratetype,
        accdetail.house_rate                                 AS invoice_house_rate,
        master_contracts.contract_type,
        allocation.allocation_completed,
        allocation.allocation_completed_date,
        public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) AS stock_allocation_check,
        NULL::text                                           AS final_invoice_number,
        NULL::text                                           AS final_invoice_exists,
        0::numeric                                           AS manual_outb_expense_amount,
        NULL::text                                           AS merged_line_splitter,
        allocation.suggest_completed,
        (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
         FROM public.sub_contracts s_c,
              public.allocated_contracts a_c
         WHERE a_c.allocation_reference = allocation.allocation_reference
           AND a_c.contno = s_c.contno
           AND a_c.split = s_c.split)                        AS origin
    FROM public.allocation
    JOIN public.allocated_contracts
        ON allocation.allocation_reference = allocated_contracts.allocation_reference
    JOIN public.sub_contracts
        ON sub_contracts.contno = allocated_contracts.contno
        AND sub_contracts.split = allocated_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.forecast_report_view_stocks_assigned_to_sales_invoice frv
        ON allocated_contracts.contno            = frv.contno
        AND allocated_contracts.split            = frv.split
        AND allocated_contracts.allocation_reference = frv.allocation_reference
        AND frv.unfixed_prov_ledref IS NOT NULL
    JOIN public.accdetail
        ON accdetail.caja_project              = 'OUTB'
        AND accdetail.accdetail_contno         = sub_contracts.contno
        AND accdetail.accdetail_split          = sub_contracts.split
        AND accdetail.accdetail_invoice_flag   = 'PI'
        AND accdetail.accdetail_final_invoice_number = frv.original_final_invoice_number
    JOIN public.accsummary
        ON accsummary.accperiod    = accdetail.accperiod
        AND accsummary.ledgernum   = accdetail.ledgernum
        AND accsummary.prov_inv_no = frv.sales_invoice_number
--    AND (accsummary.reversed = '' OR accsummary.reversed IS NULL)
    JOIN public.currency ON currency.code = accdetail.currency
    CROSS JOIN public.params
    WHERE master_contracts.contract_type = 'P'
      AND public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) = 'N'
      AND accdetail.nominal LIKE '6%'
) s3;

-- ============================================================
-- View 9: forecast_report_view_purchase_invoices_with_outbooking
-- Source: dba.forecast_report_view_purchase_invoices_with_outbooking
-- 3 sections: UNION ALL between S1+S2, then UNION (dedup) with S3.
-- S1: LEFT OUTER JOINs (rows exist even with no invoice yet).
-- S2: Stock outbooking lines (unfixed_prov_ledref IS NULL,
--     accdetail_final_invoice_number IS NULL).
-- S3: Purchase invoice charges via invoice_charges (UNION dedup).
-- Conversions:
--   if/then/else/endif -> CASE WHEN/THEN/ELSE/END
--   // comments -> removed; -- comments preserved
--   list(distinct(...)) -> string_agg(DISTINCT ...::text, ' ')
--   string(x) -> x::text; today() -> CURRENT_DATE
--   isnull(a,b) -> COALESCE(a,b)
--   ifnull(v,null,x) -> CASE WHEN v IS NULL THEN NULL ELSE x END
--   Stock_Allocation_Check alias in WHERE -> inline function call
--   final_invoice_exists alias in WHERE -> inlined in WHERE directly
--   Alias chains resolved via derived subqueries per section
--   S1 CCF: hardcoded 0.01/1 for USC/USD, sp_get_outright for others
--     (sp_curr_getunderlying version remains commented out)
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_report_view_purchase_invoices_with_outbooking AS

-- ---- Section 1: Purchase invoices (LEFT JOINs - may have no invoice yet) ----
SELECT
    s1.order_flag,
    s1.order_label,
    s1.allocation_reference,
    s1.allocation_company,
    s1.alliocation_pcentre,
    s1.allocation_commodity,
    s1.allocation_commodity_type,
    s1.allocation_date,
    s1.allocation_total_sales_quantity,
    s1.allocation_total_unfixed,
    s1.allocation_fixed_flag,
    s1.contno,
    s1.split,
    s1.priceterm,
    s1.record_date,
    s1.contract_client,
    s1.allocated_quantity,
    s1.price_curr_unit,
    s1.currency,
    s1.priceunit,
    s1.total_forecast,
    CASE WHEN s1.currency LIKE 'US%'
         THEN s1.total_forecast
         ELSE s1.ccf * s1.total_forecast END                  AS total_forecast_base_curr,
    s1.invoice_heading,
    s1.invoice_order,
    s1.invoice_flag,
    s1.invoice_number,
    s1.invoice_date,
    s1.invoice_client,
    s1.invoice_text,
    s1.invoiced_quantity,
    s1.invoice_unit_price,
    s1.invoice_currency,
    s1.invoice_priceunit,
    s1.invoice_value,
    s1.signed_invoice_value,
    s1.posted_date,
    CASE WHEN s1.ratetype = 'D'
         THEN s1.signed_invoice_value / s1.invoice_house_rate
         ELSE s1.signed_invoice_value * s1.invoice_house_rate END AS posted_invoice_value,
    s1.contract_type,
    s1.allocation_completed,
    s1.allocation_completed_date,
    s1.invoice_house_rate,
    s1.ccf                                                    AS contract_currency_to_basecurr_conversion_factor,
    s1.stock_allocation_check,
    s1.final_invoice_number,
    s1.final_invoice_exists,
    s1.manual_outb_expense_amount,
    s1.merged_line_splitter,
    s1.suggest_completed,
    s1.origin
FROM (
    SELECT
        '02'::text                                            AS order_flag,
        'P Contract:'::text                                   AS order_label,
        allocation.allocation_reference,
        allocation.company                                    AS allocation_company,
        allocation.pcentre                                    AS alliocation_pcentre,
        allocation.commodity                                  AS allocation_commodity,
        allocation.commodity_type                             AS allocation_commodity_type,
        (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
         WHERE ah.allocation_reference = allocation.allocation_reference
           AND ah.hist_type = 'AN')                          AS allocation_date,
        (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
         FROM public.allocated_contracts a_c,
              public.sub_contracts s_c,
              public.master_contracts m_c
         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
           AND s_c.contno = a_c.contno
           AND a_c.split = s_c.split
           AND s_c.contno = m_c.contno
           AND m_c.contract_type = 'S')                      AS allocation_total_sales_quantity,
        public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE WHEN public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0
             THEN 'Unfixed'::text ELSE 'Fixed'::text END     AS allocation_fixed_flag,
        sub_contracts.contno,
        sub_contracts.split,
        master_contracts.priceterm,
        master_contracts.contdate                            AS record_date,
        sub_contracts.client                                 AS contract_client,
        -1 * public.sp_convert_qty(
            (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND allocated_contracts.contno = a_c.contno
               AND a_c.split = sub_contracts.split
               AND master_contracts.contract_type = 'P'),
            sub_contracts.quantunit, 'MT')                   AS allocated_quantity,
        CASE WHEN sub_contracts.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
             ELSE sub_contracts.unitprice END                 AS price_curr_unit,
        sub_contracts.currency,
        sub_contracts.priceunit,
        CASE WHEN sub_contracts.currency = 'USC'
             THEN (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit) * 0.01)
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
             ELSE (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit))
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
        END                                                  AS total_forecast,
        -- CCF: hardcoded rates for USD/USC; sp_get_outright for other currencies.
        -- (The sp_curr_getunderlying version is commented out in the original)
        CASE WHEN sub_contracts.currency LIKE 'US%'
             THEN CASE WHEN sub_contracts.currency = 'USC' THEN 0.01 ELSE 1 END
             ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END                                                  AS ccf,
--      CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
--           THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
--           ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
--      END                                                  AS ccf,
        'Purch Invoices:'::text                              AS invoice_heading,
        '01'::text                                           AS invoice_order,
        '210'::text                                          AS invoice_flag,
        invoice.invoice_number::text                         AS invoice_number,
        invoice.posted_date                                  AS invoice_date,
        invoice.client::text                                 AS invoice_client,
        CASE WHEN invoice.invoice_number IS NULL
             THEN NULL ELSE 'Purchase Invoice'::text END     AS invoice_text,
        -1 * public.sp_convert_qty(
            invoice_details_2.invoiced_quantity,
            sub_contracts.quantunit, params.base_unit)       AS invoiced_quantity,
        invoice_details_2.unit_price::text                   AS invoice_unit_price,
        CASE WHEN sub_contracts.currency = 'USC' AND invoice.invoice_currency = 'USD'
             THEN sub_contracts.currency
             ELSE invoice.invoice_currency END               AS invoice_currency,
        sub_contracts.priceunit::text                        AS invoice_priceunit,
        public.sp_sopex_get_sum_invoice_details_2_quantity_linevalue(
            'L', invoice_details_2.invoice_number, invoice_details_2.invoice_type,
            invoice_details_2.client, invoice_details_2.allocation_reference,
            invoice_details_2.contno, invoice_details_2.split) AS invoice_value,
        -- signed_invoice_value: 0 if unposted; invoice_value only if posted to 6% nomcode; else null
        CASE WHEN invoice.posted_ledref IS NULL THEN 0
             ELSE CASE WHEN invoice_details_2.nomcode LIKE '6%'
                       THEN public.sp_sopex_get_sum_invoice_details_2_quantity_linevalue(
                                'L', invoice_details_2.invoice_number, invoice_details_2.invoice_type,
                                invoice_details_2.client, invoice_details_2.allocation_reference,
                                invoice_details_2.contno, invoice_details_2.split)
                       ELSE NULL END
        END                                                  AS signed_invoice_value,
        COALESCE(invoice.posted_date, master_contracts.contdate) AS posted_date,
        currency.ratetype,
        invoice.house_rate                                   AS invoice_house_rate,
        master_contracts.contract_type,
        allocation.allocation_completed,
        allocation.allocation_completed_date,
        public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) AS stock_allocation_check,
        (SELECT fi.final_invoice_number
         FROM public.final_invoice fi
         WHERE fi.invoice_number = invoice.invoice_number
           AND fi.invoice_type   = invoice.invoice_type
           AND fi.client         = invoice.client)           AS final_invoice_number,
        -- final_invoice_exists: 'Y' only for 34%-nomcode lines that have a final invoice
        CASE WHEN invoice_details_2.nomcode LIKE '34%'
             THEN CASE WHEN (SELECT fi.final_invoice_number FROM public.final_invoice fi
                             WHERE fi.invoice_number = invoice.invoice_number
                               AND fi.invoice_type   = invoice.invoice_type
                               AND fi.client         = invoice.client) IS NOT NULL
                       THEN 'Y' ELSE 'N' END
             ELSE 'N'
        END                                                  AS final_invoice_exists,
        0::numeric                                           AS manual_outb_expense_amount,
        NULL::text                                           AS merged_line_splitter,
        allocation.suggest_completed,
        (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
         FROM public.sub_contracts s_c,
              public.allocated_contracts a_c
         WHERE a_c.allocation_reference = allocation.allocation_reference
           AND a_c.contno = s_c.contno
           AND a_c.split = s_c.split)                        AS origin
    FROM public.allocation
    JOIN public.allocated_contracts
        ON allocation.allocation_reference = allocated_contracts.allocation_reference
    LEFT JOIN public.invoice_details_2
        ON allocated_contracts.contno            = invoice_details_2.contno
        AND allocated_contracts.split            = invoice_details_2.split
        AND allocated_contracts.allocation_reference = invoice_details_2.allocation_reference
    LEFT JOIN public.invoice
        ON invoice_details_2.invoice_number = invoice.invoice_number
        AND invoice_details_2.client        = invoice.client
        AND invoice_details_2.invoice_type  = invoice.invoice_type
    LEFT JOIN public.currency ON invoice.invoice_currency = currency.code
    JOIN public.sub_contracts
        ON sub_contracts.contno = allocated_contracts.contno
        AND sub_contracts.split = allocated_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    CROSS JOIN public.params
    WHERE master_contracts.contract_type = 'P'
      AND public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) = 'N'
      AND (
            CASE WHEN invoice_details_2.nomcode LIKE '34%'
                 THEN CASE WHEN (SELECT fi.final_invoice_number FROM public.final_invoice fi
                                 WHERE fi.invoice_number = invoice.invoice_number
                                   AND fi.invoice_type   = invoice.invoice_type
                                   AND fi.client         = invoice.client) IS NOT NULL
                           THEN 'Y' ELSE 'N' END
                 ELSE 'N'
            END = 'N'
            OR invoice_details_2.nomcode IS NULL
          )
) s1

UNION ALL

-- ---- Section 2: Stock outbooking purchase lines (provisional, no final invoice) ----
SELECT
    s2.order_flag,
    s2.order_label,
    s2.allocation_reference,
    s2.allocation_company,
    s2.alliocation_pcentre,
    s2.allocation_commodity,
    s2.allocation_commodity_type,
    s2.allocation_date,
    s2.allocation_total_sales_quantity,
    s2.allocation_total_unfixed,
    s2.allocation_fixed_flag,
    s2.contno,
    s2.split,
    s2.priceterm,
    s2.record_date,
    s2.contract_client,
    s2.allocated_quantity,
    s2.price_curr_unit,
    s2.currency,
    s2.priceunit,
    s2.total_forecast,
    CASE WHEN s2.currency LIKE 'US%'
         THEN s2.total_forecast
         ELSE s2.ccf * s2.total_forecast END                  AS total_forecast_base_curr,
    s2.invoice_heading,
    s2.invoice_order,
    s2.invoice_flag,
    s2.invoice_number,
    s2.invoice_date,
    s2.invoice_client,
    s2.invoice_text,
    s2.invoiced_quantity,
    s2.invoice_unit_price,
    s2.invoice_currency,
    s2.invoice_priceunit,
    s2.invoice_value,
    s2.signed_invoice_value,
    s2.posted_date,
    CASE WHEN s2.ratetype = 'D'
         THEN s2.signed_invoice_value / s2.frv_house_rate
         ELSE s2.signed_invoice_value * s2.frv_house_rate END AS posted_invoice_value,
    s2.contract_type,
    s2.allocation_completed,
    s2.allocation_completed_date,
    s2.invoice_house_rate,
    s2.ccf                                                    AS contract_currency_to_basecurr_conversion_factor,
    s2.stock_allocation_check,
    s2.final_invoice_number,
    s2.final_invoice_exists,
    s2.manual_outb_expense_amount,
    s2.merged_line_splitter,
    s2.suggest_completed,
    s2.origin
FROM (
    SELECT
        '02'::text                                            AS order_flag,
        'P Contract:'::text                                   AS order_label,
        allocation.allocation_reference,
        allocation.company                                    AS allocation_company,
        allocation.pcentre                                    AS alliocation_pcentre,
        allocation.commodity                                  AS allocation_commodity,
        allocation.commodity_type                             AS allocation_commodity_type,
        (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
         WHERE ah.allocation_reference = allocation.allocation_reference
           AND ah.hist_type = 'AN')                          AS allocation_date,
        (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
         FROM public.allocated_contracts a_c,
              public.sub_contracts s_c,
              public.master_contracts m_c
         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
           AND s_c.contno = a_c.contno
           AND a_c.split = s_c.split
           AND s_c.contno = m_c.contno
           AND m_c.contract_type = 'S')                      AS allocation_total_sales_quantity,
        public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE WHEN public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0
             THEN 'Unfixed'::text ELSE 'Fixed'::text END     AS allocation_fixed_flag,
        sub_contracts.contno,
        sub_contracts.split,
        master_contracts.priceterm,
        master_contracts.contdate                            AS record_date,
        sub_contracts.client                                 AS contract_client,
        -1 * public.sp_convert_qty(
            (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND allocated_contracts.contno = a_c.contno
               AND a_c.split = sub_contracts.split
               AND master_contracts.contract_type = 'P'),
            sub_contracts.quantunit, 'MT')                   AS allocated_quantity,
        CASE WHEN sub_contracts.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
             ELSE sub_contracts.unitprice END                 AS price_curr_unit,
        sub_contracts.currency,
        sub_contracts.priceunit,
        CASE WHEN sub_contracts.currency = 'USC'
             THEN (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit) * 0.01)
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
             ELSE (CASE WHEN sub_contracts.price_fixing = 'Y'
                        THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                        ELSE sub_contracts.unitprice END
                   / public.sp_convert_qty(1, sub_contracts.priceunit, params.base_unit))
                  * (-1 * public.sp_convert_qty(
                        (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
                         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                           AND allocated_contracts.contno = a_c.contno
                           AND a_c.split = sub_contracts.split
                           AND master_contracts.contract_type = 'P'),
                        sub_contracts.quantunit, 'MT'))
        END                                                  AS total_forecast,
        CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
             THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
             ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END                                                  AS ccf,
        'Purch Invoices:'::text                              AS invoice_heading,
        '02'::text                                           AS invoice_order,
        '210'::text                                          AS invoice_flag,
        frv.original_invoice_number::text                    AS invoice_number,
        NULL::date                                           AS invoice_date,
        'STK OUTB'::text                                     AS invoice_client,
        'Stock outbooking         ' || accdetail.ledgernum::text AS invoice_text,
        accsummary.an_tonnage                                AS invoiced_quantity,
        NULL::text                                           AS invoice_unit_price,
        NULL::bpchar                                         AS invoice_currency,
        NULL::text                                           AS invoice_priceunit,
        accdetail.ledamt                                     AS invoice_value,
        accdetail.ledamt                                     AS signed_invoice_value,
        accsummary.leddate                                   AS posted_date,
        currency.ratetype,
        frv.house_rate                                       AS frv_house_rate,
        accdetail.house_rate                                 AS invoice_house_rate,
        master_contracts.contract_type,
        allocation.allocation_completed,
        allocation.allocation_completed_date,
        public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) AS stock_allocation_check,
        NULL::text                                           AS final_invoice_number,
        NULL::text                                           AS final_invoice_exists,
        0::numeric                                           AS manual_outb_expense_amount,
        accdetail.linenum::text                              AS merged_line_splitter,
        allocation.suggest_completed,
        (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
         FROM public.sub_contracts s_c,
              public.allocated_contracts a_c
         WHERE a_c.allocation_reference = allocation.allocation_reference
           AND a_c.contno = s_c.contno
           AND a_c.split = s_c.split)                        AS origin
    FROM public.allocation
    JOIN public.allocated_contracts
        ON allocation.allocation_reference = allocated_contracts.allocation_reference
    JOIN public.sub_contracts
        ON sub_contracts.contno = allocated_contracts.contno
        AND sub_contracts.split = allocated_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    JOIN public.forecast_report_view_stocks_assigned_to_sales_invoice frv
        ON allocated_contracts.contno            = frv.contno
        AND allocated_contracts.split            = frv.split
        AND allocated_contracts.allocation_reference = frv.allocation_reference
        AND frv.unfixed_prov_ledref IS NULL
    JOIN public.accdetail
        ON accdetail.caja_project                = 'OUTB'
        AND accdetail.accdetail_contno           = sub_contracts.contno
        AND accdetail.accdetail_split            = sub_contracts.split
        AND accdetail.accdetail_invoice_flag     = 'PI'
        AND accdetail.accdetail_invoice_number   IS NOT NULL
        AND accdetail.accdetail_final_invoice_number IS NULL
        AND accdetail.accdetail_invoice_number   = frv.original_invoice_number
        AND accdetail.accdetail_allocation_reference = allocation.allocation_reference
    JOIN public.accsummary
        ON accsummary.accperiod  = accdetail.accperiod
        AND accsummary.ledgernum = accdetail.ledgernum
--    AND (accsummary.reversed = '' OR accsummary.reversed IS NULL)
    JOIN public.currency ON currency.code = accdetail.currency
    CROSS JOIN public.params
    WHERE master_contracts.contract_type = 'P'
      AND public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) = 'N'
      AND accdetail.nominal LIKE '6%'
) s2

UNION

-- ---- Section 3: Purchase invoice charges (via invoice_charges, added subsequently) ----
-- Note: UNION (dedup) - not UNION ALL - per the original
SELECT
    s3.order_flag,
    s3.order_label,
    s3.allocation_reference,
    s3.allocation_company,
    s3.alliocation_pcentre,
    s3.allocation_commodity,
    s3.allocation_commodity_type,
    s3.allocation_date,
    s3.allocation_total_sales_quantity,
    s3.allocation_total_unfixed,
    s3.allocation_fixed_flag,
    s3.contno,
    s3.split,
    s3.priceterm,
    s3.record_date,
    s3.contract_client,
    s3.allocated_quantity,
    s3.price_curr_unit,
    s3.currency,
    s3.priceunit,
    s3.price_curr_unit * s3.allocated_quantity            AS total_forecast,
    s3.ccf * (s3.price_curr_unit * s3.allocated_quantity) AS total_forecast_base_curr,
    s3.invoice_heading,
    s3.invoice_order,
    s3.invoice_flag,
    s3.invoice_number,
    s3.invoice_date,
    s3.invoice_client,
    s3.invoice_text,
    s3.invoiced_quantity,
    s3.invoice_unit_price,
    s3.invoice_currency,
    s3.invoice_priceunit,
    s3.invoice_value,
    s3.signed_invoice_value,
    s3.posted_date,
    CASE WHEN s3.charge_currency = s3.base_currency
         THEN s3.signed_invoice_value
         ELSE s3.signed_invoice_value * s3.invoice_house_rate END AS posted_invoice_value,
    s3.contract_type,
    s3.allocation_completed,
    s3.allocation_completed_date,
    s3.invoice_house_rate,
    s3.ccf                                                AS contract_currency_to_basecurr_conversion_factor,
    s3.stock_allocation_check,
    s3.final_invoice_number,
    s3.final_invoice_exists,
    s3.manual_outb_expense_amount,
    s3.merged_line_splitter,
    s3.suggest_completed,
    s3.origin
FROM (
    SELECT
        '02'::text                                            AS order_flag,
        'P Contract:'::text                                   AS order_label,
        allocation.allocation_reference,
        allocation.company                                    AS allocation_company,
        allocation.pcentre                                    AS alliocation_pcentre,
        allocation.commodity                                  AS allocation_commodity,
        allocation.commodity_type                             AS allocation_commodity_type,
        (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
         WHERE ah.allocation_reference = allocation.allocation_reference
           AND ah.hist_type = 'AN')                          AS allocation_date,
        (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
         FROM public.allocated_contracts a_c,
              public.sub_contracts s_c,
              public.master_contracts m_c
         WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
           AND s_c.contno = a_c.contno
           AND a_c.split = s_c.split
           AND s_c.contno = m_c.contno
           AND m_c.contract_type = 'S')                      AS allocation_total_sales_quantity,
        public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE WHEN public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > 0
             THEN 'Unfixed'::text ELSE 'Fixed'::text END     AS allocation_fixed_flag,
        sub_contracts.contno,
        sub_contracts.split,
        master_contracts.priceterm,
        master_contracts.contdate                            AS record_date,
        sub_contracts.client                                 AS contract_client,
        -- Section 3: no negation; uses Sales (S) quantity
        public.sp_convert_qty(
            (SELECT SUM(a_c.quantity) FROM public.allocated_contracts a_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND allocated_contracts.contno = a_c.contno
               AND a_c.split = sub_contracts.split
               AND master_contracts.contract_type = 'S'),
            sub_contracts.quantunit, 'MT')                   AS allocated_quantity,
        CASE WHEN sub_contracts.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
             ELSE sub_contracts.unitprice END                 AS price_curr_unit,
        sub_contracts.currency,
        sub_contracts.priceunit,
        CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
             THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
             ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END                                                  AS ccf,
        'Purch Invoices:'::text                              AS invoice_heading,
        '02'::text                                           AS invoice_order,
        '210'::text                                          AS invoice_flag,
        invoice.invoice_number::text                         AS invoice_number,
        invoice.posted_date                                  AS invoice_date,
        invoice.client::text                                 AS invoice_client,
        invoice_charges.description::text                    AS invoice_text,
        NULL::numeric                                        AS invoiced_quantity,
        NULL::text                                           AS invoice_unit_price,
        invoice_charges.currency                             AS invoice_currency,
        NULL::text                                           AS invoice_priceunit,
        CASE WHEN invoice_charges.crdrindicator = 'D'
             THEN invoice_charges.amount * -1
             ELSE invoice_charges.amount END                 AS invoice_value,
        CASE WHEN invoice.posted_ledref IS NULL THEN 0
             ELSE CASE WHEN invoice_charges.crdrindicator = 'D'
                       THEN invoice_charges.amount * -1
                       ELSE invoice_charges.amount END
        END                                                  AS signed_invoice_value,
        COALESCE(invoice.posted_date, master_contracts.contdate) AS posted_date,
        invoice_charges.currency                             AS charge_currency,
        params.base_currency,
        invoice.house_rate                                   AS invoice_house_rate,
        master_contracts.contract_type,
        allocation.allocation_completed,
        allocation.allocation_completed_date,
        public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) AS stock_allocation_check,
        NULL::text                                           AS final_invoice_number,
        NULL::text                                           AS final_invoice_exists,
        0::numeric                                           AS manual_outb_expense_amount,
        NULL::text                                           AS merged_line_splitter,
        allocation.suggest_completed,
        (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
         FROM public.sub_contracts s_c,
              public.allocated_contracts a_c
         WHERE a_c.allocation_reference = allocation.allocation_reference
           AND a_c.contno = s_c.contno
           AND a_c.split = s_c.split)                        AS origin
    FROM public.allocation
    JOIN public.allocated_contracts
        ON allocation.allocation_reference = allocated_contracts.allocation_reference
    JOIN public.invoice_details_2
        ON allocated_contracts.contno            = invoice_details_2.contno
        AND allocated_contracts.split            = invoice_details_2.split
        AND allocated_contracts.allocation_reference = invoice_details_2.allocation_reference
    JOIN public.invoice
        ON invoice_details_2.invoice_number = invoice.invoice_number
        AND invoice_details_2.client        = invoice.client
        AND invoice_details_2.invoice_type  = invoice.invoice_type
    JOIN public.invoice_charges
        ON invoice_charges.invoice_number    = invoice.invoice_number
        AND invoice_charges.client           = invoice.client
        AND invoice_charges.invoice_type     = invoice.invoice_type
        AND invoice_charges.contno           = allocated_contracts.contno
        AND invoice_charges.split            = allocated_contracts.split
        AND invoice_charges.allocation_reference = allocated_contracts.allocation_reference
    JOIN public.currency ON invoice.invoice_currency = currency.code
    JOIN public.sub_contracts
        ON sub_contracts.contno = allocated_contracts.contno
        AND sub_contracts.split = allocated_contracts.split
    JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
    CROSS JOIN public.params
    WHERE master_contracts.contract_type = 'P'
      AND invoice_charges.nominal_account NOT LIKE '3%'
      AND public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) = 'N'
) s3;

-- ============================================================
-- View 10: forecast_report_view
-- Source: dba.forecast_report_view
-- Main forecast report - UNIONs all contract, invoice, reserve,
-- expense, and outbooking activity per allocation.
-- Dependencies (must exist before this view):
--   forecast_report_view_purchase_invoices_with_outbooking
--   forecast_report_view_final_invoices_with_outbooking
--   forecast_report_outbooked_p_expenses_view
-- All sections use UNION (dedup), not UNION ALL.
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_report_view AS

-- ============================================================
-- Section 1 (01a): Sales Contracts, LEFT OUTER JOIN to invoices.
-- Must produce a row even when no invoice exists.
-- Alias chain resolved via 3-level derived subquery:
--   s1b (inner): leaf values â€” sipup, price_curr_unit,
--                allocated_quantity, ccf, invoice_value_raw,
--                invoice_number_raw
--   s1m (mid):   allocation_fixed_flag, total_forecast,
--                invoice_number (with -UNPAID suffix), signed_invoice_value
--   s1  (outer): total_forecast_base_curr, invoice_text, posted_invoice_value
-- ============================================================
SELECT
    s1.order_flag,
    s1.order_label,
    s1.allocation_reference,
    s1.allocation_company,
    s1.alliocation_pcentre,
    s1.allocation_commodity,
    s1.allocation_commodity_type,
    s1.allocation_date,
    s1.allocation_total_sales_quantity,
    s1.allocation_total_unfixed,
    s1.allocation_fixed_flag,
    s1.contno,
    s1.split,
    s1.priceterm,
    s1.record_date,
    s1.contract_client,
    s1.allocated_quantity,
    s1.price_curr_unit,
    s1.currency,
    s1.priceunit,
    s1.total_forecast,
    CASE WHEN s1.currency LIKE 'US%'
         THEN s1.total_forecast
         ELSE s1.ccf * s1.total_forecast END                          AS total_forecast_base_curr,
    s1.invoice_heading,
    s1.invoice_order,
    s1.invoice_flag,
    s1.invoice_number,
    s1.invoice_date,
    s1.invoice_client,
    CASE WHEN s1.invoice_number IS NULL THEN NULL
         ELSE 'Sales Invoice' END                                      AS invoice_text,
    s1.invoiced_quantity,
    s1.invoice_unit_price,
    s1.invoice_currency,
    s1.invoice_priceunit,
    s1.invoice_value,
    s1.signed_invoice_value,
    s1.posted_date,
    CASE WHEN s1.ratetype = 'D'
         THEN s1.signed_invoice_value / s1.invoice_house_rate
         ELSE s1.signed_invoice_value * s1.invoice_house_rate END      AS posted_invoice_value,
    s1.contract_type,
    s1.allocation_completed,
    s1.allocation_completed_date,
    s1.invoice_house_rate,
    s1.ccf                                                             AS contract_currency_to_basecurr_conversion_factor,
    s1.stock_allocation_check,
    s1.manual_outb_expense_amount,
    s1.merged_line_splitter,
    s1.suggest_completed,
    s1.origin,
    s1.sales_invoice_provisional_unpaid
FROM (
    -- s1m: compute allocation_fixed_flag, total_forecast,
    --      invoice_number (with -UNPAID), signed_invoice_value
    SELECT
        s1b.order_flag,
        s1b.order_label,
        s1b.allocation_reference,
        s1b.allocation_company,
        s1b.alliocation_pcentre,
        s1b.allocation_commodity,
        s1b.allocation_commodity_type,
        s1b.allocation_date,
        s1b.allocation_total_sales_quantity,
        s1b.allocation_total_unfixed,
        CASE WHEN s1b.allocation_total_unfixed > 0
             THEN 'Unfixed' ELSE 'Fixed' END                           AS allocation_fixed_flag,
        s1b.contno,
        s1b.split,
        s1b.priceterm,
        s1b.record_date,
        s1b.contract_client,
        s1b.allocated_quantity,
        s1b.price_curr_unit,
        s1b.currency,
        s1b.priceunit,
        CASE WHEN s1b.currency LIKE 'US%'
             THEN CASE WHEN s1b.currency = 'USC'
                       THEN (s1b.price_curr_unit / public.sp_convert_qty(1, s1b.priceunit, s1b.base_unit) * 0.01)
                            * s1b.allocated_quantity
                       ELSE (s1b.price_curr_unit / public.sp_convert_qty(1, s1b.priceunit, s1b.base_unit))
                            * s1b.allocated_quantity
                  END
             ELSE (s1b.price_curr_unit / public.sp_convert_qty(1, s1b.priceunit, s1b.base_unit))
                  * s1b.allocated_quantity
        END                                                            AS total_forecast,
        s1b.invoice_heading,
        s1b.invoice_order,
        s1b.invoice_flag,
        CASE WHEN s1b.sales_invoice_provisional_unpaid = 'Y'
             THEN s1b.invoice_number_raw || '-UNPAID'
             ELSE s1b.invoice_number_raw
        END                                                            AS invoice_number,
        s1b.invoice_date,
        s1b.invoice_client,
        s1b.invoiced_quantity,
        s1b.invoice_unit_price,
        s1b.invoice_currency,
        s1b.invoice_priceunit,
        s1b.invoice_value,
        CASE WHEN s1b.posted_ledref IS NULL THEN 0
             ELSE s1b.invoice_value END                                AS signed_invoice_value,
        s1b.posted_date,
        s1b.ratetype,
        s1b.invoice_house_rate,
        s1b.contract_type,
        s1b.allocation_completed,
        s1b.allocation_completed_date,
        s1b.ccf,
        s1b.stock_allocation_check,
        s1b.manual_outb_expense_amount,
        s1b.merged_line_splitter,
        s1b.suggest_completed,
        s1b.origin,
        s1b.sales_invoice_provisional_unpaid
    FROM (
        -- s1b (innermost): all leaf computations
        SELECT
            '01a'::text                                                AS order_flag,
            'S Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'S'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            params.base_unit,
            'Sales Invoices:'::text                                    AS invoice_heading,
            '01'::text                                                 AS invoice_order,
            '310'::text                                                AS invoice_flag,
            invoice.invoice_number::text                               AS invoice_number_raw,
            invoice.posted_date                                        AS invoice_date,
            invoice.client::text                                       AS invoice_client,
            -- commented-out alternative preserved from original:
            -- sp_convert_qty(invoice_details_2.invoiced_quantity, invoice_details_2.delivered_unit, 'MT')
            public.sp_sopex_get_sum_invoice_details_2_quantity_linevalue(
                'Q', invoice_details_2.invoice_number, invoice_details_2.invoice_type,
                invoice_details_2.client, invoice_details_2.allocation_reference,
                invoice_details_2.contno, invoice_details_2.split)    AS invoiced_quantity,
            -- (select sum(sp_convert_qty(...)) from invoice_details_2 inv_det_2 ...) as invoiced_quantity
            invoice_details_2.unit_price::text                        AS invoice_unit_price,
            sub_contracts.currency                                     AS invoice_currency,
            sub_contracts.priceunit::text                             AS invoice_priceunit,
            -- invoice.invoice_value as invoice_value (original, commented out)
            public.sp_sopex_get_sum_invoice_details_2_quantity_linevalue(
                'L', invoice_details_2.invoice_number, invoice_details_2.invoice_type,
                invoice_details_2.client, invoice_details_2.allocation_reference,
                invoice_details_2.contno, invoice_details_2.split)    AS invoice_value,
            -- invoice_details_2.unit_price * sp_convert_qty(invoiced_quantity, 'MT', priceunit) (original, commented out)
            invoice.posted_ledref,
            COALESCE(invoice.posted_date, master_contracts.contdate)  AS posted_date,
            currency.ratetype,
            invoice.house_rate                                         AS invoice_house_rate,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            NULL::text                                                 AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            CASE WHEN invoice.provisionally_released = 'Y'
                      AND (invoice.provisionally_released_settled = 'N'
                           OR invoice.provisionally_released_settled IS NULL)
                 THEN 'Y'::text ELSE 'N'::text
            END                                                        AS sales_invoice_provisional_unpaid
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        LEFT JOIN public.invoice_details_2
            ON allocated_contracts.contno            = invoice_details_2.contno
            AND allocated_contracts.split            = invoice_details_2.split
            AND allocated_contracts.allocation_reference = invoice_details_2.allocation_reference
        LEFT JOIN public.invoice
            ON invoice_details_2.invoice_number = invoice.invoice_number
            AND invoice_details_2.client        = invoice.client
            AND invoice_details_2.invoice_type  = invoice.invoice_type
        LEFT JOIN public.currency ON invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
--          AND (invoice_details_2.positional_quantity <> 0
--               OR invoice_details_2.positional_quantity IS NULL)
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s1b
) s1

UNION

-- ============================================================
-- Section 2 (01d): Sales Invoice Charges.
-- No invoice_number alias dependency.
-- 3-level nesting:
--   s2b: leaves â€” price_curr_unit, allocated_quantity, ccf,
--        invoice_value (CASE amount_indicator/crdrindicator),
--        charge_currency, base_currency, invoice_house_rate
--   s2m: total_forecast, allocation_fixed_flag, signed_invoice_value
--   s2 : total_forecast_base_curr, posted_invoice_value
-- ============================================================
SELECT
    s2.order_flag,
    s2.order_label,
    s2.allocation_reference,
    s2.allocation_company,
    s2.alliocation_pcentre,
    s2.allocation_commodity,
    s2.allocation_commodity_type,
    s2.allocation_date,
    s2.allocation_total_sales_quantity,
    s2.allocation_total_unfixed,
    s2.allocation_fixed_flag,
    s2.contno,
    s2.split,
    s2.priceterm,
    s2.record_date,
    s2.contract_client,
    s2.allocated_quantity,
    s2.price_curr_unit,
    s2.currency,
    s2.priceunit,
    s2.total_forecast,
    s2.ccf * s2.total_forecast                                        AS total_forecast_base_curr,
    s2.invoice_heading,
    s2.invoice_order,
    s2.invoice_flag,
    s2.invoice_number,
    s2.invoice_date,
    s2.invoice_client,
    s2.invoice_text,
    s2.invoiced_quantity,
    s2.invoice_unit_price,
    s2.invoice_currency,
    s2.invoice_priceunit,
    s2.invoice_value,
    s2.signed_invoice_value,
    s2.posted_date,
    CASE WHEN s2.charge_currency = s2.base_currency
         THEN s2.signed_invoice_value
         ELSE s2.signed_invoice_value * s2.invoice_house_rate END      AS posted_invoice_value,
    s2.contract_type,
    s2.allocation_completed,
    s2.allocation_completed_date,
    s2.invoice_house_rate,
    s2.ccf                                                             AS contract_currency_to_basecurr_conversion_factor,
    s2.stock_allocation_check,
    s2.manual_outb_expense_amount,
    s2.merged_line_splitter,
    s2.suggest_completed,
    s2.origin,
    s2.sales_invoice_provisional_unpaid
FROM (
    SELECT
        s2b.order_flag,
        s2b.order_label,
        s2b.allocation_reference,
        s2b.allocation_company,
        s2b.alliocation_pcentre,
        s2b.allocation_commodity,
        s2b.allocation_commodity_type,
        s2b.allocation_date,
        s2b.allocation_total_sales_quantity,
        s2b.allocation_total_unfixed,
        CASE WHEN s2b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        s2b.contno,
        s2b.split,
        s2b.priceterm,
        s2b.record_date,
        s2b.contract_client,
        s2b.allocated_quantity,
        s2b.price_curr_unit,
        s2b.currency,
        s2b.priceunit,
        s2b.price_curr_unit * s2b.allocated_quantity                   AS total_forecast,
        s2b.invoice_heading,
        s2b.invoice_order,
        s2b.invoice_flag,
        s2b.invoice_number,
        s2b.invoice_date,
        s2b.invoice_client,
        s2b.invoice_text,
        s2b.invoiced_quantity,
        s2b.invoice_unit_price,
        s2b.invoice_currency,
        s2b.invoice_priceunit,
        s2b.invoice_value,
        CASE WHEN s2b.posted_ledref IS NULL THEN 0
             ELSE s2b.invoice_value END                                AS signed_invoice_value,
        s2b.posted_date,
        s2b.charge_currency,
        s2b.base_currency,
        s2b.invoice_house_rate,
        s2b.contract_type,
        s2b.allocation_completed,
        s2b.allocation_completed_date,
        s2b.ccf,
        s2b.stock_allocation_check,
        s2b.manual_outb_expense_amount,
        s2b.merged_line_splitter,
        s2b.suggest_completed,
        s2b.origin,
        s2b.sales_invoice_provisional_unpaid
    FROM (
        SELECT
            '01d'::text                                                AS order_flag,
            'S Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'S'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            'Sales Expenses:'::text                                    AS invoice_heading,
            '04'::text                                                 AS invoice_order,
            '310'::text                                                AS invoice_flag,
            invoice.invoice_number::text                               AS invoice_number,
            invoice.posted_date                                        AS invoice_date,
            invoice.client::text                                       AS invoice_client,
            invoice_charges.description::text                         AS invoice_text,
            NULL::numeric                                              AS invoiced_quantity,
            NULL::text                                                 AS invoice_unit_price,
            invoice_charges.currency                                   AS invoice_currency,
            NULL::text                                                 AS invoice_priceunit,
            CASE WHEN invoice_charges.amount_indicator = 'A'
                 THEN CASE WHEN invoice_charges.crdrindicator = 'D'
                           THEN invoice_charges.amount * -1
                           ELSE invoice_charges.amount END
                 ELSE CASE WHEN invoice_charges.crdrindicator = 'D'
                           THEN ABS(invoice_charges.linevalue) * -1
                           ELSE ABS(invoice_charges.linevalue) END
            END                                                        AS invoice_value,
            invoice.posted_ledref,
            COALESCE(invoice.posted_date, master_contracts.contdate)  AS posted_date,
            invoice_charges.currency                                   AS charge_currency,
            params.base_currency,
            invoice.house_rate                                         AS invoice_house_rate,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            NULL::text                                                 AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            'N'::text                                                  AS sales_invoice_provisional_unpaid
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.invoice_details_2
            ON allocated_contracts.contno            = invoice_details_2.contno
            AND allocated_contracts.split            = invoice_details_2.split
            AND allocated_contracts.allocation_reference = invoice_details_2.allocation_reference
        JOIN public.invoice
            ON invoice_details_2.invoice_number = invoice.invoice_number
            AND invoice_details_2.client        = invoice.client
            AND invoice_details_2.invoice_type  = invoice.invoice_type
        JOIN public.invoice_charges
            ON invoice_charges.invoice_number   = invoice.invoice_number
            AND invoice_charges.client          = invoice.client
            AND invoice_charges.invoice_type    = invoice.invoice_type
            AND invoice_charges.contno          = allocated_contracts.contno
            AND invoice_charges.split           = allocated_contracts.split
            AND invoice_charges.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.currency ON invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND invoice_charges.nominal_account NOT LIKE '3%'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s2b
) s2

UNION

-- ============================================================
-- Section 3: Pass-through from
--   forecast_report_view_purchase_invoices_with_outbooking.
-- No alias chains; no nesting required.
-- stock_allocation_check inlined in WHERE (alias not visible there).
-- ============================================================
SELECT
    frv_pi.order_flag,
    frv_pi.order_label,
    frv_pi.allocation_reference,
    frv_pi.allocation_company,
    frv_pi.alliocation_pcentre,
    frv_pi.allocation_commodity,
    frv_pi.allocation_commodity_type,
    frv_pi.allocation_date,
    frv_pi.allocation_total_sales_quantity,
    frv_pi.allocation_total_unfixed,
    frv_pi.allocation_fixed_flag,
    frv_pi.contno,
    frv_pi.split,
    frv_pi.priceterm,
    frv_pi.record_date,
    frv_pi.contract_client,
    frv_pi.allocated_quantity,
    frv_pi.price_curr_unit,
    frv_pi.currency,
    frv_pi.priceunit,
    frv_pi.total_forecast,
    frv_pi.total_forecast_base_curr,
    frv_pi.invoice_heading,
    frv_pi.invoice_order,
    frv_pi.invoice_flag,
    frv_pi.invoice_number,
    frv_pi.invoice_date,
    frv_pi.invoice_client,
    frv_pi.invoice_text,
    frv_pi.invoiced_quantity,
    frv_pi.invoice_unit_price,
    frv_pi.invoice_currency,
    frv_pi.invoice_priceunit,
    frv_pi.invoice_value,
    frv_pi.signed_invoice_value,
    frv_pi.posted_date,
    frv_pi.posted_invoice_value,
    frv_pi.contract_type,
    frv_pi.allocation_completed,
    frv_pi.allocation_completed_date,
    frv_pi.invoice_house_rate,
    frv_pi.contract_currency_to_basecurr_conversion_factor,
    public.sp_allocation_check_if_only_stock(frv_pi.allocation_reference) AS stock_allocation_check,
    frv_pi.manual_outb_expense_amount,
    frv_pi.merged_line_splitter,
    frv_pi.suggest_completed,
    frv_pi.origin,
    'N'::text                                                          AS sales_invoice_provisional_unpaid
FROM public.forecast_report_view_purchase_invoices_with_outbooking frv_pi
WHERE public.sp_allocation_check_if_only_stock(frv_pi.allocation_reference) = 'N'

UNION

-- ============================================================
-- Section 4 (01b): Sales Reserves.
-- 3-level nesting:
--   s4b: leaves â€” price_curr_unit, allocated_quantity, ccf
--        (4-branch reserves CCF formula), invoice_priceunit
--   s4m: allocation_fixed_flag, total_forecast,
--        invoiced_quantity (= allocated_quantity),
--        invoice_value (uses allocated_quantity)
--   s4 : total_forecast_base_curr
-- CCF branches (reserves): reserves.currency = base â†’ 1;
--   underlying <> base AND reserves.currency <> underlying â†’ sp_datedfxrate;
--   underlying <> base AND reserves.currency = underlying â†’ sp_get_outright;
--   underlying = base AND reserves.currency <> underlying â†’ sp_datedfxrate;
--   else â†’ 0.
-- Commented-out alternative CCF preserved from original.
-- ============================================================
SELECT
    s4.order_flag,
    s4.order_label,
    s4.allocation_reference,
    s4.allocation_company,
    s4.alliocation_pcentre,
    s4.allocation_commodity,
    s4.allocation_commodity_type,
    s4.allocation_date,
    s4.allocation_total_sales_quantity,
    s4.allocation_total_unfixed,
    s4.allocation_fixed_flag,
    s4.contno,
    s4.split,
    s4.priceterm,
    s4.record_date,
    s4.contract_client,
    s4.allocated_quantity,
    s4.price_curr_unit,
    s4.currency,
    s4.priceunit,
    s4.total_forecast,
    CASE WHEN s4.currency LIKE 'US%'
         THEN s4.total_forecast
         ELSE s4.ccf * s4.total_forecast END                          AS total_forecast_base_curr,
    s4.invoice_heading,
    s4.invoice_order,
    s4.invoice_flag,
    s4.invoice_number,
    s4.invoice_date,
    s4.invoice_client,
    s4.invoice_text,
    s4.invoiced_quantity,
    s4.invoice_unit_price,
    s4.invoice_currency,
    s4.invoice_priceunit,
    s4.invoice_value,
    s4.signed_invoice_value,
    s4.posted_date,
    s4.posted_invoice_value,
    s4.contract_type,
    s4.allocation_completed,
    s4.allocation_completed_date,
    s4.invoice_house_rate,
    s4.ccf                                                             AS contract_currency_to_basecurr_conversion_factor,
    s4.stock_allocation_check,
    s4.manual_outb_expense_amount,
    s4.merged_line_splitter,
    s4.suggest_completed,
    s4.origin,
    s4.sales_invoice_provisional_unpaid
FROM (
    SELECT
        s4b.order_flag,
        s4b.order_label,
        s4b.allocation_reference,
        s4b.allocation_company,
        s4b.alliocation_pcentre,
        s4b.allocation_commodity,
        s4b.allocation_commodity_type,
        s4b.allocation_date,
        s4b.allocation_total_sales_quantity,
        s4b.allocation_total_unfixed,
        CASE WHEN s4b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        s4b.contno,
        s4b.split,
        s4b.priceterm,
        s4b.record_date,
        s4b.contract_client,
        s4b.allocated_quantity,
        s4b.price_curr_unit,
        s4b.currency,
        s4b.priceunit,
        CASE WHEN s4b.currency LIKE 'US%'
             THEN CASE WHEN s4b.currency = 'USC'
                       THEN (s4b.price_curr_unit / public.sp_convert_qty(1, s4b.priceunit, s4b.base_unit) * 0.01)
                            * s4b.allocated_quantity
                       ELSE (s4b.price_curr_unit / public.sp_convert_qty(1, s4b.priceunit, s4b.base_unit))
                            * s4b.allocated_quantity
                  END
             ELSE (s4b.price_curr_unit / public.sp_convert_qty(1, s4b.priceunit, s4b.base_unit))
                  * s4b.allocated_quantity
        END                                                            AS total_forecast,
        s4b.invoice_heading,
        s4b.invoice_order,
        s4b.invoice_flag,
        s4b.invoice_number,
        s4b.invoice_date,
        s4b.invoice_client,
        s4b.invoice_text,
        s4b.allocated_quantity                                         AS invoiced_quantity,
        s4b.invoice_unit_price,
        s4b.invoice_currency,
        s4b.invoice_priceunit,
        CASE WHEN s4b.amountind = 'A'
             THEN s4b.reserve_amount
             ELSE s4b.reserve_amount * public.sp_convert_qty(s4b.allocated_quantity, s4b.reserve_unit, 'MT')
        END                                                            AS invoice_value,
        NULL::numeric                                                  AS signed_invoice_value,
        s4b.posted_date,
        NULL::numeric                                                  AS posted_invoice_value,
        s4b.contract_type,
        s4b.allocation_completed,
        s4b.allocation_completed_date,
        s4b.invoice_house_rate,
        s4b.ccf,
        s4b.stock_allocation_check,
        s4b.manual_outb_expense_amount,
        s4b.merged_line_splitter,
        s4b.suggest_completed,
        s4b.origin,
        s4b.sales_invoice_provisional_unpaid
    FROM (
        SELECT
            '01b'::text                                                AS order_flag,
            'S Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'S'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            params.base_unit,
            'Sales Reserves:'::text                                    AS invoice_heading,
            '03'::text                                                 AS invoice_order,
            reserves.reserve                                           AS invoice_flag,
            'S Reserve'::text                                          AS invoice_number,
            NULL::date                                                 AS invoice_date,
            NULL::text                                                 AS invoice_client,
            reserves_types.longname::text                             AS invoice_text,
            reserves.amount::text                                      AS invoice_unit_price,
            reserves.currency                                          AS invoice_currency,
            CASE WHEN reserves.amountind = 'A' THEN NULL
                 ELSE reserves.unit END                                AS invoice_priceunit,
            reserves.amountind,
            reserves.amount                                            AS reserve_amount,
            reserves.unit                                              AS reserve_unit,
            master_contracts.contdate                                  AS posted_date,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            NULL::numeric                                              AS invoice_house_rate,
            -- Reserves CCF: 4-branch logic on reserves.currency vs underlying vs base_currency.
            -- Commented-out simpler alternative preserved from original:
            -- CASE WHEN sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
            --      THEN sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            --      ELSE sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            -- END
            CASE WHEN reserves.currency = params.base_currency
                 THEN 1
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) <> params.base_currency
                      AND reserves.currency <> public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_datedfxrate(reserves.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) <> params.base_currency
                      AND reserves.currency = public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                      AND reserves.currency <> public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_datedfxrate(reserves.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE 0
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            reserves.charges_line::text                               AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            'N'::text                                                  AS sales_invoice_provisional_unpaid
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.reserves
            ON sub_contracts.contno = reserves.contno
            AND sub_contracts.split = reserves.split
        JOIN public.reserves_types ON reserves.reserve = reserves_types.code
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s4b
) s4

UNION

-- ============================================================
-- Section 5 (02): Purchase Reserves.
-- Identical structure to Section 4 (Sales Reserves) except:
--   order_flag = '02', order_label = 'P Contract:'
--   allocated_quantity negated (-1 *), contract_type = 'P'
--   invoice_heading = 'Purch Reserves:', invoice_number = 'P Reserve'
-- Same 3-level nesting and CCF formula as Section 4.
-- Commented-out alternative CCF (with original "and then" typo) preserved.
-- ============================================================
SELECT
    s5.order_flag,
    s5.order_label,
    s5.allocation_reference,
    s5.allocation_company,
    s5.alliocation_pcentre,
    s5.allocation_commodity,
    s5.allocation_commodity_type,
    s5.allocation_date,
    s5.allocation_total_sales_quantity,
    s5.allocation_total_unfixed,
    s5.allocation_fixed_flag,
    s5.contno,
    s5.split,
    s5.priceterm,
    s5.record_date,
    s5.contract_client,
    s5.allocated_quantity,
    s5.price_curr_unit,
    s5.currency,
    s5.priceunit,
    s5.total_forecast,
    CASE WHEN s5.currency LIKE 'US%'
         THEN s5.total_forecast
         ELSE s5.ccf * s5.total_forecast END                          AS total_forecast_base_curr,
    s5.invoice_heading,
    s5.invoice_order,
    s5.invoice_flag,
    s5.invoice_number,
    s5.invoice_date,
    s5.invoice_client,
    s5.invoice_text,
    s5.invoiced_quantity,
    s5.invoice_unit_price,
    s5.invoice_currency,
    s5.invoice_priceunit,
    s5.invoice_value,
    s5.signed_invoice_value,
    s5.posted_date,
    s5.posted_invoice_value,
    s5.contract_type,
    s5.allocation_completed,
    s5.allocation_completed_date,
    s5.invoice_house_rate,
    s5.ccf                                                             AS contract_currency_to_basecurr_conversion_factor,
    s5.stock_allocation_check,
    s5.manual_outb_expense_amount,
    s5.merged_line_splitter,
    s5.suggest_completed,
    s5.origin,
    s5.sales_invoice_provisional_unpaid
FROM (
    SELECT
        s5b.order_flag,
        s5b.order_label,
        s5b.allocation_reference,
        s5b.allocation_company,
        s5b.alliocation_pcentre,
        s5b.allocation_commodity,
        s5b.allocation_commodity_type,
        s5b.allocation_date,
        s5b.allocation_total_sales_quantity,
        s5b.allocation_total_unfixed,
        CASE WHEN s5b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        s5b.contno,
        s5b.split,
        s5b.priceterm,
        s5b.record_date,
        s5b.contract_client,
        s5b.allocated_quantity,
        s5b.price_curr_unit,
        s5b.currency,
        s5b.priceunit,
        CASE WHEN s5b.currency LIKE 'US%'
             THEN CASE WHEN s5b.currency = 'USC'
                       THEN (s5b.price_curr_unit / public.sp_convert_qty(1, s5b.priceunit, s5b.base_unit) * 0.01)
                            * s5b.allocated_quantity
                       ELSE (s5b.price_curr_unit / public.sp_convert_qty(1, s5b.priceunit, s5b.base_unit))
                            * s5b.allocated_quantity
                  END
             ELSE (s5b.price_curr_unit / public.sp_convert_qty(1, s5b.priceunit, s5b.base_unit))
                  * s5b.allocated_quantity
        END                                                            AS total_forecast,
        s5b.invoice_heading,
        s5b.invoice_order,
        s5b.invoice_flag,
        s5b.invoice_number,
        s5b.invoice_date,
        s5b.invoice_client,
        s5b.invoice_text,
        s5b.allocated_quantity                                         AS invoiced_quantity,
        s5b.invoice_unit_price,
        s5b.invoice_currency,
        s5b.invoice_priceunit,
        CASE WHEN s5b.amountind = 'A'
             THEN s5b.reserve_amount
             ELSE s5b.reserve_amount * public.sp_convert_qty(s5b.allocated_quantity, s5b.reserve_unit, 'MT')
        END                                                            AS invoice_value,
        NULL::numeric                                                  AS signed_invoice_value,
        s5b.posted_date,
        NULL::numeric                                                  AS posted_invoice_value,
        s5b.contract_type,
        s5b.allocation_completed,
        s5b.allocation_completed_date,
        s5b.invoice_house_rate,
        s5b.ccf,
        s5b.stock_allocation_check,
        s5b.manual_outb_expense_amount,
        s5b.merged_line_splitter,
        s5b.suggest_completed,
        s5b.origin,
        s5b.sales_invoice_provisional_unpaid
    FROM (
        SELECT
            '02'::text                                                 AS order_flag,
            'P Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            -1 * public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'P'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            params.base_unit,
            'Purch Reserves:'::text                                    AS invoice_heading,
            '03'::text                                                 AS invoice_order,
            reserves.reserve                                           AS invoice_flag,
            'P Reserve'::text                                          AS invoice_number,
            NULL::date                                                 AS invoice_date,
            NULL::text                                                 AS invoice_client,
            reserves_types.longname::text                             AS invoice_text,
            reserves.amount::text                                      AS invoice_unit_price,
            reserves.currency                                          AS invoice_currency,
            CASE WHEN reserves.amountind = 'A' THEN NULL
                 ELSE reserves.unit END                                AS invoice_priceunit,
            reserves.amountind,
            reserves.amount                                            AS reserve_amount,
            reserves.unit                                              AS reserve_unit,
            master_contracts.contdate                                  AS posted_date,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            NULL::numeric                                              AS invoice_house_rate,
            -- Commented-out alternative CCF (original had "and then" typo):
            -- if ( sp_curr_getunderlying(sub_contracts.currency) = params.base_currency ) and then
            --     sp_datedfxrate(reserves.currency, params.base_currency, today(), today())
            -- else
            --     sp_get_outright_or_averaged_fixes_FX_rate(sub_contracts.contno, sub_contracts.split)
            -- endif as contract_currency_to_basecurr_conversion_factor
            CASE WHEN reserves.currency = params.base_currency
                 THEN 1
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) <> params.base_currency
                      AND reserves.currency <> public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_datedfxrate(reserves.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) <> params.base_currency
                      AND reserves.currency = public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                      AND reserves.currency <> public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_datedfxrate(reserves.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE 0
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            reserves.charges_line::text                               AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            'N'::text                                                  AS sales_invoice_provisional_unpaid
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.reserves
            ON sub_contracts.contno = reserves.contno
            AND sub_contracts.split = reserves.split
        JOIN public.reserves_types ON reserves.reserve = reserves_types.code
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'P'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s5b
) s5

UNION

-- ============================================================
-- Section 6 (01c): Sales Expense Notes.
-- Alias chain: invoice_value â†’ signed_invoice_value â†’
--   posted_invoice_value â†’ manual_outb_expense_amount (4 deep).
-- Handled with 3 levels + inlining posted_invoice_value expression
-- inside manual_outb_expense_amount to avoid a 4th nesting level.
--   s6b: leaves â€” price_curr_unit, allocated_quantity, ccf,
--        invoice_value (nominal_account 6%/7% vs sp_get_realised),
--        posted_ledref, ratetype, invoice_house_rate, nominal_account
--   s6m: allocation_fixed_flag, total_forecast, signed_invoice_value
--   s6 : total_forecast_base_curr, posted_invoice_value,
--        manual_outb_expense_amount (posted_invoice_value inlined)
-- total_forecast = price_curr_unit * allocated_quantity (no USC branch).
-- total_forecast_base_curr = ccf * total_forecast (no USD passthrough).
-- ============================================================
SELECT
    s6.order_flag,
    s6.order_label,
    s6.allocation_reference,
    s6.allocation_company,
    s6.alliocation_pcentre,
    s6.allocation_commodity,
    s6.allocation_commodity_type,
    s6.allocation_date,
    s6.allocation_total_sales_quantity,
    s6.allocation_total_unfixed,
    s6.allocation_fixed_flag,
    s6.contno,
    s6.split,
    s6.priceterm,
    s6.record_date,
    s6.contract_client,
    s6.allocated_quantity,
    s6.price_curr_unit,
    s6.currency,
    s6.priceunit,
    s6.total_forecast,
    s6.ccf * s6.total_forecast                                        AS total_forecast_base_curr,
    s6.invoice_heading,
    s6.invoice_order,
    s6.invoice_flag,
    s6.invoice_number,
    s6.invoice_date,
    s6.invoice_client,
    s6.invoice_text,
    s6.invoiced_quantity,
    s6.invoice_unit_price,
    s6.invoice_currency,
    s6.invoice_priceunit,
    s6.invoice_value,
    s6.signed_invoice_value,
    s6.posted_date,
    CASE WHEN s6.ratetype = 'D'
         THEN s6.signed_invoice_value / s6.invoice_house_rate
         ELSE s6.signed_invoice_value * s6.invoice_house_rate END      AS posted_invoice_value,
    s6.contract_type,
    s6.allocation_completed,
    s6.allocation_completed_date,
    s6.invoice_house_rate,
    s6.ccf                                                             AS contract_currency_to_basecurr_conversion_factor,
    s6.stock_allocation_check,
    -- manual_outb_expense_amount: posted_invoice_value inlined (avoids 4th nesting level)
    CASE WHEN s6.nominal_account = '60002'
         THEN CASE WHEN s6.ratetype = 'D'
                   THEN s6.signed_invoice_value / s6.invoice_house_rate
                   ELSE s6.signed_invoice_value * s6.invoice_house_rate END
         ELSE 0 END                                                    AS manual_outb_expense_amount,
    s6.merged_line_splitter,
    s6.suggest_completed,
    s6.origin,
    s6.sales_invoice_provisional_unpaid
FROM (
    SELECT
        s6b.order_flag,
        s6b.order_label,
        s6b.allocation_reference,
        s6b.allocation_company,
        s6b.alliocation_pcentre,
        s6b.allocation_commodity,
        s6b.allocation_commodity_type,
        s6b.allocation_date,
        s6b.allocation_total_sales_quantity,
        s6b.allocation_total_unfixed,
        CASE WHEN s6b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        s6b.contno,
        s6b.split,
        s6b.priceterm,
        s6b.record_date,
        s6b.contract_client,
        s6b.allocated_quantity,
        s6b.price_curr_unit,
        s6b.currency,
        s6b.priceunit,
        s6b.price_curr_unit * s6b.allocated_quantity                   AS total_forecast,
        s6b.invoice_heading,
        s6b.invoice_order,
        s6b.invoice_flag,
        s6b.invoice_number,
        s6b.invoice_date,
        s6b.invoice_client,
        s6b.invoice_text,
        s6b.invoiced_quantity,
        s6b.invoice_unit_price,
        s6b.invoice_currency,
        s6b.invoice_priceunit,
        s6b.invoice_value,
        CASE WHEN s6b.posted_ledref IS NULL THEN 0
             ELSE s6b.invoice_value END                                AS signed_invoice_value,
        s6b.posted_date,
        s6b.ratetype,
        s6b.invoice_house_rate,
        s6b.contract_type,
        s6b.allocation_completed,
        s6b.allocation_completed_date,
        s6b.ccf,
        s6b.stock_allocation_check,
        s6b.nominal_account,
        s6b.merged_line_splitter,
        s6b.suggest_completed,
        s6b.origin,
        s6b.sales_invoice_provisional_unpaid
    FROM (
        SELECT
            '01c'::text                                                AS order_flag,
            'S Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'S'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            'Sales Expenses:'::text                                    AS invoice_heading,
            '04'::text                                                 AS invoice_order,
            expenses_summary.expense_note_type                         AS invoice_flag,
            expenses_summary.expense_number::text                      AS invoice_number,
            expenses_summary.posted_date                               AS invoice_date,
            expenses_summary.client::text                              AS invoice_client,
            expenses_detail.description::text                         AS invoice_text,
            NULL::numeric                                              AS invoiced_quantity,
            NULL::text                                                 AS invoice_unit_price,
            expenses_detail.currency                                   AS invoice_currency,
            NULL::text                                                 AS invoice_priceunit,
            CASE WHEN expenses_detail.nominal_account LIKE '6%'
                      OR expenses_detail.nominal_account LIKE '7%'
                 THEN -1 * expenses_detail.linevalue
                 ELSE public.sp_get_realised_invoice_value(
                          'E', expenses_detail.expense_number, expenses_detail.client,
                          expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
            END                                                        AS invoice_value,
            expenses_summary.posted_ledref,
            expenses_summary.posted_date                               AS posted_date,
            currency.ratetype,
            expenses_summary.house_rate                                AS invoice_house_rate,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            expenses_detail.nominal_account,
            expenses_detail.charges_line::text                        AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            'N'::text                                                  AS sales_invoice_provisional_unpaid
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.expenses_detail
            ON allocated_contracts.contno            = expenses_detail.contno
            AND allocated_contracts.split            = expenses_detail.split
            AND allocated_contracts.allocation_reference = expenses_detail.allocation_reference
        JOIN public.expenses_summary
            ON expenses_detail.expense_number = expenses_summary.expense_number
            AND expenses_detail.client        = expenses_summary.client
        JOIN public.currency ON expenses_summary.currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s6b
) s6

UNION

-- ============================================================
-- Section 7: Pass-through from forecast_report_outbooked_p_expenses_view
--   with SUM aggregates on signed_invoice_value and posted_invoice_value.
-- stock_allocation_check is a computed expression (not a view column)
--   so GROUP BY must use the full function call, not the alias.
-- sales_invoice_provisional_unpaid = 'N' (constant) excluded from GROUP BY.
-- allocation_pcentre: this view uses the correctly spelled column name
--   (no double-i typo); UNION position 5 takes whatever value is here.
-- ============================================================
SELECT
    frv_oe.order_flag,
    frv_oe.order_label,
    frv_oe.allocation_reference,
    frv_oe.allocation_company,
    frv_oe.allocation_pcentre,
    frv_oe.allocation_commodity,
    frv_oe.allocation_commodity_type,
    frv_oe.allocation_date,
    frv_oe.allocation_total_sales_quantity,
    frv_oe.allocation_total_unfixed,
    frv_oe.allocation_fixed_flag,
    frv_oe.contno,
    frv_oe.split,
    frv_oe.priceterm,
    frv_oe.record_date,
    frv_oe.contract_client,
    frv_oe.allocated_quantity,
    frv_oe.price_curr_unit,
    frv_oe.currency,
    frv_oe.priceunit,
    frv_oe.total_forecast,
    frv_oe.total_forecast_base_curr,
    frv_oe.invoice_heading,
    frv_oe.invoice_order,
    frv_oe.invoice_flag,
    frv_oe.invoice_number,
    frv_oe.invoice_date,
    frv_oe.invoice_client,
    frv_oe.invoice_text,
    frv_oe.invoiced_quantity,
    frv_oe.invoice_unit_price,
    frv_oe.invoice_currency,
    frv_oe.invoice_priceunit,
    frv_oe.invoice_value,
    SUM(frv_oe.signed_invoice_value)                                   AS signed_invoice_value,
    frv_oe.posted_date,
    SUM(frv_oe.posted_invoice_value)                                   AS posted_invoice_value,
    frv_oe.contract_type,
    frv_oe.allocation_completed,
    frv_oe.allocation_completed_date,
    frv_oe.invoice_house_rate,
    frv_oe.contract_currency_to_basecurr_conversion_factor,
    public.sp_allocation_check_if_only_stock(
        frv_oe.allocation_reference)                                   AS stock_allocation_check,
    frv_oe.manual_outb_expense_amount,
    frv_oe.merged_line_splitter,
    frv_oe.suggest_completed,
    frv_oe.origin,
    'N'::text                                                          AS sales_invoice_provisional_unpaid
FROM public.forecast_report_outbooked_p_expenses_view frv_oe
WHERE public.sp_allocation_check_if_only_stock(frv_oe.allocation_reference) = 'N'
GROUP BY
    frv_oe.order_flag,
    frv_oe.order_label,
    frv_oe.allocation_reference,
    frv_oe.allocation_company,
    frv_oe.allocation_pcentre,
    frv_oe.allocation_commodity,
    frv_oe.allocation_commodity_type,
    frv_oe.allocation_date,
    frv_oe.allocation_total_sales_quantity,
    frv_oe.allocation_total_unfixed,
    frv_oe.allocation_fixed_flag,
    frv_oe.contno,
    frv_oe.split,
    frv_oe.priceterm,
    frv_oe.record_date,
    frv_oe.contract_client,
    frv_oe.allocated_quantity,
    frv_oe.price_curr_unit,
    frv_oe.currency,
    frv_oe.priceunit,
    frv_oe.total_forecast,
    frv_oe.total_forecast_base_curr,
    frv_oe.invoice_heading,
    frv_oe.invoice_order,
    frv_oe.invoice_flag,
    frv_oe.invoice_number,
    frv_oe.invoice_date,
    frv_oe.invoice_client,
    frv_oe.invoice_text,
    frv_oe.invoiced_quantity,
    frv_oe.invoice_unit_price,
    frv_oe.invoice_currency,
    frv_oe.invoice_priceunit,
    frv_oe.invoice_value,
    frv_oe.posted_date,
    frv_oe.contract_type,
    frv_oe.allocation_completed,
    frv_oe.allocation_completed_date,
    frv_oe.invoice_house_rate,
    frv_oe.contract_currency_to_basecurr_conversion_factor,
    public.sp_allocation_check_if_only_stock(frv_oe.allocation_reference),
    frv_oe.manual_outb_expense_amount,
    frv_oe.merged_line_splitter,
    frv_oe.suggest_completed,
    frv_oe.origin

UNION

-- ============================================================
-- Section 8 (01e): Final Sales Invoices.
-- invoice_text: ifnull(invoice_number, null, 'Final Sales Invoice')
--   â†’ CASE WHEN final_invoice_number IS NULL THEN NULL ELSE 'Final Sales Invoice' END
--   Inlined from the table column â€” no alias dependency.
-- 3-level nesting:
--   s8b: leaves â€” price_curr_unit, allocated_quantity, ccf,
--        invoice_value (= final_invoice_details_2.net_due_partial),
--        posted_ledref, ratetype, invoice_house_rate, invoice_text
--   s8m: allocation_fixed_flag, total_forecast, signed_invoice_value
--   s8 : total_forecast_base_curr (ccf * total_forecast),
--        posted_invoice_value
-- total_forecast_base_curr = ccf * total_forecast (no USD passthrough).
-- ============================================================
SELECT
    s8.order_flag,
    s8.order_label,
    s8.allocation_reference,
    s8.allocation_company,
    s8.alliocation_pcentre,
    s8.allocation_commodity,
    s8.allocation_commodity_type,
    s8.allocation_date,
    s8.allocation_total_sales_quantity,
    s8.allocation_total_unfixed,
    s8.allocation_fixed_flag,
    s8.contno,
    s8.split,
    s8.priceterm,
    s8.record_date,
    s8.contract_client,
    s8.allocated_quantity,
    s8.price_curr_unit,
    s8.currency,
    s8.priceunit,
    s8.total_forecast,
    s8.ccf * s8.total_forecast                                        AS total_forecast_base_curr,
    s8.invoice_heading,
    s8.invoice_order,
    s8.invoice_flag,
    s8.invoice_number,
    s8.invoice_date,
    s8.invoice_client,
    s8.invoice_text,
    s8.invoiced_quantity,
    s8.invoice_unit_price,
    s8.invoice_currency,
    s8.invoice_priceunit,
    s8.invoice_value,
    s8.signed_invoice_value,
    s8.posted_date,
    CASE WHEN s8.ratetype = 'D'
         THEN s8.signed_invoice_value / s8.invoice_house_rate
         ELSE s8.signed_invoice_value * s8.invoice_house_rate END      AS posted_invoice_value,
    s8.contract_type,
    s8.allocation_completed,
    s8.allocation_completed_date,
    s8.invoice_house_rate,
    s8.ccf                                                             AS contract_currency_to_basecurr_conversion_factor,
    s8.stock_allocation_check,
    s8.manual_outb_expense_amount,
    s8.merged_line_splitter,
    s8.suggest_completed,
    s8.origin,
    s8.sales_invoice_provisional_unpaid
FROM (
    SELECT
        s8b.order_flag,

        s8b.order_label,
        s8b.allocation_reference,
        s8b.allocation_company,
        s8b.alliocation_pcentre,
        s8b.allocation_commodity,
        s8b.allocation_commodity_type,
        s8b.allocation_date,
        s8b.allocation_total_sales_quantity,
        s8b.allocation_total_unfixed,
        CASE WHEN s8b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        s8b.contno,
        s8b.split,
        s8b.priceterm,
        s8b.record_date,
        s8b.contract_client,
        s8b.allocated_quantity,
        s8b.price_curr_unit,
        s8b.currency,
        s8b.priceunit,
        s8b.price_curr_unit * s8b.allocated_quantity                   AS total_forecast,
        s8b.invoice_heading,
        s8b.invoice_order,
        s8b.invoice_flag,
        s8b.invoice_number,
        s8b.invoice_date,
        s8b.invoice_client,
        s8b.invoice_text,
        s8b.invoiced_quantity,
        s8b.invoice_unit_price,
        s8b.invoice_currency,
        s8b.invoice_priceunit,
        s8b.invoice_value,
        CASE WHEN s8b.posted_ledref IS NULL THEN 0
             ELSE s8b.invoice_value END                                AS signed_invoice_value,
        s8b.posted_date,
        s8b.ratetype,
        s8b.invoice_house_rate,
        s8b.contract_type,
        s8b.allocation_completed,
        s8b.allocation_completed_date,
        s8b.ccf,
        s8b.stock_allocation_check,
        s8b.manual_outb_expense_amount,
        s8b.merged_line_splitter,
        s8b.suggest_completed,
        s8b.origin,
        s8b.sales_invoice_provisional_unpaid
    FROM (
        SELECT
            '01e'::text                                                AS order_flag,
            'S Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'S'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            'Final S Invoices:'::text                                  AS invoice_heading,
            '02'::text                                                 AS invoice_order,
            '310'::text                                                AS invoice_flag,
            final_invoice.final_invoice_number::text                  AS invoice_number,
            final_invoice.posted_date                                  AS invoice_date,
            final_invoice.client::text                                 AS invoice_client,
            -- ifnull(invoice_number, null, 'Final Sales Invoice') inlined from table column
            CASE WHEN final_invoice.final_invoice_number IS NULL
                 THEN NULL ELSE 'Final Sales Invoice' END              AS invoice_text,
            public.sp_convert_qty(
                final_invoice_details_2.invoiced_quantity,
                final_invoice_details_2.delivered_unit, 'MT')         AS invoiced_quantity,
            final_invoice_details_2.unit_price::text                  AS invoice_unit_price,
            sub_contracts.currency                                     AS invoice_currency,
            sub_contracts.priceunit::text                             AS invoice_priceunit,
            final_invoice_details_2.net_due_partial                   AS invoice_value,
            final_invoice.posted_ledref,
            final_invoice.posted_date                                  AS posted_date,
            currency.ratetype,
            final_invoice.house_rate                                   AS invoice_house_rate,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            NULL::text                                                 AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            'N'::text                                                  AS sales_invoice_provisional_unpaid
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.final_invoice_details_2
            ON allocated_contracts.contno            = final_invoice_details_2.contno
            AND allocated_contracts.split            = final_invoice_details_2.split
            AND allocated_contracts.allocation_reference = final_invoice_details_2.allocation_reference
        JOIN public.final_invoice
            ON final_invoice_details_2.invoice_number = final_invoice.invoice_number
            AND final_invoice_details_2.client        = final_invoice.client
            AND final_invoice_details_2.invoice_type  = final_invoice.invoice_type
        JOIN public.currency ON final_invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s8b
) s8

UNION

-- ============================================================
-- Section 9: Pass-through from
--   forecast_report_view_final_invoices_with_outbooking.
-- No alias chains; no nesting required.
-- stock_allocation_check inlined in WHERE (alias not visible there).
-- ============================================================
SELECT
    frv_fiwo.order_flag,
    frv_fiwo.order_label,
    frv_fiwo.allocation_reference,
    frv_fiwo.allocation_company,
    frv_fiwo.alliocation_pcentre,
    frv_fiwo.allocation_commodity,
    frv_fiwo.allocation_commodity_type,
    frv_fiwo.allocation_date,
    frv_fiwo.allocation_total_sales_quantity,
    frv_fiwo.allocation_total_unfixed,
    frv_fiwo.allocation_fixed_flag,
    frv_fiwo.contno,
    frv_fiwo.split,
    frv_fiwo.priceterm,
    frv_fiwo.record_date,
    frv_fiwo.contract_client,
    frv_fiwo.allocated_quantity,
    frv_fiwo.price_curr_unit,
    frv_fiwo.currency,
    frv_fiwo.priceunit,
    frv_fiwo.total_forecast,
    frv_fiwo.total_forecast_base_curr,
    frv_fiwo.invoice_heading,
    frv_fiwo.invoice_order,
    frv_fiwo.invoice_flag,
    frv_fiwo.invoice_number,
    frv_fiwo.invoice_date,
    frv_fiwo.invoice_client,
    frv_fiwo.invoice_text,
    frv_fiwo.invoiced_quantity,
    frv_fiwo.invoice_unit_price,
    frv_fiwo.invoice_currency,
    frv_fiwo.invoice_priceunit,
    frv_fiwo.invoice_value,
    frv_fiwo.signed_invoice_value,
    frv_fiwo.posted_date,
    frv_fiwo.posted_invoice_value,
    frv_fiwo.contract_type,
    frv_fiwo.allocation_completed,
    frv_fiwo.allocation_completed_date,
    frv_fiwo.invoice_house_rate,
    frv_fiwo.contract_currency_to_basecurr_conversion_factor,
    public.sp_allocation_check_if_only_stock(
        frv_fiwo.allocation_reference)                                AS stock_allocation_check,
    frv_fiwo.manual_outb_expense_amount,
    frv_fiwo.merged_line_splitter,
    frv_fiwo.suggest_completed,
    frv_fiwo.origin,
    'N'::text                                                         AS sales_invoice_provisional_unpaid
FROM public.forecast_report_view_final_invoices_with_outbooking frv_fiwo
WHERE public.sp_allocation_check_if_only_stock(
          frv_fiwo.allocation_reference) = 'N'

UNION

-- ============================================================
-- Section 10 (01e): Sales US Tariffs (invoice_stocks_tariffs).
-- Uses invoice/invoice_details_2 tables (not final_invoice).
-- invoice_text: 'US tariff for Invoice ' + invoice_number
--   â†’ inline alias via 3-level nesting.
-- posted_invoice_value: tariff_currency = base_currency check
--   (not ratetype D/M â€” simpler 2-branch CASE).
-- base_currency threaded from s10b â†’ s10m â†’ s10 for outer check.
-- 3-level nesting:
--   s10b: leaves â€” allocation_total_unfixed, price_curr_unit,
--         allocated_quantity, ccf, invoice_value, posted_ledref,
--         invoice_number, posted_date (COALESCE), invoice_house_rate,
--         invoice_currency (tariff_currency), base_currency
--   s10m: allocation_fixed_flag, total_forecast, signed_invoice_value,
--         invoice_text
--   s10 : total_forecast_base_curr, posted_invoice_value
-- Final UNION section â€” no trailing UNION; view closes with semicolon.
-- ============================================================
SELECT
    s10.order_flag,
    s10.order_label,
    s10.allocation_reference,
    s10.allocation_company,
    s10.alliocation_pcentre,
    s10.allocation_commodity,
    s10.allocation_commodity_type,
    s10.allocation_date,
    s10.allocation_total_sales_quantity,
    s10.allocation_total_unfixed,
    s10.allocation_fixed_flag,
    s10.contno,
    s10.split,
    s10.priceterm,
    s10.record_date,
    s10.contract_client,
    s10.allocated_quantity,
    s10.price_curr_unit,
    s10.currency,
    s10.priceunit,
    s10.total_forecast,
    s10.ccf * s10.total_forecast                                       AS total_forecast_base_curr,
    s10.invoice_heading,
    s10.invoice_order,
    s10.invoice_flag,
    s10.invoice_number,
    s10.invoice_date,
    s10.invoice_client,
    s10.invoice_text,
    s10.invoiced_quantity,
    s10.invoice_unit_price,
    s10.invoice_currency,
    s10.invoice_priceunit,
    s10.invoice_value,
    s10.signed_invoice_value,
    s10.posted_date,
    CASE WHEN s10.invoice_currency = s10.base_currency
         THEN s10.signed_invoice_value
         ELSE s10.signed_invoice_value * s10.invoice_house_rate END    AS posted_invoice_value,
    s10.contract_type,
    s10.allocation_completed,
    s10.allocation_completed_date,
    s10.invoice_house_rate,
    s10.ccf                                                            AS contract_currency_to_basecurr_conversion_factor,
    s10.stock_allocation_check,
    s10.manual_outb_expense_amount,
    s10.merged_line_splitter,
    s10.suggest_completed,
    s10.origin,
    s10.sales_invoice_provisional_unpaid
FROM (
    SELECT
        s10b.order_flag,
        s10b.order_label,
        s10b.allocation_reference,
        s10b.allocation_company,
        s10b.alliocation_pcentre,
        s10b.allocation_commodity,
        s10b.allocation_commodity_type,
        s10b.allocation_date,
        s10b.allocation_total_sales_quantity,
        s10b.allocation_total_unfixed,
        CASE WHEN s10b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        s10b.contno,
        s10b.split,
        s10b.priceterm,
        s10b.record_date,
        s10b.contract_client,
        s10b.allocated_quantity,
        s10b.price_curr_unit,
        s10b.currency,
        s10b.priceunit,
        s10b.price_curr_unit * s10b.allocated_quantity                 AS total_forecast,
        s10b.invoice_heading,
        s10b.invoice_order,
        s10b.invoice_flag,
        s10b.invoice_number,
        s10b.invoice_date,
        s10b.invoice_client,
        'US tariff for Invoice ' || s10b.invoice_number               AS invoice_text,
        s10b.invoiced_quantity,
        s10b.invoice_unit_price,
        s10b.invoice_currency,
        s10b.invoice_priceunit,
        s10b.invoice_value,
        CASE WHEN s10b.posted_ledref IS NULL THEN 0
             ELSE s10b.invoice_value END                               AS signed_invoice_value,
        s10b.posted_date,
        s10b.invoice_house_rate,
        s10b.base_currency,
        s10b.contract_type,
        s10b.allocation_completed,
        s10b.allocation_completed_date,
        s10b.ccf,
        s10b.stock_allocation_check,
        s10b.manual_outb_expense_amount,
        s10b.merged_line_splitter,
        s10b.suggest_completed,
        s10b.origin,
        s10b.sales_invoice_provisional_unpaid
    FROM (
        SELECT
            '01e'::text                                                AS order_flag,
            'S Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'S'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            'Sales US tariffs'::text                                   AS invoice_heading,
            '05'::text                                                 AS invoice_order,
            '310'::text                                                AS invoice_flag,
            invoice.invoice_number::text                               AS invoice_number,
            invoice.posted_date                                        AS invoice_date,
            invoice.client::text                                       AS invoice_client,
            NULL::numeric                                              AS invoiced_quantity,
            NULL::text                                                 AS invoice_unit_price,
            invoice_stocks_tariffs.tariff_currency                     AS invoice_currency,
            NULL::text                                                 AS invoice_priceunit,
            invoice_stocks_tariffs.tariff_total_amount                 AS invoice_value,
            invoice.posted_ledref,
            COALESCE(invoice.posted_date, master_contracts.contdate)   AS posted_date,
            invoice.house_rate                                         AS invoice_house_rate,
            params.base_currency,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            NULL::text                                                 AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            'N'::text                                                  AS sales_invoice_provisional_unpaid
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.invoice_details_2
            ON allocated_contracts.contno            = invoice_details_2.contno
            AND allocated_contracts.split            = invoice_details_2.split
            AND allocated_contracts.allocation_reference = invoice_details_2.allocation_reference
        JOIN public.invoice
            ON invoice_details_2.invoice_number = invoice.invoice_number
            AND invoice_details_2.client        = invoice.client
            AND invoice_details_2.invoice_type  = invoice.invoice_type
        JOIN public.invoice_stocks_tariffs
            ON invoice_stocks_tariffs.invoice_number = invoice.invoice_number
            AND invoice_stocks_tariffs.client        = invoice.client
            AND invoice_stocks_tariffs.invoice_type  = invoice.invoice_type
        JOIN public.currency ON invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s10b
) s10;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0025_legacy_views') THEN
        INSERT INTO schema_migrations (script_name) VALUES ('0025_legacy_views');
        RAISE NOTICE 'Migration 0025 applied successfully.';
    ELSE
        RAISE NOTICE 'Migration 0025 already recorded — skipping.';
    END IF;
END $$;
