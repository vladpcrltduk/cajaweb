-- ============================================================
-- sp_navision_dimension_xml_output
-- Source: dba.sp_navision_dimension_xml_output
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss')
--     → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS')
--     (SAP uses nn for minutes to avoid clash with mm=month).
--   IF / ELSEIF / END IF → CASE WHEN ... END.
--   '+' string concat → '||'.
--   EXECUTE IMMEDIATE 'UNLOAD SELECT XMLGEN(... FOR XML AUTO, ELEMENTS) TO file':
--     XML generation: XMLELEMENT + XMLAGG (element-centric, matching FOR XML AUTO, ELEMENTS).
--     File write: COPY (SELECT xml_text) TO filepath (FORMAT text) via dynamic EXECUTE.
--       FORMAT text writes the value as plain text — no quoting, one trailing newline.
--       COPY TO supports arbitrary absolute paths for superusers.
--   SECURITY DEFINER: function runs as its owner (must be superuser or have
--     pg_write_server_files role) so triggers and non-superuser callers can
--     invoke it without needing direct COPY TO privilege.
--   Requires: PostgreSQL service account has write access to E:\Nav_Interface\...
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_dimension_xml_output(
    as_action  varchar(10),
    as_contno  varchar(10),
    as_company varchar(2)
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
BEGIN
    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    v_filepath := CASE as_company
        WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/Dimensions/'
        WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/Dimensions/'
        ELSE            'E:/Nav_Interface/TEST/Sopex Americas/Dimensions/'
    END;

    v_filename          := v_system_date || '_Dimension_' || as_action || '_' || as_contno || '.xml';
    v_filepath_filename := v_filepath || v_filename;

    -- Build XML: equivalent of SELECT ... FOR XML AUTO, ELEMENTS wrapped in XMLGEN root.
    -- XMLAGG produces one <DimensionValue> element per row; XMLELEMENT("Root") wraps all.
    -- If the query returns no rows, XMLAGG returns NULL and <Root/> is produced.
    SELECT
        '<?xml version="1.0" encoding="UTF-8" ?>' ||
        XMLELEMENT(NAME "Root",
            XMLAGG(
                XMLELEMENT(NAME "DimensionValue",
                    XMLELEMENT(NAME "DimensionCode", dv.dimensioncode),
                    XMLELEMENT(NAME "Code",          dv.code),
                    XMLELEMENT(NAME "Name",          dv.name)
                )
            )
        )::text
    INTO v_xml
    FROM public.dimensionvalue dv
    WHERE dv.contno = as_contno
      AND dv.split  = '001';

    -- Write the XML file. FORMAT text writes the value verbatim (no quoting).
    -- %L in format() safely escapes the XML content and filepath as SQL literals.
    EXECUTE format(
        'COPY (SELECT %L::text) TO %L (FORMAT text)',
        v_xml,
        v_filepath_filename
    );
END;
$$;
