-- ============================================================
-- powerbi_caja_stocks_status_overview
-- Source: dba.PowerBI_Caja_Stocks_Status_Overview
--
-- SAP → PostgreSQL translations:
--   Mixed comma-join + LEFT OUTER JOIN → explicit JOIN chain.
--     master_contracts comma-joined with sub_contracts group → JOIN ON contno.
--     params comma-joined → CROSS JOIN public.params.
--     Trailing comma before WHERE (SAP quirk) removed.
--   Alias forward-ref: Purchase_Price (IF on price_fixing) is consumed by
--     Uninvoiced_Value in the same SELECT → resolved via CROSS JOIN LATERAL lq1.
--   IF/THEN/ENDIF → CASE WHEN ... END (three occurrences):
--     purchase_price: price_fixing='Y' → sp_phys_avefixprice else unitprice.
--     uninvoiced_value: currency='USC' → divide by 100 (USC = US cents).
--     sales_invoice_posted: nested IF → flattened CASE (null→null, posted_date null→'N', else 'Y').
--   isnull(x,0) (2-arg) → COALESCE(x,0).
--   dba.phys_stocks correlated subquery → public.phys_stocks.
--   sp_pricestr / sp_phys_avefixprice / sp_convert_qty → public.* prefix.
--   Commented-out sp_sopex_get_estimated_stock_outbooking_amount retained as comment.
--   ORDER BY aliases → ORDER BY source column refs.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_caja_stocks_status_overview AS

SELECT
    mc.contno                                                               AS purchase_contract,
    mc.contdate                                                             AS contract_date,
    mc.client                                                               AS supplier,
    mc.commodity,
    mc.commodtype                                                           AS type,
    mc.origin,
    mc.quality,
    sc.split                                                                AS contract_split,
    sc.orgunquant                                                           AS original_quantity,
    sc.unquantity                                                           AS uninvoiced_quantity,
    COALESCE((
        SELECT SUM(s.stock_qty)
        FROM public.phys_stocks s
        WHERE s.contno = st.contno
          AND s.split  = st.split
    ), 0)                                                                   AS total_stock_of_contract,
    sc.quantunit                                                            AS quantity_unit,
    sc.currency                                                             AS contract_currency,
    sc.priceunit                                                            AS contract_price_unit,
    public.sp_pricestr(
        sc.price_fixing, sc.unitprice, sc.currency, sc.priceunit,
        sc.pfcontract, sc.pfposition, sc.pfdifftype, sc.pfdiffer,
        sc.pfdiffcurr, sc.pfdiffunit
    )                                                                       AS contract_price_desc,
    lq1.purchase_price,
    CASE WHEN sc.currency = 'USC' THEN
        ROUND(public.sp_convert_qty(lq1.purchase_price, sc.quantunit, sc.priceunit) * sc.unquantity / 100, 2)
    ELSE
        ROUND(public.sp_convert_qty(lq1.purchase_price, sc.quantunit, sc.priceunit) * sc.unquantity, 2)
    END                                                                     AS uninvoiced_value,
    CASE WHEN sc.currency = 'USC' THEN 'USD' ELSE sc.currency END          AS value_currency,
    st.stock_id,
    st.quantity                                                             AS stock_quantity,
    public.sp_convert_qty(st.quantity, sc.quantunit, p.base_unit)          AS stock_tonnage,
    st.status                                                               AS stock_status,
    st.current_location                                                     AS location,
    st.warehouse,
    st.allocation_reference,
    st.original_invoice_number                                              AS parent_purchase_invoice,
    -- public.sp_sopex_get_estimated_stock_outbooking_amount(st.contno, st.split, st.stock_id, st.original_invoice_number, mc.client, st.original_allocation_reference, st.quantity, sc.quantunit) AS cost_of_stock,
    inv.invoice_number                                                      AS assigned_to_sales_invoice,
    ivs.stock_quantity                                                      AS assigned_stock_quantity,
    inv.client                                                              AS sales_invoice_client,
    inv.invoice_date                                                        AS sales_invoice_date,
    CASE WHEN inv.invoice_number IS NULL THEN NULL
         WHEN inv.posted_date IS NULL    THEN 'N'
         ELSE 'Y'
    END                                                                     AS sales_invoice_posted
FROM public.master_contracts mc
JOIN public.sub_contracts sc
    ON  sc.contno = mc.contno
LEFT JOIN public.stocks st
    ON  st.contno = sc.contno
    AND st.split  = sc.split
LEFT JOIN public.invoice_stocks ivs
    ON  ivs.contno       = st.contno
    AND ivs.split        = st.split
    AND ivs.stock_id     = st.stock_id
    AND ivs.invoice_type = 'S'
LEFT JOIN public.invoice inv
    ON  inv.invoice_number = ivs.invoice_number
    AND inv.invoice_type   = ivs.invoice_type
    AND inv.client         = ivs.client
CROSS JOIN public.params p
CROSS JOIN LATERAL (
    SELECT
        CASE WHEN sc.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sc.contno, sc.split)
             ELSE sc.unitprice
        END AS purchase_price
) AS lq1
WHERE mc.contract_type = 'P'
ORDER BY mc.contno,
         sc.split,
         st.stock_id;
