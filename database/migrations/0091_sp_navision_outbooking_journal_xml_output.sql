-- ============================================================
-- sp_navision_outbooking_journal_xml_output
-- Source: dba.sp_navision_outbooking_journal_xml_output
--
-- Writes a flat <JournalLine> XML from navision_outbookingjounal.
-- No branching, no 34500 check, no nested Header/Line structure.
-- Same column set as the 480/491 journal branches in 0085.
--
-- Note: as_accperiod is a parameter and used in the WHERE clause,
-- but NOT included in the filename (only as_ledgernum appears there) —
-- preserved faithfully from original.
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   Unused DECLARE variables (system_datetime, now_time, now_timestr) omitted.
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   FOR XML AUTO alias "JournalLine" → XMLELEMENT(NAME "JournalLine",...).
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   Backslash path separators → forward slashes.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_outbooking_journal_xml_output(
    as_action    varchar(10),
    as_accperiod varchar(6),
    as_ledgernum varchar(10),
    as_company   char(2)
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
            WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/Outbooking/'
            WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/Outbooking/'
            ELSE            'E:/Nav_Interface/TEST/Sopex Americas/Outbooking/'
        END
        || v_system_date || '_Outbooking_' || as_action || '_' || as_ledgernum || '.xml';

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
    FROM public.navision_outbookingjounal jl
    WHERE jl.accperiod = as_accperiod
      AND jl.ledgernum = as_ledgernum;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
