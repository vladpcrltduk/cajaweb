-- ============================================================
-- term_hedge_breakdown
-- Source: dba.term_hedge_breakdown
--
-- SAP → PostgreSQL translations:
--   Old Sybase outer-join notation in WHERE:
--     b.termdate =* a.contdate  ('=*' preserves right table term_view a)
--     b.termseqno =* a.seqno
--     → LEFT JOIN terminal_hedges b ON b.termdate=a.contdate AND b.termseqno=a.seqno.
--   Alias chain resolved via sequential CROSS JOIN LATERALs:
--     lq1: hedgedqty_mktunit = sp_convert_qty(b.quantity, b.quantunit, a.mktunit).
--     lq2: better_hedgedqty_mktunit = CASE WHEN a.plots IS NULL THEN lq1.*-1 ELSE lq1.*.
--     hedged_lots = lq2.better_hedgedqty_mktunit / a.lotfactor in outer SELECT.
--   IF a.plots IS NULL THEN ... ENDIF → CASE WHEN ... END.
--   sp_convert_qty → public.sp_convert_qty.
--   Schema prefix "dba." removed (all objects in public schema).
-- ============================================================

CREATE OR REPLACE VIEW public.term_hedge_breakdown AS

SELECT
    a.contdate,
    a.seqno,
    a.contno                                                               AS termcontno,
    b.contno,
    b.split,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tradetype,
    a.series,
    a.tprice,
    a.lots,
    a.lotfactor,
    a.hedgeable,
    a.mktcurr,
    b.quantity                                                             AS hedgedqty,
    b.quantunit,
    lq1.hedgedqty_mktunit,
    lq2.better_hedgedqty_mktunit,
    lq2.better_hedgedqty_mktunit / a.lotfactor                            AS hedged_lots,
    a.mktunit
FROM public.term_view a
LEFT JOIN public.terminal_hedges b
    ON  b.termdate  = a.contdate
    AND b.termseqno = a.seqno
CROSS JOIN LATERAL (
    SELECT public.sp_convert_qty(b.quantity, b.quantunit, a.mktunit)      AS hedgedqty_mktunit
) AS lq1
CROSS JOIN LATERAL (
    SELECT CASE WHEN a.plots IS NULL
                THEN lq1.hedgedqty_mktunit * -1
                ELSE lq1.hedgedqty_mktunit
           END                                                             AS better_hedgedqty_mktunit
) AS lq2
WHERE a.hedge    = 'Y'
  AND a.tradetype = 'F';
