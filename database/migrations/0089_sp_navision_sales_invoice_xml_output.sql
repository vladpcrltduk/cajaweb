-- ============================================================
-- sp_navision_sales_invoice_xml_output
-- Source: dba.sp_navision_sales_invoice_xml_output
--
-- No 34500 branching — single XML output path (unlike 0086/0088).
-- Source tables: navision_salesinvoice / navision_salesinvoice_line.
-- Join: h.no = l.invoice_number AND h.invoice_type = l.invoice_type
--       AND h.selltocustomerno = l.client.
-- Filter: h.no = as_invoice_number AND l.ledgernum = as_ledgernum.
--
-- LineNo: computed as ROW_NUMBER() OVER (ORDER BY l.sort_order_flag) * 10000.
--   This differs from 0087 sales branch (ordered by l.no, not sort_order_flag).
--
-- Window-function-inside-aggregate pattern:
--   PostgreSQL does not allow window functions inside aggregate function arguments
--   (ERROR: window functions are not allowed in aggregate function arguments).
--   Solution: two-level subquery — inner SELECT pre-computes the window function
--   and builds the XMLELEMENT; outer SELECT applies XMLAGG ORDER BY sort_order_flag.
--   The ORDER BY on the outer query (... order by Line.sort_order_flag asc) that
--   controlled element ordering in SAP is reproduced by XMLAGG ORDER BY here.
--
-- NOTE for 0087 (sp_navision_final_purchase_invoice_xml_output):
--   The sales branch in 0087 has the same window-function-inside-aggregate issue
--   (ROW_NUMBER inside XMLAGG). A corrective migration is required before 0087
--   is applied, or 0087 should be re-generated with the same two-level subquery
--   pattern used here.
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   Unused DECLARE variables (system_datetime, now_time, now_timestr) omitted.
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   Comma join FOR XML AUTO nesting → correlated two-level subquery (Header > Line).
--   row_number() OVER (order by Line.sort_order_flag) → see Window-function note above.
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   'Sales invoices' (lowercase i) for companies 01/03 → normalised to 'Sales Invoices/'.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_sales_invoice_xml_output(
    as_action         varchar(10),
    as_invoice_number varchar(10),
    as_ledgernum      varchar(10),
    as_company        char(2)
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_system_date       text;
    v_filepath_filename text;
    v_xml               text;
BEGIN
    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    v_filepath_filename :=
        CASE as_company
            WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/Sales Invoices/'
            WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/Sales Invoices/'
            ELSE            'E:/Nav_Interface/TEST/Sopex Americas/Sales Invoices/'
        END
        || v_system_date || '_Sales_Invoice_' || as_action || '_' || as_invoice_number || '.xml';

    SELECT
        '<?xml version="1.0" encoding="UTF-8" ?>' ||
        XMLELEMENT(NAME "Root",
            (SELECT XMLAGG(
                XMLELEMENT(NAME "Header",
                    XMLELEMENT(NAME "No",                        h.no),
                    XMLELEMENT(NAME "JournalTemplateName",       h.journaltemplatename),
                    XMLELEMENT(NAME "SelltoCustomerNo",          h.selltocustomerno),
                    XMLELEMENT(NAME "SelltoCustomerName",        h.selltocustomername),
                    XMLELEMENT(NAME "SelltoAddress",             h.selltoaddress),
                    XMLELEMENT(NAME "SelltoAddress2",            h.selltoaddress2),
                    XMLELEMENT(NAME "SelltoCity",                h.selltocity),
                    XMLELEMENT(NAME "SelltoPostCode",            h.selltopostcode),
                    XMLELEMENT(NAME "SelltoCountryRegionCode",   h.selltocountryregioncode),
                    XMLELEMENT(NAME "BilltoCustomerNo",          h.billtocustomerno),
                    XMLELEMENT(NAME "BilltoName",                h.billtoname),
                    XMLELEMENT(NAME "BilltoAddress",             h.billtoaddress),
                    XMLELEMENT(NAME "BilltoAddress2",            h.billtoaddress2),
                    XMLELEMENT(NAME "BilltoCity",                h.billtocity),
                    XMLELEMENT(NAME "BilltoPostCode",            h.billtopostcode),
                    XMLELEMENT(NAME "BilltoCountryRegionCode",   h.billtocountryregioncode),
                    XMLELEMENT(NAME "YourReference",             h.yourreference),
                    XMLELEMENT(NAME "OrderDate",                 h.orderdate),
                    XMLELEMENT(NAME "PostingDate",               h.postingdate),
                    XMLELEMENT(NAME "DocumentDate",              h.documentdate),
                    XMLELEMENT(NAME "ShipmentDate",              h.shipmentdate),
                    XMLELEMENT(NAME "DueDate",                   h.duedate),
                    XMLELEMENT(NAME "PaymentTermsCode",          h.paymenttermscode),
                    XMLELEMENT(NAME "PaymentDiscount",           h.paymentdiscount),
                    XMLELEMENT(NAME "PmtDiscountDate",           h.pmtdiscountdate),
                    XMLELEMENT(NAME "LocationCode",              h.locationcode),
                    XMLELEMENT(NAME "CustomerPostingGroup",      h.customerpostinggroup),
                    XMLELEMENT(NAME "CustomerPriceGroup",        h.customerpricegroup),
                    XMLELEMENT(NAME "InvoiceDiscCode",           h.invoicedisccode),
                    XMLELEMENT(NAME "CustomerDiscGroup",         h.customerdiscgroup),
                    XMLELEMENT(NAME "LanguageCode",              h.languagecode),
                    XMLELEMENT(NAME "GenBusPostingGroup",        h.genbuspostinggroup),
                    XMLELEMENT(NAME "VATBusPostingGroup",        h.vatbuspostinggroup),
                    XMLELEMENT(NAME "CurrencyCode",              h.currencycode),
                    XMLELEMENT(NAME "CurrencyFactor",            h.currencyfactor),
                    -- Nested Line elements.
                    -- Two-level subquery: inner computes ROW_NUMBER (window),
                    -- outer applies XMLAGG (aggregate) — they cannot share a query level.
                    (SELECT XMLAGG(line_xml ORDER BY sort_order_flag)
                     FROM (
                         SELECT
                             l.sort_order_flag,
                             XMLELEMENT(NAME "Line",
                                 XMLELEMENT(NAME "LineNo",
                                     (ROW_NUMBER() OVER (ORDER BY l.sort_order_flag)) * 10000),
                                 XMLELEMENT(NAME "Type",                  l.type),
                                 XMLELEMENT(NAME "No",                    l.no),
                                 XMLELEMENT(NAME "Description",           l.description),
                                 XMLELEMENT(NAME "Description2",          l.description2),
                                 XMLELEMENT(NAME "Quantity",              l.quantity),
                                 XMLELEMENT(NAME "UnitPrice",             l.unitprice),
                                 XMLELEMENT(NAME "UnitCost",              l.unitcost),
                                 XMLELEMENT(NAME "Amount",                l.amount),
                                 XMLELEMENT(NAME "VAT",                   l.vat),
                                 XMLELEMENT(NAME "LineDiscount",          l.linediscount),
                                 XMLELEMENT(NAME "ShortcutDimension1Code", l.shortcutdimension1code),
                                 XMLELEMENT(NAME "ShortcutDimension2Code", l.shortcutdimension2code),
                                 XMLELEMENT(NAME "ShortcutDimension3Code", l.shortcutdimension3code),
                                 XMLELEMENT(NAME "ShortcutDimension4Code", l.shortcutdimension4code),
                                 XMLELEMENT(NAME "ShortcutDimension5Code", l.shortcutdimension5code),
                                 XMLELEMENT(NAME "ShortcutDimension6Code", l.shortcutdimension6code),
                                 XMLELEMENT(NAME "CajaNo",                l.cajano),
                                 XMLELEMENT(NAME "GenProdPostingGroup",   l.genprodpostinggroup),
                                 XMLELEMENT(NAME "VATProdPostingGroup",   l.vatprodpostinggroup)
                             ) AS line_xml
                         FROM public.navision_salesinvoice_line l
                         WHERE l.invoice_number = h.no
                           AND l.invoice_type   = h.invoice_type
                           AND l.client         = h.selltocustomerno
                           AND l.ledgernum      = as_ledgernum
                     ) lines_ordered)
                )
            )
            FROM public.navision_salesinvoice h
            WHERE h.no = as_invoice_number)
        )::text
    INTO v_xml;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
