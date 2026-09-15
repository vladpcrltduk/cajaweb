-- ============================================================
-- terminal_open_position_details
-- Source: dba.terminal_open_position_details
--
-- SAP → PostgreSQL translations:
--   Alias dep chain resolved via three sequential CROSS JOIN LATERALs:
--     lq1: market_value, contract_value, commission  (all independent).
--     lq2: result_mktcurr = contract_value - market_value - commission.
--     lq3: result_base_currency (CASE on currency.ratetype, uses lq2).
--   Outer SELECT derives purchased_result_basecurr / sold_result_basecurr
--     from lq3.result_base_currency.
--   IF Trade_Type / plots / slots alias refs → direct column refs (tv.*).
--   isnull(x,0) (2-arg) → COALESCE(x,0).
--   ABS(COALESCE(commval,0)) for commission.
--   sp_curr_cvtunderlying / sp_curr_getunderlying / sp_lastopenhouserate /
--     sp_prompt_month → public.* prefix.
--   IF ... THEN ... ENDIF → CASE WHEN ... END.
--   Comma-joins → explicit JOINs; params → CROSS JOIN.
--   ORDER BY on source columns (aliases not portable in PostgreSQL ORDER BY
--     when they shadow source names — using source refs for safety).
-- ============================================================

CREATE OR REPLACE VIEW public.terminal_open_position_details AS

SELECT
    tv.futconts                                                            AS futures_market,
    fc.longname                                                            AS futures_market_longname,
    CASE WHEN tv.tradetype = 'F' THEN 'Futures' ELSE 'Options' END        AS trade_category,
    tv.tradetype                                                           AS trade_type,
    tv.company,
    tv.pcentre                                                             AS profit_centre,
    tv.broker,
    cl.longname                                                            AS broker_longname,
    tv.prompt,
    public.sp_prompt_month(tv.prompt)                                      AS trading_month,
    tv.contdate                                                            AS trade_date,
    tv.seqno                                                               AS trade_sequence_number,
    tv.plots,
    tv.slots,
    tv.tprice                                                              AS price,
    tv.series                                                              AS strike,
    tv.mktcurr                                                             AS currency,
    lq1.market_value,
    lq1.contract_value,
    lq1.commission,
    lq2.result_mktcurr,
    lq3.result_base_currency,
    CASE WHEN tv.plots IS NOT NULL AND tv.slots IS NULL
         THEN lq3.result_base_currency
         ELSE 0
    END                                                                    AS purchased_result_basecurr,
    CASE WHEN tv.plots IS NULL AND tv.slots IS NOT NULL
         THEN lq3.result_base_currency
         ELSE 0
    END                                                                    AS sold_result_basecurr,
    p.base_currency
FROM public.term_view tv
JOIN public.futures_contract fc
    ON fc.code = tv.futconts
JOIN public.currency
    ON currency.code = tv.mktcurr
JOIN public.client cl
    ON cl.code = tv.broker
CROSS JOIN public.params p
CROSS JOIN LATERAL (
    SELECT
        public.sp_curr_cvtunderlying(COALESCE(tv.mktvalue, 0), tv.mktcurr) AS market_value,
        public.sp_curr_cvtunderlying(COALESCE(tv.contval,  0), tv.mktcurr) AS contract_value,
        ABS(COALESCE(tv.commval, 0))                                        AS commission
) AS lq1
CROSS JOIN LATERAL (
    SELECT lq1.contract_value - lq1.market_value - lq1.commission          AS result_mktcurr
) AS lq2
CROSS JOIN LATERAL (
    SELECT
        CASE WHEN currency.ratetype = 'M'
             THEN lq2.result_mktcurr
                  * public.sp_lastopenhouserate(public.sp_curr_getunderlying(tv.mktcurr), p.base_currency)
             ELSE lq2.result_mktcurr
                  / public.sp_lastopenhouserate(public.sp_curr_getunderlying(tv.mktcurr), p.base_currency)
        END                                                                 AS result_base_currency
) AS lq3
WHERE tv.mktype = 'F'
ORDER BY tv.futconts,
         tv.tradetype,
         tv.company,
         tv.pcentre,
         tv.broker,
         tv.prompt;
