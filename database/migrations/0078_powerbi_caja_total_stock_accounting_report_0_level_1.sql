-- ============================================================
-- powerbi_caja_total_stock_accounting_report_0_level_1
-- Source: dba.PowerBI_Caja_Total_Stock_Accounting_Report_0_Level_1
-- Built incrementally: this file adds branches one at a time (UNION ALL).
--
-- Branch 1: 34% nominal INVC/OUTB journal entries from Purchase Invoices.
--
-- SAP → PostgreSQL translations (branch 1):
--   // SAP line-comment style → --
--   All comma-joins → explicit JOINs.
--   IF/THEN/ENDIF → CASE WHEN ... END.
--   '+' string concat → '||'.
--   left(x,n) → LEFT(x::text, n).
--   isnull(x,y) (2-arg) → COALESCE(x,y).
--   sp_convert_qty / sp_phys_avefixprice → public.* prefix.
--   Alias forward-references resolved via two CTEs:
--     b1_detail: row-level pre-computation of all non-aggregate columns,
--       including unfixed_reversed_invoice_number_marker (from ad.comments)
--       and quantity_tonnage (which depends on that marker).
--       Avoids the forward-ref problem: both are in the same SELECT here.
--     b1_grouped: GROUP BY + aggregates (MIN/SUM);
--       is_there_stock derived from grouped.quantity.
--   Final SELECT: computes chained alias deps
--     (invoice_number uses accdetail_invoice_number + unfixed_reversed_invoice_number_marker,
--      base_amount uses grouped ledamt + house_rate,
--      sales_contract / sales_allocation_reference use journal_book_number).
--   journal_book_temp = '210' literal (always); journal_book_number = OUTB or '210'.
--   Commented-out WHERE conditions retained as SQL comments.
-- ============================================================

DROP VIEW IF EXISTS public.powerbi_caja_total_stock_accounting_report_0_level_1 CASCADE;

CREATE VIEW public.powerbi_caja_total_stock_accounting_report_0_level_1 AS

WITH b1_detail AS (
    SELECT
        acs.ledgernum,
        ad.accdetail_contno,
        ad.accdetail_split,
        sc.client,
        acs.an_tonnage                                                      AS original_tonnage,
        public.sp_convert_qty(sc.unquantity, sc.quantunit, p.base_unit)    AS unquantity,
        public.sp_convert_qty((
            SELECT SUM(st2.quantity)
            FROM public.stocks st2
            WHERE st2.contno = sc.contno
              AND st2.split  = sc.split
        ), sc.quantunit, p.base_unit)                                       AS quantity,
        sc.unitprice,
        public.sp_phys_avefixprice(sc.contno, sc.split)                    AS contract_average_fix_price,
        sc.currency,
        sc.priceunit,
        ad.nominal,
        CASE WHEN acs.journals = 'OUTB' THEN 'OUTB' ELSE '210' END         AS journal_book_number,
        acs.an_client,
        acs.leddate,
        acs.journals,
        acs.prov_inv_no,
        acs.analysis1,
        cur.ratetype,
        ad.accdetail_invoice_number,
        ad.currency                                                         AS accdetail_currency,
        ad.ledamt,
        ad.house_rate,
        p.base_currency,
        acs.contno                                                          AS acs_contno,
        acs.split                                                           AS acs_split,
        acs.an_allocref,
        mc.company,
        mc.commodity,
        mc.commodtype,
        mc.quality,
        mc.contdate,
        mc.contno,
        mc.amenddate,
        CASE WHEN LEFT(ad.comments::text, 46) = 'Opposite posting of original Unfixed P Invoice'
             THEN ' (Reversed Unfixed Prov)'
             ELSE ''
        END                                                                 AS unfixed_reversed_invoice_number_marker,
        CASE WHEN acs.journals IN ('OUTB', 'RTRN') THEN acs.an_tonnage
             WHEN LEFT(ad.comments::text, 46) = 'Opposite posting of original Unfixed P Invoice'
                  THEN -1 * acs.an_tonnage
             ELSE public.sp_convert_qty((
                 SELECT SUM(id2.invoiced_quantity)
                 FROM public.invoice inv2
                 JOIN public.invoice_details_2 id2
                     ON  id2.invoice_number = inv2.invoice_number
                     AND id2.invoice_type   = inv2.invoice_type
                     AND id2.client         = inv2.client
                 WHERE inv2.posted_ledref = acs.ledgernum
                   AND id2.contno         = sc.contno
                   AND id2.split          = sc.split
                   AND id2.nomcode        LIKE '34%'
             ), sc.quantunit, 'MT')
        END                                                                 AS quantity_tonnage
    FROM public.accsummary acs
    JOIN public.accdetail ad
        ON  ad.accperiod = acs.accperiod
        AND ad.ledgernum = acs.ledgernum
    JOIN public.sub_contracts sc
        ON  sc.contno = ad.accdetail_contno
        AND sc.split  = ad.accdetail_split
    JOIN public.master_contracts mc
        ON  mc.contno = sc.contno
    JOIN public.phys_avail pa
        ON  pa.contno = sc.contno
        AND pa.split  = sc.split
    JOIN public.currency cur
        ON  cur.code = ad.currency
    CROSS JOIN public.params p
    WHERE mc.amenddate              IS NULL
      AND mc.contract_type          = 'P'
      AND ad.accdetail_invoice_flag = 'PI'
      AND ad.accdetail_charges_line IS NULL
      AND ad.nominal                LIKE '34%'
      AND ad.nominal                <> '34999'
      AND acs.prov_inv_no           IS NOT NULL
      AND acs.exp_inv_no            IS NULL
    --  AND ( acs.reversed IS NULL OR acs.reversed <> 'Y' )
    --  AND ( is_there_stock = 'Y' OR pa.unallocated > 0 )
),
b1_grouped AS (
    SELECT
        1                                                                   AS order_flag,
        ledgernum,
        MIN(accdetail_contno)                                               AS accdetail_contno,
        MIN(accdetail_split)                                                AS accdetail_split,
        client,
        original_tonnage,
        unquantity,
        quantity,
        CASE WHEN quantity IS NULL THEN 'N' ELSE 'Y' END                    AS is_there_stock,
        unitprice,
        contract_average_fix_price,
        currency,
        priceunit,
        MIN(nominal)                                                        AS nominal,
        '210'                                                               AS journal_book_temp,
        journal_book_number,
        an_client,
        leddate,
        journals,
        prov_inv_no,
        analysis1,
        ratetype,
        MIN(accdetail_invoice_number)                                       AS accdetail_invoice_number,
        MIN(accdetail_currency)                                             AS accdetail_currency,
        SUM(ledamt) * -1                                                    AS ledamt,
        MIN(house_rate)                                                     AS house_rate,
        base_currency,
        acs_contno,
        acs_split,
        an_allocref,
        company,
        commodity,
        commodtype,
        quality,
        contdate,
        contno,
        amenddate,
        unfixed_reversed_invoice_number_marker,
        quantity_tonnage
    FROM b1_detail
    GROUP BY
        ledgernum, client, original_tonnage, unquantity, quantity,
        unitprice, contract_average_fix_price, currency, priceunit,
        journal_book_number, an_client, leddate, journals, prov_inv_no, analysis1,
        ratetype, base_currency, acs_contno, acs_split, an_allocref,
        company, commodity, commodtype, quality, contdate, contno, amenddate,
        unfixed_reversed_invoice_number_marker, quantity_tonnage
),
-- --------------------------------------------------------
-- Branch 3 CTEs: Final Purchase Invoices (FI/PF flag, fin_inv_no not null)
-- Same CTE pattern as branch 1; alias deps handled identically.
--   quantity_tonnage: IF OUTB → an_tonnage;
--     ELIF right(left(prov_inv_no,5),3)='206' → subquery sum(final_invoice_details_2.invoiced_quantity);
--     ELSE 0.00.
--   right(left(x,5),3) → RIGHT(LEFT(x::text,5),3).
--   sales_contract / sales_allocation_reference are always '' in this branch.
--   outbooking_purchase_invoice_number = analysis5 (not analysis1).
--   unfixed_reversed_invoice_number_marker: '' if OUTB else ' (Final Invoice)'.
-- --------------------------------------------------------
b3_detail AS (
    SELECT
        acs.ledgernum,
        ad.accdetail_contno,
        ad.accdetail_split,
        sc.client,
        acs.an_tonnage                                                      AS original_tonnage,
        public.sp_convert_qty(sc.unquantity, sc.quantunit, p.base_unit)    AS unquantity,
        public.sp_convert_qty((
            SELECT SUM(st2.quantity)
            FROM public.stocks st2
            WHERE st2.contno = sc.contno
              AND st2.split  = sc.split
        ), sc.quantunit, p.base_unit)                                       AS quantity,
        sc.unitprice,
        public.sp_phys_avefixprice(sc.contno, sc.split)                    AS contract_average_fix_price,
        sc.currency,
        sc.priceunit,
        ad.nominal,
        CASE WHEN acs.journals = 'OUTB' THEN 'OUTB' ELSE '210' END         AS journal_book_number,
        acs.an_client,
        acs.leddate,
        acs.journals,
        acs.prov_inv_no,
        acs.fin_inv_no,
        acs.analysis5,
        cur.ratetype,
        ad.currency                                                         AS accdetail_currency,
        ad.ledamt,
        ad.house_rate,
        p.base_currency,
        mc.company,
        mc.commodity,
        mc.commodtype,
        mc.quality,
        mc.contdate,
        mc.contno,
        mc.amenddate,
        CASE WHEN acs.journals = 'OUTB' THEN ''
             ELSE ' (Final Invoice)'
        END                                                                 AS unfixed_reversed_invoice_number_marker,
        CASE WHEN acs.journals = 'OUTB' THEN acs.an_tonnage
             WHEN RIGHT(LEFT(acs.prov_inv_no::text, 5), 3) = '206' THEN
                 (SELECT SUM(fid2.invoiced_quantity)
                  FROM public.final_invoice_details_2 fid2
                  WHERE fid2.invoice_number = acs.prov_inv_no)
             ELSE 0.00
        END                                                                 AS quantity_tonnage
    FROM public.accsummary acs
    JOIN public.accdetail ad
        ON  ad.accperiod = acs.accperiod
        AND ad.ledgernum = acs.ledgernum
    JOIN public.sub_contracts sc
        ON  sc.contno = ad.accdetail_contno
        AND sc.split  = ad.accdetail_split
    JOIN public.master_contracts mc
        ON  mc.contno = sc.contno
    JOIN public.phys_avail pa
        ON  pa.contno = sc.contno
        AND pa.split  = sc.split
    JOIN public.currency cur
        ON  cur.code = ad.currency
    CROSS JOIN public.params p
    WHERE mc.amenddate              IS NULL
      AND mc.contract_type          = 'P'
      AND (ad.accdetail_invoice_flag = 'FI' OR ad.accdetail_invoice_flag = 'PF')
      AND acs.fin_inv_no            IS NOT NULL
      AND acs.exp_inv_no            IS NULL
      AND ad.nominal                LIKE '34%'
      AND ad.nominal                <> '34999'
    --  AND ( acs.reversed IS NULL OR acs.reversed <> 'Y' )
    --  AND ( is_there_stock = 'Y' OR pa.unallocated > 0 )
),
b3_grouped AS (
    SELECT
        3                                                                   AS order_flag,
        ledgernum,
        MIN(accdetail_contno)                                               AS accdetail_contno,
        MIN(accdetail_split)                                                AS accdetail_split,
        client,
        original_tonnage,
        unquantity,
        quantity,
        CASE WHEN quantity IS NULL THEN 'N' ELSE 'Y' END                    AS is_there_stock,
        unitprice,
        contract_average_fix_price,
        currency,
        priceunit,
        MIN(nominal)                                                        AS nominal,
        '210'                                                               AS journal_book_temp,
        journal_book_number,
        an_client,
        leddate,
        journals,
        prov_inv_no,
        fin_inv_no,
        analysis5,
        ratetype,
        MIN(accdetail_currency)                                             AS accdetail_currency,
        SUM(ledamt) * -1                                                    AS ledamt,
        MIN(house_rate)                                                     AS house_rate,
        base_currency,
        company,
        commodity,
        commodtype,
        quality,
        contdate,
        contno,
        amenddate,
        unfixed_reversed_invoice_number_marker,
        quantity_tonnage
    FROM b3_detail
    GROUP BY
        ledgernum, client, original_tonnage, unquantity, quantity,
        unitprice, contract_average_fix_price, currency, priceunit,
        journal_book_number, an_client, leddate, journals, prov_inv_no, fin_inv_no, analysis5,
        ratetype, base_currency,
        company, commodity, commodtype, quality, contdate, contno, amenddate,
        unfixed_reversed_invoice_number_marker, quantity_tonnage
)
SELECT
    order_flag,
    ledgernum,
    accdetail_contno,
    accdetail_split,
    client,
    original_tonnage,
    unquantity,
    quantity,
    is_there_stock,
    unitprice,
    contract_average_fix_price,
    currency,
    priceunit,
    nominal,
    journal_book_temp,
    journal_book_number,
    an_client,
    leddate,
    CASE WHEN journals = 'OUTB' THEN
             prov_inv_no || ' (for P Inv: ' || analysis1 || ')'
         WHEN journals = 'RTRN' THEN
             analysis1 || ' (RETURN of ' || prov_inv_no || ')'
         ELSE
             accdetail_invoice_number || unfixed_reversed_invoice_number_marker
    END                                                                     AS invoice_number,
    ''                                                                      AS expense_number,
    accdetail_currency,
    ledamt,
    house_rate,
    CASE WHEN ratetype = 'M'
         THEN ROUND(ledamt * house_rate, 2)
         ELSE ROUND(ledamt / house_rate, 2)
    END                                                                     AS base_amount,
    quantity_tonnage,
    quantity_tonnage                                                         AS quantity_tonnage_shown,
    base_currency,
    CASE WHEN journal_book_number = 'OUTB'
         THEN acs_contno || '-' || acs_split
         ELSE ''
    END                                                                     AS sales_contract,
    CASE WHEN journal_book_number = 'OUTB'
         THEN an_allocref
         ELSE ''
    END                                                                     AS sales_allocation_reference,
    analysis1                                                               AS outbooking_purchase_invoice_number,
    company,
    commodity,
    commodtype,
    quality,
    contdate,
    contno,
    unfixed_reversed_invoice_number_marker,
    amenddate
FROM b1_grouped

UNION ALL

-- --------------------------------------------------------
-- Branch 2: Invoice charges (34% nominal, INVC/OUTB, charges lines)
-- No GROUP BY; no alias forward-refs that need a LATERAL:
--   QUANTITY=0 (literal) → is_there_stock always 'Y'.
--   journal_book_temp='210' always → journal_book_number inlined.
--   journal_book_number inlined into sales_contract / sales_allocation_reference.
--   ledamt / house_rate inlined directly into base_amount.
--   quantity_tonnage=0 → quantity_tonnage_shown=0.
--   phys_avail not joined in this branch (not in original FROM).
-- --------------------------------------------------------
SELECT
    2                                                                       AS order_flag,
    acs.ledgernum,
    ad.accdetail_contno,
    ad.accdetail_split,
    sc.client,
    0::numeric(16,4)                                                        AS original_tonnage,
    0::numeric                                                              AS unquantity,
    0::numeric                                                              AS quantity,
    'Y'                                                                     AS is_there_stock,
    sc.unitprice,
    public.sp_phys_avefixprice(sc.contno, sc.split)                        AS contract_average_fix_price,
    sc.currency,
    sc.priceunit,
    ad.nominal,
    '210'                                                                   AS journal_book_temp,
    CASE WHEN acs.journals = 'OUTB' THEN 'OUTB' ELSE '210' END             AS journal_book_number,
    acs.an_client,
    acs.leddate,
    ad.accdetail_invoice_number || ' ' || ad.accdetail_reserves_type || ' Invoice charge' AS invoice_number,
    ''                                                                      AS expense_number,
    ad.currency                                                             AS accdetail_currency,
    ad.ledamt * -1                                                          AS ledamt,
    ad.house_rate,
    CASE WHEN cur.ratetype = 'M'
         THEN ROUND(ad.ledamt * -1 * ad.house_rate, 2)
         ELSE ROUND(ad.ledamt * -1 / ad.house_rate, 2)
    END                                                                     AS base_amount,
    0::numeric                                                              AS quantity_tonnage,
    0::numeric                                                              AS quantity_tonnage_shown,
    p.base_currency,
    CASE WHEN acs.journals = 'OUTB'
         THEN acs.contno || '-' || acs.split
         ELSE ''
    END                                                                     AS sales_contract,
    CASE WHEN acs.journals = 'OUTB'
         THEN acs.an_allocref
         ELSE ''
    END                                                                     AS sales_allocation_reference,
    acs.analysis1                                                           AS outbooking_purchase_invoice_number,
    mc.company,
    mc.commodity,
    mc.commodtype,
    mc.quality,
    mc.contdate,
    mc.contno,
    CASE WHEN LEFT(ad.comments::text, 46) = 'Opposite posting of original Unfixed P Invoice'
         THEN ' (Reversed Unfixed Prov)'
         ELSE ''
    END                                                                     AS unfixed_reversed_invoice_number_marker,
    mc.amenddate
FROM public.accsummary acs
JOIN public.accdetail ad
    ON  ad.accperiod = acs.accperiod
    AND ad.ledgernum = acs.ledgernum
JOIN public.sub_contracts sc
    ON  sc.contno = ad.accdetail_contno
    AND sc.split  = ad.accdetail_split
JOIN public.master_contracts mc
    ON  mc.contno = sc.contno
JOIN public.currency cur
    ON  cur.code = ad.currency
CROSS JOIN public.params p
WHERE mc.amenddate              IS NULL
  AND mc.contract_type          = 'P'
  AND acs.journals              IN ('INVC', 'OUTB')
  AND ad.accdetail_invoice_flag = 'PI'
  AND ad.accdetail_invoice_number IS NOT NULL
  AND ad.accdetail_reserves_type  IS NOT NULL
  -- the indicator for Invoice Charges: accdetail_invoice_number and accdetail_reserves_type both not null
  AND acs.prov_inv_no           IS NOT NULL
  AND acs.exp_inv_no            IS NULL
  AND ad.nominal                LIKE '34%'
  AND ad.nominal                <> '34999'
  --  AND ( acs.reversed IS NULL OR acs.reversed <> 'Y' )

UNION ALL

-- --------------------------------------------------------
-- Branch 3: Final Purchase Invoices (order_flag = 3)
-- --------------------------------------------------------
SELECT
    order_flag,
    ledgernum,
    accdetail_contno,
    accdetail_split,
    client,
    original_tonnage,
    unquantity,
    quantity,
    is_there_stock,
    unitprice,
    contract_average_fix_price,
    currency,
    priceunit,
    nominal,
    journal_book_temp,
    journal_book_number,
    an_client,
    leddate,
    CASE WHEN journals = 'OUTB' THEN
             fin_inv_no || ' (for F Inv: ' || fin_inv_no || ')'
         ELSE
             fin_inv_no || ' (Fin for P Inv: ' || prov_inv_no || ')'
    END                                                                     AS invoice_number,
    ''                                                                      AS expense_number,
    accdetail_currency,
    ledamt,
    house_rate,
    CASE WHEN ratetype = 'M'
         THEN ROUND(ledamt * house_rate, 2)
         ELSE ROUND(ledamt / house_rate, 2)
    END                                                                     AS base_amount,
    quantity_tonnage,
    quantity_tonnage                                                         AS quantity_tonnage_shown,
    base_currency,
    ''                                                                      AS sales_contract,
    ''                                                                      AS sales_allocation_reference,
    analysis5                                                               AS outbooking_purchase_invoice_number,
    company,
    commodity,
    commodtype,
    quality,
    contdate,
    contno,
    unfixed_reversed_invoice_number_marker,
    amenddate
FROM b3_grouped

UNION ALL

-- --------------------------------------------------------
-- Branch 4: Expenses invoices and their outbookings (order_flag = 4)
-- No GROUP BY; alias deps resolved via three sequential LATERALs:
--   lq1: unquantity + quantity (sp_convert_qty) + journal_book_temp (subquery or '210').
--     WHERE already filters accdetail_invoice_flag='EXP' so ELSE '210' is dead code,
--     but retained to match original.
--   lq2: is_there_stock (from lq1.quantity) + journal_book_number (from lq1.journal_book_temp).
--   lq3: quantity_tonnage — CASE on acs.reversed='Y' AND LEFT(comments,11)='Reversal of';
--     both THEN and ELSE correlated into expenses_detail (expense_type='OUTB');
--     reversed branch multiplies result by -1.
-- ledamt / house_rate inlined into base_amount (no alias forward-ref for these).
-- invoice_number always ''; unfixed_reversed_invoice_number_marker always ''.
-- original_tonnage = sp_convert_qty(orgunquant,...) (vs an_tonnage in branches 1/3).
-- isnull(x,'') → COALESCE(x,''); isnull(x,0) → COALESCE(x,0).
-- left(x,n) → LEFT(x::text,n).
-- --------------------------------------------------------
SELECT
    4                                                                       AS order_flag,
    ad.ledgernum,
    ad.accdetail_contno,
    ad.accdetail_split,
    sc.client,
    public.sp_convert_qty(sc.orgunquant, sc.quantunit, p.base_unit)        AS original_tonnage,
    lq1.unquantity,
    lq1.quantity,
    lq2.is_there_stock,
    sc.unitprice,
    public.sp_phys_avefixprice(sc.contno, sc.split)                        AS contract_average_fix_price,
    sc.currency,
    sc.priceunit,
    ad.nominal,
    lq1.journal_book_temp,
    lq2.journal_book_number,
    acs.an_client,
    acs.leddate,
    ''                                                                      AS invoice_number,
    CASE WHEN acs.journals = 'OUTB' THEN
        ad.accdetail_expense_number || ' (for P Inv: ' || acs.analysis1 || ')'
    ELSE
        ad.accdetail_expense_number || ' (for P Inv: ' ||
        COALESCE((
            SELECT MIN(ed2.purchase_invoice_number)
            FROM public.expenses_detail ed2
            WHERE ed2.expense_number = ad.accdetail_expense_number
              AND ed2.client         = acs.an_client
              AND ed2.charges_line   = ad.accdetail_charges_line
              AND ed2.expense_type   = ad.accdetail_reserves_type
        ), '') || ')'
    END                                                                     AS expense_number,
    ad.currency                                                             AS accdetail_currency,
    ad.ledamt * -1                                                          AS ledamt,
    ad.house_rate,
    CASE WHEN cur.ratetype = 'M'
         THEN ROUND(ad.ledamt * -1 * ad.house_rate, 2)
         ELSE ROUND(ad.ledamt * -1 / ad.house_rate, 2)
    END                                                                     AS base_amount,
    lq3.quantity_tonnage,
    lq3.quantity_tonnage                                                    AS quantity_tonnage_shown,
    p.base_currency,
    CASE WHEN lq2.journal_book_number = 'OUTB'
         THEN acs.contno || '-' || acs.split
         ELSE ''
    END                                                                     AS sales_contract,
    CASE WHEN lq2.journal_book_number = 'OUTB'
         THEN acs.an_allocref
         ELSE ''
    END                                                                     AS sales_allocation_reference,
    acs.analysis1                                                           AS outbooking_purchase_invoice_number,
    mc.company,
    mc.commodity,
    mc.commodtype,
    mc.quality,
    mc.contdate,
    mc.contno,
    ''                                                                      AS unfixed_reversed_invoice_number_marker,
    mc.amenddate
FROM public.accsummary acs
JOIN public.accdetail ad
    ON  ad.accperiod = acs.accperiod
    AND ad.ledgernum = acs.ledgernum
JOIN public.sub_contracts sc
    ON  sc.contno = ad.accdetail_contno
    AND sc.split  = ad.accdetail_split
JOIN public.master_contracts mc
    ON  mc.contno = sc.contno
JOIN public.phys_avail pa
    ON  pa.contno = sc.contno
    AND pa.split  = sc.split
JOIN public.currency cur
    ON  cur.code = ad.currency
CROSS JOIN public.params p
CROSS JOIN LATERAL (
    SELECT
        public.sp_convert_qty(sc.unquantity, sc.quantunit, p.base_unit)    AS unquantity,
        public.sp_convert_qty((
            SELECT SUM(st2.quantity)
            FROM public.stocks st2
            WHERE st2.contno = sc.contno
              AND st2.split  = sc.split
        ), sc.quantunit, p.base_unit)                                       AS quantity,
        CASE WHEN ad.accdetail_invoice_flag = 'EXP' THEN
            (SELECT es.expense_note_type
             FROM public.expenses_summary es
             WHERE es.expense_number = ad.accdetail_expense_number
               AND es.posted_ledref  = ad.ledgernum)
        ELSE '210'
        END                                                                 AS journal_book_temp
) AS lq1
CROSS JOIN LATERAL (
    SELECT
        CASE WHEN lq1.quantity IS NULL THEN 'N' ELSE 'Y' END               AS is_there_stock,
        CASE WHEN acs.journals = 'OUTB' THEN 'OUTB'
             ELSE lq1.journal_book_temp
        END                                                                 AS journal_book_number
) AS lq2
CROSS JOIN LATERAL (
    SELECT
        CASE WHEN acs.reversed = 'Y' AND LEFT(ad.comments::text, 11) = 'Reversal of' THEN
            COALESCE((
                SELECT MIN(ed.quantity)
                FROM public.expenses_detail ed
                WHERE ed.expense_number = ad.accdetail_expense_number
                  AND ed.client         = acs.an_client
                  AND ed.charges_line   = ad.accdetail_charges_line
                  AND ed.expense_type   = 'OUTB'
            ), 0) * -1
        ELSE
            COALESCE((
                SELECT MIN(ed.quantity)
                FROM public.expenses_detail ed
                WHERE ed.expense_number = ad.accdetail_expense_number
                  AND ed.client         = acs.an_client
                  AND ed.charges_line   = ad.accdetail_charges_line
                  AND ed.expense_type   = 'OUTB'
            ), 0)
        END                                                                 AS quantity_tonnage
) AS lq3
WHERE mc.amenddate              IS NULL
  AND mc.contract_type          = 'P'
  AND ad.accdetail_invoice_flag = 'EXP'
  AND ad.nominal                LIKE '34%'
  AND ad.nominal                <> '34999';
  --  AND ( acs.reversed IS NULL OR acs.reversed <> 'Y' )
  --  AND ( lq2.is_there_stock = 'Y' OR pa.unallocated > 0 )
