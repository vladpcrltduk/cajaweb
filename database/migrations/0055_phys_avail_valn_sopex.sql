-- ============================================================
-- phys_avail_valn_sopex
-- Source: dba.phys_avail_valn_sopex
-- Stripped-down version of phys_avail for Sopex Valuation Report.
-- openqnt = orgunquant (alias 'original' inlined directly).
-- Alias chain resolved via two sequential CROSS JOIN LATERALs:
--   fx1: computes 'fixed' (correlated SUM subquery) once.
--   fx2: computes 'unfixed' (CASE on price_fixing using fx1.fixed).
--   Outer SELECT uses fx1.fixed and fx2.unfixed for fixed_base and unfixed_base.
-- isnull(subquery, 0) → COALESCE(subquery, 0::numeric(16,4)).
-- cast(0 as numeric(16,4)) → 0::numeric(16,4).
-- IF...THEN...ELSE...ENDIF → CASE WHEN...THEN...ELSE...END.
-- ============================================================

CREATE OR REPLACE VIEW public.phys_avail_valn_sopex AS

SELECT
    a.contno,
    a.split,
    b.contract_type,
    a.orgunquant                                                         AS original,
    a.quantunit,
    a.orgunquant                                                         AS openqnt,
    a.price_fixing,
    fx1.fixed,
    fx2.unfixed,
    public.sp_convert_qty(fx1.fixed,   a.quantunit, params.base_unit)   AS fixed_base,
    public.sp_convert_qty(fx2.unfixed, a.quantunit, params.base_unit)   AS unfixed_base
FROM public.sub_contracts AS a
JOIN public.master_contracts AS b
    ON b.contno = a.contno
CROSS JOIN public.params
CROSS JOIN LATERAL (
    SELECT COALESCE(
        (SELECT SUM(f.fixed_qty)
         FROM public.phys_fixes AS f
         WHERE f.contno = a.contno
           AND f.split  = a.split),
        0::numeric(16,4)) AS fixed
) AS fx1
CROSS JOIN LATERAL (
    SELECT CASE WHEN a.price_fixing = 'Y'
                THEN a.orgunquant - fx1.fixed
                ELSE 0::numeric(16,4)
           END AS unfixed
) AS fx2;
