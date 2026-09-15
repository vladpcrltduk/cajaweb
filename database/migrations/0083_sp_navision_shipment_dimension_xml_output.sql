-- ============================================================
-- sp_navision_shipment_dimension_xml_output
-- Source: dba.sp_navision_shipment_dimension_xml_output
--
-- Writes a single-row <DimensionValue> XML for the shipment dimension
-- record. The SAP query aliases the Allocation table as "DimensionValue"
-- so FOR XML AUTO emits <DimensionValue> elements — reproduced here with
-- an explicit XMLELEMENT(NAME "DimensionValue", ...).
--
-- Key difference from 0080 (sp_navision_dimension_xml_output):
--   0080 reads from the dimensionvalue table (multiple rows, XMLAGG).
--   This reads from the allocation table aliased as DimensionValue
--   (typically one row per allocation_reference).  XMLAGG is kept in
--   case allocation_reference is not unique.
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   Unused DECLARE variables (system_datetime, now_time, now_timestr) omitted.
--   SELECT ... INTO → PL/pgSQL scalar SELECT INTO.
--   IF / ELSEIF / END IF → CASE WHEN ... END.
--   '+' string concat → '||'.
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   IsNull(left(x,50),'') → COALESCE(LEFT(x::text,50),'').
--   Literal 'SHIPMENT' as "DimensionCode" → XMLELEMENT(NAME "DimensionCode", 'SHIPMENT').
--   FOR XML AUTO, ELEMENTS → XMLELEMENT/XMLAGG (element-centric).
--   File write: EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)') as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   Backslash path separators → forward slashes (PostgreSQL accepts both on Windows).
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_shipment_dimension_xml_output(
    as_action    varchar(10),
    as_alloc_ref varchar(10)
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_system_date       text;
    v_filepath          text;
    v_filepath_filename text;
    v_xml               text;
    v_company           char(2);
BEGIN
    SELECT a.company
    INTO   v_company
    FROM   public.allocation a
    WHERE  a.allocation_reference = as_alloc_ref;

    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    v_filepath := CASE v_company
        WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/Dimensions/'
        WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/Dimensions/'
        ELSE            'E:/Nav_Interface/TEST/Sopex Americas/Dimensions/'
    END;

    v_filepath_filename := v_filepath
        || v_system_date || '_Dimension_' || as_action || '_' || as_alloc_ref || '.xml';

    -- The SAP query aliases Allocation as "DimensionValue" so FOR XML AUTO
    -- emits <DimensionValue> rows.  Reproduced here with explicit XMLELEMENT.
    -- DimensionCode is always the literal 'SHIPMENT'.
    SELECT
        '<?xml version="1.0" encoding="UTF-8" ?>' ||
        XMLELEMENT(NAME "Root",
            XMLAGG(
                XMLELEMENT(NAME "DimensionValue",
                    XMLELEMENT(NAME "DimensionCode", 'SHIPMENT'),
                    XMLELEMENT(NAME "Code",          a.allocation_reference),
                    XMLELEMENT(NAME "Name",          COALESCE(LEFT(a.notes::text, 50), ''))
                )
            )
        )::text
    INTO v_xml
    FROM public.allocation a
    WHERE a.allocation_reference = as_alloc_ref;

    EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
END;
$$;
