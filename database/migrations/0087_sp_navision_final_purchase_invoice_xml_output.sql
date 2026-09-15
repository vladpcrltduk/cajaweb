-- ============================================================
-- sp_navision_final_purchase_invoice_xml_output
-- Source: dba.sp_navision_final_purchase_invoice_xml_output
--
-- Writes a Final Purchase Invoice or Final Sales Invoice XML depending
-- on the final_invoice_journal code stored in the final_invoice table.
--
-- Journal code routing (filepath subfolder + filename infix):
--   200 / 210 → Purchase Invoices/,       filename: _Final_Purchase_Invoice_
--   220       → Purchase Credit Notes/,   filename: _Final_Purchase_Invoice_
--              (note: same filename prefix as 200/210 — preserved from original)
--   320       → Sales Invoices/,          filename: _Final_Sales_Invoice_
--   350       → Sales Credit Notes/,      filename: _Final_Sales_Invoice_
--   else      → RETURN (no file written) — matches original ELSE // nothing block
--
-- Source table differences vs 0086 (sp_navision_purchase_invoice_xml_output):
--   Purchase branch: navision_finalpurchaseinvoice / navision_finalpurchaseinvoice_line
--     (not navision_purchaseinvoice / navision_purchaseinvoice_line).
--   Filter is on Line.final_invoice_number = as_final_invoice_number
--     (NOT on Header.No = as_invoice_number as in 0086).
--     Header rows are found via EXISTS from the qualifying Line rows.
--   Sales branch: navision_finalsalesinvoice / navision_finalsalesinvoice_line.
--     Header.SelltoCustomerNo = Line.client (not BuyfromVendorNo).
--     LineNo is a computed window function: ROW_NUMBER() OVER (ORDER BY l.no) * 10000
--       (not l.lineno). Produces sequence 10000, 20000, 30000 ... per header.
--     UnitPrice included; no VendorInvoiceNo; ShipmentDate and CustomerXxx fields
--     replace RequestedReceiptDate and VendorXxx fields.
--
-- Omissions from original (intentional):
--   ls_accperiod: looked up (max accperiod from accdetail) but never referenced
--     — leftover from copy-paste of 0086; omitted here.
--   final_invoice_journal: declared but never used (final_journal used instead)
--     — dead variable; omitted.
--   Unused DECLARE variables (system_datetime, final_net_due, now_time, now_timestr).
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   IF / ELSEIF / END IF → IF / ELSIF / END IF.
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   Comma join FOR XML AUTO nesting → EXISTS filter for outer Header rows +
--     correlated XMLAGG subquery for Line rows nested inside each Header.
--   row_number() OVER (...) → ROW_NUMBER() OVER (...) (standard SQL, unchanged).
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   Backslash path separators → forward slashes.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_final_purchase_invoice_xml_output(
    as_action              varchar(10),
    as_final_invoice_number varchar(10),
    as_ledgernum           varchar(10),
    as_company             char(2)
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_system_date       text;
    v_filepath_filename text;
    v_xml               text;
    v_final_journal     char(4);
    v_subfolder         text;
    v_filename_infix    text;
BEGIN
    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    SELECT fi.final_invoice_journal
    INTO   v_final_journal
    FROM   public.final_invoice fi
    WHERE  fi.final_invoice_number = as_final_invoice_number;

    -- Early exit for unrecognised journal codes — original ELSE // nothing branch
    IF v_final_journal NOT IN ('200','210','220','320','350') THEN
        RETURN;
    END IF;

    -- Document-type subfolder and filename infix (independent of company)
    v_subfolder := CASE
        WHEN v_final_journal IN ('200','210') THEN 'Purchase Invoices/'
        WHEN v_final_journal =  '220'         THEN 'Purchase Credit Notes/'
        WHEN v_final_journal =  '320'         THEN 'Sales Invoices/'
        WHEN v_final_journal =  '350'         THEN 'Sales Credit Notes/'
    END;

    -- Filename infix: purchase group keeps '_Final_Purchase_Invoice_' even for 220
    v_filename_infix := CASE
        WHEN v_final_journal IN ('200','210','220') THEN '_Final_Purchase_Invoice_'
        WHEN v_final_journal IN ('320','350')       THEN '_Final_Sales_Invoice_'
    END;

    v_filepath_filename :=
        CASE as_company
            WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/'
            WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/'
            ELSE            'E:/Nav_Interface/TEST/Sopex Americas/'
        END
        || v_subfolder
        || v_system_date || v_filename_infix || as_action || '_' || as_final_invoice_number || '.xml';

    -- ----------------------------------------------------------------
    -- Final Purchase Invoice / Purchase Credit Note  (200, 210, 220)
    -- Filter is on Line.final_invoice_number (not Header.No).
    -- Header rows found via EXISTS from qualifying Lines.
    -- ----------------------------------------------------------------
    IF v_final_journal IN ('200','210','220') THEN

        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                (SELECT XMLAGG(
                    XMLELEMENT(NAME "Header",
                        XMLELEMENT(NAME "No",                       h.no),
                        XMLELEMENT(NAME "JournalTemplateName",      h.journaltemplatename),
                        XMLELEMENT(NAME "BuyfromVendorNo",          h.buyfromvendorno),
                        XMLELEMENT(NAME "BuyfromVendorName",        h.buyfromvendorname),
                        XMLELEMENT(NAME "BuyfromAddress",           h.buyfromaddress),
                        XMLELEMENT(NAME "BuyfromAddress2",          h.buyfromaddress2),
                        XMLELEMENT(NAME "BuyfromCity",              h.buyfromcity),
                        XMLELEMENT(NAME "BuyfromPostCode",          h.buyfrompostcode),
                        XMLELEMENT(NAME "BuyfromCountryRegionCode", h.buyfromcountryregioncode),
                        XMLELEMENT(NAME "PayToVendorNo",            h.paytovendorno),
                        XMLELEMENT(NAME "PayToName",                h.paytoname),
                        XMLELEMENT(NAME "PayToAddress",             h.paytoaddress),
                        XMLELEMENT(NAME "PayToAddress2",            h.paytoaddress2),
                        XMLELEMENT(NAME "PayToCity",                h.paytocity),
                        XMLELEMENT(NAME "PayToPostCode",            h.paytopostcode),
                        XMLELEMENT(NAME "PayToCountryRegionCode",   h.paytocountryregioncode),
                        XMLELEMENT(NAME "YourReference",            h.yourreference),
                        XMLELEMENT(NAME "OrderDate",                h.orderdate),
                        XMLELEMENT(NAME "PostingDate",              h.postingdate),
                        XMLELEMENT(NAME "DocumentDate",             h.documentdate),
                        XMLELEMENT(NAME "RequestedReceiptDate",     h.requestedreceiptdate),
                        XMLELEMENT(NAME "DueDate",                  h.duedate),
                        XMLELEMENT(NAME "PaymentTermsCode",         h.paymenttermscode),
                        XMLELEMENT(NAME "PaymentDiscount",          h.paymentdiscount),
                        XMLELEMENT(NAME "PmtDiscountDate",          h.pmtdiscountdate),
                        XMLELEMENT(NAME "VendorPostingGroup",       h.vendorpostinggroup),
                        XMLELEMENT(NAME "InvoiceDiscCode",          h.invoicedisccode),
                        XMLELEMENT(NAME "LanguageCode",             h.languagecode),
                        XMLELEMENT(NAME "GenBusPostingGroup",       h.genbuspostinggroup),
                        XMLELEMENT(NAME "VATBusPostingGroup",       h.vatbuspostinggroup),
                        XMLELEMENT(NAME "CurrencyCode",             h.currencycode),
                        XMLELEMENT(NAME "CurrencyFactor",           h.currencyfactor),
                        XMLELEMENT(NAME "VendorInvoiceNo",          h.vendorinvoiceno),
                        -- Nested Line elements
                        (SELECT XMLAGG(
                            XMLELEMENT(NAME "Line",
                                XMLELEMENT(NAME "LineNo",                l.lineno),
                                XMLELEMENT(NAME "Type",                  l.type),
                                XMLELEMENT(NAME "No",                    l.no),
                                XMLELEMENT(NAME "Description",           l.description),
                                XMLELEMENT(NAME "Description2",          l.description2),
                                XMLELEMENT(NAME "Quantity",              l.quantity),
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
                            )
                        )
                        FROM public.navision_finalpurchaseinvoice_line l
                        WHERE l.invoice_number       = h.invoice_number
                          AND l.invoice_type         = h.invoice_type
                          AND l.client               = h.buyfromvendorno
                          AND l.final_invoice_number = as_final_invoice_number
                          AND l.ledgernum            = as_ledgernum)
                    )
                )
                FROM public.navision_finalpurchaseinvoice h
                WHERE EXISTS (
                    SELECT 1
                    FROM   public.navision_finalpurchaseinvoice_line lx
                    WHERE  lx.invoice_number       = h.invoice_number
                      AND  lx.invoice_type         = h.invoice_type
                      AND  lx.client               = h.buyfromvendorno
                      AND  lx.final_invoice_number = as_final_invoice_number
                      AND  lx.ledgernum            = as_ledgernum
                ))
            )::text
        INTO v_xml;

    -- ----------------------------------------------------------------
    -- Final Sales Invoice / Sales Credit Note  (320, 350)
    -- LineNo is computed: ROW_NUMBER() OVER (ORDER BY l.no) * 10000
    -- (not l.lineno — original generates a sequence 10000, 20000, ...).
    -- ----------------------------------------------------------------
    ELSIF v_final_journal IN ('320','350') THEN

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
                                     XMLELEMENT(NAME "ShortcutDimension6Code", l.shortcutdimension6code),
                                     XMLELEMENT(NAME "CajaNo",                l.cajano),
                                     XMLELEMENT(NAME "GenProdPostingGroup",   l.genprodpostinggroup),
                                     XMLELEMENT(NAME "VATProdPostingGroup",   l.vatprodpostinggroup)
                                 ) AS line_xml
                             FROM public.navision_finalsalesinvoice_line l
                             WHERE l.invoice_number       = h.invoice_number
                               AND l.invoice_type         = h.invoice_type
                               AND l.client               = h.selltocustomerno
                               AND l.final_invoice_number = as_final_invoice_number
                               AND l.ledgernum            = as_ledgernum
                         ) lines_ordered)
                    )
                )
                FROM public.navision_finalsalesinvoice h
                WHERE EXISTS (
                    SELECT 1
                    FROM   public.navision_finalsalesinvoice_line lx
                    WHERE  lx.invoice_number       = h.invoice_number
                      AND  lx.invoice_type         = h.invoice_type
                      AND  lx.client               = h.selltocustomerno
                      AND  lx.final_invoice_number = as_final_invoice_number
                      AND  lx.ledgernum            = as_ledgernum
                ))
            )::text
        INTO v_xml;

    END IF;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
