-- ============================================================
-- sp_navision_allocation_xml_output
-- Source: dba.sp_navision_allocation_xml_output
--
-- NOTE: Original procedure carries the comment "PROBABLY NOT USED ANY MORE AT ALL".
--       Translated for completeness; review before wiring up to any trigger.
--
-- Bug in original: parameter declared as as_allocref but referenced in the
-- company lookup SELECT as as_alloc_ref (extra underscore). Fixed: as_allocref used
-- throughout.
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   SELECT ... INTO → SELECT ... INTO (PL/pgSQL scalar SELECT INTO).
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   IF/ELSEIF/END IF → CASE WHEN ... END.
--   '+' string concat → '||'.
--   IsNull(x,'') (2-arg) → COALESCE(x,'').
--   string(dateformat(x,'dd/mm/yyyy')) → TO_CHAR(x,'DD/MM/YYYY')
--     (wrapped in COALESCE(...,'') for nullable date columns).
--   sp_belgian_decimal_numbers(string(quantity),4) → public.sp_belgian_decimal_numbers(quantity::text,4).
--   Unused DECLARE variables (now_time, now_timestr) omitted.
--   FOR XML AUTO, ELEMENTS with two joined tables → nested XMLELEMENT:
--     one <Allocation> element wrapping N <allocated_contracts> child elements
--     (produced via correlated XMLAGG subquery).
--   File write: EXECUTE format('COPY ... TO %L (FORMAT text)', ...) as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_allocation_xml_output(
    as_action   varchar(10),
    as_allocref varchar(10)
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_system_date       text;
    v_filename          text;
    v_filepath          text;
    v_filepath_filename text;
    v_xml               text;
    v_company           char(2);
BEGIN
    SELECT a.company
    INTO   v_company
    FROM   public.allocation a
    WHERE  a.allocation_reference = as_allocref;

    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    v_filepath := CASE v_company
        WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/Allocations/'
        WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/Allocations/'
        ELSE            'E:/Nav_Interface/TEST/Sopex Americas/Allocations/'
    END;

    v_filename          := v_system_date || '_Allocation_' || as_action || '_' || as_allocref || '.xml';
    v_filepath_filename := v_filepath || v_filename;

    -- FOR XML AUTO, ELEMENTS with Allocation (outer) + allocated_contracts (inner)
    -- produces nested XML: one <Allocation> wrapping N <allocated_contracts> children.
    -- Correlated XMLAGG subquery handles the one-to-many relationship.
    SELECT
        '<?xml version="1.0" encoding="UTF-8" ?>' ||
        XMLELEMENT(NAME "Root",
            (SELECT
                XMLELEMENT(NAME "Allocation",
                    XMLELEMENT(NAME "allocation_reference",       a.allocation_reference),
                    XMLELEMENT(NAME "notes",                      COALESCE(a.notes,                  '')),
                    XMLELEMENT(NAME "commodity",                  COALESCE(a.commodity,              '')),
                    XMLELEMENT(NAME "commodity_type",             COALESCE(a.commodity_type,         '')),
                    XMLELEMENT(NAME "company",                    COALESCE(a.company,                '')),
                    XMLELEMENT(NAME "pcentre",                    COALESCE(a.pcentre,                '')),
                    XMLELEMENT(NAME "origin",                     COALESCE(a.origin,                 '')),
                    XMLELEMENT(NAME "etd_date",                   COALESCE(TO_CHAR(a.etd_date,  'DD/MM/YYYY'), '')),
                    XMLELEMENT(NAME "eta_date",                   COALESCE(TO_CHAR(a.eta_date,  'DD/MM/YYYY'), '')),
                    XMLELEMENT(NAME "other_reference",            COALESCE(a.other_reference,        '')),
                    XMLELEMENT(NAME "loading_location",           COALESCE(a.loading_location,       '')),
                    XMLELEMENT(NAME "transporter",                COALESCE(a.transporter,            '')),
                    XMLELEMENT(NAME "allocation_completed",       COALESCE(a.allocation_completed,   '')),
                    XMLELEMENT(NAME "allocation_completed_date",  COALESCE(TO_CHAR(a.allocation_completed_date, 'DD/MM/YYYY'), '')),
                    XMLELEMENT(NAME "suggest_completed",          COALESCE(a.suggest_completed,      '')),
                    (SELECT XMLAGG(
                        XMLELEMENT(NAME "allocated_contracts",
                            XMLELEMENT(NAME "contno",   ac.contno),
                            XMLELEMENT(NAME "split",    ac.split),
                            XMLELEMENT(NAME "quantity", public.sp_belgian_decimal_numbers(ac.quantity::text, 4))
                        )
                    )
                    FROM public.allocated_contracts ac
                    WHERE ac.allocation_reference = a.allocation_reference)
                )
            FROM public.allocation a
            WHERE a.allocation_reference = as_allocref)
        )::text
    INTO v_xml;

    EXECUTE format(
        'COPY (SELECT %L::text) TO %L (FORMAT text)',
        v_xml,
        v_filepath_filename
    );
END;
$$;
