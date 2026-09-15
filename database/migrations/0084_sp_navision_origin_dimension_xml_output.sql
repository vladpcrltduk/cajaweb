-- ============================================================
-- sp_navision_origin_dimension_xml_output
-- Source: dba.sp_navision_origin_dimension_xml_output
--
-- Writes a <DimensionValue> XML for an origin dimension record.
-- The SAP query reads from Navision_Dimension_Origin aliased as
-- "DimensionValue", so FOR XML AUTO emits <DimensionValue> rows.
--
-- Notable differences from 0080 (sp_navision_dimension_xml_output):
--   - No company lookup / no filepath branching: always writes to
--     Group Sopex/Dimensions/ (hardcoded in original).
--   - Source table is navision_dimension_origin, not dimensionvalue.
--   - Name is not truncated (no LEFT(50) in original).
--   - Filename includes '_Origin_Dimension_' segment.
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   Unused DECLARE variables (system_datetime, now_time, now_timestr) omitted.
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   IsNull(x,'') → COALESCE(x,'').
--   FOR XML AUTO, ELEMENTS (alias DimensionValue) → XMLELEMENT(NAME "DimensionValue",...).
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   Backslash path separators → forward slashes.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_origin_dimension_xml_output(
    as_action      varchar(10),
    as_origin_code varchar(10)
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
        'E:/Nav_Interface/TEST/Group Sopex/Dimensions/'
        || v_system_date || '_Origin_Dimension_' || as_action || '_' || as_origin_code || '.xml';

    SELECT
        '<?xml version="1.0" encoding="UTF-8" ?>' ||
        XMLELEMENT(NAME "Root",
            XMLAGG(
                XMLELEMENT(NAME "DimensionValue",
                    XMLELEMENT(NAME "DimensionCode", dv.dimensioncode),
                    XMLELEMENT(NAME "Code",          dv.code),
                    XMLELEMENT(NAME "Name",          COALESCE(dv.name, ''))
                )
            )
        )::text
    INTO v_xml
    FROM public.navision_dimension_origin dv
    WHERE dv.code = as_origin_code;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
