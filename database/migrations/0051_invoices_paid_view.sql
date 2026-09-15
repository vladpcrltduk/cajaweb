-- ============================================================
-- invoices_paid_view
-- Source: dba.invoices_paid_view
-- 4 UNION ALL branches showing paid invoice / expense positions.
-- SAP FROM-clause pattern resolved:
--   "A left outer join B on ..., B left outer join C on ..."
--   → chained LEFT JOINs: A LEFT JOIN B LEFT JOIN C
--   The second LEFT JOIN's "accdetail.client is not null" stays in
--   the ON clause (not moved to WHERE) to preserve outer-join
--   semantics — rows with no accdetail match keep NULL paid columns.
-- SAP UNION → UNION ALL: branches are mutually exclusive by inv_flag.
-- Nested IF/THEN/ELSE/ENDIF → flat CASE WHEN … WHEN … ELSE … END.
-- ============================================================

CREATE OR REPLACE VIEW public.invoices_paid_view AS

-- Branch 1: Provisional Invoices
SELECT
    invoice.invoice_number                                              AS inv_no,
    '1. Provisional Invoices'                                          AS inv_flag,
    CASE WHEN invoice.invoice_type = 'P' THEN 'Purchases'
         WHEN invoice.invoice_type = 'S' THEN 'Sales'
         ELSE 'Washouts'
    END                                                                 AS inv_type,
    invoice.client                                                      AS inv_client,
    invoice.invoice_date                                                AS inv_date,
    invoice.due_date                                                    AS inv_due_date,
    invoice.commodity,
    invoice.commodity_type,
    invoice.origin,
    invoice.quality,
    invoice.invoice_value                                               AS inv_value,
    invoice.invoice_currency                                            AS inv_currency,
    invoice_payments.ledgernum                                          AS led_ref,
    accdetail.currency                                                  AS paid_currency,
    accdetail.ledamt                                                    AS paid_value
FROM public.invoice
LEFT JOIN public.invoice_payments
    ON  invoice.invoice_number = invoice_payments.invoice_number
    AND invoice.invoice_type   = invoice_payments.invoice_type
    AND invoice.client         = invoice_payments.client
LEFT JOIN public.accdetail
    ON  invoice_payments.accperiod = accdetail.accperiod
    AND invoice_payments.ledgernum = accdetail.ledgernum
    AND accdetail.client IS NOT NULL
WHERE (invoice_payments.flag = 'PROV'
       OR invoice_payments.flag = 'WASH'
       OR invoice_payments.flag IS NULL)
  AND invoice.posted_ledref IS NOT NULL

UNION ALL

-- Branch 2: Final Invoices
SELECT
    final_invoice.invoice_number                                        AS inv_no,
    '2. Final Invoices'                                                 AS inv_flag,
    CASE WHEN final_invoice.invoice_type = 'P' THEN 'Purchases'
         ELSE 'Sales'
    END                                                                 AS inv_type,
    final_invoice.client                                                AS inv_client,
    final_invoice.invoice_date                                          AS inv_date,
    final_invoice.due_date                                              AS inv_due_date,
    final_invoice.commodity,
    final_invoice.commodity_type,
    final_invoice.origin,
    ' '                                                                 AS quality,
    final_invoice.net_due                                               AS inv_value,
    final_invoice.invoice_currency                                      AS inv_currency,
    invoice_payments.ledgernum                                          AS led_ref,
    accdetail.currency                                                  AS paid_currency,
    accdetail.ledamt                                                    AS paid_value
FROM public.final_invoice
LEFT JOIN public.invoice_payments
    ON  final_invoice.invoice_number = invoice_payments.invoice_number
    AND final_invoice.invoice_type   = invoice_payments.invoice_type
    AND final_invoice.client         = invoice_payments.client
LEFT JOIN public.accdetail
    ON  invoice_payments.accperiod = accdetail.accperiod
    AND invoice_payments.ledgernum = accdetail.ledgernum
    AND accdetail.client IS NOT NULL
WHERE (invoice_payments.flag = 'FINV'
       OR invoice_payments.flag IS NULL)
  AND final_invoice.posted_ledref IS NOT NULL

UNION ALL

-- Branch 3: Credit/Debit Notes
SELECT
    creditdebit_note.crdr_number                                        AS inv_no,
    '3. Credit/Debit Notes'                                             AS inv_flag,
    CASE WHEN creditdebit_note.invoice_type = 'P' THEN 'Purchases'
         WHEN creditdebit_note.invoice_type = 'S' THEN 'Sales'
         ELSE 'Washouts'
    END                                                                 AS inv_type,
    creditdebit_note.client                                             AS inv_client,
    creditdebit_note.invoice_date                                       AS inv_date,
    creditdebit_note.due_date                                           AS inv_due_date,
    creditdebit_note.commodity,
    creditdebit_note.commodtype                                         AS commodity_type,
    creditdebit_note.origin,
    ' '                                                                 AS quality,
    creditdebit_note.total_value                                        AS inv_value,
    creditdebit_note.currency                                           AS inv_currency,
    invoice_payments.ledgernum                                          AS led_ref,
    accdetail.currency                                                  AS paid_currency,
    accdetail.ledamt                                                    AS paid_value
FROM public.creditdebit_note
LEFT JOIN public.invoice_payments
    ON  creditdebit_note.invoice_number = invoice_payments.invoice_number
    AND creditdebit_note.invoice_type   = invoice_payments.invoice_type
    AND creditdebit_note.client         = invoice_payments.client
    AND creditdebit_note.crdr_number    = invoice_payments.extra_key
LEFT JOIN public.accdetail
    ON  invoice_payments.accperiod = accdetail.accperiod
    AND invoice_payments.ledgernum = accdetail.ledgernum
    AND accdetail.client IS NOT NULL
WHERE (invoice_payments.flag = 'CRDR'
       OR invoice_payments.flag IS NULL)
  AND creditdebit_note.posted_ledref IS NOT NULL

UNION ALL

-- Branch 4: Expense Notes
-- invoice_payments join uses only invoice_number + client (no invoice_type)
SELECT
    expenses_summary.expense_number                                     AS inv_no,
    '4. Expense Notes'                                                  AS inv_flag,
    ' '                                                                 AS inv_type,
    expenses_summary.client                                             AS inv_client,
    expenses_summary.expense_date                                       AS inv_date,
    expenses_summary.due_date                                           AS inv_due_date,
    expenses_summary.commodity,
    expenses_summary.commodtype                                         AS commodity_type,
    expenses_summary.origin,
    ' '                                                                 AS quality,
    expenses_summary.total_value                                        AS inv_value,
    expenses_summary.currency                                           AS inv_currency,
    invoice_payments.ledgernum                                          AS led_ref,
    accdetail.currency                                                  AS paid_currency,
    accdetail.ledamt                                                    AS paid_value
FROM public.expenses_summary
LEFT JOIN public.invoice_payments
    ON  expenses_summary.expense_number = invoice_payments.invoice_number
    AND expenses_summary.client         = invoice_payments.client
LEFT JOIN public.accdetail
    ON  invoice_payments.accperiod = accdetail.accperiod
    AND invoice_payments.ledgernum = accdetail.ledgernum
    AND accdetail.client IS NOT NULL
WHERE (invoice_payments.flag = 'EXPS'
       OR invoice_payments.flag IS NULL)
  AND expenses_summary.posted_ledref IS NOT NULL;
