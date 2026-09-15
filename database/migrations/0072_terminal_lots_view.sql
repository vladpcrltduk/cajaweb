-- ============================================================
-- terminal_lots_view
-- Source: dba.terminal_lots_view
-- No alias deps.
--
-- SAP → PostgreSQL translations:
--   left(x,n)                 → LEFT(x::text, n).
--   '+' string concat          → '||'.
--   ifnull(plots, slots*-1, plots)   (3-arg: null→slots*-1, else→plots)
--     → CASE WHEN terminal.plots IS NULL THEN terminal.slots * -1 ELSE terminal.plots END.
--   ifnull(plots, 'S', 'P')   (3-arg: null→'S', else→'P')
--     → CASE WHEN terminal.plots IS NULL THEN 'S' ELSE 'P' END.
--   sp_curr_getunderlying / sp_curr_cvtunderlying / sp_prompt_month → public.* prefix.
--   Comma-joins → explicit JOINs.
--   ORDER BY retained.
-- ============================================================

CREATE OR REPLACE VIEW public.terminal_lots_view AS

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
WHERE t.tradetype = 'F'
  AND (t.plots > 0 OR t.slots > 0)
ORDER BY t.contdate,
         t.seqno;
