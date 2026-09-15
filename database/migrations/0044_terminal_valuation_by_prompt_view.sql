-- ============================================================
-- terminal_valuation_by_prompt
-- Source: dba.terminal_valuation_by_prompt
-- Open terminal P&L grouped by prompt, for LNCF and NYCF contracts.
-- Alias chain:
--   s_b (GROUP BY): aggregates market_value, contract_value,
--                   commission, purchased/sold_lots_tonnage/lots;
--                   passes through raw plots/slots (for IS NULL
--                   conditions) and ratetype (for FX branch).
--   s_ (wrapper):   result_mktcurr = contract_value - market_value
--                   - commission.
--   Outer SELECT:   result_basecurr inlined into all three result
--                   columns (avoids 3rd nesting level); mktcurr_parent
--                   from s_b used to keep sp_lastopenhouserate call short.
-- SAP isnull(SUM(x),0) → COALESCE(SUM(x),0).
-- IF/ENDIF → CASE WHEN…END.
-- ( futconts='LNCF' OR futconts='NYCF' ) → futconts IN (…).
-- Comma-joins → explicit JOINs; params → CROSS JOIN.
-- mktcurr_parent alias (sp_curr_getunderlying(mktcurr)) expanded
--   in GROUP BY since PG does not allow alias refs there.
-- ============================================================

CREATE OR REPLACE VIEW public.terminal_valuation_by_prompt AS

SELECT
    s_.company,
    s_.terminaltype,
    s_.futconts,
    s_.prompt,
    s_.get_prompt,
    s_.purchased_lots_tonnage,
    s_.sold_lots_tonnage,
    s_.purchased_lots,
    s_.sold_lots,
    s_.valprice,
    s_.market_value,
    s_.contract_value,
    s_.commission,
    s_.result_mktcurr,
    -- result_basecurr: M ratetype → multiply; else → divide
    CASE WHEN s_.ratetype = 'M'
         THEN s_.result_mktcurr
              * public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
         ELSE s_.result_mktcurr
              / public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
    END                                                                  AS result_basecurr,
    -- purchased_result_basecurr: result_basecurr inlined (avoids 3rd nesting level)
    CASE WHEN s_.plots IS NOT NULL AND s_.slots IS NULL
         THEN CASE WHEN s_.ratetype = 'M'
                   THEN s_.result_mktcurr
                        * public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
                   ELSE s_.result_mktcurr
                        / public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
              END
         ELSE 0
    END                                                                  AS purchased_result_basecurr,
    -- sold_result_basecurr: result_basecurr inlined
    CASE WHEN s_.plots IS NULL AND s_.slots IS NOT NULL
         THEN CASE WHEN s_.ratetype = 'M'
                   THEN s_.result_mktcurr
                        * public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
                   ELSE s_.result_mktcurr
                        / public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
              END
         ELSE 0
    END                                                                  AS sold_result_basecurr,
    s_.wp_commodity,
    s_.mktcurr,
    s_.mktcurr_parent,
    s_.tradetype,
    s_.base_currency
FROM (
    -- s_: computes result_mktcurr from s_b alias deps
    SELECT
        s_b.company,
        s_b.terminaltype,
        s_b.futconts,
        s_b.prompt,
        s_b.get_prompt,
        s_b.plots,
        s_b.slots,
        s_b.valprice,
        s_b.mktcurr,
        s_b.mktcurr_parent,
        s_b.wp_commodity,
        s_b.ratetype,
        s_b.tradetype,
        s_b.base_currency,
        s_b.purchased_lots_tonnage,
        s_b.sold_lots_tonnage,
        s_b.purchased_lots,
        s_b.sold_lots,
        s_b.market_value,
        s_b.contract_value,
        s_b.commission,
        s_b.contract_value - s_b.market_value - s_b.commission        AS result_mktcurr
    FROM (
        -- s_b: GROUP BY query; all aggregates and alias-free derivations
        SELECT
            term_view.company,
            term_view.terminaltype,
            term_view.futconts,
            term_view.prompt,
            term_view.get_prompt,
            term_view.plots,
            term_view.slots,
            term_view.valprice,
            term_view.mktcurr,
            public.sp_curr_getunderlying(term_view.mktcurr)             AS mktcurr_parent,
            term_view.wp_commodity,
            currency.ratetype,
            term_view.tradetype,
            params.base_currency,
            COALESCE(SUM(
                term_view.plots
                * term_view.lotfactor
                * public.sp_convert_qty(1, term_view.mktunit, 'MT')
            ), 0)                                                        AS purchased_lots_tonnage,
            COALESCE(SUM(
                term_view.slots
                * term_view.lotfactor
                * public.sp_convert_qty(1, term_view.mktunit, 'MT')
            ), 0)                                                        AS sold_lots_tonnage,
            COALESCE(SUM(term_view.plots), 0)                           AS purchased_lots,
            COALESCE(SUM(term_view.slots), 0)                           AS sold_lots,
            public.sp_curr_cvtunderlying(
                COALESCE(SUM(term_view.mktvalue), 0),
                term_view.mktcurr)                                       AS market_value,
            public.sp_curr_cvtunderlying(
                COALESCE(SUM(term_view.contval), 0),
                term_view.mktcurr)                                       AS contract_value,
            ABS(COALESCE(SUM(term_view.commval), 0))                    AS commission
        FROM public.term_view
        JOIN public.currency ON currency.code = term_view.mktcurr
        CROSS JOIN public.params
        WHERE term_view.mktype = 'F'
          AND term_view.futconts IN ('LNCF', 'NYCF')
        GROUP BY
            term_view.company,
            term_view.terminaltype,
            term_view.futconts,
            term_view.prompt,
            term_view.get_prompt,
            term_view.plots,
            term_view.slots,
            term_view.valprice,
            term_view.mktcurr,
            public.sp_curr_getunderlying(term_view.mktcurr),
            term_view.wp_commodity,
            currency.ratetype,
            term_view.tradetype,
            params.base_currency
    ) s_b
) s_;
