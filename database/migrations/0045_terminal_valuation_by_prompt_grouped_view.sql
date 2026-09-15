-- ============================================================
-- terminal_valuation_by_prompt_grouped
-- Source: dba.terminal_valuation_by_prompt_grouped
-- Grouped (summarised) variant of terminal_valuation_by_prompt.
-- Key differences from terminal_valuation_by_prompt (0044):
--   - plots/slots NOT in GROUP BY → genuine aggregation across positions
--   - No purchased/sold_result_basecurr columns (no per-side breakdown)
--   - tradetype='F' in WHERE (not in GROUP BY / output)
--   - wp_commodity not in output or GROUP BY
-- Alias chain:
--   s_b (GROUP BY): market_value, contract_value, commission aggregates
--   s_ (wrapper):   result_mktcurr = contract_value - market_value
--                   - commission
--   Outer SELECT:   result_basecurr (IF ratetype='M' multiply/else divide)
-- mktcurr_parent alias expanded in GROUP BY (sp_curr_getunderlying).
-- ratetype passed through subqueries for FX branch; not output.
-- SAP isnull(SUM(x),0) → COALESCE(SUM(x),0).
-- IF/ENDIF → CASE WHEN…END.
-- Comma-joins → explicit JOINs; params → CROSS JOIN.
-- ============================================================

CREATE OR REPLACE VIEW public.terminal_valuation_by_prompt_grouped AS

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
    s_.mktcurr,
    s_.mktcurr_parent,
    s_.market_value,
    s_.contract_value,
    s_.commission,
    s_.result_mktcurr,
    CASE WHEN s_.ratetype = 'M'
         THEN s_.result_mktcurr
              * public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
         ELSE s_.result_mktcurr
              / public.sp_lastopenhouserate(s_.mktcurr_parent, s_.base_currency)
    END                                                                  AS result_basecurr,
    s_.base_currency
FROM (
    -- s_: computes result_mktcurr from s_b alias deps
    SELECT
        s_b.company,
        s_b.terminaltype,
        s_b.futconts,
        s_b.prompt,
        s_b.get_prompt,
        s_b.valprice,
        s_b.mktcurr,
        s_b.mktcurr_parent,
        s_b.ratetype,
        s_b.base_currency,
        s_b.purchased_lots_tonnage,
        s_b.sold_lots_tonnage,
        s_b.purchased_lots,
        s_b.sold_lots,
        s_b.market_value,
        s_b.contract_value,
        s_b.commission,
        s_b.contract_value - s_b.market_value - s_b.commission         AS result_mktcurr
    FROM (
        -- s_b: GROUP BY query; all aggregates and alias-free derivations
        SELECT
            term_view.company,
            term_view.terminaltype,
            term_view.futconts,
            term_view.prompt,
            term_view.get_prompt,
            term_view.valprice,
            term_view.mktcurr,
            public.sp_curr_getunderlying(term_view.mktcurr)             AS mktcurr_parent,
            currency.ratetype,
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
        WHERE term_view.mktype    = 'F'
          AND term_view.tradetype = 'F'
          AND term_view.futconts IN ('LNCF', 'NYCF')
        GROUP BY
            term_view.company,
            term_view.terminaltype,
            term_view.futconts,
            term_view.prompt,
            term_view.get_prompt,
            term_view.valprice,
            term_view.mktcurr,
            public.sp_curr_getunderlying(term_view.mktcurr),
            currency.ratetype,
            params.base_currency
    ) s_b
) s_;
