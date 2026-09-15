-- ============================================================
-- sp_navision_client_xml_output
-- Source: dba.sp_navision_client_xml_output
--
-- The original has ~400 lines of repetition across three outer IF branches
-- (EU+Belgium / EU+non-Belgium / non-EU) and five inner client-type branches
-- (S / T / B / P / ELSE). Factored to ~100 lines by separating the two
-- independent axes:
--
--   Axis 1 — VatRegistrationNo vs EnterpriseNo mapping:
--     EU + Belgium:         VatRegistrationNo='' , EnterpriseNo=vatno
--     EU non-Belgium:       VatRegistrationNo=vatno, EnterpriseNo=''
--     Non-EU (ELSE):        VatRegistrationNo=vatno, EnterpriseNo=''
--   → computed once into v_vatreg / v_enterprise.
--
--   Axis 2 — client type determines file type(s) and subfolder:
--     S  → Vendor XML only
--     T  → Vendor XML then Customer XML (two files)
--     B  → Customer XML only
--     P  → no output (RETURN early)
--     ELSE → Vendor XML, WITHOUT LEFT(50) truncation (preserved from original)
--
-- SAP → PostgreSQL translations:
--   DECLARE / SET → PL/pgSQL DECLARE / :=.
--   Multi-value SELECT INTO → single SELECT INTO with multiple columns.
--   IF/ELSEIF/END IF → IF/ELSIF/END IF.
--   '+' string concat → '||'.
--   isnull(x,'') (2-arg) → COALESCE(x,'').
--   left(x,50) → LEFT(x,50).
--   dateformat(now(),'yyyy_mm_dd_hh_nn_ss') → TO_CHAR(NOW(),'YYYY_MM_DD_HH24_MI_SS').
--   FOR XML AUTO, ELEMENTS (single table) → XMLELEMENT row + XMLELEMENT per column.
--   "E-Mail" as XML element name: quoted identifier preserves the hyphen.
--   File write: EXECUTE format('COPY ... TO %L (FORMAT text)') as per 0080 pattern.
--   SECURITY DEFINER: required for COPY TO outside cluster data directory.
--   Note: if country.is_eu is a boolean column, change '= ''Y''' comparisons
--   to '= true' in the IF condition below.
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_navision_client_xml_output(
    as_action          varchar(10),
    as_client          varchar(8),
    as_clients_company varchar(2)
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_client_type       char(1);
    v_client_country    char(2);
    v_client_country_eu char(1);
    v_vatno             text;
    v_vatreg            text;       -- value for VatRegistrationNo element
    v_enterprise        text;       -- value for EnterpriseNo element
    v_system_date       text;
    v_filepath_base     text;       -- company-specific path prefix
    v_filepath_filename text;
    v_xml               text;
BEGIN
    -- Single lookup: clienttype, country, EU flag, vatno
    SELECT c.clienttype, c.country,
           COALESCE(co.is_eu, 'N'),
           COALESCE(c.vatno, '')
    INTO   v_client_type, v_client_country, v_client_country_eu, v_vatno
    FROM   public.client c
    LEFT   JOIN public.country co ON co.code = c.country
    WHERE  c.code = as_client;

    v_system_date := TO_CHAR(NOW(), 'YYYY_MM_DD_HH24_MI_SS');

    -- Company-specific base path (Vendors/ or Customers/ appended per type)
    v_filepath_base := CASE as_clients_company
        WHEN '01' THEN 'E:/Nav_Interface/TEST/Group Sopex/'
        WHEN '02' THEN 'E:/Nav_Interface/TEST/Sopex Asia/'
        ELSE            'E:/Nav_Interface/TEST/Sopex Americas/'
    END;

    -- VatRegistrationNo / EnterpriseNo mapping (only difference between outer IF branches)
    IF v_client_country_eu = 'Y' AND v_client_country = 'BE' THEN
        v_vatreg     := '';
        v_enterprise := v_vatno;
    ELSE
        -- EU non-Belgium and non-EU both use the same mapping
        v_vatreg     := v_vatno;
        v_enterprise := '';
    END IF;

    -- Prospect: no export to Navision
    IF v_client_type = 'P' THEN
        RETURN;
    END IF;

    -- Supplier (S) or Buyer+Supplier (T): write Vendor XML with LEFT(50) truncation
    IF v_client_type IN ('S', 'T') THEN
        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                XMLELEMENT(NAME "Vendor",
                    XMLELEMENT(NAME "No",                          COALESCE(c.code, '')),
                    XMLELEMENT(NAME "Name",                        COALESCE(LEFT(c.longname, 50), '')),
                    XMLELEMENT(NAME "Address",                     COALESCE(LEFT(c.addr1,    50), '')),
                    XMLELEMENT(NAME "Address2",                    COALESCE(LEFT(c.addr2,    50), '')),
                    XMLELEMENT(NAME "PostCode",                    COALESCE(LEFT(c.addr4,    50), '')),
                    XMLELEMENT(NAME "City",                        COALESCE(LEFT(c.addr5,    50), '')),
                    XMLELEMENT(NAME "CountryRegionCode",           COALESCE(c.country,                        '')),
                    XMLELEMENT(NAME "PhoneNo",                     COALESCE(c.telephone1,                     '')),
                    XMLELEMENT(NAME "FaxNo",                       COALESCE(c.fax,                            '')),
                    XMLELEMENT(NAME "LanguageCode",                COALESCE(c.document_preferred_language,    '')),
                    XMLELEMENT(NAME "VatRegistrationNo",           v_vatreg),
                    XMLELEMENT(NAME "EnterpriseNo",                v_enterprise),
                    XMLELEMENT(NAME "E-Mail",                      COALESCE(c.email,                          '')),
                    XMLELEMENT(NAME "HomePage",                    COALESCE(c.web,                            '')),
                    XMLELEMENT(NAME "GeneralBusinessPostingGroup", COALESCE(c.general_bus_posting_group,      '')),
                    XMLELEMENT(NAME "VATBusinessPostingGroup",     COALESCE(c.vat_bus_posting_group,          '')),
                    XMLELEMENT(NAME "VendorPostingGroup",          COALESCE(c.vendor_posting_group,           ''))
                )
            )::text
        INTO v_xml
        FROM public.client c
        WHERE c.code = as_client;

        v_filepath_filename := v_filepath_base || 'Vendors/'
            || v_system_date || '_Vendor_' || as_action || '_' || as_client || '.xml';

        EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
    END IF;

    -- Buyer (B) or Buyer+Supplier (T): write Customer XML with LEFT(50) truncation
    IF v_client_type IN ('B', 'T') THEN
        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                XMLELEMENT(NAME "Customer",
                    XMLELEMENT(NAME "No",                          COALESCE(c.code, '')),
                    XMLELEMENT(NAME "Name",                        COALESCE(LEFT(c.longname, 50), '')),
                    XMLELEMENT(NAME "Address",                     COALESCE(LEFT(c.addr1,    50), '')),
                    XMLELEMENT(NAME "Address2",                    COALESCE(LEFT(c.addr2,    50), '')),
                    XMLELEMENT(NAME "PostCode",                    COALESCE(LEFT(c.addr4,    50), '')),
                    XMLELEMENT(NAME "City",                        COALESCE(LEFT(c.addr5,    50), '')),
                    XMLELEMENT(NAME "CountryRegionCode",           COALESCE(c.country,                        '')),
                    XMLELEMENT(NAME "PhoneNo",                     COALESCE(c.telephone1,                     '')),
                    XMLELEMENT(NAME "FaxNo",                       COALESCE(c.fax,                            '')),
                    XMLELEMENT(NAME "LanguageCode",                COALESCE(c.document_preferred_language,    '')),
                    XMLELEMENT(NAME "VatRegistrationNo",           v_vatreg),
                    XMLELEMENT(NAME "EnterpriseNo",                v_enterprise),
                    XMLELEMENT(NAME "E-Mail",                      COALESCE(c.email,                          '')),
                    XMLELEMENT(NAME "HomePage",                    COALESCE(c.web,                            '')),
                    XMLELEMENT(NAME "GeneralBusinessPostingGroup", COALESCE(c.general_bus_posting_group,      '')),
                    XMLELEMENT(NAME "VATBusinessPostingGroup",     COALESCE(c.vat_bus_posting_group,          '')),
                    XMLELEMENT(NAME "CustomerPostingGroup",        COALESCE(c.customer_posting_group,         ''))
                )
            )::text
        INTO v_xml
        FROM public.client c
        WHERE c.code = as_client;

        v_filepath_filename := v_filepath_base || 'Customers/'
            || v_system_date || '_Customer_' || as_action || '_' || as_client || '.xml';

        EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
    END IF;

    -- All other types (Bank, Broker, Warehouse, Shipping, House Account, Others, General):
    -- output as Vendor WITHOUT LEFT(50) truncation (as per original ELSE branches)
    IF v_client_type NOT IN ('S', 'T', 'B', 'P') THEN
        SELECT
            '<?xml version="1.0" encoding="UTF-8" ?>' ||
            XMLELEMENT(NAME "Root",
                XMLELEMENT(NAME "Vendor",
                    XMLELEMENT(NAME "No",                          COALESCE(c.code, '')),
                    XMLELEMENT(NAME "Name",                        COALESCE(c.longname,                       '')),
                    XMLELEMENT(NAME "Address",                     COALESCE(c.addr1,                          '')),
                    XMLELEMENT(NAME "Address2",                    COALESCE(c.addr2,                          '')),
                    XMLELEMENT(NAME "PostCode",                    COALESCE(c.addr4,                          '')),
                    XMLELEMENT(NAME "City",                        COALESCE(c.addr5,                          '')),
                    XMLELEMENT(NAME "CountryRegionCode",           COALESCE(c.country,                        '')),
                    XMLELEMENT(NAME "PhoneNo",                     COALESCE(c.telephone1,                     '')),
                    XMLELEMENT(NAME "FaxNo",                       COALESCE(c.fax,                            '')),
                    XMLELEMENT(NAME "LanguageCode",                COALESCE(c.document_preferred_language,    '')),
                    XMLELEMENT(NAME "VatRegistrationNo",           v_vatreg),
                    XMLELEMENT(NAME "EnterpriseNo",                v_enterprise),
                    XMLELEMENT(NAME "E-Mail",                      COALESCE(c.email,                          '')),
                    XMLELEMENT(NAME "HomePage",                    COALESCE(c.web,                            '')),
                    XMLELEMENT(NAME "GeneralBusinessPostingGroup", COALESCE(c.general_bus_posting_group,      '')),
                    XMLELEMENT(NAME "VATBusinessPostingGroup",     COALESCE(c.vat_bus_posting_group,          '')),
                    XMLELEMENT(NAME "VendorPostingGroup",          COALESCE(c.vendor_posting_group,           ''))
                )
            )::text
        INTO v_xml
        FROM public.client c
        WHERE c.code = as_client;

        v_filepath_filename := v_filepath_base || 'Vendors/'
            || v_system_date || '_Vendor_' || as_action || '_' || as_client || '.xml';

        EXECUTE format('COPY (SELECT %L::text) TO %L (FORMAT text)', v_xml, v_filepath_filename);
    END IF;
END;
$$;
