-- ============================================================
-- yearend_view
-- Source: dba.yearend_view
--
-- SAP → PostgreSQL translations:
--   GROUP BY + deep alias chain cannot use LATERAL (LATERALs precede GROUP BY).
--   Resolved via three CTEs:
--     grouped    — SUM aggregates + MAX(ratetype) (deterministic via join key).
--     with_rates — ave_house_rate (CASE on ratetype) + houseratelength literal.
--     with_factor — factor = MOD(ave_house_rate, houseratelength) / houseratelength.
--   Outer SELECT: balance_1, house_rate_1, balance_2, house_rate_2 inlined.
--   houseratelength = .000001 defined last in SAP SELECT (forward alias ref)
--     → materialised early in with_rates CTE.
--   "truncate"(x,6)   → TRUNC(x, 6)   (SAP reserved-word alias for numeric truncate).
--   mod(x,y)           → MOD(x, y)    (same semantics in PostgreSQL).
--   IF max(ratetype)='M' THEN ... ELSE ... ENDIF → CASE WHEN ... END.
--   Comma-join → explicit JOIN; GROUP BY column names qualified (lv.*).
--   max(currency.ratetype) in original aggregated to disambiguate from JOIN;
--     here brought into grouped CTE as MAX(c.ratetype).
-- ============================================================

CREATE OR REPLACE VIEW public.yearend_view AS

WITH grouped AS (
    SELECT
        lv.company,
        lv.pcentre,
        lv.nominal,
        lv.currency,
        SUM(lv.ledamt)                                                     AS balance,
        CAST(SUM(lv.base_amt) AS numeric(30, 16))                         AS basebalance,
        MAX(c.ratetype)                                                    AS ratetype
    FROM public.leds_view lv
    JOIN public.currency c
        ON c.code = lv.currency
    WHERE lv.preventpost = false
      AND lv.type = 'P'
    GROUP BY lv.company, lv.pcentre, lv.nominal, lv.currency
),
with_rates AS (
    SELECT
        *,
        CASE WHEN ratetype = 'M'
             THEN CAST(basebalance / balance AS numeric(30, 16))
             ELSE CAST(balance / basebalance AS numeric(30, 16))
        END                                                                AS ave_house_rate,
        0.000001::numeric                                                  AS houseratelength
    FROM grouped
),
with_factor AS (
    SELECT
        *,
        MOD(ave_house_rate, houseratelength) / houseratelength             AS factor
    FROM with_rates
)
SELECT
    company,
    pcentre,
    nominal,
    currency,
    balance,
    basebalance,
    ave_house_rate,
    factor,
    ROUND(balance * factor, 2)                                             AS balance_1,
    TRUNC(ave_house_rate, 6) + houseratelength                             AS house_rate_1,
    ROUND(balance * (1.0 - factor), 2)                                    AS balance_2,
    TRUNC(ave_house_rate, 6)                                               AS house_rate_2,
    houseratelength
FROM with_factor;
