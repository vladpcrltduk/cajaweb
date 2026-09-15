-- ============================================================
-- Forecast_Result_Accounts_07_View
-- Source: dba.Forecast_Result_Accounts_07_View
-- Purchase contracts: stock outbooking ledger entries.
-- Not currently used; reserved for future Forecast rewrite.
-- order_flag = '06' (intentional — same display level as view 06,
--   second invoice section for purchase contracts; invoice_order='02').
-- accdetail filter: caja_project='OUTB', accdetail_invoice_flag='PI',
--   accdetail_invoice_number IS NOT NULL, accdetail_final_invoice_number IS NULL,
--   nominal LIKE '6%'.
-- accsummary join: period+ledger only — no extra journals/type filters.
-- invoice_value = accdetail.ledamt (no ±crdrindicator);
--   signed_invoice_value is identical (both = accdetail.ledamt, inlined
--   in s_b to avoid a 3rd nesting level).
-- invoice_client = 'STK OUTB' (literal, not from table).
-- final_invoice_number/final_invoice_exists = NULL (literal; no filter).
-- Commented-out condition in original:
--   ( accsummary.reversed = '' OR accsummary.reversed IS NULL )
--   preserved as a comment here for reference.
-- 2-level nesting:
--   s_b (inner): invoice_value AND signed_invoice_value (both = accdetail.ledamt),
--                price_curr_unit, allocated_quantity, ccf, ratetype, house_rate
--   s_ (outer):  allocation_fixed_flag, total_forecast, posted_invoice_value
--   CREATE VIEW SELECT: total_forecast_base_curr
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_result_accounts_07_view AS

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
        s_b.invoiced_quantity,
        s_b.invoice_unit_price,
        s_b.invoice_currency,
        s_b.invoice_priceunit,
        s_b.invoice_value,
        s_b.signed_invoice_value,
        s_b.posted_date,
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
        s_b.final_invoice_exists,
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
            '02'::text                                                 AS invoice_order,
            '210'::text                                                AS invoice_flag,
            accdetail.accdetail_invoice_number                         AS invoice_number,
            NULL::date                                                 AS invoice_date,
            'STK OUTB'::text                                           AS invoice_client,
            'Stock outbooking         ' || accdetail.ledgernum         AS invoice_text,
            accsummary.an_tonnage                                      AS invoiced_quantity,
            NULL::numeric                                              AS invoice_unit_price,
            NULL::text                                                 AS invoice_currency,
            NULL::text                                                 AS invoice_priceunit,
            -- invoice_value and signed_invoice_value are both accdetail.ledamt;
            -- inlined to avoid a 3rd nesting level (signed_invoice_value = invoice_value alias)
            accdetail.ledamt                                           AS invoice_value,
            accdetail.ledamt                                           AS signed_invoice_value,
            accsummary.leddate                                         AS posted_date,
            currency.ratetype,
            accdetail.house_rate                                       AS invoice_house_rate,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            NULL::text                                                 AS final_invoice_number,
            NULL::text                                                 AS final_invoice_exists,
            0::numeric                                                 AS manual_outb_expense_amount,
            accdetail.linenum::text                                    AS merged_line_splitter,
            allocation.suggest_completed,
            (SELECT string_agg(DISTINCT s_c.origin::text, ' ')
             FROM public.sub_contracts s_c,
                  public.allocated_contracts a_c
             WHERE a_c.allocation_reference = allocation.allocation_reference
               AND a_c.contno = s_c.contno
               AND a_c.split = s_c.split)                             AS origin,
            accdetail.accperiod,
            accdetail.ledgernum,
            accdetail.linenum,
            accdetail.comments
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocation.allocation_reference = allocated_contracts.allocation_reference
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        JOIN public.accdetail
            ON accdetail.accdetail_contno            = sub_contracts.contno
            AND accdetail.accdetail_split            = sub_contracts.split
            AND accdetail.accdetail_allocation_reference = allocation.allocation_reference
            AND accdetail.caja_project               = 'OUTB'
            AND accdetail.accdetail_invoice_flag     = 'PI'
            AND accdetail.accdetail_invoice_number   IS NOT NULL
            AND accdetail.accdetail_final_invoice_number IS NULL
            AND accdetail.nominal                    LIKE '6%'
        -- ( accsummary.reversed = '' OR accsummary.reversed IS NULL )
        JOIN public.accsummary
            ON accdetail.accperiod  = accsummary.accperiod
            AND accdetail.ledgernum = accsummary.ledgernum
        JOIN public.currency ON accdetail.currency = currency.code
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'P'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s_b
) s_;
