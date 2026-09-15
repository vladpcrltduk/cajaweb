-- ============================================================
-- powerbi_caja_purchase_sales_invoices
-- Source: dba.PowerBI_Caja_Purchase_Sales_Invoices
-- 2-branch UNION ALL: provisional invoices + final invoices.
-- No alias deps — all columns come directly from tables.
--
-- SAP → PostgreSQL translations:
--   IF...THEN...ELSE...END IF          → CASE WHEN...THEN...ELSE...END
--   ifnull(x,'N','Y')  (3-arg)         → CASE WHEN x IS NULL THEN 'N' ELSE 'Y' END
--   dateformat(d,'MMMYYYY')            → TO_CHAR(d,'FMMonYYYY')   (e.g. Jan2024)
--   dateformat(d,'YYYY-MM')            → TO_CHAR(d,'YYYY-MM')
--   sp_convert_qty(...)                → public.sp_convert_qty(...)
--   Comma-joins → explicit JOINs.
--   Duplicate WHERE clause entry (invoice.client = id2.client) removed.
--   ORDER BY 2 (Invoice_Number) retained on full UNION result.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_caja_purchase_sales_invoices AS

-- Branch 1: Provisional invoices
SELECT
    CASE WHEN mc.contract_type = 'P' THEN 'Purchase Invoice' ELSE 'Sales Invoice' END  AS invoice_title,
    inv.invoice_number,
    inv.invoice_date,
    inv.commodity_type                                                                   AS invoice_commodity_type,
    inv.origin                                                                           AS invoice_origin,
    inv.quality                                                                          AS invoice_quality,
    inv.percentage_invoiced                                                              AS basis,
    CASE WHEN inv.posted_ledref IS NULL THEN 'N' ELSE 'Y' END                           AS posted,
    mc.contract_type,
    inv.posted_date,
    id2.allocation_reference,
    id2.contno                                                                           AS contract_number,
    id2.split                                                                            AS contract_split,
    sc.client                                                                            AS counterparty,
    cl.country                                                                           AS counterparty_country,
    mc.priceterm                                                                         AS contract_price_term,
    mc.prcstlocn                                                                         AS contract_price_term_location,
    inv.payment_terms,
    pt.longname                                                                          AS payment_terms_longname,
    sc.shipordelv                                                                        AS shipment_or_delivery,
    TO_CHAR(sc.shipfrom, 'FMMonYYYY')                                                   AS shipment_month,
    sc.shipfrom                                                                          AS shipment_from_date,
    sc.shipto                                                                            AS shipment_to_date,
    public.sp_convert_qty(pa.unfixed, sc.quantunit, 'MT')                               AS unfixed_tonnage,
    public.sp_convert_qty(id2.net_weight, id2.delivered_weight_unit, 'MT')              AS invoiced_tonnage,
    id2.linevalue * (inv.percentage_invoiced / 100)                                     AS invoice_line_value,
    inv.invoice_currency,
    inv.house_rate                                                                       AS invoice_house_rate,
    inv.percentage_invoiced                                                              AS invoice_basis,
    TO_CHAR(inv.posted_date, 'YYYY-MM')                                                 AS posted_date_year_month,
    inv.provisionally_released,
    inv.provisionally_released_settled
FROM public.invoice inv
JOIN public.invoice_details_2 id2
    ON  id2.invoice_type   = inv.invoice_type
    AND id2.invoice_number = inv.invoice_number
    AND id2.client         = inv.client
JOIN public.payment_term pt
    ON pt.code = inv.payment_terms
JOIN public.sub_contracts sc
    ON  sc.contno = id2.contno
    AND sc.split  = id2.split
JOIN public.master_contracts mc
    ON mc.contno = sc.contno
JOIN public.client cl
    ON cl.code = sc.client
JOIN public.phys_avail pa
    ON  pa.contno = sc.contno
    AND pa.split  = sc.split
CROSS JOIN public.params
WHERE inv.posted_date IS NOT NULL

UNION ALL

-- Branch 2: Final invoices
SELECT
    CASE WHEN mc.contract_type = 'P' THEN 'Final Purchase Invoice' ELSE 'Final Sales Invoice' END AS invoice_title,
    fi.final_invoice_number                                                              AS invoice_number,
    fi.invoice_date,
    fi.commodity_type                                                                    AS invoice_commodity_type,
    fi.origin                                                                            AS invoice_origin,
    sc.quality                                                                           AS invoice_quality,
    NULL                                                                                 AS basis,
    CASE WHEN fi.posted_ledref IS NULL THEN 'N' ELSE 'Y' END                            AS posted,
    mc.contract_type,
    fi.posted_date,
    fid2.allocation_reference,
    fid2.contno                                                                          AS contract_number,
    fid2.split                                                                           AS contract_split,
    sc.client                                                                            AS counterparty,
    cl.country                                                                           AS counterparty_country,
    mc.priceterm                                                                         AS contract_price_term,
    mc.prcstlocn                                                                         AS contract_price_term_location,
    fi.payment_terms,
    pt.longname                                                                          AS payment_terms_longname,
    sc.shipordelv                                                                        AS shipment_or_delivery,
    TO_CHAR(sc.shipfrom, 'FMMonYYYY')                                                   AS shipment_month,
    sc.shipfrom                                                                          AS shipment_from_date,
    sc.shipto                                                                            AS shipment_to_date,
    public.sp_convert_qty(pa.unfixed, sc.quantunit, 'MT')                               AS unfixed_tonnage,
    public.sp_convert_qty(fid2.net_weight, fid2.delivered_weight_unit, 'MT')            AS invoiced_tonnage,
    fid2.net_due_partial                                                                 AS invoice_line_value,
    fi.invoice_currency,
    fi.house_rate                                                                        AS invoice_house_rate,
    100                                                                                  AS invoice_basis,
    TO_CHAR(fi.posted_date, 'YYYY-MM')                                                  AS posted_date_year_month,
    NULL                                                                                 AS provisionally_released,
    NULL                                                                                 AS provisionally_released_settled
FROM public.final_invoice fi
JOIN public.final_invoice_details_2 fid2
    ON  fid2.invoice_type   = fi.invoice_type
    AND fid2.invoice_number = fi.invoice_number
    AND fid2.client         = fi.client
JOIN public.payment_term pt
    ON pt.code = fi.payment_terms
JOIN public.sub_contracts sc
    ON  sc.contno = fid2.contno
    AND sc.split  = fid2.split
JOIN public.master_contracts mc
    ON mc.contno = sc.contno
JOIN public.client cl
    ON cl.code = sc.client
JOIN public.phys_avail pa
    ON  pa.contno = sc.contno
    AND pa.split  = sc.split
CROSS JOIN public.params
WHERE fi.posted_date IS NOT NULL

ORDER BY 2;
