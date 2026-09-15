-- ============================================================
-- powerbi_forex_hedging_overview_sublevel_2
-- Source: dba.PowerBI_Forex_Hedging_Overview_Sublevel_2
-- Simple join of powerbi_forex_hedging_overview_sublevel_1 with
-- forex_hedges and terminal.  No alias deps.
--
-- SAP → PostgreSQL translations:
--   View/column names → lowercase (PostgreSQL folds all unquoted identifiers).
--   dateformat(date(terminal.prompt), 'YYYY-MM')
--     → TO_CHAR(terminal.prompt::date, 'YYYY-MM')
--     (SAP date() converts to date type; ::date cast handles char or date source).
--   Comma-joins → explicit JOINs.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_forex_hedging_overview_sublevel_2 AS

SELECT
    s1.contract_number,
    s1.split,
    s1.contract_date,
    s1.commodity_type,
    s1.original_quantity,
    s1.unit,
    s1.original_tonnage,
    s1.contract_price,
    s1.currency,
    s1.price_unit,
    s1.quantity_invoiced,
    s1.amount_invoiced,
    s1.invoice_numbers,
    fh.quantity                                                AS fx_amount_hedged,
    t.tprice                                                   AS fx_rate,
    t.prompt                                                   AS fx_maturity,
    TO_CHAR(t.prompt::date, 'YYYY-MM')                        AS fx_maturity_year_month
FROM public.powerbi_forex_hedging_overview_sublevel_1 s1
JOIN public.forex_hedges fh
    ON  fh.contno = s1.contract_number
    AND fh.split  = s1.split
JOIN public.terminal t
    ON  t.contdate = fh.termdate
    AND t.seqno    = fh.termseqno;
