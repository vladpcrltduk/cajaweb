-- ============================================================
-- powerbi_splits_browser
-- Source: dba.PowerBI_Splits_Browser
-- No alias deps.
--
-- SAP → PostgreSQL translations:
--   IF pa.unfixed > 0 THEN 'Y' ELSE 'N' ENDIF  → CASE WHEN ... END.
--   IF mc.contract_type = 'P' THEN sp_sopex_get_sum_free_unmatched_stock ELSE 0 ENDIF
--     → CASE WHEN ... END.
--   dateformat(shipfrom,'MMMYYYY')  → TO_CHAR(sc.shipfrom,'FMMonYYYY').
--   UNQUANTITY/STOCK in WHERE (unqualified SAP refs) → sc.unquantity / pa.stock.
--   "phys_avail"."Unallocated" (capital U) → pa.unallocated (PostgreSQL lowercase).
--   All sp_* functions → public.sp_* prefix.
--   Comma-joins → explicit JOINs.
--   ORDER BY retained.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_splits_browser AS

SELECT
    sc.contno,
    sc.split,
    mc.contract_type,
    mc.contdate,
    mc.company,
    sc.client,
    cl.country,
    mc.commodity,
    mc.commodtype,
    sc.origin,
    sc.quality,
    q.longname,
    sc.orgunquant,
    sc.unquantity,
    public.sp_convert_qty(sc.orgunquant, sc.quantunit, 'MT')                         AS original_tonnage,
    CASE WHEN pa.unfixed > 0 THEN 'Y' ELSE 'N' END                                  AS is_contract_unfixed,
    CASE WHEN mc.contract_type = 'P'
         THEN public.sp_sopex_get_sum_free_unmatched_stock(sc.contno, sc.split)
         ELSE 0
    END                                                                               AS true_open,
    pa.stock,
    sc.quantunit,
    sc.dest,
    sc.shipordelv,
    sc.pflots,
    mc.prcstlocn,
    sc.split_reference,
    pa.moved,
    public.sp_allocation_calculate_total_normal_alloc_quantity(sc.contno, sc.split)  AS allocated_to_sales,
    public.sp_allocation_calculate_only_normal_alloc_stock_quantity(sc.contno, sc.split) AS allocated_to_sales_invoiced,
    public.sp_allocation_calculate_only_stock_alloc_quantity(sc.contno, sc.split)   AS allocated_to_stock,
    public.sp_allocation_calculate_only_stock_alloc_stock_quantity(sc.contno, sc.split) AS allocated_to_stock_invoiced,
    pa.unallocated,
    pa.invoiced,
    pa.uninvoiced,
    pa.invposted,
    pa.invunposted,
    pa.fixed,
    pa.unfixed,
    pa.fixedlots,
    pa.unfixedlots,
    pa.fixed_base,
    pa.unfixed_base,
    pa.price_fixing,
    pa.fixbydate,
    sc.currency,
    public.sp_pricestr(sc.price_fixing, sc.unitprice, sc.currency, sc.priceunit,
        sc.pfcontract, sc.pfposition, sc.pfdifftype,
        sc.pfdiffer, sc.pfdiffcurr, sc.pfdiffunit)                                  AS price_string,
    public.sp_prompt_month(sc.valuedin)                                              AS cp_validin_str,
    sc.valuedin,
    public.sp_prompt_month(sc.vlposition)                                            AS cp_vlposition_str,
    mc.priceterm,
    sc.shipordelv                                                                     AS shipment_or_delivery,
    sc.ship_desc,
    sc.shipfrom,
    TO_CHAR(sc.shipfrom, 'FMMonYYYY')                                               AS shipment_month,
    sc.shipto,
    mc.clientref,
    mc.clientref2,
    pa.openqnt,
    public.sp_convert_qty(pa.openqnt, sc.quantunit, 'MT')                           AS open_tonnage,
    sc.pcentre,
    public.sp_phys_avetermhedgeprice(sc.contno, sc.split)                           AS avg_term_hedge_price,
    public.sp_phys_avefixprice(sc.contno, sc.split)                                 AS avgfixprice,
    public.sp_phys_getdifferential(sc.contno, sc.split)                             AS differential,
    mc.packing,
    mc.specialty,
    mc.producer,
    mc.contract_user_owner                                                            AS responsible_user,
    sc.othernotes,
    (SELECT MIN(pch.hist_user)
     FROM public.phys_contract_history pch
     WHERE pch.contno    = sc.contno
       AND pch.split     = sc.split
       AND pch.hist_type = 'CN')                                                     AS username
FROM public.phys_avail pa
JOIN public.sub_contracts sc
    ON  sc.contno = pa.contno
    AND sc.split  = pa.split
JOIN public.master_contracts mc
    ON mc.contno = sc.contno
JOIN public.client cl
    ON cl.code = sc.client
JOIN public.quality q
    ON q.code = sc.quality
WHERE (sc.unquantity > 0 OR pa.stock > 0)
ORDER BY sc.contno ASC,
         sc.split  ASC;
