-- ============================================================
-- terminal_hedged_view
-- Source: dba.terminal_hedged_view
--
-- SAP → PostgreSQL translations:
--   Alias dep chain resolved via one CROSS JOIN LATERAL:
--     lq1.hedged            = COALESCE(SUM(terminal_hedges.quantity), 0)
--     lq1.hedged_in_mkt_unit= COALESCE(SUM(term_hedged_quant_view.hedged_qty), 0)
--   Outer SELECT derives:
--     unhedged          = a.hedgeable - lq1.hedged
--     unhedged_in_mkt_unit = a.hedgeable - lq1.hedged_in_mkt_unit
--     unhedged_lots     = ROUND(unhedged_in_mkt_unit / a.lotfactor, 0)  (inlined)
--   ifnull(x,0,x) (3-arg: null→0, else→x) → COALESCE(x,0) absorbed into lq1.
--   tradetype = 'F' OR 'P' OR 'C' → tradetype IN ('F','P','C').
--   sp_termcontno → public.sp_termcontno.
--   Schema prefix dba. removed.
-- ============================================================

CREATE OR REPLACE VIEW public.terminal_hedged_view AS

SELECT
    a.contdate,
    a.seqno,
    a.contno,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tradetype,
    a.tprice,
    public.sp_termcontno(a.contdate, a.seqno)                            AS longcontno,
    a.mktunit                                                              AS unit,
    a.mktcurr                                                              AS currency,
    a.broker,
    a.bankref,
    a.physref,
    a.sub_account,
    a.counterparty,
    a.lots,
    a.plots,
    a.slots,
    a.series,
    a.hedgeable,
    a.dealratetype,
    lq1.hedged,
    a.hedgeable - lq1.hedged                                              AS unhedged,
    lq1.hedged_in_mkt_unit,
    a.hedgeable - lq1.hedged_in_mkt_unit                                  AS unhedged_in_mkt_unit,
    ROUND((a.hedgeable - lq1.hedged_in_mkt_unit) / a.lotfactor, 0)       AS unhedged_lots
FROM public.term_view a
CROSS JOIN LATERAL (
    SELECT
        COALESCE(
            (SELECT SUM(b.quantity)
             FROM public.terminal_hedges b
             WHERE b.termdate  = a.contdate
               AND b.termseqno = a.seqno),
            0)                                                             AS hedged,
        COALESCE(
            (SELECT SUM(h.hedged_qty)
             FROM public.term_hedged_quant_view h
             WHERE h.termdate  = a.contdate
               AND h.termseqno = a.seqno),
            0)                                                             AS hedged_in_mkt_unit
) AS lq1
WHERE a.hedge    = 'Y'
  AND a.tradetype IN ('F', 'P', 'C');
