-- ============================================================
-- terminal_lots_view_option
-- Source: dba.terminal_lots_view_option
-- Same structure as terminal_lots_view (0072) but for options:
--   tradetype IN ('C','P') instead of 'F'.
--   Adds terminal.series column after tprice.
--   Commented-out (plots>0 OR slots>0) filter not applied.
-- No alias deps.
--
-- SAP → PostgreSQL translations: identical to 0072.
--   left(x,n) → LEFT(x::text, n); '+' concat → '||'.
--   ifnull(plots, slots*-1, plots) (3-arg) → CASE WHEN ... END.
--   ifnull(plots, 'S', 'P')       (3-arg) → CASE WHEN ... END.
--   sp_curr_* / sp_prompt_month   → public.* prefix.
--   Comma-joins → explicit JOINs; ORDER BY retained.
-- ============================================================

CREATE OR REPLACE VIEW public.terminal_lots_view_option AS

SELECT
    t.company,
    t.futconts                                                             AS market,
    t.commodity,
    t.contdate,
    t.seqno,
    t.broker,
    cl.name                                                                AS broker_name,
    t.prompt,
    t.physref,
    public.sp_prompt_month(t.prompt)                                      AS prompt_string,
    LEFT(t.prompt::text, 6) || ' (' || public.sp_prompt_month(t.prompt) || ')' AS month,
    CAST(CASE WHEN t.plots IS NULL THEN t.slots * -1 ELSE t.plots END AS integer) AS lots,
    t.tprice,
    t.series,
    t.sub_account                                                          AS broker_account,
    t.terminaltype                                                         AS sub_account2,
    public.sp_curr_getunderlying(tv.mktcurr)                              AS currency,
    public.sp_curr_cvtunderlying(tv.varmarg, tv.mktcurr)                  AS pnl,
    CASE WHEN t.plots IS NULL THEN 'S' ELSE 'P' END                       AS ps,
    t.tradetype
FROM public.terminal t
JOIN public.client cl
    ON cl.code = t.broker
JOIN public.term_view tv
    ON  tv.contdate = t.contdate
    AND tv.seqno    = t.seqno
WHERE t.tradetype IN ('C', 'P')
ORDER BY t.contdate,
         t.seqno;
