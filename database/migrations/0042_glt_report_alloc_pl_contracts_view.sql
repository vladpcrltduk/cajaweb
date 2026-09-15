-- ============================================================
-- glt_report_alloc_pl_contracts_view
-- Source: dba.GLT_Report_Alloc_PL_Contracts_view
-- Distinct list of contno values from glt_report_alloc_pl_view.
-- MIN(contno) GROUP BY contno produces one row per contno.
-- ============================================================

CREATE OR REPLACE VIEW public.glt_report_alloc_pl_contracts_view AS

SELECT
    MIN(glt_report_alloc_pl_view.contno) AS contno
FROM public.glt_report_alloc_pl_view
GROUP BY glt_report_alloc_pl_view.contno
ORDER BY glt_report_alloc_pl_view.contno;
