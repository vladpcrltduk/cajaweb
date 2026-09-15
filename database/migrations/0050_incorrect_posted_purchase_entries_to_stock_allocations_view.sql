-- ============================================================
-- incorrect_posted_purchase_entries_to_stock_allocations_view
-- Source: dba.Incorrect_Posted_Purchase_Entries_To_Stock_Allocations
-- 3 UNION ALL branches identifying posted entries that landed on
-- stock-only allocations (stock_allocation = 'Y').
-- SAP alias-in-WHERE / alias-in-expr deps resolved per branch:
--   Branch 1: stock_allocation alias inlined in WHERE.
--   Branch 2: currency alias (correlated subquery) moved to JOIN;
--             stock_allocation alias inlined in WHERE.
--   Branch 3: amount alias (crdrindicator CASE) inlined twice into
--             base_amount to avoid a subquery;
--             expenses_summary.currency moved to JOIN;
--             stock_allocation alias inlined in WHERE.
-- IF/ENDIF → CASE WHEN…END.
-- Comma-joins → explicit JOINs; params → CROSS JOIN.
-- ============================================================

CREATE OR REPLACE VIEW public.incorrect_posted_purchase_entries_to_stock_allocations_view AS

-- Branch 1: Purchase Trading Invoices
SELECT
    '01'                                                                AS order_flag,
    'Purchase Trading Invoices'                                         AS order_name,
    invoice.invoice_number,
    invoice.invoice_date,
    invoice.posted_date,
    invoice_details_2.contno                                            AS contract,
    invoice_details_2.split,
    invoice_details_2.allocation_reference,
    public.sp_allocation_check_if_only_stock(
        invoice_details_2.allocation_reference)                         AS stock_allocation,
    invoice_details_2.linevalue                                         AS amount,
    invoice.invoice_currency                                            AS currency,
    invoice.house_rate,
    CASE WHEN currency.ratetype = 'M'
         THEN invoice_details_2.linevalue * invoice.house_rate
         ELSE invoice_details_2.linevalue / invoice.house_rate
    END                                                                 AS base_amount,
    params.base_currency                                                AS base_curr,
    invoice_details_2.nomcode                                           AS account
FROM public.invoice
JOIN public.invoice_details_2
    ON  invoice.invoice_number = invoice_details_2.invoice_number
    AND invoice.invoice_type   = invoice_details_2.invoice_type
    AND invoice.client         = invoice_details_2.client
JOIN public.sub_contracts
    ON  invoice_details_2.contno = sub_contracts.contno
    AND invoice_details_2.split  = sub_contracts.split
JOIN public.currency
    ON currency.code = invoice.invoice_currency
CROSS JOIN public.params
WHERE invoice_details_2.nomcode > '34999'
  AND public.sp_allocation_check_if_only_stock(
          invoice_details_2.allocation_reference) = 'Y'

UNION ALL

-- Branch 2: Final Trading Invoices
-- currency column is a correlated subquery into invoice (final invoices
-- carry no currency of their own; they reference their provisional invoice).
-- The same subquery is used in the JOIN for currency.ratetype lookup.
SELECT
    '01'                                                                AS order_flag,
    'Final Trading Invoices'                                            AS order_name,
    final_invoice.invoice_number,
    final_invoice.invoice_date,
    final_invoice.posted_date,
    final_invoice_details_2.contno                                      AS contract,
    final_invoice_details_2.split,
    final_invoice_details_2.allocation_reference,
    public.sp_allocation_check_if_only_stock(
        final_invoice_details_2.allocation_reference)                   AS stock_allocation,
    final_invoice_details_2.linevalue                                   AS amount,
    (SELECT inv.invoice_currency
     FROM public.invoice inv
     WHERE inv.invoice_number = final_invoice.invoice_number
       AND inv.invoice_type   = final_invoice.invoice_type
       AND inv.client         = final_invoice.client)                   AS currency,
    final_invoice.house_rate,
    CASE WHEN currency.ratetype = 'M'
         THEN final_invoice_details_2.linevalue * final_invoice.house_rate
         ELSE final_invoice_details_2.linevalue / final_invoice.house_rate
    END                                                                 AS base_amount,
    params.base_currency                                                AS base_curr,
    final_invoice_details_2.nomcode                                     AS account
FROM public.final_invoice
JOIN public.final_invoice_details_2
    ON  final_invoice.invoice_number = final_invoice_details_2.invoice_number
    AND final_invoice.invoice_type   = final_invoice_details_2.invoice_type
    AND final_invoice.client         = final_invoice_details_2.client
JOIN public.sub_contracts
    ON  final_invoice_details_2.contno = sub_contracts.contno
    AND final_invoice_details_2.split  = sub_contracts.split
JOIN public.currency ON currency.code = (
    SELECT inv.invoice_currency
    FROM public.invoice inv
    WHERE inv.invoice_number = final_invoice.invoice_number
      AND inv.invoice_type   = final_invoice.invoice_type
      AND inv.client         = final_invoice.client)
CROSS JOIN public.params
WHERE public.sp_allocation_check_if_only_stock(
          final_invoice_details_2.allocation_reference) = 'Y'
  AND final_invoice_details_2.nomcode > '34999'

UNION ALL

-- Branch 3: Expense Invoices / Posted Journals
-- amount: crdrindicator='D' negates expenses_detail.amount.
-- base_amount: amount expression inlined twice (avoids a subquery level).
-- currency join on expenses_summary.currency (alias-in-WHERE resolved).
SELECT
    '02'                                                                AS order_flag,
    'Expense Invoices / Posted Journals'                                AS order_name,
    expenses_summary.expense_number                                     AS invoice_number,
    expenses_summary.expense_date                                       AS invoice_date,
    expenses_summary.posted_date,
    expenses_detail.contno                                              AS contract,
    expenses_detail.split,
    expenses_detail.allocation_reference,
    public.sp_allocation_check_if_only_stock(
        expenses_detail.allocation_reference)                           AS stock_allocation,
    CASE WHEN expenses_detail.crdrindicator = 'D'
         THEN expenses_detail.amount * -1
         ELSE expenses_detail.amount
    END                                                                 AS amount,
    expenses_summary.currency,
    expenses_summary.house_rate,
    -- amount inlined to avoid subquery nesting
    CASE WHEN currency.ratetype = 'M'
         THEN (CASE WHEN expenses_detail.crdrindicator = 'D'
                    THEN expenses_detail.amount * -1
                    ELSE expenses_detail.amount
               END) * expenses_summary.house_rate
         ELSE (CASE WHEN expenses_detail.crdrindicator = 'D'
                    THEN expenses_detail.amount * -1
                    ELSE expenses_detail.amount
               END) / expenses_summary.house_rate
    END                                                                 AS base_amount,
    params.base_currency                                                AS base_curr,
    expenses_detail.nominal_account                                     AS account
FROM public.expenses_summary
JOIN public.expenses_detail
    ON  expenses_summary.client         = expenses_detail.client
    AND expenses_summary.expense_number = expenses_detail.expense_number
JOIN public.sub_contracts
    ON  expenses_detail.contno = sub_contracts.contno
    AND expenses_detail.split  = sub_contracts.split
JOIN public.currency
    ON currency.code = expenses_summary.currency
CROSS JOIN public.params
WHERE expenses_detail.nominal_account > '34999'
  AND public.sp_allocation_check_if_only_stock(
          expenses_detail.allocation_reference) = 'Y';
