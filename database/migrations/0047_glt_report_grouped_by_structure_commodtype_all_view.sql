-- ============================================================
-- glt_report_grouped_by_structure_commodtype_all_view
-- Source: dba.GLT_Report_Grouped_By_Structure_CommodType_ALL
-- Like glt_report_grouped_by_structure_commodtype_view (0043) but:
--   - Aggregates across ALL commodity types (no commodtype split);
--     commodity_type_code = 'ZZZZ', commodity_type_longname =
--     'ALL COMMODITY TYPES' are literal constants in every branch.
--   - Adds company.longname column.
--   - Adds explicit purch/sales result columns for each section and
--     their total (matched_total_result, open_total_result, etc.).
--   - Adds result_previous_month / result_previous_day (correlated
--     subqueries into accounts_period_month_end_results, Branch 1 only;
--     Branches 2–6 output 0).
-- 6 UNION ALL branches (SAP UNION → UNION ALL: each branch populates
--   a distinct column group; cross-branch duplicates are impossible).
-- Per-branch alias dep: purch_result + sales_result → total_result;
--   resolved by inlining (sum written twice, no subquery needed).
-- previous_month_code inlined as TO_CHAR(CURRENT_DATE - INTERVAL
--   '1 month', 'YYYYMM') wherever used (no alias ref in outer GROUP BY).
-- SAP isnull(SUM(x),0) → COALESCE(SUM(x),0).
-- Comma-joins → explicit JOINs; params → CROSS JOIN.
-- SAP OR list on terminaltype → explicit OR conditions preserved
--   (different logic per company for SG).
-- ============================================================

CREATE OR REPLACE VIEW public.glt_report_grouped_by_structure_commodtype_all_view AS

-- Branch 1: matched physical (glt_report_alloc_pl_view)
SELECT
    company.code,
    company.longname,
    'ZZZZ'                                                              AS commodity_type_code,
    'ALL COMMODITY TYPES'                                               AS commodity_type_longname,
    COALESCE(SUM(glt_report_alloc_pl_view.sales_tonnage), 0)           AS matched_tonnage,
    COALESCE(SUM(glt_report_alloc_pl_view.purchase_total_price), 0)    AS matched_purch_result,
    COALESCE(SUM(glt_report_alloc_pl_view.sales_total_price), 0)       AS matched_sales_result,
    -- matched_total_result: matched_purch_result + matched_sales_result inlined
    COALESCE(SUM(glt_report_alloc_pl_view.purchase_total_price), 0)
        + COALESCE(SUM(glt_report_alloc_pl_view.sales_total_price), 0) AS matched_total_result,
    0                                                                   AS open_tonnage,
    0                                                                   AS open_purch_result,
    0                                                                   AS open_sales_result,
    0                                                                   AS open_total_result,
    0                                                                   AS futures_open_tonnage,
    0                                                                   AS futures_open_purch_result,
    0                                                                   AS futures_open_sales_result,
    0                                                                   AS futures_open_total_result,
    0                                                                   AS futures_mathched_tonnage,
    0                                                                   AS futures_matched_purch_result,
    0                                                                   AS futures_matched_sales_result,
    0                                                                   AS futures_matched_total_result,
    0                                                                   AS options_open_tonnage,
    0                                                                   AS options_open_purch_result,
    0                                                                   AS options_open_sales_result,
    0                                                                   AS options_open_total_result,
    0                                                                   AS options_mathched_tonnage,
    0                                                                   AS options_matched_purch_result,
    0                                                                   AS options_matched_sales_result,
    0                                                                   AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    COALESCE((
        SELECT SUM(apmr.account_result)
        FROM public.accounts_period_month_end_results apmr
        WHERE apmr.accperiod = TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')
          AND apmr.company   = company.code
    ), 0)                                                               AS result_previous_month,
    COALESCE((
        SELECT SUM(apmr.month_end_result)
        FROM public.accounts_period_month_end_results apmr
        WHERE apmr.accperiod = TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')
          AND apmr.company   = company.code
    ), 0)                                                               AS result_previous_day,
    params.base_currency
FROM public.company
JOIN public.glt_report_alloc_pl_view
    ON company.code = glt_report_alloc_pl_view.company
CROSS JOIN public.params
GROUP BY
    company.code,
    company.longname,
    params.base_currency

UNION ALL

-- Branch 2: open physical (phys_valn_view_valn_sopex)
SELECT
    company.code,
    company.longname,
    'ZZZZ'                                                              AS commodity_type_code,
    'ALL COMMODITY TYPES'                                               AS commodity_type_longname,
    0                                                                   AS matched_tonnage,
    0                                                                   AS matched_purch_result,
    0                                                                   AS matched_sales_result,
    0                                                                   AS matched_total_result,
    SUM(phys_valn_view_valn_sopex.base_openqnt)                        AS open_tonnage,
    COALESCE(SUM(phys_valn_view_valn_sopex.purch_valn_result), 0)      AS open_purch_result,
    COALESCE(SUM(phys_valn_view_valn_sopex.sales_valn_result), 0)      AS open_sales_result,
    -- open_total_result: open_purch_result + open_sales_result inlined
    COALESCE(SUM(phys_valn_view_valn_sopex.purch_valn_result), 0)
        + COALESCE(SUM(phys_valn_view_valn_sopex.sales_valn_result), 0) AS open_total_result,
    0                                                                   AS futures_open_tonnage,
    0                                                                   AS futures_open_purch_result,
    0                                                                   AS futures_open_sales_result,
    0                                                                   AS futures_open_total_result,
    0                                                                   AS futures_mathched_tonnage,
    0                                                                   AS futures_matched_purch_result,
    0                                                                   AS futures_matched_sales_result,
    0                                                                   AS futures_matched_total_result,
    0                                                                   AS options_open_tonnage,
    0                                                                   AS options_open_purch_result,
    0                                                                   AS options_open_sales_result,
    0                                                                   AS options_open_total_result,
    0                                                                   AS options_mathched_tonnage,
    0                                                                   AS options_matched_purch_result,
    0                                                                   AS options_matched_sales_result,
    0                                                                   AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                   AS result_previous_month,
    0                                                                   AS result_previous_day,
    params.base_currency
FROM public.company
JOIN public.phys_valn_view_valn_sopex
    ON company.code = phys_valn_view_valn_sopex.company
CROSS JOIN public.params
WHERE phys_valn_view_valn_sopex.true_open > 0
GROUP BY
    company.code,
    company.longname,
    params.base_currency

UNION ALL

-- Branch 3: futures open (terminal_valuation_by_prompt, tradetype='F')
SELECT
    company.code,
    company.longname,
    'ZZZZ'                                                              AS commodity_type_code,
    'ALL COMMODITY TYPES'                                               AS commodity_type_longname,
    0                                                                   AS matched_tonnage,
    0                                                                   AS matched_purch_result,
    0                                                                   AS matched_sales_result,
    0                                                                   AS matched_total_result,
    0                                                                   AS open_tonnage,
    0                                                                   AS open_purch_result,
    0                                                                   AS open_sales_result,
    0                                                                   AS open_total_result,
    COALESCE(SUM(terminal_valuation_by_prompt.purchased_lots_tonnage), 0)
        - COALESCE(SUM(terminal_valuation_by_prompt.sold_lots_tonnage), 0)   AS futures_open_tonnage,
    COALESCE(SUM(terminal_valuation_by_prompt.purchased_result_basecurr), 0) AS futures_open_purch_result,
    COALESCE(SUM(terminal_valuation_by_prompt.sold_result_basecurr), 0)      AS futures_open_sales_result,
    -- futures_open_total_result: inlined
    COALESCE(SUM(terminal_valuation_by_prompt.purchased_result_basecurr), 0)
        + COALESCE(SUM(terminal_valuation_by_prompt.sold_result_basecurr), 0) AS futures_open_total_result,
    0                                                                   AS futures_mathched_tonnage,
    0                                                                   AS futures_matched_purch_result,
    0                                                                   AS futures_matched_sales_result,
    0                                                                   AS futures_matched_total_result,
    0                                                                   AS options_open_tonnage,
    0                                                                   AS options_open_purch_result,
    0                                                                   AS options_open_sales_result,
    0                                                                   AS options_open_total_result,
    0                                                                   AS options_mathched_tonnage,
    0                                                                   AS options_matched_purch_result,
    0                                                                   AS options_matched_sales_result,
    0                                                                   AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                   AS result_previous_month,
    0                                                                   AS result_previous_day,
    params.base_currency
FROM public.company
JOIN public.terminal_valuation_by_prompt
    ON company.code = terminal_valuation_by_prompt.company
CROSS JOIN public.params
WHERE terminal_valuation_by_prompt.tradetype = 'F'
  AND (   terminal_valuation_by_prompt.terminaltype = 'CA'
       OR terminal_valuation_by_prompt.terminaltype = 'US'
       OR (terminal_valuation_by_prompt.company = '02'
           AND terminal_valuation_by_prompt.terminaltype = 'SG'))
GROUP BY
    company.code,
    company.longname,
    params.base_currency

UNION ALL

-- Branch 4: futures matched (glt_report_termclosed_view, tradetype='F')
SELECT
    company.code,
    company.longname,
    'ZZZZ'                                                              AS commodity_type_code,
    'ALL COMMODITY TYPES'                                               AS commodity_type_longname,
    0                                                                   AS matched_tonnage,
    0                                                                   AS matched_purch_result,
    0                                                                   AS matched_sales_result,
    0                                                                   AS matched_total_result,
    0                                                                   AS open_tonnage,
    0                                                                   AS open_purch_result,
    0                                                                   AS open_sales_result,
    0                                                                   AS open_total_result,
    0                                                                   AS futures_open_tonnage,
    0                                                                   AS futures_open_purch_result,
    0                                                                   AS futures_open_sales_result,
    0                                                                   AS futures_open_total_result,
    COALESCE(SUM(glt_report_termclosed_view.sold_settled_tonnage), 0)          AS futures_mathched_tonnage,
    COALESCE(SUM(glt_report_termclosed_view.purch_sett_result_base_curr), 0)   AS futures_matched_purch_result,
    COALESCE(SUM(glt_report_termclosed_view.sold_sett_result_base_curr), 0)    AS futures_matched_sales_result,
    -- futures_matched_total_result: inlined
    COALESCE(SUM(glt_report_termclosed_view.purch_sett_result_base_curr), 0)
        + COALESCE(SUM(glt_report_termclosed_view.sold_sett_result_base_curr), 0) AS futures_matched_total_result,
    0                                                                   AS options_open_tonnage,
    0                                                                   AS options_open_purch_result,
    0                                                                   AS options_open_sales_result,
    0                                                                   AS options_open_total_result,
    0                                                                   AS options_mathched_tonnage,
    0                                                                   AS options_matched_purch_result,
    0                                                                   AS options_matched_sales_result,
    0                                                                   AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                   AS result_previous_month,
    0                                                                   AS result_previous_day,
    params.base_currency
FROM public.company
JOIN public.glt_report_termclosed_view
    ON company.code = glt_report_termclosed_view.company
CROSS JOIN public.params
WHERE glt_report_termclosed_view.tradetype = 'F'
  AND (   glt_report_termclosed_view.terminaltype = 'CA'
       OR glt_report_termclosed_view.terminaltype = 'US'
       OR (glt_report_termclosed_view.company = '02'
           AND glt_report_termclosed_view.terminaltype = 'SG'))
  AND (glt_report_termclosed_view.settlement_confirmed = 'N'
       OR glt_report_termclosed_view.settlement_confirmed IS NULL)
GROUP BY
    company.code,
    company.longname,
    params.base_currency

UNION ALL

-- Branch 5: options open (terminal_valuation_by_prompt, tradetype<>'F')
SELECT
    company.code,
    company.longname,
    'ZZZZ'                                                              AS commodity_type_code,
    'ALL COMMODITY TYPES'                                               AS commodity_type_longname,
    0                                                                   AS matched_tonnage,
    0                                                                   AS matched_purch_result,
    0                                                                   AS matched_sales_result,
    0                                                                   AS matched_total_result,
    0                                                                   AS open_tonnage,
    0                                                                   AS open_purch_result,
    0                                                                   AS open_sales_result,
    0                                                                   AS open_total_result,
    0                                                                   AS futures_open_tonnage,
    0                                                                   AS futures_open_purch_result,
    0                                                                   AS futures_open_sales_result,
    0                                                                   AS futures_open_total_result,
    0                                                                   AS futures_mathched_tonnage,
    0                                                                   AS futures_matched_purch_result,
    0                                                                   AS futures_matched_sales_result,
    0                                                                   AS futures_matched_total_result,
    COALESCE(SUM(terminal_valuation_by_prompt.purchased_lots_tonnage), 0)
        - COALESCE(SUM(terminal_valuation_by_prompt.sold_lots_tonnage), 0)   AS options_open_tonnage,
    COALESCE(SUM(terminal_valuation_by_prompt.purchased_result_basecurr), 0) AS options_open_purch_result,
    COALESCE(SUM(terminal_valuation_by_prompt.sold_result_basecurr), 0)      AS options_open_sales_result,
    -- options_open_total_result: inlined
    COALESCE(SUM(terminal_valuation_by_prompt.purchased_result_basecurr), 0)
        + COALESCE(SUM(terminal_valuation_by_prompt.sold_result_basecurr), 0) AS options_open_total_result,
    0                                                                   AS options_mathched_tonnage,
    0                                                                   AS options_matched_purch_result,
    0                                                                   AS options_matched_sales_result,
    0                                                                   AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                   AS result_previous_month,
    0                                                                   AS result_previous_day,
    params.base_currency
FROM public.company
JOIN public.terminal_valuation_by_prompt
    ON company.code = terminal_valuation_by_prompt.company
CROSS JOIN public.params
WHERE terminal_valuation_by_prompt.tradetype <> 'F'
  AND (   terminal_valuation_by_prompt.terminaltype = 'CA'
       OR terminal_valuation_by_prompt.terminaltype = 'US'
       OR (terminal_valuation_by_prompt.company = '02'
           AND terminal_valuation_by_prompt.terminaltype = 'SG'))
GROUP BY
    company.code,
    company.longname,
    params.base_currency

UNION ALL

-- Branch 6: options matched (glt_report_termclosed_view, tradetype<>'F')
SELECT
    company.code,
    company.longname,
    'ZZZZ'                                                              AS commodity_type_code,
    'ALL COMMODITY TYPES'                                               AS commodity_type_longname,
    0                                                                   AS matched_tonnage,
    0                                                                   AS matched_purch_result,
    0                                                                   AS matched_sales_result,
    0                                                                   AS matched_total_result,
    0                                                                   AS open_tonnage,
    0                                                                   AS open_purch_result,
    0                                                                   AS open_sales_result,
    0                                                                   AS open_total_result,
    0                                                                   AS futures_open_tonnage,
    0                                                                   AS futures_open_purch_result,
    0                                                                   AS futures_open_sales_result,
    0                                                                   AS futures_open_total_result,
    0                                                                   AS futures_mathched_tonnage,
    0                                                                   AS futures_matched_purch_result,
    0                                                                   AS futures_matched_sales_result,
    0                                                                   AS futures_matched_total_result,
    0                                                                   AS options_open_tonnage,
    0                                                                   AS options_open_purch_result,
    0                                                                   AS options_open_sales_result,
    0                                                                   AS options_open_total_result,
    COALESCE(SUM(glt_report_termclosed_view.histaction_s_purch_settled_tonnage), 0) AS options_mathched_tonnage,
    COALESCE(SUM(glt_report_termclosed_view.purch_sett_result_base_curr), 0)        AS options_matched_purch_result,
    COALESCE(SUM(glt_report_termclosed_view.sold_sett_result_base_curr), 0)         AS options_matched_sales_result,
    -- options_matched_total_result: inlined
    COALESCE(SUM(glt_report_termclosed_view.purch_sett_result_base_curr), 0)
        + COALESCE(SUM(glt_report_termclosed_view.sold_sett_result_base_curr), 0)   AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                   AS result_previous_month,
    0                                                                   AS result_previous_day,
    params.base_currency
FROM public.company
JOIN public.glt_report_termclosed_view
    ON company.code = glt_report_termclosed_view.company
CROSS JOIN public.params
WHERE glt_report_termclosed_view.tradetype <> 'F'
  AND (   glt_report_termclosed_view.terminaltype = 'CA'
       OR glt_report_termclosed_view.terminaltype = 'US'
       OR (glt_report_termclosed_view.company = '02'
           AND glt_report_termclosed_view.terminaltype = 'SG'))
  AND (glt_report_termclosed_view.settlement_confirmed = 'N'
       OR glt_report_termclosed_view.settlement_confirmed IS NULL)
GROUP BY
    company.code,
    company.longname,
    params.base_currency

ORDER BY 1;
