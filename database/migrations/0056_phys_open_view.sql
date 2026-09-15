-- ============================================================
-- phys_open_view
-- Source: dba.phys_open_view
-- Alias chain resolved via a single CROSS JOIN LATERAL that computes all
-- 5 correlated subqueries once (allocated, invoiced, fixed, fixedlots, stock).
-- Derived aliases then expressed in outer SELECT:
--   unallocated  = b.orgunquant - lq.allocated
--   invposted    = moved = b.orgunquant - b.unquantity  (inlined)
--   invunposted  = lq.invoiced - invposted               (inlined)
--   uninvoiced   = b.orgunquant - lq.invoiced
--   unfixed      = CASE WHEN price_fixing='Y' THEN b.orgunquant - lq.fixed ELSE 0
--   unfixedlots  = CASE WHEN price_fixing='Y' THEN b.pflots - lq.fixedlots ELSE 0
-- isnull(subquery, 0) → COALESCE(subquery, 0).
-- decimal(16,4) → numeric(16,4) (PostgreSQL alias).
-- IF...THEN...ELSE...ENDIF → CASE WHEN...THEN...ELSE...END.
-- params aliased 'h' retained from source.
-- ============================================================

CREATE OR REPLACE VIEW public.phys_open_view AS

SELECT
    b.contno,
    b.split,
    h.systemdate,
    a.company,
    a.pcentre,
    a.commodity,
    a.commodtype,
    a.origin,
    b.valuedin,
    a.contract_type,
    b.orgunquant                                                         AS original,
    b.quantunit,
    b.unquantity                                                         AS openqnt,
    b.orgunquant - b.unquantity                                          AS moved,
    lq.allocated,
    b.orgunquant - lq.allocated                                          AS unallocated,
    lq.invoiced,
    b.orgunquant - b.unquantity                                          AS invposted,
    lq.invoiced - (b.orgunquant - b.unquantity)                         AS invunposted,
    b.orgunquant - lq.invoiced                                           AS uninvoiced,
    b.price_fixing,
    lq.fixed,
    CASE WHEN b.price_fixing = 'Y'
         THEN b.orgunquant - lq.fixed
         ELSE 0::numeric(16,4)
    END                                                                  AS unfixed,
    lq.fixedlots,
    CASE WHEN b.price_fixing = 'Y'
         THEN b.pflots - lq.fixedlots
         ELSE 0
    END                                                                  AS unfixedlots,
    lq.stock
FROM public.master_contracts AS a
JOIN public.sub_contracts AS b
    ON b.contno = a.contno
CROSS JOIN public.params AS h
CROSS JOIN LATERAL (
    SELECT
        COALESCE(
            (SELECT SUM(c.quantity)
             FROM public.allocated_contracts AS c
             WHERE c.contno = b.contno AND c.split = b.split),
            0)                                                           AS allocated,
        COALESCE(
            (SELECT SUM(d.positional_quantity)
             FROM public.invoice_details AS d
             WHERE d.contno = b.contno AND d.split = b.split),
            0)                                                           AS invoiced,
        COALESCE(
            (SELECT SUM(f.fixed_qty)
             FROM public.phys_fixes AS f
             WHERE f.contno = b.contno AND f.split = b.split),
            0::numeric(16,4))                                            AS fixed,
        COALESCE(
            (SELECT SUM(f.lots)
             FROM public.fixes AS f
             WHERE f.contno = b.contno AND f.split = b.split),
            0)                                                           AS fixedlots,
        COALESCE(
            (SELECT SUM(s.stock_qty)
             FROM public.phys_stocks AS s
             WHERE s.contno = b.contno AND s.split = b.split),
            0)                                                           AS stock
) AS lq;
