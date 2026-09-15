-- ============================================================
-- powerbi_caja_stocks_by_warehouse
-- Source: dba.PowerBI_Caja_Stocks_By_Warehouse
--
-- SAP → PostgreSQL translations:
--   base_unit used in sp_convert_qty (col 4) is a forward alias to
--     (select params.base_unit from params) at the end of the SELECT.
--     Resolved: CROSS JOIN public.params; params.base_unit used throughout.
--   net_wgt > 0 in WHERE references SELECT alias — inlined to
--     public.sp_convert_qty(stocks.quantity, stocks.quantity_unit, params.base_unit) > 0.
--   (select params.base_unit from params) → params.base_unit (already joined).
--   Comma-joins for sub_contracts and master_contracts → explicit JOINs.
--   LEFT OUTER JOINs for client and shipment retained as-is.
--   CASE stocks.status WHEN 'A' THEN ... END — ANSI CASE, valid in PostgreSQL.
--   sp_allocation_check_if_only_stock / sp_convert_qty → public.* prefix.
--   ORDER BY retained (faithful to source; order not guaranteed when view is queried).
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_caja_stocks_by_warehouse AS

SELECT
    stocks.contno,
    stocks.split,
    stocks.stock_id,
    public.sp_convert_qty(stocks.quantity, stocks.quantity_unit, params.base_unit) AS net_wgt,
    'MT'                                                                             AS quantity_unit,
    CASE stocks.status
        WHEN 'A' THEN 'Afloat'
        WHEN 'L' THEN 'Landed'
        WHEN 'I' THEN 'ISF Filled'
        WHEN 'G' THEN 'Warehouse in origin'
        WHEN 'T' THEN 'Sample approved/SI Sent'
        WHEN 'S' THEN 'Sample approved'
        WHEN 'D' THEN 'Pending Roaster Approval'
        WHEN 'R' THEN 'Release waiting for B/L'
        WHEN 'F' THEN 'Pending Final Fixation'
        WHEN 'B' THEN 'Tolling'
        WHEN 'P' THEN 'Warehouse Pending'
        WHEN 'W' THEN 'Warehouse'
        WHEN 'N' THEN 'No Sample'
        WHEN 'C' THEN 'Completed'
        WHEN 'O' THEN 'Other'
    END                                                                              AS stock_status,
    stocks.company,
    stocks.pcentre,
    stocks.commodity,
    stocks.commodity_type,
    stocks.origin,
    stocks.quality,
    stocks.allocation_reference,
    public.sp_allocation_check_if_only_stock(stocks.allocation_reference)           AS stock_allocation,
    stocks.original_allocation_reference                                             AS original_allocation,
    stocks.shipment_id,
    shipment.eta,
    shipment.arrived_instore_date,
    stocks.current_location,
    stocks.final_landing                                                             AS stock_in_date,
    stocks.status,
    stocks.original_client                                                           AS supplier,
    mc.priceterm                                                                     AS price_terms,
    params.base_unit,
    cl.longname
FROM public.stocks
LEFT OUTER JOIN public.client cl
    ON cl.code = stocks.warehouse
LEFT OUTER JOIN public.shipment
    ON shipment.shipment_id = stocks.shipment_id
JOIN public.sub_contracts sc
    ON  sc.contno = stocks.contno
    AND sc.split  = stocks.split
JOIN public.master_contracts mc
    ON mc.contno = sc.contno
CROSS JOIN public.params
WHERE public.sp_convert_qty(stocks.quantity, stocks.quantity_unit, params.base_unit) > 0
ORDER BY cl.longname ASC,
         stocks.contno ASC,
         stocks.split ASC,
         stocks.stock_id ASC;
