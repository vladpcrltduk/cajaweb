-- ============================================================
-- glt_report_alloc_pl_view
-- Source: dba.GLT_Report_Alloc_PL_view
-- Physical allocation P&L for completed allocations, fixed only.
-- Alias chain resolution (SAP allows alias refs in subsequent cols
-- and WHERE; PostgreSQL requires subqueries):
--   s_b (inner): tonnage, invoiced_quant, alloc_total_unfixed,
--                stock_allocation_check, price_curr_unit,
--                total_fobbing_usd_mt
--   s_ (middle): invoiced_tonnage, purchase/sales_tonnage,
--                row_fixed_flag, fixed_flag, fobst_price
--   Outer SELECT: open_tonnage, total_price, purchase/sales_total_price
--                 WHERE stock_allocation_check='N' AND fixed_flag='Fixed'
-- total_price inlined into purchase_total_price / sales_total_price
--   to avoid a third subquery level.
-- SAP IF…ENDIF → CASE WHEN…END; isnull(x,0) → COALESCE(x,0).
-- Comma-joins → explicit JOINs.
-- ============================================================

CREATE OR REPLACE VIEW public.glt_report_alloc_pl_view AS

SELECT
    s_.company,
    s_.commodtype,
    s_.stock_allocation_check,
    s_.allocation_reference,
    s_.contdate,
    s_.contract_type,
    s_.contno,
    s_.client,
    s_.tonnage,
    s_.purchase_tonnage,
    s_.sales_tonnage,
    s_.invoiced_quant,
    s_.invoiced_tonnage,
    CASE WHEN s_.contract_type = 'P'
         THEN (ABS(s_.tonnage) - s_.invoiced_tonnage) * -1
         ELSE (ABS(s_.tonnage) - s_.invoiced_tonnage)
    END                                                                  AS open_tonnage,
    s_.origin,
    s_.unfixed,
    s_.row_fixed_flag,
    s_.alloc_total_unfixed,
    s_.fixed_flag,
    s_.price_curr_unit,
    s_.total_fobbing_usd_mt,
    s_.fobst_price,
    -- total_price
    CASE WHEN s_.contract_type = 'P'
         THEN ABS(s_.tonnage * s_.fobst_price) * -1
         ELSE s_.tonnage * s_.fobst_price
    END                                                                  AS total_price,
    -- purchase_total_price: total_price inlined (avoids 3rd nesting level)
    CASE WHEN s_.contract_type = 'P'
         THEN ABS(s_.tonnage * s_.fobst_price) * -1
         ELSE 0
    END                                                                  AS purchase_total_price,
    -- sales_total_price: total_price inlined
    CASE WHEN s_.contract_type = 'P'
         THEN 0
         ELSE s_.tonnage * s_.fobst_price
    END                                                                  AS sales_total_price
FROM (
    -- s_: computes alias-dep columns from s_b
    SELECT
        s_b.company,
        s_b.commodtype,
        s_b.stock_allocation_check,
        s_b.allocation_reference,
        s_b.contdate,
        s_b.contract_type,
        s_b.contno,
        s_b.client,
        s_b.tonnage,
        CASE WHEN s_b.contract_type = 'P' THEN s_b.tonnage ELSE 0 END   AS purchase_tonnage,
        CASE WHEN s_b.contract_type = 'P' THEN 0 ELSE s_b.tonnage END   AS sales_tonnage,
        s_b.invoiced_quant,
        public.sp_convert_qty(s_b.invoiced_quant,
            s_b.quantunit, 'MT')                                         AS invoiced_tonnage,
        s_b.origin,
        s_b.unfixed,
        CASE WHEN s_b.unfixed > 0 THEN 'Unfixed' ELSE 'Fixed' END       AS row_fixed_flag,
        s_b.alloc_total_unfixed,
        CASE WHEN s_b.alloc_total_unfixed > 0
             THEN 'Unfixed' ELSE 'Fixed' END                             AS fixed_flag,
        s_b.price_curr_unit,
        s_b.total_fobbing_usd_mt,
        public.sp_get_fobst_price(
            s_b.contract_type,
            s_b.price_curr_unit,
            s_b.total_fobbing_usd_mt)                                   AS fobst_price
    FROM (
        -- s_b: raw table columns; all alias-free derivations
        SELECT
            master_contracts.company,
            master_contracts.commodtype,
            public.sp_allocation_check_if_only_stock(
                allocated_contracts.allocation_reference)                AS stock_allocation_check,
            allocated_contracts.allocation_reference,
            master_contracts.contdate,
            master_contracts.contract_type,
            sub_contracts.contno,
            sub_contracts.client,
            CASE WHEN master_contracts.contract_type = 'P'
                 THEN public.sp_convert_qty(
                          allocated_contracts.quantity,
                          sub_contracts.quantunit, 'MT') * -1
                 ELSE public.sp_convert_qty(
                          allocated_contracts.quantity,
                          sub_contracts.quantunit, 'MT')
            END                                                          AS tonnage,
            COALESCE((
                SELECT SUM(id2.invoiced_quantity)
                FROM public.invoice_details_2 id2
                WHERE id2.contno               = allocated_contracts.contno
                  AND id2.split               = allocated_contracts.split
                  AND id2.allocation_reference = allocated_contracts.allocation_reference
            ), 0)                                                        AS invoiced_quant,
            sub_contracts.quantunit,
            sub_contracts.origin,
            phys_avail.unfixed,
            public.sp_phys_total_alloc_unfixed(
                allocated_contracts.allocation_reference)                AS alloc_total_unfixed,
            CASE WHEN phys_avail.unfixed > 0
                 THEN 0
                 ELSE public.sp_phys_calc_outright_fixed_price(
                          sub_contracts.contno,
                          sub_contracts.split,
                          params.base_currency, 'MT')
            END                                                          AS price_curr_unit,
            public.sp_get_total_reserves_in_base(
                sub_contracts.contno,
                sub_contracts.split)                                     AS total_fobbing_usd_mt
        FROM public.allocation
        JOIN public.allocated_contracts
            ON allocated_contracts.allocation_reference = allocation.allocation_reference
        JOIN public.sub_contracts
            ON sub_contracts.contno = allocated_contracts.contno
           AND sub_contracts.split  = allocated_contracts.split
        JOIN public.phys_avail
            ON phys_avail.contno = sub_contracts.contno
           AND phys_avail.split  = sub_contracts.split
        JOIN public.master_contracts
            ON master_contracts.contno = sub_contracts.contno
        CROSS JOIN public.params
        WHERE allocation.allocation_completed = 'N'
    ) s_b
) s_
WHERE s_.stock_allocation_check = 'N'
  AND s_.fixed_flag = 'Fixed'
ORDER BY
    s_.company,
    s_.commodtype,
    s_.fixed_flag,
    s_.allocation_reference,
    s_.contract_type;
