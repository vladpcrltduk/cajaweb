-- ============================================================
-- term_hedged_view
-- Source: dba.term_hedged_view
--
-- SAP → PostgreSQL translations:
--   Alias dep: hedged (correlated subquery) referenced in unhedged.
--     Resolved via CROSS JOIN LATERAL; COALESCE(SUM(...),0) absorbs the
--     ifnull(hedged,0,hedged) (3-arg: if null → 0, else → hedged = COALESCE).
--     unhedged = a.hedgeable - lq1.hedged in outer SELECT.
--   Schema prefix dba. removed; comma-join → explicit WHERE-style remains as
--     LATERAL correlated subquery references a.contdate / a.seqno directly.
--   term_hedged_quant_view → public.term_hedged_quant_view.
--   term_view → public.term_view.
-- ============================================================

CREATE OR REPLACE VIEW public.term_hedged_view AS

SELECT
    a.contdate,
    a.seqno,
    a.contno,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tradetype,
    a.series,
    a.tprice,
    a.lots,
    a.hedgeable,
    a.mktcurr,
    a.mktunit,
    lq1.hedged,
    a.hedgeable - lq1.hedged                                              AS unhedged
FROM public.term_view a
CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(h.hedged_qty), 0) AS hedged
    FROM public.term_hedged_quant_view h
    WHERE h.termdate  = a.contdate
      AND h.termseqno = a.seqno
) AS lq1
WHERE a.hedge    = 'Y'
  AND a.tradetype <> 'X';
