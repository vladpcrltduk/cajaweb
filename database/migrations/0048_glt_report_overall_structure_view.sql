-- ============================================================
-- glt_report_overall_structure_view
-- Source: dba.GLT_Report_Overall_Structure
-- Top-level aggregation view: sums all result columns from the
-- two sibling views and returns one row per company/commodity_type.
--   Branch 1: per-commodity-type rows from
--             glt_report_grouped_by_structure_commodtype_view (0043)
--   Branch 2: all-commodity-types rollup rows from
--             glt_report_grouped_by_structure_commodtype_all_view (0047)
-- SAP UNION → UNION ALL preserved (branches differ on commodity_type_code
--   so cross-branch duplicates are impossible).
-- WHERE (1=1) no-ops omitted.
-- ============================================================

CREATE OR REPLACE VIEW public.glt_report_overall_structure_view AS

SELECT
    code                                                                AS company_code,
    longname                                                            AS company_longname,
    commodity_type_code,
    commodity_type_longname,
    SUM(matched_tonnage)                                                AS matched_tonnage,
    SUM(matched_purch_result)                                           AS matched_purch_result,
    SUM(matched_sales_result)                                           AS matched_sales_result,
    SUM(matched_total_result)                                           AS matched_total_result,
    SUM(open_tonnage)                                                   AS open_tonnage,
    SUM(open_purch_result)                                              AS open_purch_result,
    SUM(open_sales_result)                                              AS open_sales_result,
    SUM(open_total_result)                                              AS open_total_result,
    SUM(futures_open_tonnage)                                           AS futures_open_tonnage,
    SUM(futures_open_purch_result)                                      AS futures_open_purch_result,
    SUM(futures_open_sales_result)                                      AS futures_open_sales_result,
    SUM(futures_open_total_result)                                      AS futures_open_total_result,
    SUM(futures_mathched_tonnage)                                       AS futures_mathched_tonnage,
    SUM(futures_matched_purch_result)                                   AS futures_matched_purch_result,
    SUM(futures_matched_sales_result)                                   AS futures_matched_sales_result,
    SUM(futures_matched_total_result)                                   AS futures_matched_total_result,
    SUM(options_open_tonnage)                                           AS options_open_tonnage,
    SUM(options_open_purch_result)                                      AS options_open_purch_result,
    SUM(options_open_sales_result)                                      AS options_open_sales_result,
    SUM(options_open_total_result)                                      AS options_open_total_result,
    SUM(options_mathched_tonnage)                                       AS options_mathched_tonnage,
    SUM(options_matched_purch_result)                                   AS options_matched_purch_result,
    SUM(options_matched_sales_result)                                   AS options_matched_sales_result,
    SUM(options_matched_total_result)                                   AS options_matched_total_result,
    MIN(previous_month_code)                                            AS previous_month_code,
    SUM(result_previous_month)                                          AS result_previous_month,
    SUM(result_previous_day)                                            AS result_previous_day,
    base_currency
FROM public.glt_report_grouped_by_structure_commodtype_view
GROUP BY
    code,
    longname,
    commodity_type_code,
    commodity_type_longname,
    base_currency

UNION ALL

SELECT
    code                                                                AS company_code,
    longname                                                            AS company_longname,
    commodity_type_code,
    commodity_type_longname,
    SUM(matched_tonnage)                                                AS matched_tonnage,
    SUM(matched_purch_result)                                           AS matched_purch_result,
    SUM(matched_sales_result)                                           AS matched_sales_result,
    SUM(matched_total_result)                                           AS matched_total_result,
    SUM(open_tonnage)                                                   AS open_tonnage,
    SUM(open_purch_result)                                              AS open_purch_result,
    SUM(open_sales_result)                                              AS open_sales_result,
    SUM(open_total_result)                                              AS open_total_result,
    SUM(futures_open_tonnage)                                           AS futures_open_tonnage,
    SUM(futures_open_purch_result)                                      AS futures_open_purch_result,
    SUM(futures_open_sales_result)                                      AS futures_open_sales_result,
    SUM(futures_open_total_result)                                      AS futures_open_total_result,
    SUM(futures_mathched_tonnage)                                       AS futures_mathched_tonnage,
    SUM(futures_matched_purch_result)                                   AS futures_matched_purch_result,
    SUM(futures_matched_sales_result)                                   AS futures_matched_sales_result,
    SUM(futures_matched_total_result)                                   AS futures_matched_total_result,
    SUM(options_open_tonnage)                                           AS options_open_tonnage,
    SUM(options_open_purch_result)                                      AS options_open_purch_result,
    SUM(options_open_sales_result)                                      AS options_open_sales_result,
    SUM(options_open_total_result)                                      AS options_open_total_result,
    SUM(options_mathched_tonnage)                                       AS options_mathched_tonnage,
    SUM(options_matched_purch_result)                                   AS options_matched_purch_result,
    SUM(options_matched_sales_result)                                   AS options_matched_sales_result,
    SUM(options_matched_total_result)                                   AS options_matched_total_result,
    MIN(previous_month_code)                                            AS previous_month_code,
    SUM(result_previous_month)                                          AS result_previous_month,
    SUM(result_previous_day)                                            AS result_previous_day,
    base_currency
FROM public.glt_report_grouped_by_structure_commodtype_all_view
GROUP BY
    code,
    longname,
    commodity_type_code,
    commodity_type_longname,
    base_currency;
