-- ============================================================
-- Forecast_Result_Accounts_04_View
-- Source: dba.Forecast_Result_Accounts_04_View
-- Sales reserves (contract reserves against allocations).
-- Not currently used; reserved for future Forecast rewrite.
-- No accdetail/accsummary/invoice joins; those columns are NULL.
-- Alias chains resolved via 3-level derived subquery:
--   s_b (inner): allocated_quantity (function), price_curr_unit (CASE),
--                ccf (4-branch reserves formula), invoice_priceunit
--   s_m (mid):   allocation_fixed_flag, total_forecast (USC handling),
--                invoiced_quantity (= allocated_quantity),
--                invoice_value (CASE amountind using allocated_quantity)
--   s_  (outer): total_forecast_base_curr (US% branch)
-- CCF 4-branch: reserves.currency = base → 1;
--   underlying <> base AND reserves.currency <> underlying → datedfxrate(reserves);
--   underlying <> base AND reserves.currency = underlying → fixes_fx_rate;
--   underlying = base AND reserves.currency <> underlying → datedfxrate(reserves);
--   else → 0
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_result_accounts_04_view AS

SELECT
    s_.order_flag,
    s_.order_label,
    s_.allocation_reference,
    s_.allocation_company,
    s_.alliocation_pcentre,
    s_.allocation_commodity,
    s_.allocation_commodity_type,
    s_.allocation_date,
    s_.allocation_total_sales_quantity,
    s_.allocation_total_unfixed,
    s_.allocation_fixed_flag,
    s_.contno,
    s_.split,
    s_.priceterm,
    s_.record_date,
    s_.contract_client,
    s_.allocated_quantity,
    s_.price_curr_unit,
    s_.currency,
    s_.priceunit,
    s_.total_forecast,
    CASE WHEN s_.currency LIKE 'US%'
         THEN s_.total_forecast
         ELSE s_.ccf * s_.total_forecast END                          AS total_forecast_base_curr,
    s_.invoice_heading,
    s_.invoice_order,
    s_.invoice_flag,
    s_.invoice_number,
    s_.invoice_date,
    s_.invoice_client,
    s_.invoice_text,
    s_.invoiced_quantity,
    s_.invoice_unit_price,
    s_.invoice_currency,
    s_.invoice_priceunit,
    s_.invoice_value,
    s_.signed_invoice_value,
    s_.posted_date,
    s_.posted_invoice_value,
    s_.contract_type,
    s_.allocation_completed,
    s_.allocation_completed_date,
    s_.invoice_house_rate,
    s_.ccf                                                            AS contract_currency_to_basecurr_conversion_factor,
    s_.stock_allocation_check,
    s_.manual_outb_expense_amount,
    s_.merged_line_splitter,
    s_.suggest_completed,
    s_.origin,
    s_.accperiod,
    s_.ledgernum,
    s_.linenum,
    s_.comments
FROM (
    SELECT
        s_b.order_flag,
        s_b.order_label,
        s_b.allocation_reference,
        s_b.allocation_company,
        s_b.alliocation_pcentre,
        s_b.allocation_commodity,
        s_b.allocation_commodity_type,
        s_b.allocation_date,
        s_b.allocation_total_sales_quantity,
        s_b.allocation_total_unfixed,
        CASE WHEN s_b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        s_b.contno,
        s_b.split,
        s_b.priceterm,
        s_b.record_date,
        s_b.contract_client,
        s_b.allocated_quantity,
        s_b.price_curr_unit,
        s_b.currency,
        s_b.priceunit,
        CASE WHEN s_b.currency LIKE 'US%'
             THEN CASE WHEN s_b.currency = 'USC'
                       THEN (s_b.price_curr_unit / public.sp_convert_qty(1, s_b.priceunit, s_b.base_unit) * 0.01)
                            * s_b.allocated_quantity
                       ELSE (s_b.price_curr_unit / public.sp_convert_qty(1, s_b.priceunit, s_b.base_unit))
                            * s_b.allocated_quantity
                  END
             ELSE (s_b.price_curr_unit / public.sp_convert_qty(1, s_b.priceunit, s_b.base_unit))
                  * s_b.allocated_quantity
        END                                                           AS total_forecast,
        s_b.invoice_heading,
        s_b.invoice_order,
        s_b.invoice_flag,
        s_b.invoice_number,
        s_b.invoice_date,
        s_b.invoice_client,
        s_b.invoice_text,
        s_b.allocated_quantity                                        AS invoiced_quantity,
        s_b.invoice_unit_price,
        s_b.invoice_currency,
        s_b.invoice_priceunit,
        CASE WHEN s_b.amountind = 'A'
             THEN s_b.reserve_amount
             ELSE s_b.reserve_amount
                  * public.sp_convert_qty(s_b.allocated_quantity, s_b.reserve_unit, 'MT')
        END                                                           AS invoice_value,
        s_b.signed_invoice_value,
        s_b.posted_date,
        s_b.posted_invoice_value,
        s_b.contract_type,
        s_b.allocation_completed,
        s_b.allocation_completed_date,
        s_b.invoice_house_rate,
        s_b.ccf,
        s_b.stock_allocation_check,
        s_b.manual_outb_expense_amount,
        s_b.merged_line_splitter,
        s_b.suggest_completed,
        s_b.origin,
        s_b.accperiod,
        s_b.ledgernum,
        s_b.linenum,
        s_b.comments
    FROM (
        SELECT
            '04'::text                                                 AS order_flag,
            'S Contract:'::text                                        AS order_label,
            allocation.allocation_reference,
            allocation.company                                         AS allocation_company,
            allocation.pcentre                                         AS alliocation_pcentre,
            allocation.commodity                                       AS allocation_commodity,
            allocation.commodity_type                                  AS allocation_commodity_type,
            (SELECT MIN(ah.hist_date) FROM public.allocation_history ah
             WHERE ah.allocation_reference = allocation.allocation_reference
               AND ah.hist_type = 'AN')                               AS allocation_date,
            (SELECT SUM(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'))
             FROM public.allocated_contracts a_c,
                  public.sub_contracts s_c,
                  public.master_contracts m_c
             WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
               AND s_c.contno = a_c.contno
               AND a_c.split = s_c.split
               AND s_c.contno = m_c.contno
               AND m_c.contract_type = 'S')                           AS allocation_total_sales_quantity,
            public.sp_phys_total_alloc_unfixed(
                allocation.allocation_reference)                       AS allocation_total_unfixed,
            sub_contracts.contno,
            sub_contracts.split,
            master_contracts.priceterm,
            master_contracts.contdate                                  AS record_date,
            sub_contracts.client                                       AS contract_client,
            public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'S'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            params.base_unit,
            'Sales Reserves:'::text                                    AS invoice_heading,
            '03'::text                                                 AS invoice_order,
            reserves.reserve                                           AS invoice_flag,
            'S Reserve'::text                                          AS invoice_number,
            NULL::date                                                 AS invoice_date,
            NULL::text                                                 AS invoice_client,
            reserves_types.longname                                    AS invoice_text,
            reserves.amount                                            AS invoice_unit_price,
            reserves.currency                                          AS invoice_currency,
            CASE WHEN reserves.amountind = 'A' THEN NULL
                 ELSE reserves.unit END                                AS invoice_priceunit,
            -- reserve_amount and reserve_unit passed through for invoice_value in s_m
            reserves.amount                                            AS reserve_amount,
            reserves.unit                                              AS reserve_unit,
            reserves.amountind,
            NULL::numeric                                              AS signed_invoice_value,
            master_contracts.contdate                                  AS posted_date,
            NULL::numeric                                              AS posted_invoice_value,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            NULL::numeric                                              AS invoice_house_rate,
            -- 4-branch reserves CCF
            CASE WHEN reserves.currency = params.base_currency
                 THEN 1
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) <> params.base_currency
                      AND reserves.currency <> public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_datedfxrate(reserves.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) <> params.base_currency
                      AND reserves.currency = public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
                 WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                      AND reserves.currency <> public.sp_curr_getunderlying(sub_contracts.currency)
                 THEN public.sp_datedfxrate(reserves.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE 0
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            reserves.charges_line::text                                AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            NULL::text                                                 AS accperiod,
            NULL::text                                                 AS ledgernum,
            NULL::integer                                              AS linenum,
            NULL::text                                                 AS comments
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        JOIN public.reserves
            ON sub_contracts.contno = reserves.contno
            AND sub_contracts.split = reserves.split
        JOIN public.reserves_types ON reserves.reserve = reserves_types.code
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s_b
) s_;
