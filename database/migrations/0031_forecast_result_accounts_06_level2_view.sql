-- ============================================================
-- Forecast_Result_Accounts_06_level2_View
-- Source: dba.Forecast_Result_Accounts_06_level2_View
-- UNDERLYING view for 06_View. Purchase contracts with stock
-- invoices (invoice_type='S'), before final invoicing.
-- Not currently used; reserved for future Forecast rewrite.
-- Key differences from Sales views:
--   contract_type = 'P'; allocated_quantity is negated (-1*)
--   CCF: US% → USC=0.01/else 1; non-US → fixes_fx_rate (no datedfxrate)
--   signed_invoice_value: CASE posted_ledref IS NULL THEN 0 ELSE NULL
--     (returns NULL when posted; no alias dep on invoice_value)
--   invoice_value: stock_unit_price * invoiced_quantity (alias dep)
--   posted_invoice_value: ratetype D/M on signed_invoice_value
--   final_invoice_number: subquery → final_invoice_exists ('N'/'Y')
--   WHERE final_invoice_exists='N' → outer SELECT's WHERE clause
-- 2-level nesting:
--   s_b (inner): invoiced_quantity (= -1 * stock_quantity),
--                signed_invoice_value (alias-free posted_ledref check),
--                final_invoice_number (subquery), invoice_number (raw),
--                invoice_currency (USC/USD check), ccf, ratetype,
--                invoice_house_rate, stock_unit_price, base_unit
--   s_ (outer): allocation_fixed_flag, total_forecast (USC handling),
--               invoice_value (stock_unit_price * invoiced_quantity),
--               posted_invoice_value, invoice_text, final_invoice_exists
--   CREATE VIEW SELECT: total_forecast_base_curr
--   WHERE s_.final_invoice_exists = 'N'
-- FROM: all LEFT OUTER JOINs to stocks/invoice_stocks/invoice/currency
-- No accdetail/accsummary; accperiod/ledgernum/linenum/comments are NULL
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_result_accounts_06_level2_view AS

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
    s_.final_invoice_number,
    s_.final_invoice_exists,
    s_.manual_outb_expense_amount,
    s_.merged_line_splitter,
    s_.suggest_completed,
    s_.origin,
    s_.accperiod,
    s_.ledgernum,
    s_.linenum,
    s_.comments
FROM (
    -- s_: computes all alias-dep columns; labeled s_ for outer SELECT's s_.* references
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
        -- total_forecast: USC handling via sp_convert_qty + 0.01 factor
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
        CASE WHEN s_b.invoice_number IS NULL THEN NULL
             ELSE 'Purchase Invoice' END                              AS invoice_text,
        s_b.invoiced_quantity,
        s_b.invoice_unit_price,
        s_b.invoice_currency,
        s_b.invoice_priceunit,
        -- invoice_value: alias dep on invoiced_quantity (from s_b)
        s_b.stock_unit_price * s_b.invoiced_quantity                  AS invoice_value,
        s_b.signed_invoice_value,
        s_b.posted_date,
        -- posted_invoice_value: alias dep on signed_invoice_value (from s_b)
        CASE WHEN s_b.ratetype = 'D'
             THEN s_b.signed_invoice_value / s_b.invoice_house_rate
             ELSE s_b.signed_invoice_value * s_b.invoice_house_rate END AS posted_invoice_value,
        s_b.contract_type,
        s_b.allocation_completed,
        s_b.allocation_completed_date,
        s_b.invoice_house_rate,
        s_b.ccf,
        s_b.stock_allocation_check,
        s_b.final_invoice_number,
        CASE WHEN s_b.final_invoice_number IS NULL THEN 'N' ELSE 'Y' END AS final_invoice_exists,
        s_b.manual_outb_expense_amount,
        s_b.merged_line_splitter,
        s_b.suggest_completed,
        s_b.origin,
        s_b.accperiod,
        s_b.ledgernum,
        s_b.linenum,
        s_b.comments
    FROM (
        -- s_b: raw table columns plus alias-free derivations
        SELECT
            '06'::text                                                 AS order_flag,
            'P Contract:'::text                                        AS order_label,
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
            -- allocated_quantity negated for purchase contracts
            -1 * public.sp_convert_qty(
                (SELECT SUM(a_c.quantity)
                 FROM public.allocated_contracts a_c
                 WHERE allocated_contracts.allocation_reference = a_c.allocation_reference
                   AND allocated_contracts.contno = a_c.contno
                   AND a_c.split = sub_contracts.split
                   AND master_contracts.contract_type = 'P'),
                sub_contracts.quantunit, 'MT')                        AS allocated_quantity,
            CASE WHEN sub_contracts.price_fixing = 'Y'
                 THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
                 ELSE sub_contracts.unitprice
            END                                                        AS price_curr_unit,
            sub_contracts.currency,
            sub_contracts.priceunit,
            params.base_unit,
            'Purch Invoices:'::text                                    AS invoice_heading,
            '01'::text                                                 AS invoice_order,
            '210'::text                                                AS invoice_flag,
            invoice.invoice_number,
            invoice.posted_date                                        AS invoice_date,
            invoice.client                                             AS invoice_client,
            -- invoiced_quantity negated from invoice_stocks.stock_quantity
            -1 * invoice_stocks.stock_quantity                         AS invoiced_quantity,
            stocks.stock_unit_price                                    AS invoice_unit_price,
            stocks.stock_unit_price,
            -- invoice_currency: USC→USD mapping, else invoice.invoice_currency
            CASE WHEN sub_contracts.currency = 'USC' AND invoice.invoice_currency = 'USD'
                 THEN sub_contracts.currency
                 ELSE invoice.invoice_currency
            END                                                        AS invoice_currency,
            sub_contracts.priceunit                                    AS invoice_priceunit,
            -- signed_invoice_value: alias-free; 0 when unposted, NULL when posted
            CASE WHEN invoice.posted_ledref IS NULL THEN 0::numeric
                 ELSE NULL::numeric END                                AS signed_invoice_value,
            COALESCE(invoice.posted_date, master_contracts.contdate)   AS posted_date,
            currency.ratetype,
            invoice.house_rate                                         AS invoice_house_rate,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            -- CCF: US% → USC=0.01/else 1; non-US → fixes_fx_rate (no datedfxrate)
            CASE WHEN sub_contracts.currency LIKE 'US%'
                 THEN CASE WHEN sub_contracts.currency = 'USC' THEN 0.01 ELSE 1 END
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            -- final_invoice_number: NULL when no final invoice exists for this invoice
            (SELECT fi.final_invoice_number FROM public.final_invoice fi
             WHERE fi.invoice_number = invoice.invoice_number
               AND fi.invoice_type   = invoice.invoice_type
               AND fi.client         = invoice.client)                AS final_invoice_number,
            0::numeric                                                 AS manual_outb_expense_amount,
            NULL::text                                                 AS merged_line_splitter,
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
        LEFT OUTER JOIN public.stocks
            ON allocated_contracts.allocation_reference = stocks.allocation_reference
            AND allocated_contracts.contno = stocks.contno
            AND allocated_contracts.split  = stocks.split
        LEFT OUTER JOIN public.invoice_stocks
            ON stocks.contno    = invoice_stocks.contno
            AND stocks.split    = invoice_stocks.split
            AND stocks.stock_id = invoice_stocks.stock_id
            AND invoice_stocks.invoice_type = 'S'
        LEFT OUTER JOIN public.invoice
            ON invoice_stocks.invoice_number = invoice.invoice_number
            AND invoice_stocks.client        = invoice.client
            AND invoice_stocks.invoice_type  = invoice.invoice_type
        LEFT OUTER JOIN public.currency ON invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'P'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s_b
) s_
WHERE s_.final_invoice_exists = 'N';
