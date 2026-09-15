-- ============================================================
-- powerbi_caja_unfixed_position
-- Source: dba.PowerBI_Caja_Unfixed_Position
--
-- SAP → PostgreSQL translations:
--   Alias deps resolved via one CROSS JOIN LATERAL (all independent):
--     lq1.fixed_quantity  = COALESCE(SUM phys_fixes, 0) — used in fixed_quantity_mt,
--                           unfixed_quantity, unfixed_mt, and WHERE Unfixed_Quantity <> 0.
--     lq1.fixed_lots      = COALESCE(SUM fixes.lots, 0) — used in unfixed_lots.
--     lq1.market_month_eng = sp_prompt_month(pfposition) — used in price_fix_differential.
--   Unfixed_Quantity <> 0 in WHERE → (sc.orgunquant - lq1.fixed_quantity) <> 0.
--   isnull(x,0)   → COALESCE(x,0).
--   string(x)     → x::text.
--   '+' concat    → '||'.
--   SAP uppercase col names (SHIPMENT, PFPOSITION, etc.) → lowercase in PostgreSQL.
--   Comma-joins → explicit JOINs; params → CROSS JOIN.
--   ORDER BY retained (faithful to source).
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_caja_unfixed_position AS

SELECT
    mc.commodtype                                                                     AS commod_type,
    mc.company,
    sc.contno                                                                         AS contract_no,
    sc.split,
    sc.client                                                                         AS contract_client,
    cl.country                                                                        AS client_country,
    mc.contract_type,
    mc.contdate                                                                       AS contract_date,
    public.sp_shipment_desc(sc.shipment, sc.shipordelv)                              AS shipment_period,
    sc.pfcontract                                                                     AS market,
    sc.pfposition                                                                     AS market_month,
    lq1.market_month_eng,
    '(' || sc.pfoption || ') ' || sc.pfcontract || ' / ' || lq1.market_month_eng
        || ' ' || sc.pfdifftype || ' ' || sc.pfdiffer::text                          AS price_fix_differential,
    sc.fixbydate                                                                      AS fix_by_date,
    sc.orgunquant                                                                     AS contract_quantity,
    sc.quantunit                                                                      AS contract_unit,
    public.sp_convert_qty(sc.orgunquant, sc.quantunit, p.base_unit)                 AS contract_quantity_mt,
    lq1.fixed_quantity,
    public.sp_convert_qty(lq1.fixed_quantity, sc.quantunit, p.base_unit)            AS fixed_quantity_mt,
    lq1.fixed_lots,
    sc.orgunquant - lq1.fixed_quantity                                               AS unfixed_quantity,
    public.sp_convert_qty(sc.orgunquant - lq1.fixed_quantity, sc.quantunit, p.base_unit) AS unfixed_mt,
    sc.pflots - lq1.fixed_lots                                                       AS unfixed_lots,
    sc.origin,
    sc.quality,
    p.base_unit
FROM public.master_contracts mc
JOIN public.sub_contracts sc
    ON sc.contno = mc.contno
JOIN public.client cl
    ON cl.code = sc.client
CROSS JOIN public.params p
CROSS JOIN LATERAL (
    SELECT
        COALESCE(
            (SELECT SUM(pf.fixed_qty)
             FROM public.phys_fixes pf
             WHERE pf.contno = sc.contno
               AND pf.split  = sc.split),
            0)                                                                        AS fixed_quantity,
        COALESCE(
            (SELECT SUM(f.lots)
             FROM public.fixes f
             WHERE f.contno = sc.contno
               AND f.split  = sc.split),
            0)                                                                        AS fixed_lots,
        public.sp_prompt_month(sc.pfposition)                                        AS market_month_eng
) AS lq1
WHERE sc.price_fixing = 'Y'
  AND (sc.orgunquant - lq1.fixed_quantity) <> 0
ORDER BY mc.commodtype ASC,
         sc.pfposition ASC,
         sc.pfcontract ASC,
         mc.contract_type ASC,
         sc.contno ASC,
         sc.split ASC;
