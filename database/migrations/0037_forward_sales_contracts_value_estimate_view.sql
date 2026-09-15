-- ============================================================
-- forward_sales_contracts_value_estimate_view
-- Source: dba.forward_sales_contracts_value_estimate_view
-- 19 UNION ALL branches (sort_flag '00'â€“'18'), one per rolling
-- month window relative to params.systemdate.
-- Branch '18' has no upper bound (18+ months onwards).
-- SAP alias chains resolved by inlining DATE_TRUNC arithmetic â€”
-- no subquery nesting required.
-- SAPâ†’PG: IFâ€¦ENDIFâ†’CASE; isnullâ†’COALESCE; month()/year()â†’EXTRACT;
--   dateadd(month,N,x)â†’x+INTERVAL; dateformatâ†’TO_CHAR('FMMonth YYYY');
--   cast(x as char)â†’x::text; date(x)â†’x::date;
--   comma-joinsâ†’explicit JOIN/CROSS JOIN.
-- ORDER BY: original positional refs 1,15,3,4 â†’
--   sort_flag, contract_currency, contno, split.
-- ============================================================

CREATE OR REPLACE VIEW public.forward_sales_contracts_value_estimate_view AS

-- sort_flag '00': Current Month
SELECT
    '00'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate))::int   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate))::int    AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate), 'MM')             AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate), 'YYYY')           AS year_to_use_string,
    DATE_TRUNC('month', params.systemdate)::date                      AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '1 month')::date                                   AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate),
        'FMMonth YYYY')                                               AS month_label,
    '(Current Month)'::text                                           AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= DATE_TRUNC('month', params.systemdate)::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '1 month')::date

UNION ALL

-- sort_flag '01': +1 Month
SELECT
    '01'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '1 month')::int                                    AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '1 month')::int                                    AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '1 month', 'MM')                                   AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '1 month', 'YYYY')                                 AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '1 month')::date                                   AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '2 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '1 month', 'FMMonth YYYY')                        AS month_label,
    '(+1 Month)'::text                                                AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '1 month')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '2 months')::date

UNION ALL

-- sort_flag '02': +2 Months
SELECT
    '02'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '2 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '2 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '2 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '2 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '2 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '3 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '2 months', 'FMMonth YYYY')                       AS month_label,
    '(+2 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '2 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '3 months')::date

UNION ALL

-- sort_flag '03': +3 Months
SELECT
    '03'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '3 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '3 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '3 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '3 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '3 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '4 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '3 months', 'FMMonth YYYY')                       AS month_label,
    '(+3 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '3 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '4 months')::date

UNION ALL

-- sort_flag '04': +4 Months
SELECT
    '04'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '4 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '4 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '4 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '4 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '4 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '5 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '4 months', 'FMMonth YYYY')                       AS month_label,
    '(+4 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '4 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '5 months')::date

UNION ALL

-- sort_flag '05': +5 Months
SELECT
    '05'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '5 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '5 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '5 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '5 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '5 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '6 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '5 months', 'FMMonth YYYY')                       AS month_label,
    '(+5 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '5 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '6 months')::date

UNION ALL

-- sort_flag '06': +6 Months
SELECT
    '06'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '6 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '6 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '6 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '6 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '6 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '7 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '6 months', 'FMMonth YYYY')                       AS month_label,
    '(+6 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '6 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '7 months')::date

UNION ALL

-- sort_flag '07': +7 Months
SELECT
    '07'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '7 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '7 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '7 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '7 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '7 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '8 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '7 months', 'FMMonth YYYY')                       AS month_label,
    '(+7 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '7 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '8 months')::date

UNION ALL

-- sort_flag '08': +8 Months
SELECT
    '08'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '8 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '8 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '8 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '8 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '8 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '9 months')::date                                  AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '8 months', 'FMMonth YYYY')                       AS month_label,
    '(+8 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '8 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '9 months')::date

UNION ALL

-- sort_flag '09': +9 Months
SELECT
    '09'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '9 months')::int                                   AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '9 months')::int                                   AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '9 months', 'MM')                                  AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '9 months', 'YYYY')                                AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '9 months')::date                                  AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '10 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '9 months', 'FMMonth YYYY')                       AS month_label,
    '(+9 Months)'::text                                               AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '9 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '10 months')::date

UNION ALL

-- sort_flag '10': +10 Months
SELECT
    '10'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '10 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '10 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '10 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '10 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '10 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '11 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '10 months', 'FMMonth YYYY')                      AS month_label,
    '(+10 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '10 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '11 months')::date

UNION ALL

-- sort_flag '11': +11 Months
SELECT
    '11'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '11 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '11 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '11 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '11 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '11 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '12 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '11 months', 'FMMonth YYYY')                      AS month_label,
    '(+11 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '11 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '12 months')::date

UNION ALL

-- sort_flag '12': +12 Months
SELECT
    '12'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '12 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '12 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '12 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '12 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '12 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '13 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '12 months', 'FMMonth YYYY')                      AS month_label,
    '(+12 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '12 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '13 months')::date

UNION ALL

-- sort_flag '13': +13 Months
SELECT
    '13'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '13 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '13 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '13 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '13 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '13 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '14 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '13 months', 'FMMonth YYYY')                      AS month_label,
    '(+13 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '13 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '14 months')::date

UNION ALL

-- sort_flag '14': +14 Months
SELECT
    '14'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '14 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '14 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '14 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '14 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '14 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '15 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '14 months', 'FMMonth YYYY')                      AS month_label,
    '(+14 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '14 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '15 months')::date

UNION ALL

-- sort_flag '15': +15 Months
SELECT
    '15'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '15 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '15 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '15 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '15 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '15 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '16 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '15 months', 'FMMonth YYYY')                      AS month_label,
    '(+15 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '15 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '16 months')::date

UNION ALL

-- sort_flag '16': +16 Months
SELECT
    '16'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '16 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '16 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '16 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '16 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '16 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '17 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '16 months', 'FMMonth YYYY')                      AS month_label,
    '(+16 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '16 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '17 months')::date

UNION ALL

-- sort_flag '17': +17 Months
SELECT
    '17'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '17 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '17 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '17 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '17 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '17 months')::date                                 AS month_to_use_first_day,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '18 months')::date                                 AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '17 months', 'FMMonth YYYY')                      AS month_label,
    '(+17 Months)'::text                                              AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '17 months')::date
  AND sub_contracts.shipfrom <  (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '18 months')::date

UNION ALL

-- sort_flag '18': +18 Months and onwards (no upper bound)
SELECT
    '18'::text                                                         AS sort_flag,
    phys_pricing_valn_sopex.company,
    phys_pricing_valn_sopex.contno,
    phys_pricing_valn_sopex.split,
    phys_pricing_valn_sopex.contdate,
    phys_pricing_valn_sopex.commodity,
    phys_pricing_valn_sopex.commodtype,
    phys_pricing_valn_sopex.origin,
    phys_pricing_valn_sopex.quality,
    phys_pricing_valn_sopex.original,
    phys_pricing_valn_sopex.quantunit,
    phys_pricing_valn_sopex.client,
    phys_pricing_valn_sopex.openqnt,
    CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
         THEN phys_pricing_valn_sopex.pfdiffcurr
         ELSE phys_pricing_valn_sopex.currency
    END                                                                AS original_contract_currency,
    public.sp_curr_getunderlying(
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END)                                                           AS contract_currency,
    public.sp_pricestr(
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        phys_pricing_valn_sopex.currency,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit)                           AS price_string,
    public.sp_calc_value(
        phys_pricing_valn_sopex.openqnt,
        phys_pricing_valn_sopex.quantunit,
        phys_pricing_valn_sopex.price_fixing,
        phys_pricing_valn_sopex.unitprice,
        CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
             THEN phys_pricing_valn_sopex.pfdiffcurr
             ELSE phys_pricing_valn_sopex.currency
        END,
        phys_pricing_valn_sopex.priceunit,
        phys_pricing_valn_sopex.pfcontract,
        phys_pricing_valn_sopex.pfposition,
        phys_pricing_valn_sopex.pfdifftype,
        phys_pricing_valn_sopex.pfdiffer,
        phys_pricing_valn_sopex.pfdiffcurr,
        phys_pricing_valn_sopex.pfdiffunit,
        public.sp_curr_getunderlying(
            CASE WHEN phys_pricing_valn_sopex.price_fixing = 'Y'
                 THEN phys_pricing_valn_sopex.pfdiffcurr
                 ELSE phys_pricing_valn_sopex.currency
            END),
        params.systemdate)                                             AS phys_value,
    COALESCE(phys_pricing_valn_sopex.ship_desc,
             phys_pricing_valn_sopex.shipment)                        AS ship_desc,
    phys_pricing_valn_sopex.shipfrom,
    phys_pricing_valn_sopex.shipto,
    EXTRACT(MONTH FROM params.systemdate)::int                        AS current_month,
    EXTRACT(YEAR FROM params.systemdate)::int                         AS current_year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '18 months')::int                                  AS month_to_use,
    EXTRACT(YEAR FROM DATE_TRUNC('month', params.systemdate)
        + INTERVAL '18 months')::int                                  AS year_to_use,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '18 months', 'MM')                                 AS month_to_use_string,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '18 months', 'YYYY')                               AS year_to_use_string,
    (DATE_TRUNC('month', params.systemdate)
        + INTERVAL '18 months')::date                                 AS month_to_use_first_day,
    NULL::date                                                         AS next_month_first_day,
    TO_CHAR(DATE_TRUNC('month', params.systemdate)
        + INTERVAL '18 months', 'FMMonth YYYY')                      AS month_label,
    '(+18 Months and onwards)'::text                                  AS month_text_label,
    params.systemdate
FROM public.phys_pricing_valn_sopex
JOIN public.master_contracts
    ON master_contracts.contno = phys_pricing_valn_sopex.contno
JOIN public.sub_contracts
    ON sub_contracts.contno = phys_pricing_valn_sopex.contno
   AND sub_contracts.split  = phys_pricing_valn_sopex.split
CROSS JOIN public.params
WHERE phys_pricing_valn_sopex.openqnt > 0
  AND master_contracts.contract_type = 'S'
  AND sub_contracts.shipfrom >= (DATE_TRUNC('month', params.systemdate)
                                     + INTERVAL '18 months')::date

ORDER BY sort_flag, contract_currency, contno, split;

