-- ============================================================
-- powerbi_physical_contracts
-- Source: dba.PowerBI_Physical_Contracts
-- Simple join of master_contracts, sub_contracts, phys_avail, params.
-- No alias deps or complex transformations.
--
-- SAP → PostgreSQL translations:
--   sp_convert_qty(...) → public.sp_convert_qty(...).
--   Comma-joins → explicit JOINs; params → CROSS JOIN.
--   ORDER BY retained.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_physical_contracts AS

SELECT
    mc.contract_type,
    sc.contno                                                          AS contract_number,
    sc.split,
    mc.contdate                                                        AS contract_date,
    sc.client,
    mc.commodtype                                                      AS commodity_type,
    mc.origin,
    mc.quality,
    sc.orgunquant                                                      AS original_quantity,
    sc.quantunit                                                       AS quantity_unit,
    public.sp_convert_qty(sc.orgunquant, sc.quantunit, p.base_unit)   AS original_tonnage,
    sc.unquantity                                                      AS open_quantity,
    public.sp_convert_qty(sc.unquantity, sc.quantunit, p.base_unit)   AS open_tonnage,
    pa.stock                                                           AS stock_quantity,
    public.sp_convert_qty(pa.stock, sc.quantunit, p.base_unit)        AS stock_tonnage
FROM public.master_contracts mc
JOIN public.sub_contracts sc
    ON sc.contno = mc.contno
JOIN public.phys_avail pa
    ON  pa.contno = sc.contno
    AND pa.split  = sc.split
CROSS JOIN public.params p
ORDER BY mc.contract_type,
         sc.contno,
         sc.split;
