-- ============================================================
-- outstand_inv_view2
-- Source: dba.outstand_inv_view2
-- 2-branch UNION ALL: invoices (type_flag='I') + expense summaries (type_flag='E').
-- Branches mutually exclusive on type_flag → UNION ALL.
-- Alias dep resolved: pay_amount (correlated subquery) referenced in cp_outstand_amt.
--   Each branch uses CROSS JOIN LATERAL to compute pay_amount once;
--   outer SELECT derives cp_outstand_amt = inv_value - pay_amount.
-- isnull(sum(...),0) → COALESCE(SUM(...),0).
-- cast(... as numeric(16,2)) → ::numeric(16,2).
-- ============================================================

CREATE OR REPLACE VIEW public.outstand_inv_view2 AS

-- Branch 1: Invoices
SELECT
    invoice.allocation_reference,
    invoice.invoice_type                                                 AS inv_type,
    invoice.client,
    invoice.invoice_number                                               AS inv_number,
    invoice.company,
    invoice.pcentre,
    invoice.invoice_value                                                AS inv_value,
    invoice.invoice_currency                                             AS inv_currency,
    invoice.due_date,
    pd.pay_amount,
    invoice.invoice_value - pd.pay_amount                               AS cp_outstand_amt,
    CAST('I' AS char(1))                                                AS type_flag
FROM public.invoice
CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(ipd.pay_amount), 0)::numeric(16,2) AS pay_amount
    FROM public.invoice_payment_detail ipd
    WHERE ipd.invoice_type   = invoice.invoice_type
      AND ipd.client         = invoice.client
      AND ipd.invoice_number = invoice.invoice_number
) AS pd

UNION ALL

-- Branch 2: Expense summaries
SELECT
    expenses_summary.allocation_reference,
    expenses_summary.expense_type                                        AS inv_type,
    expenses_summary.client,
    expenses_summary.expense_number                                      AS inv_number,
    expenses_summary.company,
    expenses_summary.pcentre,
    expenses_summary.total_value                                         AS inv_value,
    expenses_summary.currency                                            AS inv_currency,
    expenses_summary.due_date,
    pd.pay_amount,
    expenses_summary.total_value - pd.pay_amount                        AS cp_outstand_amt,
    CAST('E' AS char(1))                                                AS type_flag
FROM public.expenses_summary
CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(ipd.pay_amount), 0)::numeric(16,2) AS pay_amount
    FROM public.invoice_payment_detail ipd
    WHERE ipd.invoice_type   = expenses_summary.expense_type
      AND ipd.client         = expenses_summary.client
      AND ipd.invoice_number = expenses_summary.expense_number
) AS pd;
