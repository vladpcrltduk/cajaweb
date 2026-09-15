-- ============================================================
-- sp_navision_sales_return_invoice_xml_output
-- Source: dba.sp_navision_sales_return_invoice_xml_output
--
-- Structurally identical to 0089 (sp_navision_sales_invoice_xml_output)
-- with these differences:
--
--   Source tables:
--     navision_salesinvoice_return / navision_salesinvoice_return_line
--     (not navision_salesinvoice / navision_salesinvoice_line).
--
--   Filter / join key on header:
--     h.invoice_number = as_invoice_number  (not h.no).
--     Join to line: h.invoice_number = l.invoice_number.
--     Header SELECT still emits <No> from h.no.
--
--   LineNo ordering: ROW_NUMBER() OVER (ORDER BY l.no)
--     (0089 orders by l.sort_order_flag).
--
--   Line columns: no ShortcutDimension6Code (only Dimension1–5Code, then CajaNo).
--
--   Filename infix: '_Sales_Invoice_Return_' (not '_Sales_Invoice_').
--
-- Window-function-inside-aggregate: same two-level subquery pattern as 0089 —
--   inner SELECT pre-computes ROW_NUMBER; outer XMLAGG ORDER BY l.no.
--
-- SAP → PostgreSQL translations: same as 0089.
--   Unused DECLARE variables (system_datetime, now_time, now_timestr) omitted.
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   Comma join FOR XML AUTO nesting → correlated two-level subquery (Header > Line).
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   'Sales invoices' (lowercase i) for companies 01/03 → normalised to 'Sales Invoices/'.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_sales_return_invoice_xml_output(
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
        || v_system_date || '_Sales_Invoice_Return_' || as_action || '_' || as_invoice_number || '.xml';

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
                    (SELECT XMLAGG(line_xml ORDER BY no)
                     FROM (
                         SELECT
                             l.no,
                             XMLELEMENT(NAME "Line",
                                 XMLELEMENT(NAME "LineNo",
                                     (ROW_NUMBER() OVER (ORDER BY l.no)) * 10000),
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
                                 XMLELEMENT(NAME "CajaNo",                l.cajano),
                                 XMLELEMENT(NAME "GenProdPostingGroup",   l.genprodpostinggroup),
                                 XMLELEMENT(NAME "VATProdPostingGroup",   l.vatprodpostinggroup)
                             ) AS line_xml
                         FROM public.navision_salesinvoice_return_line l
                         WHERE l.invoice_number = h.invoice_number
                           AND l.invoice_type   = h.invoice_type
                           AND l.client         = h.selltocustomerno
                           AND l.ledgernum      = as_ledgernum
                     ) lines_ordered)
                )
            )
            FROM public.navision_salesinvoice_return h
            WHERE h.invoice_number = as_invoice_number)
        )::text
    INTO v_xml;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
