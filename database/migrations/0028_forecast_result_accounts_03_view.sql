-- ============================================================
-- Forecast_Result_Accounts_03_View
-- Source: dba.Forecast_Result_Accounts_03_View
-- Final sales invoices linked to posted ledger journals.
-- Not currently used; reserved for future Forecast rewrite.
-- UNION ALL of two sections:
--   Section A: regular final invoices
--     (accdetail.accdetail_final_invoice_number = final_invoice.final_invoice_number)
--   Section B: deleted final invoices with different final invoice numbers
--     (accdetail.accdetail_final_invoice_number <> final_invoice.final_invoice_number)
-- Differences from 01/02 views:
--   invoice_value: final_invoice.net_due (not sp_sopex or ledamt)
--   signed_invoice_value: inlined in s_b — CASE posted_ledref IS NULL
--     THEN 0 ELSE final_invoice.net_due (no alias dep, both from table)
--   posted_invoice_value: ratetype D/M on accdetail.ledamt — no null guard;
--     returns NULL when accdetail has no LEFT OUTER JOIN match
--   posted_date: final_invoice.posted_date (no COALESCE)
--   total_forecast: price_curr_unit * allocated_quantity (no USC handling)
--   total_forecast_base_curr: ccf * total_forecast (no US% branch)
-- 3-level nesting per section (sa/sb):
--   s_b (inner): all leaf values incl. signed_invoice_value,
--                posted_invoice_value (both alias-free)
--   s_m (mid):   allocation_fixed_flag, total_forecast
--   s_  (outer): total_forecast_base_curr
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_result_accounts_03_view AS

-- ---- Section A: regular final invoices ----
SELECT
    sa.order_flag,
    sa.order_label,
    sa.allocation_reference,
    sa.allocation_company,
    sa.alliocation_pcentre,
    sa.allocation_commodity,
    sa.allocation_commodity_type,
    sa.allocation_date,
    sa.allocation_total_sales_quantity,
    sa.allocation_total_unfixed,
    sa.allocation_fixed_flag,
    sa.contno,
    sa.split,
    sa.priceterm,
    sa.record_date,
    sa.contract_client,
    sa.allocated_quantity,
    sa.price_curr_unit,
    sa.currency,
    sa.priceunit,
    sa.total_forecast,
    sa.ccf * sa.total_forecast                                        AS total_forecast_base_curr,
    sa.invoice_heading,
    sa.invoice_order,
    sa.invoice_flag,
    sa.invoice_number,
    sa.invoice_date,
    sa.invoice_client,
    sa.invoice_text,
    sa.invoiced_quantity,
    sa.invoice_unit_price,
    sa.invoice_currency,
    sa.invoice_priceunit,
    sa.invoice_value,
    sa.signed_invoice_value,
    sa.posted_date,
    sa.posted_invoice_value,
    sa.contract_type,
    sa.allocation_completed,
    sa.allocation_completed_date,
    sa.invoice_house_rate,
    sa.ccf                                                            AS contract_currency_to_basecurr_conversion_factor,
    sa.stock_allocation_check,
    sa.manual_outb_expense_amount,
    sa.merged_line_splitter,
    sa.suggest_completed,
    sa.origin,
    sa.accperiod,
    sa.ledgernum,
    sa.linenum,
    sa.comments
FROM (
    SELECT
        sa_b.order_flag,
        sa_b.order_label,
        sa_b.allocation_reference,
        sa_b.allocation_company,
        sa_b.alliocation_pcentre,
        sa_b.allocation_commodity,
        sa_b.allocation_commodity_type,
        sa_b.allocation_date,
        sa_b.allocation_total_sales_quantity,
        sa_b.allocation_total_unfixed,
        CASE WHEN sa_b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        sa_b.contno,
        sa_b.split,
        sa_b.priceterm,
        sa_b.record_date,
        sa_b.contract_client,
        sa_b.allocated_quantity,
        sa_b.price_curr_unit,
        sa_b.currency,
        sa_b.priceunit,
        sa_b.price_curr_unit * sa_b.allocated_quantity                AS total_forecast,
        sa_b.invoice_heading,
        sa_b.invoice_order,
        sa_b.invoice_flag,
        sa_b.invoice_number,
        sa_b.invoice_date,
        sa_b.invoice_client,
        sa_b.invoice_text,
        sa_b.invoiced_quantity,
        sa_b.invoice_unit_price,
        sa_b.invoice_currency,
        sa_b.invoice_priceunit,
        sa_b.invoice_value,
        sa_b.signed_invoice_value,
        sa_b.posted_date,
        sa_b.posted_invoice_value,
        sa_b.contract_type,
        sa_b.allocation_completed,
        sa_b.allocation_completed_date,
        sa_b.invoice_house_rate,
        sa_b.ccf,
        sa_b.stock_allocation_check,
        sa_b.manual_outb_expense_amount,
        sa_b.merged_line_splitter,
        sa_b.suggest_completed,
        sa_b.origin,
        sa_b.accperiod,
        sa_b.ledgernum,
        sa_b.linenum,
        sa_b.comments
    FROM (
        SELECT
            '03'::text                                                 AS order_flag,
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
            'Final S Invoices:'::text                                  AS invoice_heading,
            '02'::text                                                 AS invoice_order,
            '310'::text                                                AS invoice_flag,
            -- Section A: invoice_number from final_invoice
            final_invoice.final_invoice_number                         AS invoice_number,
            final_invoice.posted_date                                  AS invoice_date,
            final_invoice.client                                       AS invoice_client,
            CASE WHEN final_invoice.final_invoice_number IS NULL
                 THEN NULL ELSE 'Final Sales Invoice' END              AS invoice_text,
            public.sp_convert_qty(
                final_invoice_details_2.invoiced_quantity,
                final_invoice_details_2.delivered_unit, 'MT')         AS invoiced_quantity,
            final_invoice_details_2.unit_price                         AS invoice_unit_price,
            sub_contracts.currency                                     AS invoice_currency,
            sub_contracts.priceunit                                    AS invoice_priceunit,
            final_invoice.net_due                                      AS invoice_value,
            -- signed_invoice_value inlined: no alias dep on invoice_value
            CASE WHEN final_invoice.posted_ledref IS NULL THEN 0
                 ELSE final_invoice.net_due END                        AS signed_invoice_value,
            final_invoice.posted_date                                  AS posted_date,
            -- posted_invoice_value: no null guard; NULL when accdetail unmatched
            CASE WHEN currency.ratetype = 'D'
                 THEN accdetail.ledamt / accdetail.house_rate
                 ELSE accdetail.ledamt * accdetail.house_rate END      AS posted_invoice_value,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            final_invoice.house_rate                                   AS invoice_house_rate,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            NULL::text                                                 AS merged_line_splitter,
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
        LEFT OUTER JOIN public.accdetail
            ON allocated_contracts.contno            = accdetail.accdetail_contno
            AND allocated_contracts.split            = accdetail.accdetail_split
            AND allocated_contracts.allocation_reference = accdetail.accdetail_allocation_reference
            AND accdetail.accdetail_invoice_flag     = 'SF'
            AND accdetail.accdetail_invoice_number   IS NOT NULL
            AND accdetail.accdetail_final_invoice_number IS NOT NULL
            AND accdetail.accdetail_expense_number   IS NULL
            AND accdetail.accdetail_cr_dr_number     IS NULL
            AND accdetail.accdetail_reserves_type    IS NULL
            AND accdetail.accdetail_charges_line     IS NULL
        LEFT OUTER JOIN public.accsummary
            ON accdetail.accperiod  = accsummary.accperiod
            AND accdetail.ledgernum = accsummary.ledgernum
            AND accsummary.journals    = 'INVC'
            AND accsummary.an_invtype  = 'S'
            AND accsummary.an_conttype = 'S'
            AND accsummary.prov_inv_no IS NOT NULL
            AND accsummary.crdr_inv_no IS NULL
            AND accsummary.exp_inv_no  IS NULL
            AND accsummary.fin_inv_no  IS NOT NULL
        JOIN public.final_invoice_details_2
            ON allocated_contracts.contno            = final_invoice_details_2.contno
            AND allocated_contracts.split            = final_invoice_details_2.split
            AND allocated_contracts.allocation_reference = final_invoice_details_2.allocation_reference
        JOIN public.final_invoice
            ON final_invoice_details_2.invoice_number = final_invoice.invoice_number
            AND final_invoice_details_2.client        = final_invoice.client
            AND final_invoice_details_2.invoice_type  = final_invoice.invoice_type
        JOIN public.currency ON final_invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
          AND (
              (    accsummary.ledgernum IS NOT NULL
               AND accsummary.prov_inv_no               = final_invoice.invoice_number
               AND accsummary.fin_inv_no                = final_invoice.final_invoice_number
               AND accdetail.accdetail_final_invoice_number = final_invoice.final_invoice_number)
              OR accsummary.ledgernum IS NULL
          )
    ) sa_b
) sa

UNION ALL

-- ---- Section B: deleted final invoices with different final invoice numbers ----
SELECT
    sb.order_flag,
    sb.order_label,
    sb.allocation_reference,
    sb.allocation_company,
    sb.alliocation_pcentre,
    sb.allocation_commodity,
    sb.allocation_commodity_type,
    sb.allocation_date,
    sb.allocation_total_sales_quantity,
    sb.allocation_total_unfixed,
    sb.allocation_fixed_flag,
    sb.contno,
    sb.split,
    sb.priceterm,
    sb.record_date,
    sb.contract_client,
    sb.allocated_quantity,
    sb.price_curr_unit,
    sb.currency,
    sb.priceunit,
    sb.total_forecast,
    sb.ccf * sb.total_forecast                                        AS total_forecast_base_curr,
    sb.invoice_heading,
    sb.invoice_order,
    sb.invoice_flag,
    sb.invoice_number,
    sb.invoice_date,
    sb.invoice_client,
    sb.invoice_text,
    sb.invoiced_quantity,
    sb.invoice_unit_price,
    sb.invoice_currency,
    sb.invoice_priceunit,
    sb.invoice_value,
    sb.signed_invoice_value,
    sb.posted_date,
    sb.posted_invoice_value,
    sb.contract_type,
    sb.allocation_completed,
    sb.allocation_completed_date,
    sb.invoice_house_rate,
    sb.ccf                                                            AS contract_currency_to_basecurr_conversion_factor,
    sb.stock_allocation_check,
    sb.manual_outb_expense_amount,
    sb.merged_line_splitter,
    sb.suggest_completed,
    sb.origin,
    sb.accperiod,
    sb.ledgernum,
    sb.linenum,
    sb.comments
FROM (
    SELECT
        sb_b.order_flag,
        sb_b.order_label,
        sb_b.allocation_reference,
        sb_b.allocation_company,
        sb_b.alliocation_pcentre,
        sb_b.allocation_commodity,
        sb_b.allocation_commodity_type,
        sb_b.allocation_date,
        sb_b.allocation_total_sales_quantity,
        sb_b.allocation_total_unfixed,
        CASE WHEN sb_b.allocation_total_unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END AS allocation_fixed_flag,
        sb_b.contno,
        sb_b.split,
        sb_b.priceterm,
        sb_b.record_date,
        sb_b.contract_client,
        sb_b.allocated_quantity,
        sb_b.price_curr_unit,
        sb_b.currency,
        sb_b.priceunit,
        sb_b.price_curr_unit * sb_b.allocated_quantity                AS total_forecast,
        sb_b.invoice_heading,
        sb_b.invoice_order,
        sb_b.invoice_flag,
        sb_b.invoice_number,
        sb_b.invoice_date,
        sb_b.invoice_client,
        sb_b.invoice_text,
        sb_b.invoiced_quantity,
        sb_b.invoice_unit_price,
        sb_b.invoice_currency,
        sb_b.invoice_priceunit,
        sb_b.invoice_value,
        sb_b.signed_invoice_value,
        sb_b.posted_date,
        sb_b.posted_invoice_value,
        sb_b.contract_type,
        sb_b.allocation_completed,
        sb_b.allocation_completed_date,
        sb_b.invoice_house_rate,
        sb_b.ccf,
        sb_b.stock_allocation_check,
        sb_b.manual_outb_expense_amount,
        sb_b.merged_line_splitter,
        sb_b.suggest_completed,
        sb_b.origin,
        sb_b.accperiod,
        sb_b.ledgernum,
        sb_b.linenum,
        sb_b.comments
    FROM (
        SELECT
            '03'::text                                                 AS order_flag,
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
            'Final S Invoices:'::text                                  AS invoice_heading,
            '02'::text                                                 AS invoice_order,
            '310'::text                                                AS invoice_flag,
            -- Section B: invoice_number from accdetail (deleted invoice number)
            accdetail.accdetail_final_invoice_number                   AS invoice_number,
            final_invoice.posted_date                                  AS invoice_date,
            final_invoice.client                                       AS invoice_client,
            CASE WHEN accdetail.accdetail_final_invoice_number IS NULL
                 THEN NULL ELSE 'Final Sales Invoice' END              AS invoice_text,
            public.sp_convert_qty(
                final_invoice_details_2.invoiced_quantity,
                final_invoice_details_2.delivered_unit, 'MT')         AS invoiced_quantity,
            final_invoice_details_2.unit_price                         AS invoice_unit_price,
            sub_contracts.currency                                     AS invoice_currency,
            sub_contracts.priceunit                                    AS invoice_priceunit,
            final_invoice.net_due                                      AS invoice_value,
            CASE WHEN final_invoice.posted_ledref IS NULL THEN 0
                 ELSE final_invoice.net_due END                        AS signed_invoice_value,
            final_invoice.posted_date                                  AS posted_date,
            CASE WHEN currency.ratetype = 'D'
                 THEN accdetail.ledamt / accdetail.house_rate
                 ELSE accdetail.ledamt * accdetail.house_rate END      AS posted_invoice_value,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            final_invoice.house_rate                                   AS invoice_house_rate,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            0::numeric                                                 AS manual_outb_expense_amount,
            NULL::text                                                 AS merged_line_splitter,
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
        LEFT OUTER JOIN public.accdetail
            ON allocated_contracts.contno            = accdetail.accdetail_contno
            AND allocated_contracts.split            = accdetail.accdetail_split
            AND allocated_contracts.allocation_reference = accdetail.accdetail_allocation_reference
            AND accdetail.accdetail_invoice_flag     = 'SF'
            AND accdetail.accdetail_invoice_number   IS NOT NULL
            AND accdetail.accdetail_final_invoice_number IS NOT NULL
            AND accdetail.accdetail_expense_number   IS NULL
            AND accdetail.accdetail_cr_dr_number     IS NULL
            AND accdetail.accdetail_reserves_type    IS NULL
            AND accdetail.accdetail_charges_line     IS NULL
        LEFT OUTER JOIN public.accsummary
            ON accdetail.accperiod  = accsummary.accperiod
            AND accdetail.ledgernum = accsummary.ledgernum
            AND accsummary.journals    = 'INVC'
            AND accsummary.an_invtype  = 'S'
            AND accsummary.an_conttype = 'S'
            AND accsummary.prov_inv_no IS NOT NULL
            AND accsummary.crdr_inv_no IS NULL
            AND accsummary.exp_inv_no  IS NULL
            AND accsummary.fin_inv_no  IS NOT NULL
        JOIN public.final_invoice_details_2
            ON allocated_contracts.contno            = final_invoice_details_2.contno
            AND allocated_contracts.split            = final_invoice_details_2.split
            AND allocated_contracts.allocation_reference = final_invoice_details_2.allocation_reference
        JOIN public.final_invoice
            ON final_invoice_details_2.invoice_number = final_invoice.invoice_number
            AND final_invoice_details_2.client        = final_invoice.client
            AND final_invoice_details_2.invoice_type  = final_invoice.invoice_type
        JOIN public.currency ON final_invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
          AND (
              (    accsummary.ledgernum IS NOT NULL
               AND accsummary.prov_inv_no               = final_invoice.invoice_number
               AND accsummary.fin_inv_no               <> final_invoice.final_invoice_number
               AND accdetail.accdetail_final_invoice_number <> final_invoice.final_invoice_number)
              OR accsummary.ledgernum IS NULL
          )
    ) sb_b
) sb;
