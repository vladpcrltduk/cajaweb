-- ============================================================
-- Forecast_Result_Accounts_08_View
-- Source: dba.Forecast_Result_Accounts_08_View
-- Purchase invoice charges linked to posted ledger journals.
-- Not currently used; reserved for future Forecast rewrite.
-- Purchase-contract parallel to view 02 (sales invoice charges).
-- order_flag = '07'; invoice_order = '02', invoice_flag = '210'.
-- allocated_quantity: NOT negated; inner subquery uses contract_type='S'
--   (unlike 06_level2/07 which negate and use 'P').
-- total_forecast = price_curr_unit * allocated_quantity (simple multiply;
--   no USC/sp_convert_qty division unlike 06_level2/07).
-- total_forecast_base_curr = ccf * total_forecast (no US% branch).
-- posted_invoice_value: checks invoice_charges.currency = base_currency
--   (not ratetype D/M) — same pattern as view 02.
-- currency table joined on invoice.invoice_currency=currency.code;
--   ratetype not referenced — join kept as implicit filter on known currencies.
-- accdetail filter: invoice_flag='PI', invoice_number IS NOT NULL,
--   final_invoice_number IS NULL, expense_number IS NULL, cr_dr_number IS NULL,
--   reserves_type IS NOT NULL, charges_line IS NOT NULL.
-- accsummary: journals='INVC', an_invtype='P', an_conttype='P',
--   prov_inv_no IS NOT NULL, crdr/exp/fin_inv_no IS NULL.
-- invoice_charges.nominal_account NOT LIKE '3%' in WHERE.
-- invoice_value = ledamt ± crdrindicator; signed_invoice_value inlined
--   in s_b (CASE posted_ledref → 0/invoice_value) to avoid 3rd level.
-- 2-level nesting:
--   s_b (inner): invoice_value (ledamt ± crdrindicator),
--                signed_invoice_value (CASE posted_ledref, inlined),
--                price_curr_unit, allocated_quantity, ccf, base_currency,
--                invoice_house_rate
--   s_  (outer): allocation_fixed_flag, total_forecast, posted_invoice_value
--   CREATE VIEW SELECT: total_forecast_base_curr
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_result_accounts_08_view AS

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
    s_.ccf * s_.total_forecast                                        AS total_forecast_base_curr,
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
        s_b.price_curr_unit * s_b.allocated_quantity                  AS total_forecast,
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
        -- posted_invoice_value: currency=base → signed as-is; else multiply by house_rate
        CASE WHEN s_b.invoice_currency = s_b.base_currency
             THEN s_b.signed_invoice_value
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
            '07'::text                                                 AS order_flag,
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
            -- allocated_quantity: not negated; inner subquery uses contract_type='S'
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
            'Purch Invoices:'::text                                    AS invoice_heading,
            '02'::text                                                 AS invoice_order,
            '210'::text                                                AS invoice_flag,
            invoice.invoice_number,
            invoice.posted_date                                        AS invoice_date,
            invoice.client                                             AS invoice_client,
            invoice_charges.description                                AS invoice_text,
            NULL::numeric                                              AS invoiced_quantity,
            NULL::numeric                                              AS invoice_unit_price,
            invoice_charges.currency                                   AS invoice_currency,
            NULL::text                                                 AS invoice_priceunit,
            -- invoice_value: debit → ledamt as-is; credit → negate
            CASE WHEN invoice_charges.crdrindicator = 'D'
                 THEN accdetail.ledamt
                 ELSE accdetail.ledamt * -1
            END                                                        AS invoice_value,
            -- signed_invoice_value: inlined (avoids 3rd nesting level)
            CASE WHEN invoice.posted_ledref IS NULL THEN 0::numeric
                 ELSE CASE WHEN invoice_charges.crdrindicator = 'D'
                           THEN accdetail.ledamt
                           ELSE accdetail.ledamt * -1
                      END
            END                                                        AS signed_invoice_value,
            COALESCE(invoice.posted_date, master_contracts.contdate)   AS posted_date,
            invoice.house_rate                                         AS invoice_house_rate,
            params.base_currency,
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
        JOIN public.accdetail
            ON allocated_contracts.contno            = accdetail.accdetail_contno
            AND allocated_contracts.split            = accdetail.accdetail_split
            AND allocated_contracts.allocation_reference = accdetail.accdetail_allocation_reference
            AND accdetail.accdetail_invoice_flag     = 'PI'
            AND accdetail.accdetail_invoice_number   IS NOT NULL
            AND accdetail.accdetail_final_invoice_number IS NULL
            AND accdetail.accdetail_expense_number   IS NULL
            AND accdetail.accdetail_cr_dr_number     IS NULL
            AND accdetail.accdetail_reserves_type    IS NOT NULL
            AND accdetail.accdetail_charges_line     IS NOT NULL
        JOIN public.accsummary
            ON accdetail.accperiod  = accsummary.accperiod
            AND accdetail.ledgernum = accsummary.ledgernum
            AND accsummary.journals    = 'INVC'
            AND accsummary.an_invtype  = 'P'
            AND accsummary.an_conttype = 'P'
            AND accsummary.prov_inv_no IS NOT NULL
            AND accsummary.crdr_inv_no IS NULL
            AND accsummary.exp_inv_no  IS NULL
            AND accsummary.fin_inv_no  IS NULL
        JOIN public.invoice_details_2
            ON allocated_contracts.contno            = invoice_details_2.contno
            AND allocated_contracts.split            = invoice_details_2.split
            AND allocated_contracts.allocation_reference = invoice_details_2.allocation_reference
        JOIN public.invoice
            ON invoice_details_2.invoice_number = invoice.invoice_number
            AND invoice_details_2.client        = invoice.client
            AND invoice_details_2.invoice_type  = invoice.invoice_type
        JOIN public.invoice_charges
            ON invoice_charges.invoice_number      = invoice.invoice_number
            AND invoice_charges.client             = invoice.client
            AND invoice_charges.invoice_type       = invoice.invoice_type
            AND invoice_charges.contno             = allocated_contracts.contno
            AND invoice_charges.split              = allocated_contracts.split
            AND invoice_charges.allocation_reference = allocated_contracts.allocation_reference
        -- currency joined on invoice_currency; ratetype not used here but join
        -- preserved as implicit filter ensuring invoice_currency is a known code
        JOIN public.currency ON invoice.invoice_currency = currency.code
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
            AND sub_contracts.split = allocated_contracts.split
        JOIN public.master_contracts ON sub_contracts.contno = master_contracts.contno
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'P'
          AND invoice_charges.nominal_account NOT LIKE '3%'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
    ) s_b
) s_;
