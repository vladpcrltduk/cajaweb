-- ============================================================
-- powerbi_trading_browser
-- Source: dba.PowerBI_Trading_Browser
-- Simple passthrough from physical_trading_browser_main_view.
-- No alias deps or expression transformations.
--
-- SAP → PostgreSQL translations:
--   WITH (NOLOCK) table hint removed (SQL Server only; meaningless in PostgreSQL).
--   WHERE 1=1 removed (no-op filter).
--   ORDER BY 18, 7, 9 → ORDER BY column names (pos 18=eudr_date_harvest,
--     7=commodity, 9=client) for readability.
--   Source view name and all column names lowercased.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_trading_browser AS

SELECT
    v.conttype                    AS contract_type,
    v.contno                      AS contract_number,
    v.split                       AS contract_split,
    v.contdate                    AS contract_date,
    v.company,
    v.pcentre                     AS profit_centre,
    v.commodity,
    v.commodtype                  AS commodity_type,
    v.client,
    v.client_country,
    v.origin,
    v.quality,
    v.priceterm                   AS price_terms,
    v.prcst_location              AS price_terms_location,
    v.payment_term,
    v.certification,
    v.eudr_flag,
    v.eudr_date_harvest,
    v.ship_period                 AS shipment_period,
    v.delivery_period,
    v.vlcontract                  AS market,
    v.cp_valuedin_str             AS month,
    v.valn_string                 AS differential,
    v.base_openqnt                AS open_quantity,
    v.base_allocated              AS allocated,
    v.allocated_unfixed_tonnage   AS allocated_unfixed,
    v.base_unallocated            AS unallocated,
    v.base_invoiced               AS invoiced,
    v.invoiced_status,
    v.shipment_statuses,
    v.shipment_etd,
    v.shipment_eta,
    v.stock_warehouses
FROM public.physical_trading_browser_main_view v
ORDER BY v.eudr_date_harvest,
         v.commodity,
         v.client;
