-- ============================================================
-- sp_navision_expense_invoice_xml_output
-- Source: dba.sp_navision_expense_invoice_xml_output
--
-- Routes expense invoices to different XML layouts and Nav_Interface
-- subfolders based on the expense_note_type (expenses_journal) code.
--
-- Filepath routing (two independent axes, collapsed from nested IF/ELSEIF):
--   Axis 1 — journal type → subfolder:
--     200/201/206  → Purchase Invoices/
--     220          → Purchase Credit Notes/
--     306/320      → Sales Invoices/
--     350          → Sales Credit Notes/
--     480/490/491/499 → Outbooking/
--   Axis 2 — as_company → company prefix:
--     01 → Group Sopex / 02 → Sopex Asia / else → Sopex Americas
--   If expense_note_type is none of the above, v_subfolder is NULL and the
--   filepath_filename will be NULL — COPY TO will raise an error, matching
--   the original behaviour (filepath string stays empty).
--
-- XML branch routing:
--   200/201/206/220 → Purchase Invoice layout:
--     Nested <Header> wrapping <Line> children, from navision_expenseinvoice
--     joined to navision_expenseinvoice_line.
--     FOR XML AUTO with two comma-joined tables produces Header > Line nesting;
--     reproduced here with a correlated XMLAGG subquery inside each Header row.
--   480 → navision_480_journal flat JournalLine rows (includes AccountType).
--   490 → navision_490_journal flat JournalLine rows (no AccountType column).
--   491 → navision_491_journal flat JournalLine rows (includes AccountType).
--   else (306/320/350/499) → Sales Invoice layout:
--     Same nested Header > Line structure, but Header uses SellTo/BillTo
--     columns instead of BuyFrom/PayTo, and Line adds UnitPrice.
--     Note: join condition still uses h.buyfromvendorno = l.client —
--     preserved faithfully from original (navision_expenseinvoice view
--     exposes this column for both purchase and sales records).
--     Note: 499 writes to Outbooking/ folder but uses the Sales Invoice XML
--     layout — this matches the original behaviour.
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   Unused DECLARE variables (system_datetime, now_time, now_timestr,
--     expense_total_value, expense_details_linecount) omitted.
--   CHAR(4) expense_note_type → compared as text literals (no padding issue).
--   IF / ELSEIF / END IF → IF / ELSIF / END IF.
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   Comma join (Header, Line) FOR XML AUTO nesting → correlated XMLAGG subquery.
--   FOR XML AUTO alias name → XMLELEMENT NAME matches the alias ("Header","Line","JournalLine").
--   Column names: SAP uses mixed-case (BuyfromVendorNo); PostgreSQL stores
--     lowercase (buyfromvendorno) — XMLELEMENT NAME preserves the CamelCase
--     expected by Navision; the column reference uses lowercase.
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   Backslash path separators → forward slashes.
--   Commented-out line in original (--if expenses_journal = '490'...) preserved
--     in this comment: 480 was added to the Outbooking group later.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_expense_invoice_xml_output(
    as_action         varchar(10),
    as_expense_number varchar(10),
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
    v_expenses_journal  text;   -- expense_note_type from expenses_summary
    v_subfolder         text;
    v_filepath_base     text;
BEGIN
    SELECT es.expense_note_type
    INTO   v_expenses_journal
    FROM   public.expenses_summary es
    WHERE  es.expense_number = as_expense_number;

    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    -- Document-type subfolder (Axis 1)
    v_subfolder := CASE
        WHEN v_expenses_journal IN ('200','201','206') THEN 'Purchase Invoices/'
        WHEN v_expenses_journal =  '220'               THEN 'Purchase Credit Notes/'
        WHEN v_expenses_journal IN ('306','320')        THEN 'Sales Invoices/'
        WHEN v_expenses_journal =  '350'               THEN 'Sales Credit Notes/'
        WHEN v_expenses_journal IN ('480','490','491','499') THEN 'Outbooking/'
    END;

    -- Company path prefix (Axis 2)
    v_filepath_base := CASE as_company
        WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/'
        WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/'
        ELSE            'E:/Nav_Interface/TEST/Sopex Americas/'
    END;

    v_filepath_filename := v_filepath_base || v_subfolder
        || v_system_date || '_Expense_Invoice_' || as_action || '_' || as_expense_number || '.xml';

    -- ----------------------------------------------------------------
    -- Purchase Invoice / Purchase Credit Note  (200, 201, 206, 220)
    -- ----------------------------------------------------------------
    IF v_expenses_journal IN ('200','201','206','220') THEN

        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                -- Outer XMLAGG in case expense_number matches more than one header row
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
                        -- Nested Line elements (correlated subquery reproduces FOR XML AUTO nesting)
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
                        FROM public.navision_expenseinvoice_line l
                        WHERE l.expense_number = h.no
                          AND l.client         = h.buyfromvendorno
                          AND l.ledgernum      = as_ledgernum)
                    )
                )
                FROM public.navision_expenseinvoice h
                WHERE h.no = as_expense_number)
            )::text
        INTO v_xml;

    -- ----------------------------------------------------------------
    -- Outbooking 480 journal (includes AccountType)
    -- ----------------------------------------------------------------
    ELSIF v_expenses_journal = '480' THEN

        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                XMLAGG(
                    XMLELEMENT(NAME "JournalLine",
                        XMLELEMENT(NAME "JournalTemplateName",    jl.journaltemplatename),
                        XMLELEMENT(NAME "JournalBatchName",       jl.journalbatchname),
                        XMLELEMENT(NAME "DocumentNo",             jl.documentno),
                        XMLELEMENT(NAME "AccountType",            jl.accounttype),
                        XMLELEMENT(NAME "AccountNo",              jl.accountno),
                        XMLELEMENT(NAME "Description",            jl.description),
                        XMLELEMENT(NAME "PostingDate",            jl.postingdate),
                        XMLELEMENT(NAME "Quantity",               jl.quantity),
                        XMLELEMENT(NAME "Amount",                 jl.amount),
                        XMLELEMENT(NAME "CurrencyCode",           jl.currencycode),
                        XMLELEMENT(NAME "CurrencyFactor",         jl.currencyfactor),
                        XMLELEMENT(NAME "ShortcutDimension1Code", jl.shortcutdimension1code),
                        XMLELEMENT(NAME "ShortcutDimension2Code", jl.shortcutdimension2code),
                        XMLELEMENT(NAME "ShortcutDimension3Code", jl.shortcutdimension3code),
                        XMLELEMENT(NAME "ShortcutDimension4Code", jl.shortcutdimension4code),
                        XMLELEMENT(NAME "ShortcutDimension5Code", jl.shortcutdimension5code),
                        XMLELEMENT(NAME "CajaNo",                 jl.cajano)
                    )
                )
            )::text
        INTO v_xml
        FROM public.navision_480_journal jl
        WHERE jl.documentno = as_expense_number
          AND jl.ledgernum  = as_ledgernum;

    -- ----------------------------------------------------------------
    -- Outbooking 490 journal — G/L structure, no AccountType column
    -- ----------------------------------------------------------------
    ELSIF v_expenses_journal = '490' THEN

        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                XMLAGG(
                    XMLELEMENT(NAME "JournalLine",
                        XMLELEMENT(NAME "JournalTemplateName",    jl.journaltemplatename),
                        XMLELEMENT(NAME "JournalBatchName",       jl.journalbatchname),
                        XMLELEMENT(NAME "DocumentNo",             jl.documentno),
                        XMLELEMENT(NAME "AccountNo",              jl.accountno),
                        XMLELEMENT(NAME "Description",            jl.description),
                        XMLELEMENT(NAME "PostingDate",            jl.postingdate),
                        XMLELEMENT(NAME "Quantity",               jl.quantity),
                        XMLELEMENT(NAME "Amount",                 jl.amount),
                        XMLELEMENT(NAME "CurrencyCode",           jl.currencycode),
                        XMLELEMENT(NAME "CurrencyFactor",         jl.currencyfactor),
                        XMLELEMENT(NAME "ShortcutDimension1Code", jl.shortcutdimension1code),
                        XMLELEMENT(NAME "ShortcutDimension2Code", jl.shortcutdimension2code),
                        XMLELEMENT(NAME "ShortcutDimension3Code", jl.shortcutdimension3code),
                        XMLELEMENT(NAME "ShortcutDimension4Code", jl.shortcutdimension4code),
                        XMLELEMENT(NAME "ShortcutDimension5Code", jl.shortcutdimension5code),
                        XMLELEMENT(NAME "CajaNo",                 jl.cajano)
                    )
                )
            )::text
        INTO v_xml
        FROM public.navision_490_journal jl
        WHERE jl.documentno = as_expense_number
          AND jl.ledgernum  = as_ledgernum;

    -- ----------------------------------------------------------------
    -- Outbooking 491 journal — G/L structure with AccountType
    -- ----------------------------------------------------------------
    ELSIF v_expenses_journal = '491' THEN

        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                XMLAGG(
                    XMLELEMENT(NAME "JournalLine",
                        XMLELEMENT(NAME "JournalTemplateName",    jl.journaltemplatename),
                        XMLELEMENT(NAME "JournalBatchName",       jl.journalbatchname),
                        XMLELEMENT(NAME "DocumentNo",             jl.documentno),
                        XMLELEMENT(NAME "AccountType",            jl.accounttype),
                        XMLELEMENT(NAME "AccountNo",              jl.accountno),
                        XMLELEMENT(NAME "Description",            jl.description),
                        XMLELEMENT(NAME "PostingDate",            jl.postingdate),
                        XMLELEMENT(NAME "Quantity",               jl.quantity),
                        XMLELEMENT(NAME "Amount",                 jl.amount),
                        XMLELEMENT(NAME "CurrencyCode",           jl.currencycode),
                        XMLELEMENT(NAME "CurrencyFactor",         jl.currencyfactor),
                        XMLELEMENT(NAME "ShortcutDimension1Code", jl.shortcutdimension1code),
                        XMLELEMENT(NAME "ShortcutDimension2Code", jl.shortcutdimension2code),
                        XMLELEMENT(NAME "ShortcutDimension3Code", jl.shortcutdimension3code),
                        XMLELEMENT(NAME "ShortcutDimension4Code", jl.shortcutdimension4code),
                        XMLELEMENT(NAME "ShortcutDimension5Code", jl.shortcutdimension5code),
                        XMLELEMENT(NAME "CajaNo",                 jl.cajano)
                    )
                )
            )::text
        INTO v_xml
        FROM public.navision_491_journal jl
        WHERE jl.documentno = as_expense_number
          AND jl.ledgernum  = as_ledgernum;

    -- ----------------------------------------------------------------
    -- Sales Invoice / Sales Credit Note / 499 Outbooking  (306, 320, 350, 499)
    -- ----------------------------------------------------------------
    ELSE

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
                        -- Nested Line elements
                        (SELECT XMLAGG(
                            XMLELEMENT(NAME "Line",
                                XMLELEMENT(NAME "LineNo",                l.lineno),
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
                            )
                        )
                        FROM public.navision_expenseinvoice_line l
                        WHERE l.expense_number = h.no
                          AND l.client         = h.buyfromvendorno
                          AND l.ledgernum      = as_ledgernum)
                    )
                )
                FROM public.navision_expenseinvoice h
                WHERE h.no = as_expense_number)
            )::text
        INTO v_xml;

    END IF;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
