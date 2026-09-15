-- ============================================================
-- overall_contract_view
-- Source: dba.overall_contract_view
-- 2-branch UNION ALL: physical trading lines + reserve lines.
-- Both branches filter phys_pricing.status = 'FORWARD'.
-- Branch 1 alias dep: base_openqnt (computed) referenced in sp_calc_value_phys arg.
--   Resolved via CROSS JOIN LATERAL; bq.base_openqnt used in line_value and as output column.
-- Branch 2: base_openqnt = 0 hardcoded; sp_calc_value_phys 'P' case inlines 0 directly.
-- SAP string concat '+' → '||'; string(x) → x::text; IF(...) → CASE WHEN.
-- CASE reserves.amountind WHEN ... preserved as-is.
-- ============================================================

CREATE OR REPLACE VIEW public.overall_contract_view AS

-- Branch 1: Physical trading lines
SELECT
    phys_pricing.contno,
    phys_pricing.split,
    phys_pricing.contno || phys_pricing.split                           AS ref,
    CASE WHEN phys_pricing.contract_type = 'P'
         THEN 'Physical Purchase Trade'
         ELSE 'Physical Sales Trade'
    END                                                                  AS type_flag,
    1                                                                    AS order_flag,
    public.sp_pricestr(
        phys_pricing.price_fixing, phys_pricing.unitprice, phys_pricing.currency,
        phys_pricing.priceunit, phys_pricing.pfcontract, phys_pricing.pfposition,
        phys_pricing.pfdifftype, phys_pricing.pfdiffer, phys_pricing.pfdiffcurr,
        phys_pricing.pfdiffunit)                                         AS price_string,
    public.sp_calc_value_phys(
        phys_pricing.contno, phys_pricing.split, bq.base_openqnt, params.base_unit,
        phys_pricing.price_fixing, phys_pricing.unitprice, phys_pricing.currency,
        phys_pricing.priceunit, phys_pricing.pfcontract, phys_pricing.pfposition,
        phys_pricing.pfdifftype, phys_pricing.pfdiffer, phys_pricing.pfdiffcurr,
        phys_pricing.pfdiffunit, params.base_currency, params.systemdate) AS line_value,
    bq.base_openqnt,
    params.base_unit,
    params.base_currency
FROM public.phys_pricing
CROSS JOIN public.params
CROSS JOIN LATERAL (
    SELECT public.sp_convert_qty(phys_pricing.openqnt, phys_pricing.quantunit, params.base_unit)
           * CASE WHEN phys_pricing.contract_type = 'P' THEN 1 ELSE -1 END AS base_openqnt
) AS bq
WHERE phys_pricing.status = 'FORWARD'

UNION ALL

-- Branch 2: Reserve lines
-- base_openqnt = 0; sp_calc_value_phys 'P' case inlines 0 as the base_openqnt argument.
SELECT
    phys_pricing.contno,
    phys_pricing.split,
    phys_pricing.contno || phys_pricing.split || reserves.charges_line::text AS ref,
    'Reserve'                                                            AS type_flag,
    2                                                                    AS order_flag,
    CASE reserves.amountind
        WHEN 'A' THEN reserves.reserve || ' @ ' || reserves.amount::text || ' ' || reserves.currency
        WHEN 'R' THEN reserves.reserve || ' @ ' || reserves.amount::text || ' ' || reserves.currency || ' per ' || reserves.unit
        WHEN 'P' THEN reserves.reserve || ' @ ' || reserves.amount::text || '% of contract value'
    END                                                                  AS price_string,
    CASE reserves.amountind
        WHEN 'A' THEN
            reserves.amount * public.sp_firstopenhouserate(reserves.currency, params.base_currency)
        WHEN 'R' THEN
            public.sp_convert_qty(phys_pricing.original, phys_pricing.quantunit, reserves.unit)
            * reserves.amount
            * public.sp_firstopenhouserate(reserves.currency, params.base_currency)
        WHEN 'P' THEN
            public.sp_calc_value_phys(
                phys_pricing.contno, phys_pricing.split, 0, params.base_unit,
                phys_pricing.price_fixing, phys_pricing.unitprice, phys_pricing.currency,
                phys_pricing.priceunit, phys_pricing.pfcontract, phys_pricing.pfposition,
                phys_pricing.pfdifftype, phys_pricing.pfdiffer, phys_pricing.pfdiffcurr,
                phys_pricing.pfdiffunit, params.base_currency, params.systemdate)
            * reserves.amount / 100
    END                                                                  AS line_value,
    0                                                                    AS base_openqnt,
    params.base_unit,
    params.base_currency
FROM public.phys_pricing
JOIN public.reserves
    ON  reserves.contno = phys_pricing.contno
    AND reserves.split  = phys_pricing.split
CROSS JOIN public.params
WHERE phys_pricing.status = 'FORWARD';
