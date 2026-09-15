-- ============================================================
-- powerbi_caja_total_stock_accounting_report_view
-- Source: dba.PowerBI_Caja_Total_Stock_Accounting_Report_View
-- Passthrough summary on top of powerbi_caja_total_stock_accounting_report_0_level_1.
--
-- SAP → PostgreSQL translations:
--   Comma-join of level_1 view + params → explicit CROSS JOIN public.params.
--   GROUP BY alias refs → source column expressions
--     (PostgreSQL does not allow SELECT aliases in GROUP BY).
--   ORDER BY alias refs → source column expressions.
--   dba.PowerBI_Caja_Total_Stock_Accounting_Report_0_Level_1
--     → public.powerbi_caja_total_stock_accounting_report_0_level_1.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_caja_total_stock_accounting_report_view AS

SELECT
    v.accdetail_contno                                                      AS contract_number,
    v.accdetail_split                                                       AS contract_split,
    v.company                                                               AS contract_company,
    v.commodity                                                             AS contract_commodity,
    v.commodtype                                                            AS contract_commod_type,
    v.quality                                                               AS contract_quality,
    v.contdate                                                              AS contract_date,
    SUM(v.quantity_tonnage)                                                 AS contract_quantity_tonnage,
    SUM(v.base_amount)                                                      AS contract_accounting_balance,
    p.base_currency
FROM public.powerbi_caja_total_stock_accounting_report_0_level_1 v
CROSS JOIN public.params p
WHERE v.accdetail_contno NOT LIKE '8%'
GROUP BY
    v.accdetail_contno,
    v.accdetail_split,
    v.company,
    v.commodity,
    v.commodtype,
    v.quality,
    v.contdate,
    p.base_currency
ORDER BY
    v.accdetail_contno,
    v.accdetail_split;
