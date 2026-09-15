-- ============================================================
-- general_invoices
-- Source: dba.general_invoices
-- 4 UNION ALL branches: provisional/washout invoices, final
-- invoices, credit/debit notes, and expenses.
-- SAP *=: client.country *= country.code → client LEFT OUTER
--   JOIN country ON client.country = country.code (client preserved).
-- SAP IF…ENDIF → CASE WHEN…END.
-- IfNull(x,'N','Y') (3-arg) → CASE WHEN x IS NULL THEN 'N' ELSE 'Y' END.
-- String concat '+' → '||'.
-- CreditDebit_Note → creditdebit_note (lowercase).
-- ============================================================

CREATE OR REPLACE VIEW public.general_invoices AS

-- Branch 1: Provisional and washout invoices
SELECT
    CASE WHEN invoice.invoice_type = 'W' THEN 'W' ELSE 'P' END         AS inv_flag,
    invoice.invoice_number                                               AS inv_number,
    ''::text                                                             AS other_id_number,
    invoice.invoice_type                                                 AS inv_type,
    CASE WHEN invoice.invoice_type = 'W'
         THEN 'Washout'
         ELSE 'Prov ' || invoice.invoice_type
    END                                                                  AS inv_label,
    invoice.allocation_reference                                         AS alloc_ref,
    invoice.client                                                       AS client,
    client.country,
    invoice.invoice_date                                                 AS inv_date,
    invoice.posted_date                                                  AS posted_date,
    invoice.posted_ledref                                                AS posted_ledref,
    invoice.company                                                      AS company,
    invoice.pcentre                                                      AS pcentre,
    invoice.commodity                                                    AS commodity,
    invoice.commodity_type                                               AS commodtype,
    invoice.origin                                                       AS origin,
    invoice.invoice_value                                                AS inv_value,
    invoice.invoice_currency                                             AS currency,
    CASE WHEN invoice.posted_ledref IS NULL THEN 'N' ELSE 'Y' END       AS posted,
    invoice.internal_notes                                               AS notes,
    invoice.description                                                  AS description
FROM public.invoice
JOIN public.client ON invoice.client = client.code
LEFT OUTER JOIN public.country ON client.country = country.code

UNION ALL

-- Branch 2: Final invoices
SELECT
    'F'::text                                                            AS inv_flag,
    final_invoice.final_invoice_number                                   AS inv_number,
    final_invoice.invoice_number                                         AS other_id_number,
    final_invoice.invoice_type                                           AS inv_type,
    CASE WHEN final_invoice.invoice_type = 'S'
         THEN 'Final S'
         ELSE 'Final P'
    END                                                                  AS inv_label,
    invoice.allocation_reference                                         AS alloc_ref,
    final_invoice.client                                                 AS client,
    client.country,
    final_invoice.invoice_date                                           AS inv_date,
    final_invoice.posted_date                                            AS posted_date,
    final_invoice.posted_ledref                                          AS posted_ledref,
    final_invoice.company                                                AS company,
    final_invoice.pcentre                                                AS pcentre,
    final_invoice.commodity                                              AS commodity,
    final_invoice.commodity_type                                         AS commodtype,
    final_invoice.origin                                                 AS origin,
    final_invoice.net_due                                                AS inv_value,
    final_invoice.invoice_currency                                       AS currency,
    CASE WHEN final_invoice.posted_ledref IS NULL THEN 'N' ELSE 'Y' END AS posted,
    final_invoice.notes                                                  AS notes,
    final_invoice.description                                            AS description
FROM public.invoice
JOIN public.final_invoice
    ON  invoice.invoice_number = final_invoice.invoice_number
    AND invoice.client         = final_invoice.client
    AND invoice.invoice_type   = final_invoice.invoice_type
JOIN public.client ON invoice.client = client.code
LEFT OUTER JOIN public.country ON client.country = country.code

UNION ALL

-- Branch 3: Credit/Debit notes
SELECT
    'C'::text                                                            AS inv_flag,
    creditdebit_note.crdr_number                                         AS inv_number,
    creditdebit_note.invoice_number                                      AS other_id_number,
    creditdebit_note.invoice_type                                        AS inv_type,
    'C/D Note'::text                                                     AS inv_label,
    invoice.allocation_reference                                         AS alloc_ref,
    creditdebit_note.client                                              AS client,
    client.country,
    creditdebit_note.invoice_date                                        AS inv_date,
    creditdebit_note.posted_date                                         AS posted_date,
    creditdebit_note.posted_ledref                                       AS posted_ledref,
    creditdebit_note.company                                             AS company,
    creditdebit_note.pcentre                                             AS pcentre,
    creditdebit_note.commodity                                           AS commodity,
    creditdebit_note.commodtype                                          AS commodtype,
    creditdebit_note.origin                                              AS origin,
    creditdebit_note.total_value                                         AS inv_value,
    creditdebit_note.currency                                            AS currency,
    CASE WHEN creditdebit_note.posted_ledref IS NULL
         THEN 'N' ELSE 'Y' END                                          AS posted,
    creditdebit_note.notes                                               AS notes,
    creditdebit_note.description                                         AS description
FROM public.invoice
JOIN public.creditdebit_note
    ON  invoice.invoice_number = creditdebit_note.invoice_number
    AND invoice.client         = creditdebit_note.client
    AND invoice.invoice_type   = creditdebit_note.invoice_type
JOIN public.client ON invoice.client = client.code
LEFT OUTER JOIN public.country ON client.country = country.code

UNION ALL

-- Branch 4: Expenses
SELECT
    'E'::text                                                            AS inv_flag,
    expenses_summary.expense_number                                      AS inv_number,
    ''::text                                                             AS other_id_number,
    ''::text                                                             AS inv_type,
    'Expense'::text                                                      AS inv_label,
    ''::text                                                             AS alloc_ref,
    expenses_summary.client                                              AS client,
    client.country,
    expenses_summary.expense_date                                        AS inv_date,
    expenses_summary.posted_date                                         AS posted_date,
    expenses_summary.posted_ledref                                       AS posted_ledref,
    expenses_summary.company                                             AS company,
    expenses_summary.pcentre                                             AS pcentre,
    expenses_summary.commodity                                           AS commodity,
    expenses_summary.commodtype                                          AS commodtype,
    expenses_summary.origin                                              AS origin,
    expenses_summary.total_value                                         AS inv_value,
    expenses_summary.currency                                            AS currency,
    CASE WHEN expenses_summary.posted_ledref IS NULL
         THEN 'N' ELSE 'Y' END                                          AS posted,
    expenses_summary.notes                                               AS notes,
    expenses_summary.description                                         AS description
FROM public.expenses_summary
JOIN public.client ON expenses_summary.client = client.code
LEFT OUTER JOIN public.country ON client.country = country.code;
