-- ============================================================
-- glt_report_grouped_by_structure_commodtype
-- Source: dba.GLT_Report_Grouped_By_Structure_CommodType
-- 6 UNION ALL branches (5 UNIONs); each populates a distinct
-- section of columns, zeroing the rest:
--   Branch 1: matched physical  (glt_report_alloc_pl_view)
--   Branch 2: open physical     (phys_valn_view_valn_sopex)
--   Branch 3: futures open      (terminal_valuation_by_prompt, tradetype='F')
--   Branch 4: futures matched   (glt_report_termclosed_view, tradetype='F')
--   Branch 5: options open      (terminal_valuation_by_prompt, tradetype<>'F')
--   Branch 6: options matched   (glt_report_termclosed_view, tradetype<>'F')
-- UNION → UNION ALL: cross-branch duplicates are impossible
--   (each branch has different non-zero columns) — dedup is wasted.
-- Alias deps (*_total_result = *_purch + *_sales) inlined in each
--   branch; SAP allows same-SELECT alias refs, PG does not.
-- previous_month_code alias inlined as TO_CHAR expression wherever
--   used (3 times in Branch 1; once in Branches 2–6).
-- SAP: dateformat(DATEADD(month,-1,today()),'YYYYMM')
--   → TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')
-- isnull(SUM(x),0) → COALESCE(SUM(x),0).
-- Comma-joins → explicit JOINs; params → CROSS JOIN.
-- Typos futures_mathched_tonnage / options_mathched_tonnage
--   preserved for column-name compatibility with existing consumers.
-- ============================================================

CREATE OR REPLACE VIEW public.glt_report_grouped_by_structure_commodtype_view AS

-- Branch 1: Matched physical contracts (glt_report_alloc_pl_view)
SELECT
    co.code,
    co.longname,
    ct.code                                                              AS commodity_type_code,
    ct.longname                                                          AS commodity_type_longname,
    COALESCE(SUM(glt.sales_tonnage), 0)                                 AS matched_tonnage,
    COALESCE(SUM(glt.purchase_total_price), 0)                          AS matched_purch_result,
    COALESCE(SUM(glt.sales_total_price), 0)                             AS matched_sales_result,
    COALESCE(SUM(glt.purchase_total_price), 0)
        + COALESCE(SUM(glt.sales_total_price), 0)                       AS matched_total_result,
    0                                                                    AS open_tonnage,
    0                                                                    AS open_purch_result,
    0                                                                    AS open_sales_result,
    0                                                                    AS open_total_result,
    0                                                                    AS futures_open_tonnage,
    0                                                                    AS futures_open_purch_result,
    0                                                                    AS futures_open_sales_result,
    0                                                                    AS futures_open_total_result,
    0                                                                    AS futures_mathched_tonnage,
    0                                                                    AS futures_matched_purch_result,
    0                                                                    AS futures_matched_sales_result,
    0                                                                    AS futures_matched_total_result,
    0                                                                    AS options_open_tonnage,
    0                                                                    AS options_open_purch_result,
    0                                                                    AS options_open_sales_result,
    0                                                                    AS options_open_total_result,
    0                                                                    AS options_mathched_tonnage,
    0                                                                    AS options_matched_purch_result,
    0                                                                    AS options_matched_sales_result,
    0                                                                    AS options_matched_total_result,
    -- previous_month_code alias inlined (used twice below in correlated subqueries)
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    COALESCE((
        SELECT MAX(apmr.account_result)
        FROM public.accounts_period_month_end_results apmr
        WHERE apmr.accperiod       = TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')
          AND apmr.company         = co.code
          AND apmr.additional_flag = ct.code
    ), 0)                                                                AS result_previous_month,
    COALESCE((
        SELECT MAX(apmr.month_end_result)
        FROM public.accounts_period_month_end_results apmr
        WHERE apmr.accperiod       = TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')
          AND apmr.company         = co.code
          AND apmr.additional_flag = ct.code
    ), 0)                                                                AS result_previous_day,
    p.base_currency
FROM public.glt_report_alloc_pl_view glt
JOIN public.company co        ON co.code = glt.company
JOIN public.commodity_type ct ON ct.code = glt.commodtype
CROSS JOIN public.params p
WHERE ct.code IN ('ARA', 'ROB')
GROUP BY
    co.code,
    co.longname,
    ct.code,
    ct.longname,
    p.base_currency

UNION ALL

-- Branch 2: Open physical (phys_valn_view_valn_sopex)
SELECT
    co.code,
    co.longname,
    ct.code                                                              AS commodity_type_code,
    ct.longname                                                          AS commodity_type_longname,
    0                                                                    AS matched_tonnage,
    0                                                                    AS matched_purch_result,
    0                                                                    AS matched_sales_result,
    0                                                                    AS matched_total_result,
    SUM(pvs.base_openqnt)                                               AS open_tonnage,
    COALESCE(SUM(pvs.purch_valn_result), 0)                             AS open_purch_result,
    COALESCE(SUM(pvs.sales_valn_result), 0)                             AS open_sales_result,
    COALESCE(SUM(pvs.purch_valn_result), 0)
        + COALESCE(SUM(pvs.sales_valn_result), 0)                       AS open_total_result,
    0                                                                    AS futures_open_tonnage,
    0                                                                    AS futures_open_purch_result,
    0                                                                    AS futures_open_sales_result,
    0                                                                    AS futures_open_total_result,
    0                                                                    AS futures_mathched_tonnage,
    0                                                                    AS futures_matched_purch_result,
    0                                                                    AS futures_matched_sales_result,
    0                                                                    AS futures_matched_total_result,
    0                                                                    AS options_open_tonnage,
    0                                                                    AS options_open_purch_result,
    0                                                                    AS options_open_sales_result,
    0                                                                    AS options_open_total_result,
    0                                                                    AS options_mathched_tonnage,
    0                                                                    AS options_matched_purch_result,
    0                                                                    AS options_matched_sales_result,
    0                                                                    AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                    AS result_previous_month,
    0                                                                    AS result_previous_day,
    p.base_currency
FROM public.phys_valn_view_valn_sopex pvs
JOIN public.company co        ON co.code = pvs.company
JOIN public.commodity_type ct ON ct.code = pvs.commodtype
CROSS JOIN public.params p
WHERE ct.code IN ('ARA', 'ROB')
  AND pvs.true_open > 0
GROUP BY
    co.code,
    co.longname,
    ct.code,
    ct.longname,
    p.base_currency

UNION ALL

-- Branch 3: Futures open (terminal_valuation_by_prompt, tradetype='F')
SELECT
    co.code,
    co.longname,
    ct.code                                                              AS commodity_type_code,
    ct.longname                                                          AS commodity_type_longname,
    0                                                                    AS matched_tonnage,
    0                                                                    AS matched_purch_result,
    0                                                                    AS matched_sales_result,
    0                                                                    AS matched_total_result,
    0                                                                    AS open_tonnage,
    0                                                                    AS open_purch_result,
    0                                                                    AS open_sales_result,
    0                                                                    AS open_total_result,
    COALESCE(SUM(tvbp.purchased_lots_tonnage), 0)
        - COALESCE(SUM(tvbp.sold_lots_tonnage), 0)                      AS futures_open_tonnage,
    COALESCE(SUM(tvbp.purchased_result_basecurr), 0)                    AS futures_open_purch_result,
    COALESCE(SUM(tvbp.sold_result_basecurr), 0)                         AS futures_open_sales_result,
    COALESCE(SUM(tvbp.purchased_result_basecurr), 0)
        + COALESCE(SUM(tvbp.sold_result_basecurr), 0)                   AS futures_open_total_result,
    0                                                                    AS futures_mathched_tonnage,
    0                                                                    AS futures_matched_purch_result,
    0                                                                    AS futures_matched_sales_result,
    0                                                                    AS futures_matched_total_result,
    0                                                                    AS options_open_tonnage,
    0                                                                    AS options_open_purch_result,
    0                                                                    AS options_open_sales_result,
    0                                                                    AS options_open_total_result,
    0                                                                    AS options_mathched_tonnage,
    0                                                                    AS options_matched_purch_result,
    0                                                                    AS options_matched_sales_result,
    0                                                                    AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                    AS result_previous_month,
    0                                                                    AS result_previous_day,
    p.base_currency
FROM public.terminal_valuation_by_prompt tvbp
JOIN public.company co        ON co.code = tvbp.company
JOIN public.commodity_type ct ON ct.code = tvbp.wp_commodity
CROSS JOIN public.params p
WHERE ct.code IN ('ARA', 'ROB')
  AND tvbp.tradetype = 'F'
  AND (   tvbp.terminaltype = 'CA'
       OR tvbp.terminaltype = 'US'
       OR (tvbp.company = '02' AND tvbp.terminaltype = 'SG'))
GROUP BY
    co.code,
    co.longname,
    ct.code,
    ct.longname,
    p.base_currency

UNION ALL

-- Branch 4: Futures matched (glt_report_termclosed_view, tradetype='F')
SELECT
    co.code,
    co.longname,
    ct.code                                                              AS commodity_type_code,
    ct.longname                                                          AS commodity_type_longname,
    0                                                                    AS matched_tonnage,
    0                                                                    AS matched_purch_result,
    0                                                                    AS matched_sales_result,
    0                                                                    AS matched_total_result,
    0                                                                    AS open_tonnage,
    0                                                                    AS open_purch_result,
    0                                                                    AS open_sales_result,
    0                                                                    AS open_total_result,
    0                                                                    AS futures_open_tonnage,
    0                                                                    AS futures_open_purch_result,
    0                                                                    AS futures_open_sales_result,
    0                                                                    AS futures_open_total_result,
    COALESCE(SUM(gltc.sold_settled_tonnage), 0)                         AS futures_mathched_tonnage,
    COALESCE(SUM(gltc.purch_sett_result_base_curr), 0)                  AS futures_matched_purch_result,
    COALESCE(SUM(gltc.sold_sett_result_base_curr), 0)                   AS futures_matched_sales_result,
    COALESCE(SUM(gltc.purch_sett_result_base_curr), 0)
        + COALESCE(SUM(gltc.sold_sett_result_base_curr), 0)             AS futures_matched_total_result,
    0                                                                    AS options_open_tonnage,
    0                                                                    AS options_open_purch_result,
    0                                                                    AS options_open_sales_result,
    0                                                                    AS options_open_total_result,
    0                                                                    AS options_mathched_tonnage,
    0                                                                    AS options_matched_purch_result,
    0                                                                    AS options_matched_sales_result,
    0                                                                    AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                    AS result_previous_month,
    0                                                                    AS result_previous_day,
    p.base_currency
FROM public.glt_report_termclosed_view gltc
JOIN public.company co        ON co.code = gltc.company
JOIN public.commodity_type ct ON ct.code = gltc.wp_commodity
CROSS JOIN public.params p
WHERE ct.code IN ('ARA', 'ROB')
  AND gltc.tradetype = 'F'
  AND (   gltc.terminaltype = 'CA'
       OR gltc.terminaltype = 'US'
       OR (gltc.company = '02' AND gltc.terminaltype = 'SG'))
  AND (gltc.settlement_confirmed = 'N' OR gltc.settlement_confirmed IS NULL)
GROUP BY
    co.code,
    co.longname,
    ct.code,
    ct.longname,
    p.base_currency

UNION ALL

-- Branch 5: Options open (terminal_valuation_by_prompt, tradetype<>'F')
SELECT
    co.code,
    co.longname,
    ct.code                                                              AS commodity_type_code,
    ct.longname                                                          AS commodity_type_longname,
    0                                                                    AS matched_tonnage,
    0                                                                    AS matched_purch_result,
    0                                                                    AS matched_sales_result,
    0                                                                    AS matched_total_result,
    0                                                                    AS open_tonnage,
    0                                                                    AS open_purch_result,
    0                                                                    AS open_sales_result,
    0                                                                    AS open_total_result,
    0                                                                    AS futures_open_tonnage,
    0                                                                    AS futures_open_purch_result,
    0                                                                    AS futures_open_sales_result,
    0                                                                    AS futures_open_total_result,
    0                                                                    AS futures_mathched_tonnage,
    0                                                                    AS futures_matched_purch_result,
    0                                                                    AS futures_matched_sales_result,
    0                                                                    AS futures_matched_total_result,
    COALESCE(SUM(tvbp.purchased_lots_tonnage), 0)
        - COALESCE(SUM(tvbp.sold_lots_tonnage), 0)                      AS options_open_tonnage,
    COALESCE(SUM(tvbp.purchased_result_basecurr), 0)                    AS options_open_purch_result,
    COALESCE(SUM(tvbp.sold_result_basecurr), 0)                         AS options_open_sales_result,
    COALESCE(SUM(tvbp.purchased_result_basecurr), 0)
        + COALESCE(SUM(tvbp.sold_result_basecurr), 0)                   AS options_open_total_result,
    0                                                                    AS options_mathched_tonnage,
    0                                                                    AS options_matched_purch_result,
    0                                                                    AS options_matched_sales_result,
    0                                                                    AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                    AS result_previous_month,
    0                                                                    AS result_previous_day,
    p.base_currency
FROM public.terminal_valuation_by_prompt tvbp
JOIN public.company co        ON co.code = tvbp.company
JOIN public.commodity_type ct ON ct.code = tvbp.wp_commodity
CROSS JOIN public.params p
WHERE ct.code IN ('ARA', 'ROB')
  AND tvbp.tradetype <> 'F'
  AND (   tvbp.terminaltype = 'CA'
       OR tvbp.terminaltype = 'US'
       OR (tvbp.company = '02' AND tvbp.terminaltype = 'SG'))
GROUP BY
    co.code,
    co.longname,
    ct.code,
    ct.longname,
    p.base_currency

UNION ALL

-- Branch 6: Options matched (glt_report_termclosed_view, tradetype<>'F')
SELECT
    co.code,
    co.longname,
    ct.code                                                              AS commodity_type_code,
    ct.longname                                                          AS commodity_type_longname,
    0                                                                    AS matched_tonnage,
    0                                                                    AS matched_purch_result,
    0                                                                    AS matched_sales_result,
    0                                                                    AS matched_total_result,
    0                                                                    AS open_tonnage,
    0                                                                    AS open_purch_result,
    0                                                                    AS open_sales_result,
    0                                                                    AS open_total_result,
    0                                                                    AS futures_open_tonnage,
    0                                                                    AS futures_open_purch_result,
    0                                                                    AS futures_open_sales_result,
    0                                                                    AS futures_open_total_result,
    0                                                                    AS futures_mathched_tonnage,
    0                                                                    AS futures_matched_purch_result,
    0                                                                    AS futures_matched_sales_result,
    0                                                                    AS futures_matched_total_result,
    0                                                                    AS options_open_tonnage,
    0                                                                    AS options_open_purch_result,
    0                                                                    AS options_open_sales_result,
    0                                                                    AS options_open_total_result,
    COALESCE(SUM(gltc.histaction_s_purch_settled_tonnage), 0)           AS options_mathched_tonnage,
    COALESCE(SUM(gltc.purch_sett_result_base_curr), 0)                  AS options_matched_purch_result,
    COALESCE(SUM(gltc.sold_sett_result_base_curr), 0)                   AS options_matched_sales_result,
    COALESCE(SUM(gltc.purch_sett_result_base_curr), 0)
        + COALESCE(SUM(gltc.sold_sett_result_base_curr), 0)             AS options_matched_total_result,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYYMM')               AS previous_month_code,
    0                                                                    AS result_previous_month,
    0                                                                    AS result_previous_day,
    p.base_currency
FROM public.glt_report_termclosed_view gltc
JOIN public.company co        ON co.code = gltc.company
JOIN public.commodity_type ct ON ct.code = gltc.wp_commodity
CROSS JOIN public.params p
WHERE ct.code IN ('ARA', 'ROB')
  AND gltc.tradetype <> 'F'
  AND (   gltc.terminaltype = 'CA'
       OR gltc.terminaltype = 'US'
       OR (gltc.company = '02' AND gltc.terminaltype = 'SG'))
  AND (gltc.settlement_confirmed = 'N' OR gltc.settlement_confirmed IS NULL)
GROUP BY
    co.code,
    co.longname,
    ct.code,
    ct.longname,
    p.base_currency

ORDER BY 1;
