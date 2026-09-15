-- ============================================================
-- treasury_hedged_view
-- Source: dba.treasury_hedged_view
-- Same pattern as term_hedged_view (0070) but filters tradetype='T'
-- and aggregates from treasury_hedges instead of terminal_hedges.
--
-- SAP → PostgreSQL translations:
--   Alias dep: hedged (correlated subquery) referenced in unhedged.
--     Resolved via CROSS JOIN LATERAL; COALESCE(SUM(...),0) absorbs
--     ifnull(hedged,0,hedged) (3-arg: null→0, else→hedged).
--     unhedged = a.hedgeable - lq1.hedged in outer SELECT.
--   Schema prefix dba. removed.
-- ============================================================

CREATE OR REPLACE VIEW public.treasury_hedged_view AS

SELECT
    a.contdate,
    a.seqno,
    a.contno,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tprice,
    a.lots,
    a.hedgeable,
    a.mktcurr,
    a.othercurr,
    a.dealratetype,
    lq1.hedged,
    a.hedgeable - lq1.hedged                                              AS unhedged
FROM public.term_view a
CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(b.quantity), 0) AS hedged
    FROM public.treasury_hedges b
    WHERE b.termdate  = a.contdate
      AND b.termseqno = a.seqno
) AS lq1
WHERE a.hedge    = 'Y'
  AND a.tradetype = 'T';
