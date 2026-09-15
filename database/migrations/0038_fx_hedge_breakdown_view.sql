-- ============================================================
-- fx_hedge_breakdown
-- Source: dba.fx_hedge_breakdown
-- Joins term_view (a) to forex_hedges (b) for hedged FX deals.
-- SAP =* operator: b.termdate=*a.contdate → a is the preserved
-- (outer) table → a LEFT OUTER JOIN b.
-- Comma-join with =* conditions → explicit LEFT OUTER JOIN.
-- ============================================================

CREATE OR REPLACE VIEW public.fx_hedge_breakdown AS

SELECT
    a.contdate,
    a.seqno,
    a.contno                    AS termcontno,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tprice,
    a.lots,
    a.hedgeable,
    a.mktcurr,
    a.othercurr,
    a.dealratetype,
    b.contno,
    b.split,
    b.quantity                  AS hedged_qty
FROM public.term_view a
LEFT OUTER JOIN public.forex_hedges b
    ON b.termdate  = a.contdate
   AND b.termseqno = a.seqno
WHERE a.hedge     = 'Y'
  AND a.tradetype = 'X';
