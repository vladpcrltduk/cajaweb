-- ============================================================
-- Forecast_Result_Accounts_05_View
-- Source: dba.Forecast_Result_Accounts_05_View
-- Sales expense notes linked to posted ledger journals.
-- Not currently used; reserved for future Forecast rewrite.
-- 4-level alias chain: invoice_value → signed_invoice_value
--   → posted_invoice_value → manual_outb_expense_amount.
-- Resolved with 3 levels by inlining posted_invoice_value
-- into manual_outb_expense_amount at the outer (s_) level.
--   s_b (inner): invoice_value (4-branch CASE on nominal_account
--                and reversal comments), price_curr_unit,
--                allocated_quantity, ccf, ratetype,
--                invoice_house_rate, nominal_account, posted_ledref
--   s_m (mid):   allocation_fixed_flag, total_forecast,
--                signed_invoice_value
--   s_  (outer): total_forecast_base_curr, posted_invoice_value,
--                manual_outb_expense_amount (posted_invoice_value inlined)
-- accdetail filter: flag='EXP', expense_number IS NOT NULL,
--   reserves_type IS NOT NULL, charges_line IS NOT NULL.
-- WHERE guard: exp_inv_no / accdetail_expense_number /
--   accdetail_charges_line / accdetail_reserves_type match.
-- ============================================================

CREATE OR REPLACE VIEW public.forecast_result_accounts_05_view AS

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
    CASE WHEN s_.ratetype = 'D'
         THEN s_.signed_invoice_value / s_.invoice_house_rate
         ELSE s_.signed_invoice_value * s_.invoice_house_rate END     AS posted_invoice_value,
    s_.contract_type,
    s_.allocation_completed,
    s_.allocation_completed_date,
    s_.invoice_house_rate,
    s_.ccf                                                            AS contract_currency_to_basecurr_conversion_factor,
    s_.stock_allocation_check,
    -- manual_outb_expense_amount: inline posted_invoice_value to avoid 4th level
    CASE WHEN s_.nominal_account = '60002'
         THEN CASE WHEN s_.ratetype = 'D'
                   THEN s_.signed_invoice_value / s_.invoice_house_rate
                   ELSE s_.signed_invoice_value * s_.invoice_house_rate END
         ELSE 0
    END                                                               AS manual_outb_expense_amount,
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
        CASE WHEN s_b.posted_ledref IS NULL THEN 0
             ELSE s_b.invoice_value END                               AS signed_invoice_value,
        s_b.posted_date,
        s_b.ratetype,
        s_b.invoice_house_rate,
        s_b.nominal_account,
        s_b.contract_type,
        s_b.allocation_completed,
        s_b.allocation_completed_date,
        s_b.ccf,
        s_b.stock_allocation_check,
        s_b.merged_line_splitter,
        s_b.suggest_completed,
        s_b.origin,
        s_b.accperiod,
        s_b.ledgernum,
        s_b.linenum,
        s_b.comments
    FROM (
        SELECT
            '05'::text                                                 AS order_flag,
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
            'Sales Expenses:'::text                                    AS invoice_heading,
            '04'::text                                                 AS invoice_order,
            expenses_summary.expense_note_type                         AS invoice_flag,
            expenses_summary.expense_number                            AS invoice_number,
            expenses_summary.posted_date                               AS invoice_date,
            expenses_summary.client                                    AS invoice_client,
            expenses_detail.description                                AS invoice_text,
            NULL::numeric                                              AS invoiced_quantity,
            NULL::numeric                                              AS invoice_unit_price,
            expenses_detail.currency                                   AS invoice_currency,
            NULL::text                                                 AS invoice_priceunit,
            -- invoice_value: 4-branch on nominal_account and reversal comments
            CASE WHEN expenses_detail.nominal_account LIKE '6%'
                      OR expenses_detail.nominal_account LIKE '7%'
                 THEN CASE WHEN LEFT(accdetail.comments, 12) = 'Reversal of '
                           THEN expenses_detail.linevalue
                           ELSE expenses_detail.linevalue * -1
                      END
                 ELSE CASE WHEN LEFT(accdetail.comments, 12) = 'Reversal of '
                           THEN public.sp_get_realised_invoice_value(
                                    'E', expenses_detail.expense_number, expenses_detail.client,
                                    expenses_detail.charges_line, expenses_detail.contno,
                                    expenses_detail.split) * -1
                           ELSE public.sp_get_realised_invoice_value(
                                    'E', expenses_detail.expense_number, expenses_detail.client,
                                    expenses_detail.charges_line, expenses_detail.contno,
                                    expenses_detail.split)
                      END
            END                                                        AS invoice_value,
            expenses_summary.posted_ledref,
            expenses_summary.posted_date                               AS posted_date,
            currency.ratetype,
            expenses_summary.house_rate                                AS invoice_house_rate,
            expenses_detail.nominal_account,
            master_contracts.contract_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            CASE WHEN public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency
                 THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
                 ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
            END                                                        AS ccf,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)              AS stock_allocation_check,
            expenses_detail.charges_line::text                         AS merged_line_splitter,
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
        LEFT OUTER JOIN public.accdetail
            ON allocated_contracts.contno            = accdetail.accdetail_contno
            AND allocated_contracts.split            = accdetail.accdetail_split
            AND allocated_contracts.allocation_reference = accdetail.accdetail_allocation_reference
            AND accdetail.accdetail_invoice_flag     = 'EXP'
            AND accdetail.accdetail_invoice_number   IS NULL
            AND accdetail.accdetail_final_invoice_number IS NULL
            AND accdetail.accdetail_expense_number   IS NOT NULL
            AND accdetail.accdetail_cr_dr_number     IS NULL
            AND accdetail.accdetail_reserves_type    IS NOT NULL
            AND accdetail.accdetail_charges_line     IS NOT NULL
        LEFT OUTER JOIN public.accsummary
            ON accdetail.accperiod  = accsummary.accperiod
            AND accdetail.ledgernum = accsummary.ledgernum
            AND accsummary.journals    = 'INVC'
            AND accsummary.prov_inv_no IS NULL
            AND accsummary.crdr_inv_no IS NULL
            AND accsummary.exp_inv_no  IS NOT NULL
            AND accsummary.fin_inv_no  IS NULL
        JOIN public.expenses_detail
            ON allocated_contracts.contno            = expenses_detail.contno
            AND allocated_contracts.split            = expenses_detail.split
            AND allocated_contracts.allocation_reference = expenses_detail.allocation_reference
        JOIN public.expenses_summary
            ON expenses_detail.expense_number = expenses_summary.expense_number
            AND expenses_detail.client        = expenses_summary.client
        JOIN public.currency ON expenses_summary.currency = currency.code
        CROSS JOIN public.params
        WHERE master_contracts.contract_type = 'S'
          AND public.sp_allocation_check_if_only_stock(
                  allocated_contracts.allocation_reference) = 'N'
          AND (
              (    accsummary.ledgernum IS NOT NULL
               AND accsummary.exp_inv_no              = expenses_summary.expense_number
               AND accdetail.accdetail_expense_number = expenses_summary.expense_number
               AND accdetail.accdetail_charges_line   = expenses_detail.charges_line
               AND accdetail.accdetail_reserves_type  = expenses_detail.expense_type)
              OR accsummary.ledgernum IS NULL
          )
    ) s_b
) s_;
