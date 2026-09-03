-- Migration 0014: Widen allocation_reference variant columns from char(10) to char(20)
-- Columns:
--   allocation_reallocation_history.from_alloc_ref
--   allocation_reallocation_history.to_alloc_ref
--   allocation_reallocation_history.original_allocation_reference
--   stocks.original_allocation_reference
-- No FK constraints. 3 views depend on stocks.original_allocation_reference.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0014_alloc_ref_variants_widen') THEN
    RAISE NOTICE 'Migration 0014 already applied, skipping.';
    RETURN;
  END IF;

  -- ============================================================
  -- STEP 1: Drop dependent views
  -- ============================================================
  DROP VIEW IF EXISTS public.invoice_details_2_copy_of_original_view CASCADE;
  DROP VIEW IF EXISTS public.powerbi_caja_stocks_by_warehouse CASCADE;
  DROP VIEW IF EXISTS public.powerbi_invoiced_contracts CASCADE;

  -- ============================================================
  -- STEP 2: Widen columns
  -- ============================================================
  ALTER TABLE public.allocation_reallocation_history ALTER COLUMN from_alloc_ref              TYPE char(20);
  ALTER TABLE public.allocation_reallocation_history ALTER COLUMN to_alloc_ref                TYPE char(20);
  ALTER TABLE public.allocation_reallocation_history ALTER COLUMN original_allocation_reference TYPE char(20);
  ALTER TABLE public.stocks                          ALTER COLUMN original_allocation_reference TYPE char(20);

  INSERT INTO schema_migrations (script_name) VALUES ('0014_alloc_ref_variants_widen');
  RAISE NOTICE 'Migration 0014 applied successfully.';
END;
$$;

-- ============================================================
-- Recreate 3 dependent views
-- ============================================================

CREATE OR REPLACE VIEW public.invoice_details_2_copy_of_original_view AS
 SELECT stocks.contno,
    stocks.split,
    sum(stocks.net_shipped_weight) AS stock_quantity,
    stocks.original_allocation_reference,
    stocks.original_invoice_number,
    stocks.original_invoice_type,
    stocks.original_client
   FROM public.stocks,
    public.invoice_stocks
  WHERE ((stocks.original_invoice_number = invoice_stocks.invoice_number) AND (stocks.original_invoice_type = invoice_stocks.invoice_type) AND (stocks.original_client = invoice_stocks.client) AND (stocks.contno = invoice_stocks.contno) AND (stocks.split = invoice_stocks.split) AND (stocks.stock_id = invoice_stocks.stock_id))
  GROUP BY stocks.contno, stocks.split, stocks.original_allocation_reference, stocks.original_invoice_number, stocks.original_invoice_type, stocks.original_client
  ORDER BY stocks.contno, stocks.split, stocks.original_allocation_reference, stocks.original_invoice_number, stocks.original_invoice_type, stocks.original_client;

CREATE OR REPLACE VIEW public.powerbi_caja_stocks_by_warehouse AS
 SELECT stocks.contno,
    stocks.split,
    stocks.stock_id,
    public.sp_convert_qty(stocks.quantity, stocks.quantity_unit, params.base_unit) AS net_wgt,
    'MT'::text AS quantity_unit,
        CASE stocks.status
            WHEN 'A'::bpchar THEN 'Afloat'::text
            WHEN 'L'::bpchar THEN 'Landed'::text
            WHEN 'I'::bpchar THEN 'ISF Filled'::text
            WHEN 'G'::bpchar THEN 'Warehouse in origin'::text
            WHEN 'T'::bpchar THEN 'Sample approved/SI Sent'::text
            WHEN 'S'::bpchar THEN 'Sample approved'::text
            WHEN 'D'::bpchar THEN 'Pending Roaster Approval'::text
            WHEN 'R'::bpchar THEN 'Release waiting for B/L'::text
            WHEN 'F'::bpchar THEN 'Pending Final Fixation'::text
            WHEN 'B'::bpchar THEN 'Tolling'::text
            WHEN 'P'::bpchar THEN 'Warehouse Pending'::text
            WHEN 'W'::bpchar THEN 'Warehouse'::text
            WHEN 'N'::bpchar THEN 'No Sample'::text
            WHEN 'C'::bpchar THEN 'Completed'::text
            WHEN 'O'::bpchar THEN 'Other'::text
            ELSE NULL::text
        END AS stock_status,
    stocks.company,
    stocks.pcentre,
    stocks.commodity,
    stocks.commodity_type,
    stocks.origin,
    stocks.quality,
    stocks.allocation_reference,
    public.sp_allocation_check_if_only_stock(stocks.allocation_reference) AS stock_allocation,
    stocks.original_allocation_reference AS original_allocation,
    stocks.shipment_id,
    shipment.eta,
    shipment.arrived_instore_date,
    stocks.current_location,
    stocks.final_landing AS stock_in_date,
    stocks.status,
    stocks.original_client AS supplier,
    master_contracts.priceterm AS price_terms,
    ( SELECT params_1.base_unit
           FROM public.params params_1) AS base_unit,
    client.longname
   FROM ((public.stocks
     LEFT JOIN public.client ON ((stocks.warehouse = client.code)))
     LEFT JOIN public.shipment ON ((stocks.shipment_id = shipment.shipment_id))),
    public.sub_contracts,
    public.master_contracts,
    public.params
  WHERE ((sub_contracts.split = stocks.split) AND (sub_contracts.contno = stocks.contno) AND (sub_contracts.contno = master_contracts.contno) AND (public.sp_convert_qty(stocks.quantity, stocks.quantity_unit, params.base_unit) > (0)::numeric))
  ORDER BY client.longname, stocks.contno, stocks.split, stocks.stock_id;

CREATE OR REPLACE VIEW public.powerbi_invoiced_contracts AS
 SELECT invoice.invoice_type,
    invoice.invoice_number,
    stocks.original_allocation_reference AS invoice_allocation_reference,
    invoice.client AS invoice_client,
    client.country AS client_country,
    invoice.commodity_type AS invoice_commodity_type,
    invoice.origin AS invoice_origin,
    invoice.quality AS invoice_quality,
    invoice.invoice_date AS invoice_document_date,
    invoice.posted_date AS invoice_posted_date,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.house_rate AS invoice_house_rate,
    invoice.payment_terms AS invoice_payment_terms,
    sub_contracts.contno AS contract_number,
    sub_contracts.split,
    master_contracts.contdate AS contract_date,
    master_contracts.priceterm AS price_terms,
    master_contracts.prcstlocn AS price_terms_location,
    sub_contracts.shipordelv AS shipment_or_delivery,
    sub_contracts.shipment AS shipment_period,
    sub_contracts.shipfrom AS shipment_from,
    sub_contracts.shipto AS shipment_to,
    sub_contracts.orgunquant AS contract_original_quantity,
    sub_contracts.quantunit AS quantity_unit,
    public.sp_convert_qty(sub_contracts.orgunquant, sub_contracts.quantunit, params.base_unit) AS contract_original_tonnage,
    ( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))) AS invoice_positional_quantity,
    public.sp_convert_qty(( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))), sub_contracts.quantunit, params.base_unit) AS invoice_positional_tonnage,
    ( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))) AS invoice_invoiced_quantity,
    public.sp_convert_qty(( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))), sub_contracts.quantunit, params.base_unit) AS invoice_invoiced_tonnage,
    (((((stocks.contno)::text || '-'::text) || (stocks.split)::text) || '-'::text) || concat(stocks.stock_id)) AS stock_reference,
    invoice_stocks.stock_quantity,
    stocks.quantity_unit AS stock_quantity_unit,
    public.sp_convert_qty(invoice_stocks.stock_quantity, stocks.quantity_unit, params.base_unit) AS stock_tonnage,
    stocks.original_invoice_number AS stock_purchase_invoice_number,
    stocks.original_client AS stock_purchase_invoice_client,
    stocks.original_allocation_reference AS stock_purchase_allocation_reference,
    stocks.commodity_type AS stock_commodity_type,
    stocks.origin AS stock_origin,
    stocks.quality AS stock_quality,
    invoice.invoice_date AS stock_purchase_invoice_document_date,
    invoice.posted_date AS stock_purchase_invoice_posted_date
   FROM public.invoice,
    public.invoice_stocks,
    public.master_contracts,
    public.sub_contracts,
    public.client,
    public.stocks,
    public.params
  WHERE ((invoice.invoice_type = invoice_stocks.invoice_type) AND (invoice.invoice_number = invoice_stocks.invoice_number) AND (invoice.client = invoice_stocks.client) AND (invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id) AND (stocks.contno = sub_contracts.contno) AND (stocks.split = sub_contracts.split) AND (invoice_stocks.contno = master_contracts.contno) AND (invoice.client = client.code) AND (invoice.invoice_type = 'P'::bpchar) AND (invoice_stocks.stock_quantity > (0)::numeric) AND (invoice.posted_date IS NOT NULL))
UNION ALL
 SELECT invoice_details_2.invoice_type,
    invoice_details_2.invoice_number,
    invoice_details_2.allocation_reference AS invoice_allocation_reference,
    invoice_details_2.client AS invoice_client,
    client.country AS client_country,
    invoice.commodity_type AS invoice_commodity_type,
    invoice.origin AS invoice_origin,
    invoice.quality AS invoice_quality,
    invoice.invoice_date AS invoice_document_date,
    invoice.posted_date AS invoice_posted_date,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.house_rate AS invoice_house_rate,
    invoice.payment_terms AS invoice_payment_terms,
    invoice_details_2.contno AS contract_number,
    invoice_details_2.split,
    master_contracts.contdate AS contract_date,
    master_contracts.priceterm AS price_terms,
    master_contracts.prcstlocn AS price_terms_location,
    sub_contracts.shipordelv AS shipment_or_delivery,
    sub_contracts.shipment AS shipment_period,
    sub_contracts.shipfrom AS shipment_from,
    sub_contracts.shipto AS shipment_to,
    sub_contracts.orgunquant AS contract_original_quantity,
    sub_contracts.quantunit AS quantity_unit,
    public.sp_convert_qty(sub_contracts.orgunquant, sub_contracts.quantunit, params.base_unit) AS contract_original_tonnage,
    invoice_details_2.positional_quantity AS invoice_positional_quantity,
    public.sp_convert_qty(invoice_details_2.positional_quantity, sub_contracts.quantunit, params.base_unit) AS invoice_positional_tonnage,
    invoice_details_2.invoiced_quantity AS invoice_invoiced_quantity,
    public.sp_convert_qty(invoice_details_2.invoiced_quantity, sub_contracts.quantunit, params.base_unit) AS invoice_invoiced_tonnage,
    (((((stocks.contno)::text || '-'::text) || (stocks.split)::text) || '-'::text) || concat(stocks.stock_id)) AS stock_reference,
    invoice_stocks.stock_quantity,
    stocks.quantity_unit AS stock_quantity_unit,
    public.sp_convert_qty(invoice_stocks.stock_quantity, stocks.quantity_unit, params.base_unit) AS stock_tonnage,
    stocks.original_invoice_number AS stock_purchase_invoice_number,
    stocks.original_client AS stock_purchase_invoice_client,
    stocks.original_allocation_reference AS stock_purchase_allocation_reference,
    stocks.commodity_type AS stock_commodity_type,
    stocks.origin AS stock_origin,
    stocks.quality AS stock_quality,
    ( SELECT purch_invoice.invoice_date
           FROM public.invoice purch_invoice
          WHERE ((purch_invoice.invoice_number = stocks.original_invoice_number) AND (purch_invoice.client = stocks.original_client) AND (purch_invoice.invoice_type = 'P'::bpchar))) AS stock_purchase_invoice_document_date,
    ( SELECT purch_invoice.posted_date
           FROM public.invoice purch_invoice
          WHERE ((purch_invoice.invoice_number = stocks.original_invoice_number) AND (purch_invoice.client = stocks.original_client) AND (purch_invoice.invoice_type = 'P'::bpchar))) AS stock_purchase_invoice_posted_date
   FROM public.invoice,
    public.invoice_details_2,
    public.invoice_stocks,
    public.master_contracts,
    public.sub_contracts,
    public.client,
    public.stocks,
    public.params
  WHERE ((invoice.invoice_type = invoice_details_2.invoice_type) AND (invoice.invoice_number = invoice_details_2.invoice_number) AND (invoice.client = invoice_details_2.client) AND (invoice_details_2.invoice_type = invoice_stocks.invoice_type) AND (invoice_details_2.invoice_number = invoice_stocks.invoice_number) AND (invoice_details_2.client = invoice_stocks.client) AND (invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id) AND (invoice.client = client.code) AND (invoice_details_2.contno = master_contracts.contno) AND (invoice_details_2.contno = sub_contracts.contno) AND (invoice_details_2.split = sub_contracts.split) AND (invoice.invoice_type = 'S'::bpchar))
  ORDER BY 1, 2, 4, 10, 11;
