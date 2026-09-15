-- ============================================================
-- sp_navision_purchase_invoice_xml_output
-- Source: dba.sp_navision_purchase_invoice_xml_output
--
-- Writes a Purchase Invoice XML, or — if the ledger entry contains a
-- nominal '34500' row (unfixed/provisional posting) — writes a General
-- Ledger Journal XML to the Outbooking folder instead.
--
-- Branch logic:
--   1. Find the latest accperiod for the ledger entry (max(accperiod)).
--   2. Count rows where nominal = '34500' in that period.
--      If count = 0 → regular Purchase Invoice XML (navision_purchaseinvoice
--        + navision_purchaseinvoice_line, nested Header > Line).
--      If count > 0 → provisional G/L Journal XML (navision_34500_invoice,
--        flat JournalLine rows).
--
-- Important: the 34500 branch overrides the filepath to Group Sopex/Outbooking/
-- regardless of the as_company parameter — this matches the original exactly.
-- If 34500 provisional postings can occur for companies 02 or 03, the filepath
-- may need to be made company-aware.
--
-- Source table differences vs 0085 (sp_navision_expense_invoice_xml_output):
--   Header/Line: navision_purchaseinvoice / navision_purchaseinvoice_line
--     (not navision_expenseinvoice / navision_expenseinvoice_line).
--   Join condition includes Header.invoice_type = Line.invoice_type
--     (not present in 0085).
--   34500 journal: navision_34500_invoice — same columns as navision_490_journal
--     but WITHOUT CajaNo.
--
-- Path capitalisation: original uses 'Purchase invoices' (lowercase i) for
-- companies 01 and 03, 'Purchase Invoices' for 02. Normalised to 'Purchase Invoices/'
-- throughout — Windows paths are case-insensitive, so this is safe.
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   Unused DECLARE variables (system_datetime, now_time, now_timestr) omitted.
--   'if invoice_34500 < 1' → 'IF v_invoice_34500 = 0' (COUNT always >= 0; equivalent).
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   Comma join FOR XML AUTO nesting → correlated XMLAGG subquery (Header > Line).
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   Backslash path separators → forward slashes.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_purchase_invoice_xml_output(
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
    v_ls_accperiod      text;
    v_invoice_34500     integer;
BEGIN
    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    -- Latest accounting period for this ledger entry
    SELECT MAX(ad.accperiod)
    INTO   v_ls_accperiod
    FROM   public.accdetail ad
    WHERE  ad.ledgernum = as_ledgernum;

    -- Check for 34500 (unfixed/provisional) nominal rows
    SELECT COUNT(*)
    INTO   v_invoice_34500
    FROM   public.accdetail ad
    WHERE  ad.accperiod = v_ls_accperiod
      AND  ad.ledgernum = as_ledgernum
      AND  ad.nominal   = '34500';

    -- ----------------------------------------------------------------
    -- Regular Purchase Invoice (no 34500 rows in this period)
    -- ----------------------------------------------------------------
    IF v_invoice_34500 = 0 THEN

        v_filepath_filename :=
            CASE as_company
                WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/Purchase Invoices/'
                WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/Purchase Invoices/'
                ELSE            'E:/Nav_Interface/TEST/Sopex Americas/Purchase Invoices/'
            END
            || v_system_date || '_Purchase_Invoice_' || as_action || '_' || as_invoice_number || '.xml';

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
                        FROM public.navision_purchaseinvoice_line l
                        WHERE l.invoice_number = h.no
                          AND l.invoice_type   = h.invoice_type
                          AND l.client         = h.buyfromvendorno
                          AND l.ledgernum      = as_ledgernum)
                    )
                )
                FROM public.navision_purchaseinvoice h
                WHERE h.no = as_invoice_number)
            )::text
        INTO v_xml;

    -- ----------------------------------------------------------------
    -- Provisional / unfixed posting (34500 nominal row found)
    -- Writes to Group Sopex/Outbooking/ regardless of as_company —
    -- preserved from original; see header comment if this is a concern.
    -- ----------------------------------------------------------------
    ELSE

        v_filepath_filename :=
            'E:/Nav_Interface/TEST/Group Sopex/Outbooking/'
            || v_system_date || '_Provisional_' || as_invoice_number
            || '_' || as_action || '_' || as_ledgernum || '.xml';

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
                        XMLELEMENT(NAME "ShortcutDimension5Code", jl.shortcutdimension5code)
                        -- navision_34500_invoice has no CajaNo column (unlike navision_490_journal)
                    )
                )
            )::text
        INTO v_xml
        FROM public.navision_34500_invoice jl
        WHERE jl.accperiod = v_ls_accperiod
          AND jl.ledgernum = as_ledgernum;

    END IF;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
