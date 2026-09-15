-- ============================================================
-- phys_valn_view_open_and_unfixed
-- Source: dba.phys_valn_view_open_and_unfixed
-- 2-branch UNION: open/unfixed physical positions (phys_valn_view) +
--                 closed-but-unfixed allocations (allocations_closed_but_unfixed).
-- Uses CTEs b1/b2 for readability; each branch resolves its alias chain via
-- sequential CROSS JOIN LATERALs.
--
-- Branch 1 alias deps:
--   lq1: unit_to_mt_conversation_factor, currency_to_basecurr_conversion_factor,
--         costs_per_base_unit, valuation_price_basecurr_mt   (all independent)
--   lq2: unit_price_basecurr_mt   (uses lq1)
--   lq3: final_price_basecurr_mt  (uses lq1, lq2)
--   lq4: valn_result              (uses lq1, lq3)
--   params added as CROSS JOIN (replaces 3 scalar subqueries at end of SELECT).
--
-- Branch 2 alias deps:
--   lq1: openqnt, fixed_unfixed_flag, status
--   lq2: base_openqnt, unit_to_mt_conversation_factor,
--         currency_to_basecurr_conversion_factor, temporary_price
--   lq3: unit_price_basecurr_mt, phys_value, valn_value
--   lq4: phys_pandl, resvs_pandl
--   lq5: costs_per_base_unit
--   lq6: final_price_basecurr_mt, valuation_price_basecurr_mt
--   lq7: valn_result
--
-- today() → CURRENT_DATE.
-- SAP IF → CASE WHEN; IF F THEN 'N' ELSE 'Y' → CASE WHEN valn_type='F' THEN 'N' ELSE 'Y' END.
-- Original UNION (not UNION ALL) preserved — cross-branch dedup intentional.
-- ============================================================

CREATE OR REPLACE VIEW public.phys_valn_view_open_and_unfixed AS

WITH b1 AS (
    SELECT
        pvv.company,
        pvv.pcentre,
        pvv.commodity,
        c.longname                                                       AS commodity_longname,
        pvv.commodtype,
        ct.longname                                                      AS commodtype_longname,
        pvv.origin,
        pvv.quality,
        q.name                                                           AS quality_name,
        pvv.valuedin,
        pvv.valuedin_str,
        pvv.contdate,
        pvv.contract_type,
        pvv.contno,
        pvv.split,
        pvv.client,
        pvv.price_fixing,
        pvv.priceterm,
        pvv.prcst_location,
        pvv.shipfrom,
        pvv.shipto,
        TO_CHAR(pvv.shipfrom, 'MM/YY') || '-' || TO_CHAR(pvv.shipto, 'MM/YY') AS ship_period,
        pvv.openqnt,
        pvv.quantunit,
        pvv.status,
        pvv.flag,
        pvv.fixed_unfixed_flag,
        pvv.base_openqnt,
        pvv.sysbaseunit,
        pvv.unitprice,
        pvv.currency,
        pvv.priceunit,
        lq1.unit_to_mt_conversation_factor,
        lq1.currency_to_basecurr_conversion_factor,
        NULL                                                             AS temporary_price,
        lq2.unit_price_basecurr_mt,
        lq1.costs_per_base_unit,
        lq3.final_price_basecurr_mt,
        lq1.valuation_price_basecurr_mt,
        lq4.valn_result,
        pvv.price_string,
        pvv.valn_string,
        pvv.phys_value,
        pvv.valn_value,
        pvv.phys_pandl,
        pvv.term_pandl,
        pvv.fx_pandl,
        pvv.resvs_pandl,
        pvv.net_pandl,
        CASE WHEN pvv.ct_valn_type = 'M' THEN 'M' ELSE '' END          AS valuation_type,
        pvv.cddifftype,
        pvv.cddiffer,
        pvv.original_pfdifftype,
        pvv.original_pfdiffer,
        p.base_unit,
        p.base_currency,
        p.systemdate
    FROM public.phys_valn_view pvv
    JOIN public.commodity_type ct ON ct.code = pvv.commodtype
    JOIN public.commodity c       ON c.code  = pvv.commodity
    JOIN public.quality q         ON q.code  = pvv.quality
    CROSS JOIN public.params p
    CROSS JOIN LATERAL (
        SELECT
            CASE WHEN p.base_currency = 'GBP'
                 THEN public.sp_convert_qty(1, pvv.quantunit, p.base_unit)
                 ELSE 1.0 / public.sp_convert_qty(1, pvv.priceunit, p.base_unit)
            END                                                          AS unit_to_mt_conversation_factor,
            CASE WHEN public.sp_curr_getunderlying(pvv.currency) = p.base_currency
                 THEN public.sp_datedfxrate(pvv.currency, p.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_FX_rate(pvv.contno, pvv.split)
            END                                                          AS currency_to_basecurr_conversion_factor,
            CASE WHEN pvv.contract_type = 'P'
                 THEN pvv.resvs_pandl / pvv.base_openqnt
                 ELSE (pvv.resvs_pandl / pvv.base_openqnt) * -1
            END                                                          AS costs_per_base_unit,
            pvv.valn_value / pvv.base_openqnt                           AS valuation_price_basecurr_mt
    ) AS lq1
    CROSS JOIN LATERAL (
        SELECT pvv.unitprice * lq1.unit_to_mt_conversation_factor * lq1.currency_to_basecurr_conversion_factor AS unit_price_basecurr_mt
    ) AS lq2
    CROSS JOIN LATERAL (
        SELECT
            CASE WHEN lq2.unit_price_basecurr_mt IS NOT NULL
                 THEN lq2.unit_price_basecurr_mt + lq1.costs_per_base_unit
                 ELSE (pvv.phys_value / pvv.base_openqnt) + lq1.costs_per_base_unit
            END                                                          AS final_price_basecurr_mt
    ) AS lq3
    CROSS JOIN LATERAL (
        SELECT (lq1.valuation_price_basecurr_mt - lq3.final_price_basecurr_mt) * pvv.base_openqnt AS valn_result
    ) AS lq4
    WHERE pvv.unfixed_unallocated_flag <> 'FFFA'
      AND pvv.openqnt > 0
),

b2 AS (
    SELECT
        mc.company,
        mc.pcentre,
        mc.commodity,
        c.longname                                                       AS commodity_longname,
        mc.commodtype,
        ct.longname                                                      AS commodtype_longname,
        mc.origin,
        sc.quality,
        q.name                                                           AS quality_name,
        sc.valuedin,
        public.sp_prompt_month(sc.valuedin)                              AS valuedin_str,
        mc.contdate,
        mc.contract_type,
        sc.contno,
        sc.split,
        sc.client,
        sc.price_fixing,
        mc.priceterm,
        mc.prcstlocn                                                     AS prcst_location,
        sc.shipfrom,
        sc.shipto,
        TO_CHAR(sc.shipfrom, 'MM/YY') || '-' || TO_CHAR(sc.shipto, 'MM/YY') AS ship_period,
        lq1.openqnt,
        sc.quantunit,
        lq1.status,
        acbu.closed_fixed_unfixed_flag                                   AS flag,
        lq1.fixed_unfixed_flag,
        lq2.base_openqnt,
        p.base_unit                                                      AS sysbaseunit,
        NULL                                                             AS unitprice,
        sc.currency,
        sc.priceunit,
        lq2.unit_to_mt_conversation_factor,
        lq2.currency_to_basecurr_conversion_factor,
        lq2.temporary_price,
        lq3.unit_price_basecurr_mt,
        lq5.costs_per_base_unit,
        lq6.final_price_basecurr_mt,
        lq6.valuation_price_basecurr_mt,
        lq7.valn_result,
        public.sp_pricestr(sc.price_fixing, sc.unitprice, sc.currency, sc.priceunit,
            sc.pfcontract, sc.pfposition, sc.pfdifftype, sc.pfdiffer,
            sc.pfdiffcurr, sc.pfdiffunit)                               AS price_string,
        CASE WHEN sc.valn_type = 'P'
             THEN public.sp_pricestr_MMYY(
                      CASE WHEN vd.valn_type = 'F' THEN 'N' ELSE 'Y' END,
                      vd.valn_price, vd.valn_curr, vd.valn_unit,
                      vd.vlcontract, vd.vlposition, vd.vldifftype,
                      vd.vldiffer, vd.vldiffcurr, vd.vldiffunit)
             ELSE public.sp_pricestr_MMYY(
                      CASE WHEN sc.valn_type = 'F' THEN 'N' ELSE 'Y' END,
                      sc.valn_price, sc.valn_curr, sc.valn_unit,
                      sc.vlcontract, sc.vlposition, sc.vldifftype,
                      sc.vldiffer, sc.vldiffcurr, sc.vldiffunit)
        END                                                              AS valn_string,
        lq3.phys_value,
        lq3.valn_value,
        lq4.phys_pandl,
        0                                                                AS term_pandl,
        0                                                                AS fx_pandl,
        lq4.resvs_pandl,
        lq4.phys_pandl + lq4.resvs_pandl                               AS net_pandl,
        CASE WHEN sc.valn_type = 'M' THEN 'M' ELSE '' END              AS valuation_type,
        sc.cddifftype,
        sc.cddiffer,
        sc.pfdifftype                                                    AS original_pfdifftype,
        sc.pfdiffer                                                      AS original_pfdiffer,
        p.base_unit,
        p.base_currency,
        p.systemdate
    FROM public.allocations_closed_but_unfixed acbu
    JOIN public.sub_contracts sc
        ON  sc.contno = acbu.contno
        AND sc.split  = acbu.split
    JOIN public.master_contracts mc
        ON mc.contno = sc.contno
    JOIN public.phys_avail pa
        ON  pa.contno = sc.contno
        AND pa.split  = sc.split
    JOIN public.val_differentials vd
        ON  vd.company    = mc.company
        AND vd.pcentre    = mc.pcentre
        AND vd.commodity  = mc.commodity
        AND vd.commodtype = mc.commodtype
        AND vd.origin     = sc.origin
        AND vd.quality    = sc.quality
        AND vd.valuedin   = sc.valuedin
    JOIN public.commodity_type ct ON ct.code = mc.commodtype
    JOIN public.commodity c       ON c.code  = mc.commodity
    JOIN public.quality q         ON q.code  = sc.quality
    CROSS JOIN public.params p
    CROSS JOIN LATERAL (
        SELECT
            CASE WHEN mc.contract_type = 'P' THEN acbu.openqnt ELSE acbu.openqnt * -1 END AS openqnt,
            CASE WHEN acbu.closed_fixed_unfixed_flag = 'CLOSED_UNFIXED' THEN 'Unpriced' ELSE 'Priced' END AS fixed_unfixed_flag,
            CASE WHEN acbu.closed_fixed_unfixed_flag = 'CLOSED_UNFIXED' THEN 'UNFIXED' ELSE 'FIXED' END AS status
    ) AS lq1
    CROSS JOIN LATERAL (
        SELECT
            public.sp_convert_qty(lq1.openqnt, sc.quantunit, 'MT')      AS base_openqnt,
            CASE WHEN p.base_currency = 'GBP'
                 THEN public.sp_convert_qty(1, sc.quantunit, p.base_unit)
                 ELSE 1.0 / public.sp_convert_qty(1, sc.priceunit, p.base_unit)
            END                                                          AS unit_to_mt_conversation_factor,
            CASE WHEN public.sp_curr_getunderlying(sc.currency) = p.base_currency
                 THEN public.sp_datedfxrate(sc.currency, p.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_FX_rate(sc.contno, sc.split)
            END                                                          AS currency_to_basecurr_conversion_factor,
            CASE WHEN sc.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sc.contno, sc.split)
                 ELSE sc.unitprice
            END                                                          AS temporary_price
    ) AS lq2
    CROSS JOIN LATERAL (
        SELECT
            CASE WHEN lq1.fixed_unfixed_flag = 'Priced'
                 THEN lq2.temporary_price * lq2.unit_to_mt_conversation_factor * lq2.currency_to_basecurr_conversion_factor
                 ELSE NULL
            END                                                          AS unit_price_basecurr_mt,
            public.sp_calc_value(ABS(lq1.openqnt), sc.quantunit, sc.price_fixing,
                sc.unitprice, sc.currency, sc.priceunit,
                sc.pfcontract, sc.pfposition, sc.pfdifftype,
                sc.pfdiffer, sc.pfdiffcurr, sc.pfdiffunit,
                p.base_currency, p.systemdate)
            * CASE WHEN mc.contract_type = 'P' THEN 1 ELSE -1 END      AS phys_value,
            CASE WHEN sc.valn_type = 'P'
                 THEN public.sp_calc_value(ABS(lq1.openqnt), sc.quantunit,
                          CASE WHEN vd.valn_type = 'F' THEN 'N' ELSE 'Y' END,
                          vd.valn_price, vd.valn_curr, vd.valn_unit,
                          vd.vlcontract, vd.vlposition, vd.vldifftype,
                          vd.vldiffer, vd.vldiffcurr, vd.vldiffunit,
                          p.base_currency, p.systemdate)
                 ELSE public.sp_calc_value(ABS(lq1.openqnt), sc.quantunit,
                          CASE WHEN sc.valn_type = 'F' THEN 'N' ELSE 'Y' END,
                          sc.valn_price, sc.valn_curr, sc.valn_unit,
                          sc.vlcontract, sc.vlposition, sc.vldifftype,
                          sc.vldiffer, sc.vldiffcurr, sc.vldiffunit,
                          p.base_currency, p.systemdate)
            END
            * CASE WHEN mc.contract_type = 'P' THEN 1 ELSE -1 END      AS valn_value
    ) AS lq3
    CROSS JOIN LATERAL (
        SELECT
            lq3.valn_value - lq3.phys_value                             AS phys_pandl,
            public.sp_phys_valn_resvs(
                sc.contno, sc.split,
                public.sp_convert_qty(ABS(lq1.openqnt), sc.quantunit, p.base_unit),
                p.base_unit,
                public.sp_convert_qty(sc.orgunquant, sc.quantunit, p.base_unit),
                public.sp_calc_value(ABS(lq1.openqnt), sc.quantunit, sc.price_fixing,
                    sc.unitprice, sc.currency, sc.priceunit,
                    sc.pfcontract, sc.pfposition, sc.pfdifftype,
                    sc.pfdiffer, sc.pfdiffcurr, sc.pfdiffunit,
                    p.base_currency, p.systemdate),
                p.base_currency, p.systemdate)                          AS resvs_pandl
    ) AS lq4
    CROSS JOIN LATERAL (
        SELECT
            CASE WHEN mc.contract_type = 'P'
                 THEN lq4.resvs_pandl / lq2.base_openqnt
                 ELSE (lq4.resvs_pandl / lq2.base_openqnt) * -1
            END                                                          AS costs_per_base_unit
    ) AS lq5
    CROSS JOIN LATERAL (
        SELECT
            CASE WHEN lq3.unit_price_basecurr_mt IS NOT NULL
                 THEN lq3.unit_price_basecurr_mt + lq5.costs_per_base_unit
                 ELSE (lq3.phys_value / lq2.base_openqnt) + lq5.costs_per_base_unit
            END                                                          AS final_price_basecurr_mt,
            lq3.valn_value / lq2.base_openqnt                           AS valuation_price_basecurr_mt
    ) AS lq6
    CROSS JOIN LATERAL (
        SELECT (lq6.valuation_price_basecurr_mt - lq6.final_price_basecurr_mt) * lq2.base_openqnt AS valn_result
    ) AS lq7
)

SELECT * FROM b1
UNION
SELECT * FROM b2;
