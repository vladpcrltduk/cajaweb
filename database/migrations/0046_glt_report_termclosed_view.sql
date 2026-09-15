-- ============================================================
-- glt_report_termclosed_view
-- Source: dba.GLT_Report_Termclosed_view
-- Closed/settled terminal positions for CA, US, SG terminal types.
-- Alias chain (4 tiers, resolved with 2 subquery levels):
--   s_b (Tier 1): tonnage_factor, contval_posted, commis_posted,
--                 mktcurr, mktcurr_parent — alias-free function calls.
--   s_ (Tier 2): sett_result, purch/sold_settled_tonnage,
--                sett_result_base_curr (sett_result inlined here to
--                avoid a 3rd nesting level).
--   Outer SELECT (Tier 3): histaction_S_purch_settled_tonnage
--                           (dep on purch_settled_tonnage);
--                           purch/sold_sett_result_base_curr
--                           (deps on sett_result_base_curr).
-- Inlinings:
--   sett_result written twice inside sett_result_base_curr CASE.
--   sett_result_base_curr written three times (standalone pass-through
--   + purch + sold conditions).
-- ratetype and base_currency: passed through s_ for computation only;
--   not output columns.
-- SAP isnull(x,0) → COALESCE(x,0); IF…ENDIF → CASE WHEN…END.
-- Comma-joins → explicit JOINs; OR terminaltype list → IN (…).
-- mktcurr_parent = sp_curr_getunderlying expanded inline (no alias dep).
-- ============================================================

CREATE OR REPLACE VIEW public.glt_report_termclosed_view AS

SELECT
    s_.histaction,
    s_.histdate,
    s_.contdate,
    s_.seqno,
    s_.company,
    s_.pcentre,
    s_.commodity,
    s_.futconts,
    s_.prompt,
    s_.tradetype,
    s_.series,
    s_.mktype,
    s_.tprice,
    s_.plots,
    s_.slots,
    s_.terminaltype,
    s_.settlement_confirmed,
    s_.wp_commodity,
    s_.tonnage_factor,
    s_.contval_posted,
    s_.commis_posted,
    s_.sett_result,
    s_.purch_settled_tonnage,
    s_.sold_settled_tonnage,
    CASE WHEN s_.histaction = 'S'
         THEN s_.purch_settled_tonnage
         ELSE 0
    END                                                                  AS histaction_s_purch_settled_tonnage,
    s_.mktcurr,
    s_.mktcurr_parent,
    s_.sett_result_base_curr,
    CASE WHEN s_.plots IS NOT NULL AND s_.slots IS NULL
         THEN s_.sett_result_base_curr
         ELSE 0
    END                                                                  AS purch_sett_result_base_curr,
    CASE WHEN s_.plots IS NULL AND s_.slots IS NOT NULL
         THEN s_.sett_result_base_curr
         ELSE 0
    END                                                                  AS sold_sett_result_base_curr
FROM (
    -- s_: Tier 2 — alias deps on s_b; sett_result inlined into
    -- sett_result_base_curr to avoid a 3rd subquery level
    SELECT
        s_b.histaction,
        s_b.histdate,
        s_b.contdate,
        s_b.seqno,
        s_b.company,
        s_b.pcentre,
        s_b.commodity,
        s_b.futconts,
        s_b.prompt,
        s_b.tradetype,
        s_b.series,
        s_b.mktype,
        s_b.tprice,
        s_b.plots,
        s_b.slots,
        s_b.terminaltype,
        s_b.settlement_confirmed,
        s_b.wp_commodity,
        s_b.tonnage_factor,
        s_b.contval_posted,
        s_b.commis_posted,
        s_b.mktcurr,
        s_b.mktcurr_parent,
        COALESCE(s_b.contval_posted, 0)
            - COALESCE(s_b.commis_posted, 0)                            AS sett_result,
        COALESCE(s_b.plots, 0) * s_b.tonnage_factor                    AS purch_settled_tonnage,
        COALESCE(s_b.slots, 0) * s_b.tonnage_factor                    AS sold_settled_tonnage,
        -- sett_result inlined (written twice) to stay at 2 subquery levels
        CASE WHEN s_b.ratetype = 'M'
             THEN (COALESCE(s_b.contval_posted, 0) - COALESCE(s_b.commis_posted, 0))
                  * public.sp_lastopenhouserate(s_b.mktcurr_parent, s_b.base_currency)
             ELSE (COALESCE(s_b.contval_posted, 0) - COALESCE(s_b.commis_posted, 0))
                  / public.sp_lastopenhouserate(s_b.mktcurr_parent, s_b.base_currency)
        END                                                              AS sett_result_base_curr
    FROM (
        -- s_b: Tier 1 — raw columns + alias-free function calls
        SELECT
            termclosed.histaction,
            termclosed.histdate,
            termclosed.contdate,
            termclosed.seqno,
            termclosed.company,
            termclosed.pcentre,
            termclosed.commodity,
            termclosed.futconts,
            termclosed.prompt,
            termclosed.tradetype,
            termclosed.series,
            termclosed.mktype,
            termclosed.tprice,
            termclosed.plots,
            termclosed.slots,
            termclosed.terminaltype,
            termclosed.settlement_confirmed,
            futures_contract.wp_commodity,
            public.sp_convert_qty(
                futures_contract.lotfactor,
                futures_contract.unit,
                params.base_unit)                                        AS tonnage_factor,
            public.sp_curr_cvtunderlying(
                termclosed.contval_posted,
                futures_contract.currency)                               AS contval_posted,
            public.sp_curr_cvtunderlying(
                termclosed.commis_posted * -1,
                termclosed.commcurr)                                     AS commis_posted,
            futures_contract.currency                                    AS mktcurr,
            public.sp_curr_getunderlying(futures_contract.currency)      AS mktcurr_parent,
            currency.ratetype,
            params.base_currency
        FROM public.termclosed
        JOIN public.futures_contract
            ON termclosed.futconts = futures_contract.code
        JOIN public.currency
            ON futures_contract.currency = currency.code
        CROSS JOIN public.params
        WHERE termclosed.terminaltype IN ('CA', 'US', 'SG')
    ) s_b
) s_;
