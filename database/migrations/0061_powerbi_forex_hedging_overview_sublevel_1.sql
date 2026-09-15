-- ============================================================
-- powerbi_forex_hedging_overview_sublevel_1
-- Source: dba.PowerBI_Forex_Hedging_Overview_Sublevel_1
--
-- SAP → PostgreSQL translations:
--   Nested IF/THEN → nested CASE WHEN.
--   sp_phys_avefixprice called once via lq1 (only when price_fixing='Y'),
--     then lq2 derives contract_price — avoids double function call.
--   GROUP BY aliases not supported in PostgreSQL — expressions repeated;
--     lq1.original_tonnage and lq2.contract_price referenced by lateral alias.
--   sp_sopex_get_sum_invoice_value(contno, split) is functionally determined
--     by GROUP BY keys; added to GROUP BY to satisfy PostgreSQL.
--   list(invoice_number) → STRING_AGG(inv.invoice_number, ',').
--   Comma-joins → explicit JOINs; params → CROSS JOIN.
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_forex_hedging_overview_sublevel_1 AS

SELECT
    sc.contno                                                                         AS contract_number,
    sc.split,
    mc.contdate                                                                       AS contract_date,
    mc.commodtype                                                                     AS commodity_type,
    sc.orgunquant                                                                     AS original_quantity,
    sc.quantunit                                                                      AS unit,
    lq1.original_tonnage,
    lq2.contract_price,
    sc.currency,
    sc.priceunit                                                                      AS price_unit,
    SUM(id2.invoiced_quantity)                                                        AS quantity_invoiced,
    public.sp_sopex_get_sum_invoice_value(sc.contno, sc.split)                       AS amount_invoiced,
    STRING_AGG(inv.invoice_number, ',')                                               AS invoice_numbers
FROM public.master_contracts mc
JOIN public.sub_contracts sc
    ON sc.contno = mc.contno
JOIN public.invoice_details_2 id2
    ON  id2.contno = sc.contno
    AND id2.split  = sc.split
JOIN public.invoice inv
    ON  inv.invoice_number = id2.invoice_number
    AND inv.invoice_type   = id2.invoice_type
    AND inv.client         = id2.client
CROSS JOIN public.params p
CROSS JOIN LATERAL (
    SELECT
        public.sp_convert_qty(sc.orgunquant, sc.quantunit, p.base_unit)              AS original_tonnage,
        CASE WHEN sc.price_fixing = 'Y'
             THEN public.sp_phys_avefixprice(sc.contno, sc.split)
             ELSE NULL
        END                                                                           AS avefixprice
) AS lq1
CROSS JOIN LATERAL (
    SELECT
        CASE WHEN sc.price_fixing = 'Y'
             THEN CASE WHEN lq1.avefixprice = 0.0000 THEN 0.00::numeric
                       ELSE lq1.avefixprice
                  END
             ELSE sc.unitprice
        END                                                                           AS contract_price
) AS lq2
WHERE inv.posted_ledref IS NOT NULL
GROUP BY
    sc.contno,
    sc.split,
    mc.contdate,
    mc.commodtype,
    sc.orgunquant,
    sc.quantunit,
    lq1.original_tonnage,
    lq2.contract_price,
    sc.currency,
    sc.priceunit,
    public.sp_sopex_get_sum_invoice_value(sc.contno, sc.split);
