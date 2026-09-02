-- Fix: Recreate views dropped by CASCADE during migration 0010

CREATE OR REPLACE VIEW public.phys_riskposn AS
 SELECT d.company,
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN public.sp_futmkt_getunderlying(c.vlcontract)
            ELSE public.sp_futmkt_getunderlying(d.vlcontract)
        END AS market,
    d.valuedin,
    public.sp_prompt_month(d.valuedin) AS valuedin_str,
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN c.vlposition
            ELSE d.vlposition
        END AS vlposition,
    public.sp_prompt_month(
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN c.vlposition
            ELSE d.vlposition
        END) AS vlposition_str,
    sum(
        CASE
            WHEN ((d.price_fixing = 'N'::bpchar) AND (d.status = 'STOCK'::text)) THEN ((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
            ELSE (0)::numeric
        END) AS stocks_priced,
    sum(
        CASE
            WHEN ((d.price_fixing = 'Y'::bpchar) AND (d.status = 'STOCK'::text)) THEN ((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
            ELSE (0)::numeric
        END) AS stocks_unpriced,
    sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN ((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
            ELSE (0)::numeric
        END) AS fwd_priced_purchase,
    sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN ((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
            ELSE (0)::numeric
        END) AS fwd_unpriced_purchase,
    sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN ((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
            ELSE (0)::numeric
        END) AS fwd_priced_sales,
    sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN ((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
            ELSE (0)::numeric
        END) AS fwd_unpriced_sales,
    0 AS excg_purchase,
    0 AS excg_sale,
    d.pcentre,
    d.commodity
   FROM ((public.val_differentials c
     JOIN public.phys_pricing_riskposn d ON (((d.company = c.company) AND (d.pcentre = c.pcentre) AND (d.commodity = c.commodity) AND (d.commodtype = c.commodtype) AND (d.origin = c.origin) AND (d.quality = c.quality) AND (d.valuedin = c.valuedin))))
     CROSS JOIN public.params)
  WHERE (d.openqnt > (0)::numeric)
  GROUP BY d.company,
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN public.sp_futmkt_getunderlying(c.vlcontract)
            ELSE public.sp_futmkt_getunderlying(d.vlcontract)
        END, d.valuedin,
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN c.vlposition
            ELSE d.vlposition
        END, d.pcentre, d.commodity
UNION
 SELECT terminal.company,
    terminal.futconts AS market,
    terminal.prompt AS valuedin,
    public.sp_prompt_month(terminal.prompt) AS valuedin_str,
    terminal.prompt AS vlposition,
    public.sp_prompt_month(terminal.prompt) AS vlposition_str,
    0 AS stocks_priced,
    0 AS stocks_unpriced,
    0 AS fwd_priced_purchase,
    0 AS fwd_unpriced_purchase,
    0 AS fwd_priced_sales,
    0 AS fwd_unpriced_sales,
    sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)) AS excg_purchase,
    sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.slots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)) AS excg_sale,
    terminal.pcentre,
    terminal.commodity
   FROM ((public.terminal
     JOIN public.futures_contract ON ((terminal.futconts = futures_contract.code)))
     CROSS JOIN public.params)
  WHERE ((terminal.tradetype = 'F'::bpchar) AND (COALESCE(terminal.plots, terminal.slots) > (0)::numeric))
  GROUP BY terminal.company, terminal.futconts, terminal.prompt, terminal.pcentre, terminal.commodity;


CREATE OR REPLACE VIEW public.phys_valn_view_valn_sopex AS
 WITH base AS (
         SELECT d_1.company,
            d_1.pcentre,
            d_1.commodity,
            d_1.commodtype,
            d_1.origin,
            d_1.quality,
            d_1.valuedin,
            public.sp_prompt_month(d_1.valuedin) AS valuedin_str,
            d_1.contno,
            d_1.split,
            d_1.contract_type,
            d_1.contdate,
            d_1.client,
            d_1.priceterm,
            d_1.prcst_location,
            d_1.payterm,
            d_1.shipfrom,
            d_1.shipto,
            d_1.ship_desc,
            d_1.shipordelv,
            d_1.certification,
            d_1.eudr_flag,
            d_1.openqnt,
            d_1.quantunit,
            d_1.original AS origqnt,
            d_1.unitprice,
            d_1.status,
            d_1.flag,
                CASE d_1.flag
                    WHEN 'FIX'::text THEN 'Priced'::text
                    WHEN 'PFUNFIX'::text THEN 'Unpriced'::text
                    WHEN 'PFFIX'::text THEN 'Priced'::text
                    ELSE 'Fixed'::text
                END AS fixed_unfixed_flag,
            ( SELECT pa.unfixed
                   FROM public.phys_avail pa
                  WHERE ((pa.contno = d_1.contno) AND (pa.split = d_1.split))) AS unfixed_quantity,
            d_1.est_fx_rate,
            d_1.cddifftype,
            d_1.cddiffer,
            d_1.original_price_fixing,
            d_1.original_pfdifftype,
            d_1.original_pfdiffer,
            d_1.original_pfposition,
            d_1.price_fixing,
            d_1.currency,
            d_1.priceunit,
            d_1.pfcontract,
            d_1.pfposition,
            d_1.pfdifftype,
            d_1.pfdiffer,
            d_1.pfdiffcurr,
            d_1.pfdiffunit,
            d_1.valn_type AS ct_valn_type,
            d_1.valn_price AS ct_valn_price,
            d_1.valn_curr AS ct_valn_curr,
            d_1.valn_unit AS ct_valn_unit,
            d_1.vlcontract AS ct_vlcontract,
            d_1.vlposition AS ct_vlposition,
            d_1.vldifftype AS ct_vldifftype,
            d_1.vldiffer AS ct_vldiffer,
            d_1.vldiffcurr AS ct_vldiffcurr,
            d_1.vldiffunit AS ct_vldiffunit,
            c.valn_type AS ps_valn_type,
            c.valn_price AS ps_valn_price,
            c.valn_curr AS ps_valn_curr,
            c.valn_unit AS ps_valn_unit,
            c.vlcontract AS ps_vlcontract,
            c.vlposition AS ps_vlposition,
            c.vldifftype AS ps_vldifftype,
            c.vldiffer AS ps_vldiffer,
            c.vldiffcurr AS ps_vldiffcurr,
            c.vldiffunit AS ps_vldiffunit,
                CASE
                    WHEN (d_1.valn_type = 'P'::bpchar) THEN c.vlposition
                    ELSE d_1.vlposition
                END AS chosen_vlposition,
                CASE
                    WHEN (d_1.valn_type = 'P'::bpchar) THEN c.vlcontract
                    ELSE d_1.vlcontract
                END AS chosen_vlcontract,
                CASE
                    WHEN (d_1.valn_type = 'P'::bpchar) THEN c.vldifftype
                    ELSE d_1.vldifftype
                END AS chosen_vldifftype,
                CASE
                    WHEN (d_1.valn_type = 'P'::bpchar) THEN c.vldiffer
                    ELSE d_1.vldiffer
                END AS chosen_vldiffer,
                CASE
                    WHEN (d_1.valn_type = 'P'::bpchar) THEN c.vldiffcurr
                    ELSE d_1.vldiffcurr
                END AS chosen_vldiffcurr,
                CASE
                    WHEN (d_1.valn_type = 'P'::bpchar) THEN c.vldiffunit
                    ELSE d_1.vldiffunit
                END AS chosen_vldiffunit,
            c.vlcontract AS c_vlcontract,
            c.vlposition AS c_vlposition,
            c.vldifftype AS c_vldifftype,
            c.vldiffer AS c_vldiffer,
            c.vldiffcurr AS c_vldiffcurr,
            c.vldiffunit AS c_vldiffunit,
            c.valn_type AS c_valn_type,
            c.valn_price AS c_valn_price,
            c.valn_curr AS c_valn_curr,
            c.valn_unit AS c_valn_unit,
            params.base_unit,
            params.base_currency,
            params.systemdate,
            d_1.tracking_unpriced
           FROM ((public.val_differentials c
             JOIN public.phys_pricing_valn_sopex d_1 ON (((d_1.company = c.company) AND (d_1.pcentre = c.pcentre) AND (d_1.commodity = c.commodity) AND (d_1.commodtype = c.commodtype) AND (d_1.origin = c.origin) AND (d_1.quality = c.quality) AND (d_1.valuedin = c.valuedin))))
             CROSS JOIN public.params)
        ), computed AS (
         SELECT b.company,
            b.pcentre,
            b.commodity,
            b.commodtype,
            b.origin,
            b.quality,
            b.valuedin,
            b.valuedin_str,
            b.contno,
            b.split,
            b.contract_type,
            b.contdate,
            b.client,
            b.priceterm,
            b.prcst_location,
            b.payterm,
            b.shipfrom,
            b.shipto,
            b.ship_desc,
            b.shipordelv,
            b.certification,
            b.eudr_flag,
            b.openqnt,
            b.quantunit,
            b.origqnt,
            b.unitprice,
            b.status,
            b.flag,
            b.fixed_unfixed_flag,
            b.unfixed_quantity,
            b.est_fx_rate,
            b.cddifftype,
            b.cddiffer,
            b.original_price_fixing,
            b.original_pfdifftype,
            b.original_pfdiffer,
            b.original_pfposition,
            b.price_fixing,
            b.currency,
            b.priceunit,
            b.pfcontract,
            b.pfposition,
            b.pfdifftype,
            b.pfdiffer,
            b.pfdiffcurr,
            b.pfdiffunit,
            b.ct_valn_type,
            b.ct_valn_price,
            b.ct_valn_curr,
            b.ct_valn_unit,
            b.ct_vlcontract,
            b.ct_vlposition,
            b.ct_vldifftype,
            b.ct_vldiffer,
            b.ct_vldiffcurr,
            b.ct_vldiffunit,
            b.ps_valn_type,
            b.ps_valn_price,
            b.ps_valn_curr,
            b.ps_valn_unit,
            b.ps_vlcontract,
            b.ps_vlposition,
            b.ps_vldifftype,
            b.ps_vldiffer,
            b.ps_vldiffcurr,
            b.ps_vldiffunit,
            b.chosen_vlposition,
            b.chosen_vlcontract,
            b.chosen_vldifftype,
            b.chosen_vldiffer,
            b.chosen_vldiffcurr,
            b.chosen_vldiffunit,
            b.c_vlcontract,
            b.c_vlposition,
            b.c_vldifftype,
            b.c_vldiffer,
            b.c_vldiffcurr,
            b.c_vldiffunit,
            b.c_valn_type,
            b.c_valn_price,
            b.c_valn_curr,
            b.c_valn_unit,
            b.base_unit,
            b.base_currency,
            b.systemdate,
            b.tracking_unpriced,
                CASE
                    WHEN (b.unfixed_quantity > (0)::numeric) THEN 'Y'::text
                    ELSE 'N'::text
                END AS is_contract_unfixed,
                CASE
                    WHEN (b.unfixed_quantity <= (0)::numeric) THEN (b.openqnt - public.sp_allocation_calculate_only_normal_alloc_quantity(b.contno, b.split))
                    ELSE b.openqnt
                END AS true_open
           FROM base b
        ), derived AS (
         SELECT c.company,
            c.pcentre,
            c.commodity,
            c.commodtype,
            c.origin,
            c.quality,
            c.valuedin,
            c.valuedin_str,
            c.contno,
            c.split,
            c.contract_type,
            c.contdate,
            c.client,
            c.priceterm,
            c.prcst_location,
            c.payterm,
            c.shipfrom,
            c.shipto,
            c.ship_desc,
            c.shipordelv,
            c.certification,
            c.eudr_flag,
            c.openqnt,
            c.quantunit,
            c.origqnt,
            c.unitprice,
            c.status,
            c.flag,
            c.fixed_unfixed_flag,
            c.unfixed_quantity,
            c.est_fx_rate,
            c.cddifftype,
            c.cddiffer,
            c.original_price_fixing,
            c.original_pfdifftype,
            c.original_pfdiffer,
            c.original_pfposition,
            c.price_fixing,
            c.currency,
            c.priceunit,
            c.pfcontract,
            c.pfposition,
            c.pfdifftype,
            c.pfdiffer,
            c.pfdiffcurr,
            c.pfdiffunit,
            c.ct_valn_type,
            c.ct_valn_price,
            c.ct_valn_curr,
            c.ct_valn_unit,
            c.ct_vlcontract,
            c.ct_vlposition,
            c.ct_vldifftype,
            c.ct_vldiffer,
            c.ct_vldiffcurr,
            c.ct_vldiffunit,
            c.ps_valn_type,
            c.ps_valn_price,
            c.ps_valn_curr,
            c.ps_valn_unit,
            c.ps_vlcontract,
            c.ps_vlposition,
            c.ps_vldifftype,
            c.ps_vldiffer,
            c.ps_vldiffcurr,
            c.ps_vldiffunit,
            c.chosen_vlposition,
            c.chosen_vlcontract,
            c.chosen_vldifftype,
            c.chosen_vldiffer,
            c.chosen_vldiffcurr,
            c.chosen_vldiffunit,
            c.c_vlcontract,
            c.c_vlposition,
            c.c_vldifftype,
            c.c_vldiffer,
            c.c_vldiffcurr,
            c.c_vldiffunit,
            c.c_valn_type,
            c.c_valn_price,
            c.c_valn_curr,
            c.c_valn_unit,
            c.base_unit,
            c.base_currency,
            c.systemdate,
            c.tracking_unpriced,
            c.is_contract_unfixed,
            c.true_open,
                CASE
                    WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(c.true_open, c.quantunit, c.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(c.true_open, c.quantunit, c.base_unit))
                END AS base_openqnt,
                CASE
                    WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(c.origqnt, c.quantunit, c.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(c.origqnt, c.quantunit, c.base_unit))
                END AS base_origqnt,
            public.sp_pricestr_mmyy(c.price_fixing, c.unitprice, c.currency, c.priceunit, c.pfcontract, c.pfposition, c.pfdifftype, c.pfdiffer, c.pfdiffcurr, c.pfdiffunit) AS price_string,
                CASE
                    WHEN (c.original_price_fixing = 'Y'::bpchar) THEN public.sp_pricestr_mmyy('Y'::bpchar, c.unitprice, c.currency, c.priceunit, c.pfcontract, c.original_pfposition, c.original_pfdifftype, c.original_pfdiffer, c.pfdiffcurr, c.pfdiffunit)
                    ELSE NULL::character varying
                END AS price_fixing_diff_string,
                CASE
                    WHEN (c.ct_valn_type = 'P'::bpchar) THEN public.sp_pricestr_mmyy((
                    CASE
                        WHEN (c.c_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, c.c_valn_price, c.c_valn_curr, c.c_valn_unit, c.c_vlcontract, c.c_vlposition, c.c_vldifftype, c.c_vldiffer, c.c_vldiffcurr, c.c_vldiffunit)
                    ELSE public.sp_pricestr_mmyy((
                    CASE
                        WHEN (c.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, c.ct_valn_price, c.ct_valn_curr, c.ct_valn_unit, c.ct_vlcontract, c.ct_vlposition, c.ct_vldifftype, c.ct_vldiffer, c.ct_vldiffcurr, c.ct_vldiffunit)
                END AS valn_string,
                CASE
                    WHEN (c.ct_valn_type = 'P'::bpchar) THEN c.c_vlposition
                    ELSE c.ct_vlposition
                END AS valn_month,
            (public.sp_calc_value(c.true_open, c.quantunit, c.price_fixing, c.unitprice, c.currency, c.priceunit, c.pfcontract, c.pfposition, c.pfdifftype, c.pfdiffer, c.pfdiffcurr, c.pfdiffunit, c.base_currency, c.systemdate) * (
                CASE
                    WHEN (c.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END)::numeric) AS phys_value,
            (
                CASE
                    WHEN (c.ct_valn_type = 'P'::bpchar) THEN public.sp_calc_value(c.true_open, c.quantunit, (
                    CASE
                        WHEN (c.c_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, c.c_valn_price, c.c_valn_curr, c.c_valn_unit, c.c_vlcontract, c.c_vlposition, c.c_vldifftype, c.c_vldiffer, c.c_vldiffcurr, c.c_vldiffunit, c.base_currency, c.systemdate)
                    ELSE public.sp_calc_value(c.true_open, c.quantunit, (
                    CASE
                        WHEN (c.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, c.ct_valn_price, c.ct_valn_curr, c.ct_valn_unit, c.ct_vlcontract, c.ct_vlposition, c.ct_vldifftype, c.ct_vldiffer, c.ct_vldiffcurr, c.ct_vldiffunit, c.base_currency, c.systemdate)
                END * (
                CASE
                    WHEN (c.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END)::numeric) AS valn_value,
            public.sp_phys_valn_term(c.contno, c.split, c.true_open, c.origqnt, c.base_currency, c.systemdate) AS term_pandl,
            public.sp_phys_valn_fx(c.contno, c.split, c.true_open, c.origqnt, c.base_currency, c.systemdate) AS fx_pandl,
            public.sp_phys_valn_resvs(c.contno, c.split, public.sp_convert_qty(c.true_open, c.quantunit, c.base_unit), c.base_unit, public.sp_convert_qty(c.origqnt, c.quantunit, c.base_unit), public.sp_calc_value(c.true_open, c.quantunit, c.price_fixing, c.unitprice, c.currency, c.priceunit, c.pfcontract, c.pfposition, c.pfdifftype, c.pfdiffer, c.pfdiffcurr, c.pfdiffunit, c.base_currency, c.systemdate), c.base_currency, c.systemdate) AS resvs_pandl,
                CASE
                    WHEN (c.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, c.quantunit, c.base_unit)
                    ELSE (1.0 / public.sp_convert_qty((1)::numeric, c.priceunit, c.base_unit))
                END AS unit_to_mt_conversion_factor,
                CASE
                    WHEN (public.sp_curr_getunderlying(c.currency) = c.base_currency) THEN public.sp_datedfxrate(c.currency, c.base_currency, CURRENT_DATE, CURRENT_DATE)
                    ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(c.contno, c.split)
                END AS currency_to_basecurr_conversion_factor,
            public.sp_get_total_reserves_in_base(c.contno, c.split) AS costs_per_base_unit
           FROM computed c
        )
 SELECT company,
    pcentre,
    commodity,
    commodtype,
    origin,
    quality,
    valuedin,
    valuedin_str,
    contno,
    split,
    contract_type,
    contdate,
    client,
    priceterm,
    prcst_location,
    payterm,
    shipfrom,
    shipto,
    ship_desc,
    shipordelv,
    certification,
    eudr_flag,
    openqnt,
    quantunit,
    origqnt,
    unitprice,
    status,
    flag,
    fixed_unfixed_flag,
    unfixed_quantity,
    is_contract_unfixed,
    true_open,
    est_fx_rate,
    cddifftype,
    cddiffer,
    original_price_fixing,
    original_pfdifftype,
    original_pfdiffer,
    original_pfposition,
    base_openqnt,
    base_origqnt,
    base_unit AS sysbaseunit,
    price_fixing,
    currency,
    priceunit,
    pfcontract,
    pfposition,
    pfdifftype,
    pfdiffer,
    pfdiffcurr,
    pfdiffunit,
    price_string,
    ct_valn_type,
    ct_valn_price,
    ct_valn_curr,
    ct_valn_unit,
    ct_vlcontract,
    ct_vlposition,
    ct_vldifftype,
    ct_vldiffer,
    ct_vldiffcurr,
    ct_vldiffunit,
    ps_valn_type,
    ps_valn_price,
    ps_valn_curr,
    ps_valn_unit,
    ps_vlcontract,
    ps_vlposition,
    ps_vldifftype,
    ps_vldiffer,
    ps_vldiffcurr,
    ps_vldiffunit,
    chosen_vlposition,
    chosen_vlcontract,
    chosen_vldifftype,
    chosen_vldiffer,
    chosen_vldiffcurr,
    chosen_vldiffunit,
    price_fixing_diff_string,
    valn_string,
    valn_month,
    base_currency AS sysbasecurr,
    phys_value,
    valn_value,
    (valn_value - phys_value) AS phys_pandl,
    term_pandl,
    fx_pandl,
    resvs_pandl,
    ((((valn_value - phys_value) + term_pandl) + fx_pandl) + resvs_pandl) AS net_pandl,
    costs_per_base_unit,
    unit_to_mt_conversion_factor,
    currency_to_basecurr_conversion_factor,
    ((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) AS unit_price_basecurr_mt,
        CASE
            WHEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) IS NOT NULL) THEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) + COALESCE(costs_per_base_unit, (0)::numeric))
            ELSE ((phys_value / base_openqnt) + COALESCE(costs_per_base_unit, (0)::numeric))
        END AS final_price_basecurr_mt,
    (valn_value / base_openqnt) AS valuation_price_basecurr_mt,
    (((valn_value / base_openqnt) -
        CASE
            WHEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) IS NOT NULL) THEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) + COALESCE(costs_per_base_unit, (0)::numeric))
            ELSE ((phys_value / base_openqnt) + COALESCE(costs_per_base_unit, (0)::numeric))
        END) * base_openqnt) AS valn_result,
    tracking_unpriced,
        CASE
            WHEN (contract_type = 'P'::bpchar) THEN (((valn_value / base_openqnt) -
            CASE
                WHEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) IS NOT NULL) THEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) + COALESCE(costs_per_base_unit, (0)::numeric))
                ELSE ((phys_value / base_openqnt) + COALESCE(costs_per_base_unit, (0)::numeric))
            END) * base_openqnt)
            ELSE (0)::numeric
        END AS purch_valn_result,
        CASE
            WHEN (contract_type = 'P'::bpchar) THEN (0)::numeric
            ELSE (((valn_value / base_openqnt) -
            CASE
                WHEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) IS NOT NULL) THEN (((unitprice * unit_to_mt_conversion_factor) * currency_to_basecurr_conversion_factor) + COALESCE(costs_per_base_unit, (0)::numeric))
                ELSE ((phys_value / base_openqnt) + COALESCE(costs_per_base_unit, (0)::numeric))
            END) * base_openqnt)
        END AS sales_valn_result
   FROM derived d;


CREATE OR REPLACE VIEW public.phys_riskposn_sopex AS
 SELECT d.company,
        CASE
            WHEN (d.chosen_vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.chosen_vlcontract
        END AS market,
        CASE
            WHEN (d.fixed_unfixed_flag = 'Unpriced'::text) THEN COALESCE(d.pfposition, d.chosen_vlposition)
            ELSE d.chosen_vlposition
        END AS vlposition,
    public.sp_prompt_month(
        CASE
            WHEN (d.fixed_unfixed_flag = 'Unpriced'::text) THEN COALESCE(d.pfposition, d.chosen_vlposition)
            ELSE d.chosen_vlposition
        END) AS vlposition_str,
    (sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.fixed_unfixed_flag = 'Priced'::text)) THEN public.sp_convert_qty(d.true_open, d.quantunit, params.base_unit)
            ELSE (0)::numeric
        END) - sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.fixed_unfixed_flag = 'Priced'::text)) THEN public.sp_convert_qty(d.true_open, d.quantunit, params.base_unit)
            ELSE (0)::numeric
        END)) AS priced_balance,
    (sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.fixed_unfixed_flag = 'Unpriced'::text)) THEN public.sp_convert_qty(d.true_open, d.quantunit, params.base_unit)
            ELSE (0)::numeric
        END) - sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.fixed_unfixed_flag = 'Unpriced'::text)) THEN public.sp_convert_qty(d.true_open, d.quantunit, params.base_unit)
            ELSE (0)::numeric
        END)) AS unpriced_balance,
    0 AS excg_balance,
    d.commodity,
    d.commodtype
   FROM (public.phys_valn_view_valn_sopex d
     CROSS JOIN public.params)
  WHERE (d.true_open > (0)::numeric)
  GROUP BY d.company,
        CASE
            WHEN (d.chosen_vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.chosen_vlcontract
        END,
        CASE
            WHEN (d.fixed_unfixed_flag = 'Unpriced'::text) THEN COALESCE(d.pfposition, d.chosen_vlposition)
            ELSE d.chosen_vlposition
        END, d.pcentre, d.commodity, d.commodtype
UNION
 SELECT terminal.company,
    terminal.futconts AS market,
    terminal.prompt AS vlposition,
    public.sp_prompt_month(terminal.prompt) AS vlposition_str,
    0 AS priced_balance,
    0 AS unpriced_balance,
    (COALESCE(sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric) + COALESCE(sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.slots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric)) AS excg_balance,
    terminal.commodity,
    futures_contract.wp_commodity AS commodtype
   FROM ((public.terminal
     JOIN public.futures_contract ON ((terminal.futconts = futures_contract.code)))
     CROSS JOIN public.params)
  WHERE ((terminal.tradetype = 'F'::bpchar) AND (COALESCE(terminal.plots, terminal.slots) > (0)::numeric) AND (terminal.futconts = ANY (ARRAY['LNCF'::bpchar, 'NYCF'::bpchar])) AND (terminal.terminaltype = ANY (ARRAY['CA'::bpchar, 'US'::bpchar, 'SG'::bpchar])))
  GROUP BY terminal.company, terminal.futconts, terminal.prompt, terminal.commodity, futures_contract.wp_commodity;


CREATE OR REPLACE VIEW public.phys_riskposn_sopex_call_put_options AS
 SELECT d.company,
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END AS market,
    d.commodity,
    d.vlposition AS valuedin,
        CASE
            WHEN (d.vlposition IS NULL) THEN '-Not Spec'::bpchar
            ELSE public.sp_prompt_month(d.vlposition)
        END AS valuedin_str,
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN c.vlposition
            ELSE d.vlposition
        END AS vlposition,
    public.sp_prompt_month(
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN c.vlposition
            ELSE d.vlposition
        END) AS vlposition_str,
    sum(
        CASE
            WHEN ((d.price_fixing = 'N'::bpchar) AND (d.status = 'STOCK'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN (d.commodtype <> 'BEA'::bpchar) THEN COALESCE(e.bean_factor, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS stocks_priced,
    public.sp_sopex_list_hedge_position_contracts('P'::bpchar, 'N'::bpchar, 'STOCK'::bpchar, d.company, COALESCE(
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, ''::bpchar), COALESCE(d.vlposition, ''::bpchar)) AS stocks_priced_contract_list,
    sum(
        CASE
            WHEN ((d.price_fixing = 'Y'::bpchar) AND (d.status = 'STOCK'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN (d.commodtype <> 'BEA'::bpchar) THEN COALESCE(e.bean_factor, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS stocks_unpriced,
    public.sp_sopex_list_hedge_position_contracts('P'::bpchar, 'Y'::bpchar, 'STOCK'::bpchar, d.company, COALESCE(
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, ''::bpchar), COALESCE(d.vlposition, ''::bpchar)) AS stocks_unpriced_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN (d.commodtype <> 'BEA'::bpchar) THEN COALESCE(e.bean_factor, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_priced_purchase,
    public.sp_sopex_list_hedge_position_contracts('P'::bpchar, 'N'::bpchar, 'FORWARD'::bpchar, d.company, COALESCE(
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, ''::bpchar), COALESCE(d.vlposition, ''::bpchar)) AS fwd_priced_purchase_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN (d.commodtype <> 'BEA'::bpchar) THEN COALESCE(e.bean_factor, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_unpriced_purchase,
    public.sp_sopex_list_hedge_position_contracts('P'::bpchar, 'Y'::bpchar, 'FORWARD'::bpchar, d.company, COALESCE(
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, ''::bpchar), COALESCE(d.vlposition, ''::bpchar)) AS fwd_unpriced_purchase_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN (d.commodtype <> 'BEA'::bpchar) THEN COALESCE(e.bean_factor, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_priced_sales,
    public.sp_sopex_list_hedge_position_contracts('S'::bpchar, 'N'::bpchar, 'FORWARD'::bpchar, d.company, COALESCE(
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, ''::bpchar), COALESCE(d.vlposition, ''::bpchar)) AS fwd_priced_sales_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN (d.commodtype <> 'BEA'::bpchar) THEN COALESCE(e.bean_factor, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_unpriced_sales,
    public.sp_sopex_list_hedge_position_contracts('S'::bpchar, 'Y'::bpchar, 'FORWARD'::bpchar, d.company, COALESCE(
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, ''::bpchar), COALESCE(d.vlposition, ''::bpchar)) AS fwd_unpriced_sales_contract_list,
    0 AS excg_purchase,
    0 AS excg_sale,
    0 AS options_call_purchase,
    0 AS options_put_purchase,
    0 AS options_call_sale,
    0 AS options_put_sale,
    0 AS delta_adjusted_options_call_purchase,
    0 AS delta_adjusted_options_put_purchase,
    0 AS delta_adjusted_options_call_sale,
    0 AS delta_adjusted_options_put_sale
   FROM (((public.phys_pricing_riskposn d
     LEFT JOIN public.val_differentials c ON (((d.company = c.company) AND (d.pcentre = c.pcentre) AND (d.commodity = c.commodity) AND (d.commodtype = c.commodtype) AND (d.origin = c.origin) AND (d.quality = c.quality) AND (d.valuedin = c.valuedin))))
     JOIN public.commodity_type e ON ((d.commodtype = e.code)))
     CROSS JOIN public.params)
  WHERE (d.openqnt > (0)::numeric)
  GROUP BY d.company, d.commodity,
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, d.vlposition, d.valn_type, c.vlposition
UNION
 SELECT terminal.company,
    terminal.futconts AS market,
    terminal.commodity,
    terminal.prompt AS valuedin,
    public.sp_prompt_month(terminal.prompt) AS valuedin_str,
    terminal.prompt AS vlposition,
    public.sp_prompt_month(terminal.prompt) AS vlposition_str,
    0 AS stocks_priced,
    ''::character varying AS stocks_priced_contract_list,
    0 AS stocks_unpriced,
    ''::character varying AS stocks_unpriced_contract_list,
    0 AS fwd_priced_purchase,
    ''::character varying AS fwd_priced_purchase_contract_list,
    0 AS fwd_unpriced_purchase,
    ''::character varying AS fwd_unpriced_purchase_contract_list,
    0 AS fwd_priced_sales,
    ''::character varying AS fwd_priced_sales_contract_list,
    0 AS fwd_unpriced_sales,
    ''::character varying AS fwd_unpriced_sales_contract_list,
    sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)) AS excg_purchase,
    sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.slots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)) AS excg_sale,
    0 AS options_call_purchase,
    0 AS options_put_purchase,
    0 AS options_call_sale,
    0 AS options_put_sale,
    0 AS delta_adjusted_options_call_purchase,
    0 AS delta_adjusted_options_put_purchase,
    0 AS delta_adjusted_options_call_sale,
    0 AS delta_adjusted_options_put_sale
   FROM ((public.terminal
     JOIN public.futures_contract ON ((terminal.futconts = futures_contract.code)))
     CROSS JOIN public.params)
  WHERE ((terminal.tradetype = 'F'::bpchar) AND (COALESCE(terminal.plots, terminal.slots) > (0)::numeric) AND (terminal.futconts <> 'GCCME'::bpchar))
  GROUP BY terminal.company, terminal.commodity, terminal.futconts, terminal.prompt
UNION
 SELECT terminal.company,
    terminal.futconts AS market,
    terminal.commodity,
    terminal.prompt AS valuedin,
    public.sp_prompt_month(terminal.prompt) AS valuedin_str,
    terminal.prompt AS vlposition,
    public.sp_prompt_month(terminal.prompt) AS vlposition_str,
    0 AS stocks_priced,
    ''::character varying AS stocks_priced_contract_list,
    0 AS stocks_unpriced,
    ''::character varying AS stocks_unpriced_contract_list,
    0 AS fwd_priced_purchase,
    ''::character varying AS fwd_priced_purchase_contract_list,
    0 AS fwd_unpriced_purchase,
    ''::character varying AS fwd_unpriced_purchase_contract_list,
    0 AS fwd_priced_sales,
    ''::character varying AS fwd_priced_sales_contract_list,
    0 AS fwd_unpriced_sales,
    ''::character varying AS fwd_unpriced_sales_contract_list,
    0 AS excg_purchase,
    0 AS excg_sale,
        CASE
            WHEN (terminal.tradetype = 'C'::bpchar) THEN COALESCE(sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric)
            ELSE (0)::numeric
        END AS options_call_purchase,
        CASE
            WHEN (terminal.tradetype = 'P'::bpchar) THEN (('-1'::integer)::numeric * COALESCE(sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (0)::numeric
        END AS options_put_purchase,
        CASE
            WHEN (terminal.tradetype = 'C'::bpchar) THEN (('-1'::integer)::numeric * COALESCE(sum(public.sp_convert_qty((terminal.slots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (0)::numeric
        END AS options_call_sale,
        CASE
            WHEN (terminal.tradetype = 'P'::bpchar) THEN COALESCE(sum(public.sp_convert_qty((terminal.slots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric)
            ELSE (0)::numeric
        END AS options_put_sale,
        CASE
            WHEN (terminal.tradetype = 'C'::bpchar) THEN (COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric) * COALESCE(sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (0)::numeric
        END AS delta_adjusted_options_call_purchase,
        CASE
            WHEN (terminal.tradetype = 'P'::bpchar) THEN ((('-1'::integer)::numeric * COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric)) * COALESCE(sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (0)::numeric
        END AS delta_adjusted_options_put_purchase,
        CASE
            WHEN (terminal.tradetype = 'C'::bpchar) THEN ((('-1'::integer)::numeric * COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric)) * COALESCE(sum(public.sp_convert_qty((terminal.slots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (0)::numeric
        END AS delta_adjusted_options_call_sale,
        CASE
            WHEN (terminal.tradetype = 'P'::bpchar) THEN (COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric) * COALESCE(sum(public.sp_convert_qty((terminal.slots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (0)::numeric
        END AS delta_adjusted_options_put_sale
   FROM ((public.terminal
     JOIN public.futures_contract ON ((terminal.futconts = futures_contract.code)))
     CROSS JOIN public.params)
  WHERE ((terminal.tradetype = ANY (ARRAY['C'::bpchar, 'P'::bpchar])) AND (COALESCE(terminal.plots, terminal.slots) > (0)::numeric) AND (terminal.futconts <> 'GCCME'::bpchar))
  GROUP BY terminal.company, terminal.commodity, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series;


CREATE OR REPLACE VIEW public.phys_riskposn_sopex_options AS
 SELECT d.company,
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END AS market,
    d.commodity,
    d.vlposition AS valuedin,
        CASE
            WHEN (d.vlposition IS NULL) THEN '-Not Spec'::bpchar
            ELSE public.sp_prompt_month(d.vlposition)
        END AS valuedin_str,
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN c.vlposition
            ELSE d.vlposition
        END AS vlposition,
    public.sp_prompt_month(
        CASE
            WHEN (d.valn_type = 'P'::bpchar) THEN c.vlposition
            ELSE d.vlposition
        END) AS vlposition_str,
    sum(
        CASE
            WHEN ((d.price_fixing = 'N'::bpchar) AND (d.status = 'STOCK'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN ((c.vldifftype = '*'::bpchar) AND (d.commodity <> 'BEAN'::bpchar)) THEN COALESCE(c.vldiffer, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS stocks_priced,
    string_agg(DISTINCT (
        CASE
            WHEN ((d.price_fixing = 'N'::bpchar) AND (d.status = 'STOCK'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text, ', '::text ORDER BY ((
        CASE
            WHEN ((d.price_fixing = 'N'::bpchar) AND (d.status = 'STOCK'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text)) AS stocks_priced_contract_list,
    sum(
        CASE
            WHEN ((d.price_fixing = 'Y'::bpchar) AND (d.status = 'STOCK'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN ((c.vldifftype = '*'::bpchar) AND (d.commodity <> 'BEAN'::bpchar)) THEN COALESCE(c.vldiffer, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS stocks_unpriced,
    string_agg(DISTINCT (
        CASE
            WHEN ((d.price_fixing = 'Y'::bpchar) AND (d.status = 'STOCK'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text, ', '::text ORDER BY ((
        CASE
            WHEN ((d.price_fixing = 'Y'::bpchar) AND (d.status = 'STOCK'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text)) AS stocks_unpriced_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN ((c.vldifftype = '*'::bpchar) AND (d.commodity <> 'BEAN'::bpchar)) THEN COALESCE(c.vldiffer, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_priced_purchase,
    string_agg(DISTINCT (
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text, ', '::text ORDER BY ((
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text)) AS fwd_priced_purchase_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN ((c.vldifftype = '*'::bpchar) AND (d.commodity <> 'BEAN'::bpchar)) THEN COALESCE(c.vldiffer, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_unpriced_purchase,
    string_agg(DISTINCT (
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text, ', '::text ORDER BY ((
        CASE
            WHEN ((d.contract_type = 'P'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text)) AS fwd_unpriced_purchase_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN ((c.vldifftype = '*'::bpchar) AND (d.commodity <> 'BEAN'::bpchar)) THEN COALESCE(c.vldiffer, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_priced_sales,
    string_agg(DISTINCT (
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text, ', '::text ORDER BY ((
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'N'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text)) AS fwd_priced_sales_contract_list,
    sum(
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN (((
            CASE
                WHEN (d.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)) * COALESCE(
            CASE
                WHEN ((c.vldifftype = '*'::bpchar) AND (d.commodity <> 'BEAN'::bpchar)) THEN COALESCE(c.vldiffer, (1)::numeric)
                ELSE (1)::numeric
            END, (1)::numeric))
            ELSE (0)::numeric
        END) AS fwd_unpriced_sales,
    string_agg(DISTINCT (
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text, ', '::text ORDER BY ((
        CASE
            WHEN ((d.contract_type = 'S'::bpchar) AND (d.price_fixing = 'Y'::bpchar) AND (d.status = 'FORWARD'::text)) THEN d.contno
            ELSE NULL::bpchar
        END)::text)) AS fwd_unpriced_sales_contract_list,
    0 AS excg_purchase,
    0 AS excg_sale,
    0 AS options_purchase,
    0 AS options_sale,
    0 AS delta_adjusted_options_purchase,
    0 AS delta_adjusted_options_sale
   FROM ((public.phys_pricing_riskposn d
     LEFT JOIN public.val_differentials c ON (((d.company = c.company) AND (d.pcentre = c.pcentre) AND (d.commodity = c.commodity) AND (d.commodtype = c.commodtype) AND (d.origin = c.origin) AND (d.quality = c.quality) AND (d.valuedin = c.valuedin))))
     CROSS JOIN public.params)
  WHERE (d.openqnt > (0)::numeric)
  GROUP BY d.company, d.commodity,
        CASE
            WHEN (d.vlcontract = 'NY46'::bpchar) THEN 'NYCF'::bpchar
            ELSE d.vlcontract
        END, d.vlposition, d.valn_type, c.vlposition
UNION
 SELECT terminal.company,
    terminal.futconts AS market,
    terminal.commodity,
    terminal.prompt AS valuedin,
    public.sp_prompt_month(terminal.prompt) AS valuedin_str,
    terminal.prompt AS vlposition,
    public.sp_prompt_month(terminal.prompt) AS vlposition_str,
    0 AS stocks_priced,
    ''::text AS stocks_priced_contract_list,
    0 AS stocks_unpriced,
    ''::text AS stocks_unpriced_contract_list,
    0 AS fwd_priced_purchase,
    ''::text AS fwd_priced_purchase_contract_list,
    0 AS fwd_unpriced_purchase,
    ''::text AS fwd_unpriced_purchase_contract_list,
    0 AS fwd_priced_sales,
    ''::text AS fwd_priced_sales_contract_list,
    0 AS fwd_unpriced_sales,
    ''::text AS fwd_unpriced_sales_contract_list,
    sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)) AS excg_purchase,
    sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.slots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)) AS excg_sale,
    0 AS options_purchase,
    0 AS options_sale,
    0 AS delta_adjusted_options_purchase,
    0 AS delta_adjusted_options_sale
   FROM ((public.terminal
     JOIN public.futures_contract ON ((terminal.futconts = futures_contract.code)))
     CROSS JOIN public.params)
  WHERE ((terminal.tradetype = 'F'::bpchar) AND (COALESCE(terminal.plots, terminal.slots) > (0)::numeric) AND (terminal.futconts <> 'GCCME'::bpchar))
  GROUP BY terminal.company, terminal.commodity, terminal.futconts, terminal.prompt
UNION
 SELECT terminal.company,
    terminal.futconts AS market,
    terminal.commodity,
    terminal.prompt AS valuedin,
    public.sp_prompt_month(terminal.prompt) AS valuedin_str,
    terminal.prompt AS vlposition,
    public.sp_prompt_month(terminal.prompt) AS vlposition_str,
    0 AS stocks_priced,
    ''::text AS stocks_priced_contract_list,
    0 AS stocks_unpriced,
    ''::text AS stocks_unpriced_contract_list,
    0 AS fwd_priced_purchase,
    ''::text AS fwd_priced_purchase_contract_list,
    0 AS fwd_unpriced_purchase,
    ''::text AS fwd_unpriced_purchase_contract_list,
    0 AS fwd_priced_sales,
    ''::text AS fwd_priced_sales_contract_list,
    0 AS fwd_unpriced_sales,
    ''::text AS fwd_unpriced_sales_contract_list,
    0 AS excg_purchase,
    0 AS excg_sale,
        CASE
            WHEN (terminal.tradetype = 'C'::bpchar) THEN COALESCE(sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric)
            ELSE COALESCE(sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.plots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric)
        END AS options_purchase,
        CASE
            WHEN (terminal.tradetype = 'P'::bpchar) THEN COALESCE(sum(public.sp_convert_qty((terminal.slots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric)
            ELSE COALESCE(sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.slots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric)
        END AS options_sale,
        CASE
            WHEN (terminal.tradetype = 'C'::bpchar) THEN (COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric) * COALESCE(sum(public.sp_convert_qty((terminal.plots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric) * COALESCE(sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.plots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
        END AS delta_adjusted_options_purchase,
        CASE
            WHEN (terminal.tradetype = 'P'::bpchar) THEN (COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric) * COALESCE(sum(public.sp_convert_qty((terminal.slots * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
            ELSE (COALESCE(abs(public.sp_term_get_options_delta(CURRENT_DATE, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series)), (0)::numeric) * COALESCE(sum(public.sp_convert_qty(((('-1'::integer)::numeric * terminal.slots) * futures_contract.lotfactor), futures_contract.unit, params.base_unit)), (0)::numeric))
        END AS delta_adjusted_options_sale
   FROM ((public.terminal
     JOIN public.futures_contract ON ((terminal.futconts = futures_contract.code)))
     CROSS JOIN public.params)
  WHERE ((terminal.tradetype = ANY (ARRAY['C'::bpchar, 'P'::bpchar])) AND (COALESCE(terminal.plots, terminal.slots) > (0)::numeric) AND (terminal.futconts <> 'GCCME'::bpchar))
  GROUP BY terminal.company, terminal.commodity, terminal.futconts, terminal.prompt, terminal.tradetype, terminal.series;


CREATE OR REPLACE VIEW public.phys_valn_view AS
 WITH base AS (
         SELECT d.company,
            d.pcentre,
            d.commodity,
            d.commodtype,
            d.origin,
            d.quality,
            d.valuedin,
            public.sp_prompt_month(d.valuedin) AS valuedin_str,
            d.contno,
            d.split,
            d.contract_type,
            d.contdate,
            d.client,
            d.priceterm,
            d.prcst_location,
            d.payterm,
            d.shipfrom,
            d.shipto,
            d.ship_desc,
            d.openqnt,
            d.quantunit,
            d.original AS origqnt,
            d.unitprice,
            d.status,
            d.flag,
                CASE d.flag
                    WHEN 'FW_FIX'::text THEN 'Priced'::text
                    WHEN 'FW_PFUNFIX'::text THEN 'Unpriced'::text
                    WHEN 'FW_PFFIX'::text THEN 'Priced'::text
                    WHEN 'ST_FIX'::text THEN 'Priced'::text
                    WHEN 'ST_PFUNFIX'::text THEN 'Unpriced'::text
                    WHEN 'ST_PFFIX'::text THEN 'Priced'::text
                    ELSE 'Fixed'::text
                END AS fixed_unfixed_flag,
            public.sp_contno_fully_allocated_fixed(d.contno, d.split) AS unfixed_unallocated_flag,
            d.est_fx_rate,
            d.cddifftype,
            d.cddiffer,
            d.original_pfdifftype,
            d.original_pfdiffer,
                CASE
                    WHEN (d.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
                END AS base_openqnt,
                CASE
                    WHEN (d.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(d.original, d.quantunit, params.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(d.original, d.quantunit, params.base_unit))
                END AS base_origqnt,
            params.base_unit,
            d.price_fixing,
            d.currency,
            d.priceunit,
            d.pfcontract,
            d.pfposition,
            d.pfdifftype,
            d.pfdiffer,
            d.pfdiffcurr,
            d.pfdiffunit,
            public.sp_pricestr_mmyy(d.price_fixing, d.unitprice, d.currency, d.priceunit, d.pfcontract, d.pfposition, d.pfdifftype, d.pfdiffer, d.pfdiffcurr, d.pfdiffunit) AS price_string,
            d.valn_type AS ct_valn_type,
            d.valn_price AS ct_valn_price,
            d.valn_curr AS ct_valn_curr,
            d.valn_unit AS ct_valn_unit,
            d.vlcontract AS ct_vlcontract,
            d.vlposition AS ct_vlposition,
            d.vldifftype AS ct_vldifftype,
            d.vldiffer AS ct_vldiffer,
            d.vldiffcurr AS ct_vldiffcurr,
            d.vldiffunit AS ct_vldiffunit,
            c_1.valn_type AS ps_valn_type,
            c_1.valn_price AS ps_valn_price,
            c_1.valn_curr AS ps_valn_curr,
            c_1.valn_unit AS ps_valn_unit,
            c_1.vlcontract AS ps_vlcontract,
            c_1.vlposition AS ps_vlposition,
            c_1.vldifftype AS ps_vldifftype,
            c_1.vldiffer AS ps_vldiffer,
            c_1.vldiffcurr AS ps_vldiffcurr,
            c_1.vldiffunit AS ps_vldiffunit,
            c_1.valn_type AS c_valn_type,
            c_1.valn_price AS c_valn_price,
            c_1.valn_curr AS c_valn_curr,
            c_1.valn_unit AS c_valn_unit,
            c_1.vlcontract AS c_vlcontract,
            c_1.vlposition AS c_vlposition,
            c_1.vldifftype AS c_vldifftype,
            c_1.vldiffer AS c_vldiffer,
            c_1.vldiffcurr AS c_vldiffcurr,
            c_1.vldiffunit AS c_vldiffunit,
            params.base_currency,
            params.systemdate
           FROM ((public.val_differentials c_1
             JOIN public.phys_pricing d ON (((d.company = c_1.company) AND (d.pcentre = c_1.pcentre) AND (d.commodity = c_1.commodity) AND (d.commodtype = c_1.commodtype) AND (d.origin = c_1.origin) AND (d.quality = c_1.quality) AND (d.valuedin = c_1.valuedin))))
             CROSS JOIN public.params)
        ), computed AS (
         SELECT b.company,
            b.pcentre,
            b.commodity,
            b.commodtype,
            b.origin,
            b.quality,
            b.valuedin,
            b.valuedin_str,
            b.contno,
            b.split,
            b.contract_type,
            b.contdate,
            b.client,
            b.priceterm,
            b.prcst_location,
            b.payterm,
            b.shipfrom,
            b.shipto,
            b.ship_desc,
            b.openqnt,
            b.quantunit,
            b.origqnt,
            b.unitprice,
            b.status,
            b.flag,
            b.fixed_unfixed_flag,
            b.unfixed_unallocated_flag,
            b.est_fx_rate,
            b.cddifftype,
            b.cddiffer,
            b.original_pfdifftype,
            b.original_pfdiffer,
            b.base_openqnt,
            b.base_origqnt,
            b.base_unit,
            b.price_fixing,
            b.currency,
            b.priceunit,
            b.pfcontract,
            b.pfposition,
            b.pfdifftype,
            b.pfdiffer,
            b.pfdiffcurr,
            b.pfdiffunit,
            b.price_string,
            b.ct_valn_type,
            b.ct_valn_price,
            b.ct_valn_curr,
            b.ct_valn_unit,
            b.ct_vlcontract,
            b.ct_vlposition,
            b.ct_vldifftype,
            b.ct_vldiffer,
            b.ct_vldiffcurr,
            b.ct_vldiffunit,
            b.ps_valn_type,
            b.ps_valn_price,
            b.ps_valn_curr,
            b.ps_valn_unit,
            b.ps_vlcontract,
            b.ps_vlposition,
            b.ps_vldifftype,
            b.ps_vldiffer,
            b.ps_vldiffcurr,
            b.ps_vldiffunit,
            b.c_valn_type,
            b.c_valn_price,
            b.c_valn_curr,
            b.c_valn_unit,
            b.c_vlcontract,
            b.c_vlposition,
            b.c_vldifftype,
            b.c_vldiffer,
            b.c_vldiffcurr,
            b.c_vldiffunit,
            b.base_currency,
            b.systemdate,
                CASE
                    WHEN (b.ct_valn_type = 'P'::bpchar) THEN public.sp_pricestr_mmyy((
                    CASE
                        WHEN (b.c_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.c_valn_price, b.c_valn_curr, b.c_valn_unit, b.c_vlcontract, b.c_vlposition, b.c_vldifftype, b.c_vldiffer, b.c_vldiffcurr, b.c_vldiffunit)
                    ELSE public.sp_pricestr_mmyy((
                    CASE
                        WHEN (b.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.ct_valn_price, b.ct_valn_curr, b.ct_valn_unit, b.ct_vlcontract, b.ct_vlposition, b.ct_vldifftype, b.ct_vldiffer, b.ct_vldiffcurr, b.ct_vldiffunit)
                END AS valn_string,
            (public.sp_calc_value(b.openqnt, b.quantunit, b.price_fixing, b.unitprice, b.currency, b.priceunit, b.pfcontract, b.pfposition, b.pfdifftype, b.pfdiffer, b.pfdiffcurr, b.pfdiffunit, b.base_currency, b.systemdate) * (
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END)::numeric) AS phys_value,
            (
                CASE
                    WHEN (b.ct_valn_type = 'P'::bpchar) THEN public.sp_calc_value(b.openqnt, b.quantunit, (
                    CASE
                        WHEN (b.c_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.c_valn_price, b.c_valn_curr, b.c_valn_unit, b.c_vlcontract, b.c_vlposition, b.c_vldifftype, b.c_vldiffer, b.c_vldiffcurr, b.c_vldiffunit, b.base_currency, b.systemdate)
                    ELSE public.sp_calc_value(b.openqnt, b.quantunit, (
                    CASE
                        WHEN (b.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.ct_valn_price, b.ct_valn_curr, b.ct_valn_unit, b.ct_vlcontract, b.ct_vlposition, b.ct_vldifftype, b.ct_vldiffer, b.ct_vldiffcurr, b.ct_vldiffunit, b.base_currency, b.systemdate)
                END * (
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END)::numeric) AS valn_value,
            public.sp_phys_valn_term(b.contno, b.split, b.openqnt, b.origqnt, b.base_currency, b.systemdate) AS term_pandl,
            public.sp_phys_valn_fx(b.contno, b.split, b.openqnt, b.origqnt, b.base_currency, b.systemdate) AS fx_pandl,
            public.sp_phys_valn_resvs(b.contno, b.split, public.sp_convert_qty(b.openqnt, b.quantunit, b.base_unit), b.base_unit, public.sp_convert_qty(b.origqnt, b.quantunit, b.base_unit), public.sp_calc_value(b.openqnt, b.quantunit, b.price_fixing, b.unitprice, b.currency, b.priceunit, b.pfcontract, b.pfposition, b.pfdifftype, b.pfdiffer, b.pfdiffcurr, b.pfdiffunit, b.base_currency, b.systemdate), b.base_currency, b.systemdate) AS resvs_pandl
           FROM base b
        )
 SELECT company,
    pcentre,
    commodity,
    commodtype,
    origin,
    quality,
    valuedin,
    valuedin_str,
    contno,
    split,
    contract_type,
    contdate,
    client,
    priceterm,
    prcst_location,
    payterm,
    shipfrom,
    shipto,
    ship_desc,
    openqnt,
    quantunit,
    origqnt,
    unitprice,
    status,
    flag,
    fixed_unfixed_flag,
    unfixed_unallocated_flag,
    est_fx_rate,
    cddifftype,
    cddiffer,
    original_pfdifftype,
    original_pfdiffer,
    base_openqnt,
    base_origqnt,
    base_unit AS sysbaseunit,
    price_fixing,
    currency,
    priceunit,
    pfcontract,
    pfposition,
    pfdifftype,
    pfdiffer,
    pfdiffcurr,
    pfdiffunit,
    price_string,
    ct_valn_type,
    ct_valn_price,
    ct_valn_curr,
    ct_valn_unit,
    ct_vlcontract,
    ct_vlposition,
    ct_vldifftype,
    ct_vldiffer,
    ct_vldiffcurr,
    ct_vldiffunit,
    ps_valn_type,
    ps_valn_price,
    ps_valn_curr,
    ps_valn_unit,
    ps_vlcontract,
    ps_vlposition,
    ps_vldifftype,
    ps_vldiffer,
    ps_vldiffcurr,
    ps_vldiffunit,
    valn_string,
    base_currency AS sysbasecurr,
    phys_value,
    valn_value,
    (valn_value - phys_value) AS phys_pandl,
    term_pandl,
    fx_pandl,
    resvs_pandl,
    ((((valn_value - phys_value) + term_pandl) + fx_pandl) + resvs_pandl) AS net_pandl
   FROM computed c;


CREATE OR REPLACE VIEW public.phys_valn_view_valn_sopex_optimised AS
 SELECT d.company,
    d.pcentre,
    d.commodity,
    d.commodtype,
    d.origin,
    d.quality,
    d.valuedin,
    public.sp_prompt_month(d.valuedin) AS valuedin_str,
    d.contno,
    d.split,
    d.contract_type,
    d.contdate,
    d.client,
    d.priceterm,
    d.prcst_location,
    d.payterm,
    d.shipfrom,
    d.shipto,
    d.ship_desc,
    d.shipordelv,
    d.certification,
    d.eudr_flag,
    d.openqnt,
    d.quantunit,
    d.original AS origqnt,
    d.unitprice,
    d.status,
    d.flag,
        CASE d.flag
            WHEN 'FIX'::text THEN 'Priced'::text
            WHEN 'PFUNFIX'::text THEN 'Unpriced'::text
            WHEN 'PFFIX'::text THEN 'Priced'::text
            ELSE 'Fixed'::text
        END AS fixed_unfixed_flag,
    ( SELECT phys_avail.unfixed
           FROM public.phys_avail
          WHERE ((phys_avail.contno = d.contno) AND (phys_avail.split = d.split))) AS unfixed_quantity,
        CASE
            WHEN (( SELECT phys_avail.unfixed
               FROM public.phys_avail
              WHERE ((phys_avail.contno = d.contno) AND (phys_avail.split = d.split))) > (0)::numeric) THEN 'Y'::text
            ELSE 'N'::text
        END AS is_contract_unfixed,
    d.true_open,
    d.est_fx_rate,
    d.cddifftype,
    d.cddiffer,
    d.original_price_fixing,
    d.original_pfdifftype,
    d.original_pfdiffer,
    d.original_pfposition,
    d.base_openqnt,
    'MT'::text AS sysbaseunit,
    d.price_fixing,
    d.currency,
    d.priceunit,
    d.pfcontract,
    d.pfposition,
    d.pfdifftype,
    d.pfdiffer,
    d.pfdiffcurr,
    d.pfdiffunit,
    d.valn_type AS ct_valn_type,
    d.valn_price AS ct_valn_price,
    d.valn_curr AS ct_valn_curr,
    d.valn_unit AS ct_valn_unit,
    d.vlcontract AS ct_vlcontract,
    d.vlposition AS ct_vlposition,
    d.vldifftype AS ct_vldifftype,
    d.vldiffer AS ct_vldiffer,
    d.vldiffcurr AS ct_vldiffcurr,
    d.vldiffunit AS ct_vldiffunit,
    d.chosen_vlposition,
    d.chosen_vlcontract,
    d.chosen_vldifftype,
    d.chosen_vldiffer,
    d.chosen_vldiffcurr,
    d.chosen_vldiffunit,
    d.price_fixing_diff_string,
    d.valn_string,
    d.valn_month,
    params.base_currency AS sysbasecurr,
    d.phys_value,
    d.valn_value,
    d.costs_per_base_unit,
    d.unit_to_mt_conversation_factor,
    d.currency_to_basecurr_conversion_factor,
    d.unit_price_basecurr_mt,
    d.final_price_basecurr_mt,
    d.valuation_price_basecurr_mt,
    d.tracking_unpriced,
    ((d.valuation_price_basecurr_mt - d.final_price_basecurr_mt) * d.base_openqnt) AS valn_result,
        CASE
            WHEN (d.contract_type = 'P'::bpchar) THEN ((d.valuation_price_basecurr_mt - d.final_price_basecurr_mt) * d.base_openqnt)
            ELSE (0)::numeric
        END AS purch_valn_result,
        CASE
            WHEN (d.contract_type = 'P'::bpchar) THEN (0)::numeric
            ELSE ((d.valuation_price_basecurr_mt - d.final_price_basecurr_mt) * d.base_openqnt)
        END AS sales_valn_result
   FROM (public.phys_pricing_valn_sopex_full_report d
     CROSS JOIN public.params)
  WHERE (d.true_open > (0)::numeric);


CREATE OR REPLACE VIEW public.physical_trading_browser_underlying_level2_view AS
 SELECT phys_valn_view_valn_sopex.company,
    phys_valn_view_valn_sopex.pcentre,
    phys_valn_view_valn_sopex.commodity,
    phys_valn_view_valn_sopex.commodtype,
    commodity_type.longname AS commodtype_longname,
    phys_valn_view_valn_sopex.origin,
    phys_valn_view_valn_sopex.quality,
    commodity_type.longname AS comm_description,
    phys_valn_view_valn_sopex.contno,
    phys_valn_view_valn_sopex.split,
    phys_valn_view_valn_sopex.contract_type AS conttype,
    phys_valn_view_valn_sopex.contdate,
    'Alloc & Fixed'::text AS allocated_fixed_flag,
    'Unallocated OR Alloc but Unfixed'::text AS unallocated_fixed_flag,
    phys_valn_view_valn_sopex.client,
    client.country AS client_country,
    phys_valn_view_valn_sopex.certification,
    sub_contracts.eudr_flag,
    sub_contracts.eudr_date_harvest,
    phys_valn_view_valn_sopex.shipfrom,
    phys_valn_view_valn_sopex.shipto,
        CASE
            WHEN (phys_valn_view_valn_sopex.shipordelv = 'S'::bpchar) THEN ((to_char((phys_valn_view_valn_sopex.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((phys_valn_view_valn_sopex.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS ship_period,
        CASE
            WHEN (phys_valn_view_valn_sopex.shipordelv = 'D'::bpchar) THEN ((to_char((phys_valn_view_valn_sopex.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((phys_valn_view_valn_sopex.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS delivery_period,
    phys_valn_view_valn_sopex.shipordelv,
    COALESCE(public.sp_prompt_month(sub_contracts.pfposition), ''::bpchar) AS cp_pfposition_str,
    phys_valn_view_valn_sopex.priceterm,
    phys_valn_view_valn_sopex.prcst_location,
    phys_valn_view_valn_sopex.payterm AS payment_term,
    phys_valn_view_valn_sopex.chosen_vlcontract AS vlcontract,
    phys_valn_view_valn_sopex.chosen_vlposition AS valuedin,
    public.sp_prompt_month(phys_valn_view_valn_sopex.chosen_vlposition) AS cp_valuedin_str,
    ((((((phys_valn_view_valn_sopex.chosen_vldifftype)::text || ((phys_valn_view_valn_sopex.chosen_vldiffer)::numeric(10,2))::text) || ' '::text) || (phys_valn_view_valn_sopex.chosen_vldiffcurr)::text) || '/'::text) || (phys_valn_view_valn_sopex.chosen_vldiffunit)::text) AS valn_string,
    phys_valn_view_valn_sopex.valn_month,
    params.systemdate,
    phys_valn_view_valn_sopex.true_open AS open_quantity,
    public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar) AS base_openqnt,
    0 AS base_allocated,
    0 AS allocated_unfixed_tonnage,
        CASE
            WHEN (phys_valn_view_valn_sopex.contract_type = 'P'::bpchar) THEN (abs(public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar)) - (abs(0))::numeric)
            ELSE ((abs(public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar)) - (abs(0))::numeric) * ('-1'::integer)::numeric)
        END AS base_unallocated,
    public.sp_list_allocated_contracts_details_fixed(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS allocated_to_contracts_details,
    public.sp_list_allocated_contracts_details_unfixed(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS unallocated_to_contracts_details,
        CASE
            WHEN (phys_valn_view_valn_sopex.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(public.sp_list_allocated_contracts_details_unfixed_invq(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'Q'::bpchar), phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(public.sp_list_allocated_contracts_details_unfixed_invq(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'Q'::bpchar), phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS base_invoiced,
    ''::text AS invoiced_status,
    public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar) AS unquantity_tonnage,
    public.sp_contract_shipment_statuses(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS shipment_statuses,
    public.sp_contract_shipment_etd_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'S'::bpchar) AS shipment_etd,
    public.sp_contract_shipment_etd_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'L'::bpchar) AS shipment_etd_list,
    public.sp_contract_shipment_eta_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'S'::bpchar) AS shipment_eta,
    public.sp_contract_shipment_eta_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'L'::bpchar) AS shipment_eta_list,
    ( SELECT string_agg(DISTINCT (stocks.warehouse)::text, ', '::text) AS string_agg
           FROM public.stocks
          WHERE ((stocks.contno = phys_valn_view_valn_sopex.contno) AND (stocks.split = phys_valn_view_valn_sopex.split))) AS stock_warehouses,
    public.sp_list_allocated_contracts_unpaid_sales_invoices_unfixed(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS unsettled_provisional_invoices,
    public.sp_contract_shipment_eudr_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'TEXT'::bpchar) AS contract_shipment_eudr_info,
    public.sp_contract_shipment_eudr_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'STATUS'::bpchar) AS contract_shipment_eudr_status,
    phys_valn_view_valn_sopex.quantunit,
    'OPEN'::text AS row_marker
   FROM (((((public.phys_valn_view_valn_sopex
     JOIN public.sub_contracts ON (((phys_valn_view_valn_sopex.contno = sub_contracts.contno) AND (phys_valn_view_valn_sopex.split = sub_contracts.split))))
     JOIN public.commodity_type ON ((phys_valn_view_valn_sopex.commodtype = commodity_type.code)))
     JOIN public.quality ON ((phys_valn_view_valn_sopex.quality = quality.code)))
     JOIN public.client ON ((phys_valn_view_valn_sopex.client = client.code)))
     CROSS JOIN public.params)
  WHERE (phys_valn_view_valn_sopex.true_open > (0)::numeric)
UNION ALL
 SELECT master_contracts.company,
    master_contracts.pcentre,
    master_contracts.commodity,
    master_contracts.commodtype,
    commodity_type.longname AS commodtype_longname,
    master_contracts.origin,
    master_contracts.quality,
    commodity_type.longname AS comm_description,
    sub_contracts.contno,
    sub_contracts.split,
    master_contracts.contract_type AS conttype,
    master_contracts.contdate,
    'Alloc & Fixed'::text AS allocated_fixed_flag,
    'Unallocated OR Alloc but Unfixed'::text AS unallocated_fixed_flag,
    master_contracts.client,
    client.country AS client_country,
    sub_contracts.certification,
    sub_contracts.eudr_flag,
    sub_contracts.eudr_date_harvest,
    sub_contracts.shipfrom,
    sub_contracts.shipto,
        CASE
            WHEN (sub_contracts.shipordelv = 'S'::bpchar) THEN ((to_char((sub_contracts.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((sub_contracts.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS ship_period,
        CASE
            WHEN (sub_contracts.shipordelv = 'D'::bpchar) THEN ((to_char((sub_contracts.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((sub_contracts.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS delivery_period,
    sub_contracts.shipordelv,
    COALESCE(public.sp_prompt_month(sub_contracts.pfposition), ''::bpchar) AS cp_pfposition_str,
    master_contracts.priceterm,
    master_contracts.prcstlocn AS prcst_location,
    master_contracts.payterm AS payment_term,
    sub_contracts.vlcontract,
    sub_contracts.vlposition AS valuedin,
    public.sp_prompt_month(sub_contracts.vlposition) AS cp_valuedin_str,
        CASE
            WHEN (sub_contracts.valn_type = 'F'::bpchar) THEN ((((((sub_contracts.valn_price)::numeric(10,2))::text || ' '::text) || (sub_contracts.valn_curr)::text) || '/'::text) || (sub_contracts.valn_unit)::text)
            ELSE ((((((sub_contracts.vldifftype)::text || ((sub_contracts.vldiffer)::numeric(10,2))::text) || ' '::text) || (sub_contracts.vldiffcurr)::text) || '/'::text) || (sub_contracts.vldiffunit)::text)
        END AS valn_string,
    sub_contracts.vlposition AS valn_month,
    params.systemdate,
        CASE
            WHEN (master_contracts.contract_type = 'S'::bpchar) THEN (sum(physical_trading_browser_underlying_level1_view.alloc_quantity) * ('-1'::integer)::numeric)
            ELSE sum(physical_trading_browser_underlying_level1_view.alloc_quantity)
        END AS open_quantity,
    sum(physical_trading_browser_underlying_level1_view.base_alloc_quantity) AS base_openqnt,
    sum(physical_trading_browser_underlying_level1_view.base_alloc_quantity) AS base_allocated,
    0 AS allocated_unfixed_tonnage,
    0 AS base_unallocated,
    public.sp_list_allocated_contracts_details_fixed(sub_contracts.contno, sub_contracts.split) AS allocated_to_contracts_details,
    public.sp_list_allocated_contracts_details_unfixed(sub_contracts.contno, sub_contracts.split) AS unallocated_to_contracts_details,
        CASE
            WHEN (master_contracts.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(public.sp_list_allocated_contracts_details_fixed_invq(sub_contracts.contno, sub_contracts.split, 'Q'::bpchar), sub_contracts.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(public.sp_list_allocated_contracts_details_fixed_invq(sub_contracts.contno, sub_contracts.split, 'Q'::bpchar), sub_contracts.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS base_invoiced,
    ''::text AS invoiced_status,
    0 AS unquantity_tonnage,
    public.sp_contract_shipment_statuses(sub_contracts.contno, sub_contracts.split) AS shipment_statuses,
    public.sp_contract_shipment_etd_info(sub_contracts.contno, sub_contracts.split, 'S'::bpchar) AS shipment_etd,
    public.sp_contract_shipment_etd_info(sub_contracts.contno, sub_contracts.split, 'L'::bpchar) AS shipment_etd_list,
    public.sp_contract_shipment_eta_info(sub_contracts.contno, sub_contracts.split, 'S'::bpchar) AS shipment_eta,
    public.sp_contract_shipment_eta_info(sub_contracts.contno, sub_contracts.split, 'L'::bpchar) AS shipment_eta_list,
    ( SELECT string_agg(DISTINCT (stocks.warehouse)::text, ', '::text) AS string_agg
           FROM public.stocks
          WHERE ((stocks.contno = sub_contracts.contno) AND (stocks.split = sub_contracts.split))) AS stock_warehouses,
    public.sp_list_allocated_contracts_unpaid_sales_invoices_fixed(sub_contracts.contno, sub_contracts.split) AS unsettled_provisional_invoices,
    public.sp_contract_shipment_eudr_info(sub_contracts.contno, sub_contracts.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'TEXT'::bpchar) AS contract_shipment_eudr_info,
    public.sp_contract_shipment_eudr_info(sub_contracts.contno, sub_contracts.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'STATUS'::bpchar) AS contract_shipment_eudr_status,
    sub_contracts.quantunit,
    'ALLOC'::text AS row_marker
   FROM (((((public.physical_trading_browser_underlying_level1_view
     JOIN public.sub_contracts ON (((sub_contracts.contno = physical_trading_browser_underlying_level1_view.contno) AND (sub_contracts.split = physical_trading_browser_underlying_level1_view.split))))
     JOIN public.master_contracts ON ((sub_contracts.contno = master_contracts.contno)))
     JOIN public.commodity_type ON ((master_contracts.commodtype = commodity_type.code)))
     JOIN public.client ON ((sub_contracts.client = client.code)))
     CROSS JOIN public.params)
  GROUP BY master_contracts.company, master_contracts.pcentre, master_contracts.commodity, master_contracts.commodtype, commodity_type.longname, master_contracts.origin, master_contracts.quality, sub_contracts.contno, sub_contracts.split, master_contracts.contract_type, master_contracts.contdate, master_contracts.client, client.country, sub_contracts.certification, sub_contracts.eudr_flag, sub_contracts.eudr_date_harvest, sub_contracts.quantunit, sub_contracts.shipfrom, sub_contracts.shipto, sub_contracts.shipordelv, master_contracts.priceterm, master_contracts.prcstlocn, master_contracts.payterm, sub_contracts.vlcontract, sub_contracts.vlposition, sub_contracts.valn_type, sub_contracts.valn_price, sub_contracts.valn_curr, sub_contracts.valn_unit, sub_contracts.vldifftype, sub_contracts.vldiffer, sub_contracts.vldiffcurr, sub_contracts.vldiffunit, sub_contracts.pfposition, params.systemdate;


CREATE OR REPLACE VIEW public.physical_trading_browser_underlying_level3_view AS
 WITH agg AS (
         SELECT l2.company,
            l2.pcentre,
            l2.commodity,
            l2.commodtype,
            l2.commodtype_longname,
            l2.origin,
            l2.quality,
            l2.comm_description,
            l2.contno,
            l2.split,
            l2.conttype,
            l2.contdate,
            l2.allocated_fixed_flag,
            l2.unallocated_fixed_flag,
            l2.client,
            l2.client_country,
            l2.certification,
            l2.eudr_flag,
            l2.eudr_date_harvest,
            l2.shipfrom,
            l2.shipto,
            l2.ship_period,
            l2.delivery_period,
            l2.shipordelv,
            l2.cp_pfposition_str,
            l2.priceterm,
            l2.prcst_location,
            l2.payment_term,
            l2.vlcontract,
            l2.valuedin,
            l2.cp_valuedin_str,
            l2.valn_string,
            l2.valn_month,
            l2.systemdate,
            l2.quantunit,
            l2.allocated_to_contracts_details,
            l2.unallocated_to_contracts_details,
            l2.shipment_statuses,
            l2.shipment_etd,
            l2.shipment_etd_list,
            l2.shipment_eta,
            l2.shipment_eta_list,
            l2.stock_warehouses,
            l2.unsettled_provisional_invoices,
            l2.contract_shipment_eudr_info,
            l2.contract_shipment_eudr_status,
            sum(l2.open_quantity) AS sum_open_quantity,
            sum(l2.base_openqnt) AS sum_base_openqnt,
            sum(l2.base_allocated) AS sum_base_allocated,
            sum(l2.base_invoiced) AS sum_base_invoiced,
            sum(l2.unquantity_tonnage) AS sum_unquantity_tonnage
           FROM public.physical_trading_browser_underlying_level2_view l2
          GROUP BY l2.company, l2.pcentre, l2.commodity, l2.commodtype, l2.commodtype_longname, l2.origin, l2.quality, l2.comm_description, l2.contno, l2.split, l2.conttype, l2.contdate, l2.allocated_fixed_flag, l2.unallocated_fixed_flag, l2.client, l2.client_country, l2.certification, l2.eudr_flag, l2.eudr_date_harvest, l2.shipfrom, l2.shipto, l2.ship_period, l2.delivery_period, l2.shipordelv, l2.cp_pfposition_str, l2.priceterm, l2.prcst_location, l2.payment_term, l2.vlcontract, l2.valuedin, l2.cp_valuedin_str, l2.valn_string, l2.valn_month, l2.systemdate, l2.quantunit, l2.allocated_to_contracts_details, l2.unallocated_to_contracts_details, l2.shipment_statuses, l2.shipment_etd, l2.shipment_etd_list, l2.shipment_eta, l2.shipment_eta_list, l2.stock_warehouses, l2.unsettled_provisional_invoices, l2.contract_shipment_eudr_info, l2.contract_shipment_eudr_status
        )
 SELECT company,
    pcentre,
    commodity,
    commodtype,
    commodtype_longname,
    origin,
    quality,
    comm_description,
    contno,
    split,
    conttype,
    contdate,
    allocated_fixed_flag,
    unallocated_fixed_flag,
    client,
    client_country,
    certification,
    eudr_flag,
    eudr_date_harvest,
    shipfrom,
    shipto,
    ship_period,
    delivery_period,
    shipordelv,
    cp_pfposition_str,
    priceterm,
    prcst_location,
    payment_term,
    vlcontract,
    valuedin,
    cp_valuedin_str,
    valn_string,
    valn_month,
    systemdate,
        CASE
            WHEN (conttype = 'P'::bpchar) THEN sum_open_quantity
            ELSE (('-1'::integer)::numeric * sum_open_quantity)
        END AS open_quantity,
    quantunit,
        CASE
            WHEN (conttype = 'P'::bpchar) THEN sum_base_openqnt
            ELSE (('-1'::integer)::numeric * sum_base_openqnt)
        END AS base_openqnt,
        CASE
            WHEN (conttype = 'P'::bpchar) THEN sum_base_allocated
            ELSE (('-1'::integer)::numeric * sum_base_allocated)
        END AS base_allocated,
        CASE
            WHEN (conttype = 'P'::bpchar) THEN public.sp_convert_qty(public.sp_allocation_calculate_only_normal_unfixed_alloc_quantity(contno, split), quantunit, 'MT'::bpchar)
            ELSE (('-1'::integer)::numeric * public.sp_convert_qty(public.sp_allocation_calculate_only_normal_unfixed_alloc_quantity(contno, split), quantunit, 'MT'::bpchar))
        END AS allocated_unfixed_tonnage,
        CASE
            WHEN (conttype = 'P'::bpchar) THEN ((
            CASE
                WHEN (conttype = 'P'::bpchar) THEN sum_base_openqnt
                ELSE (('-1'::integer)::numeric * sum_base_openqnt)
            END -
            CASE
                WHEN (conttype = 'P'::bpchar) THEN public.sp_convert_qty(public.sp_allocation_calculate_only_normal_unfixed_alloc_quantity(contno, split), quantunit, 'MT'::bpchar)
                ELSE (('-1'::integer)::numeric * public.sp_convert_qty(public.sp_allocation_calculate_only_normal_unfixed_alloc_quantity(contno, split), quantunit, 'MT'::bpchar))
            END) -
            CASE
                WHEN (conttype = 'P'::bpchar) THEN sum_base_allocated
                ELSE (('-1'::integer)::numeric * sum_base_allocated)
            END)
            ELSE (((abs(
            CASE
                WHEN (conttype = 'P'::bpchar) THEN sum_base_openqnt
                ELSE (('-1'::integer)::numeric * sum_base_openqnt)
            END) - abs(
            CASE
                WHEN (conttype = 'P'::bpchar) THEN public.sp_convert_qty(public.sp_allocation_calculate_only_normal_unfixed_alloc_quantity(contno, split), quantunit, 'MT'::bpchar)
                ELSE (('-1'::integer)::numeric * public.sp_convert_qty(public.sp_allocation_calculate_only_normal_unfixed_alloc_quantity(contno, split), quantunit, 'MT'::bpchar))
            END)) - abs(
            CASE
                WHEN (conttype = 'P'::bpchar) THEN sum_base_allocated
                ELSE (('-1'::integer)::numeric * sum_base_allocated)
            END)) * ('-1'::integer)::numeric)
        END AS base_unallocated,
    allocated_to_contracts_details,
    unallocated_to_contracts_details,
    sum_base_invoiced AS base_invoiced,
    (abs(
        CASE
            WHEN (conttype = 'P'::bpchar) THEN sum_base_openqnt
            ELSE (('-1'::integer)::numeric * sum_base_openqnt)
        END) - abs(sum_base_invoiced)) AS base_uninvoiced,
    ''::text AS invoiced_status,
    sum_unquantity_tonnage AS unquantity_tonnage,
    shipment_statuses,
    shipment_etd,
    shipment_etd_list,
    shipment_eta,
    shipment_eta_list,
    stock_warehouses,
    unsettled_provisional_invoices,
    contract_shipment_eudr_info,
    contract_shipment_eudr_status
   FROM agg a;


CREATE OR REPLACE VIEW public.physical_trading_browser_main_view AS
 SELECT company,
    pcentre,
    commodity,
    commodtype,
    commodtype_longname,
    origin,
    quality,
    comm_description,
    contno,
    split,
    conttype,
    contdate,
    allocated_fixed_flag,
    unallocated_fixed_flag,
    client,
    client_country,
    certification,
    eudr_flag,
    eudr_date_harvest,
    shipfrom,
    shipto,
    ship_period,
    delivery_period,
    shipordelv,
    cp_pfposition_str,
    priceterm,
    prcst_location,
    payment_term,
    vlcontract,
    valuedin,
    cp_valuedin_str,
    valn_string,
    valn_month,
    systemdate,
    open_quantity,
    base_openqnt,
    base_allocated,
    allocated_unfixed_tonnage,
        CASE
            WHEN (conttype = 'P'::bpchar) THEN ((base_openqnt - allocated_unfixed_tonnage) - base_allocated)
            ELSE (((abs(base_openqnt) - abs(allocated_unfixed_tonnage)) - abs(base_allocated)) * ('-1'::integer)::numeric)
        END AS base_unallocated,
    allocated_to_contracts_details,
    unallocated_to_contracts_details,
    base_invoiced,
    base_uninvoiced,
        CASE
            WHEN (base_invoiced = base_openqnt) THEN 'Fully Invoiced'::text
            ELSE
            CASE
                WHEN (base_invoiced = (0)::numeric) THEN 'Not invoiced'::text
                ELSE 'Partially invoiced'::text
            END
        END AS invoiced_status,
    unquantity_tonnage,
    shipment_statuses,
    shipment_etd,
    shipment_etd_list,
    shipment_eta,
    shipment_eta_list,
    stock_warehouses,
    unsettled_provisional_invoices,
    contract_shipment_eudr_info,
    contract_shipment_eudr_status
   FROM public.physical_trading_browser_underlying_level3_view l3;


