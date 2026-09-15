-- ============================================================
-- Navision / Business Central interface views
-- Source: dba.Navision_34500_* (and related) series
-- All Navision interface views collected in this single file.
-- Common translation rules across all Navision views:
--   left(s,n)              → LEFT(s,n)
--   string(x)              → x::text
--   dateformat(d,'fmt')    → TO_CHAR(d,'fmt') (SAP→PG format codes)
--   isnull(a,b[,c])        → COALESCE(a,b[,c])
--   IF/ENDIF               → CASE WHEN…END
--   + (string concat)      → ||
--   Comma-joins            → explicit JOINs; params → CROSS JOIN
--   sp_belgian_decimal_numbers preserved (custom PG function)
-- ============================================================


-- ------------------------------------------------------------
-- navision_34500_invoice_view
-- Source: dba.Navision_34500_Invoice
-- Purchase invoice lines for Navision journal import.
-- Alias dep: invoice_description (correlated subquery, last column)
--   is referenced in Description — inlined there to resolve dep.
-- CurrencyFactor: Cajá inverts 1/rate for ALL non-base currencies
--   sent to Navision (confirmed by Gunther 2022-10-13 after EUR/USD
--   dipped below 1). Inner branch handles rate<1 vs rate>=1 to
--   ensure leading zero is added correctly.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_34500_invoice_view AS

SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    CASE WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice'
         THEN 'PURCH 226'
         ELSE 'PURCH 206'
    END                                                                  AS journaltemplatename,
    CASE WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice'
         THEN 'DEFAULT'
         ELSE 'PURCH'
    END                                                                  AS journalbatchname,
    CASE WHEN LEFT(accdetail.comments, 46) = 'Opposite posting of original Unfixed P Invoice'
         THEN accsummary.notes
         ELSE accsummary.prov_inv_no
    END                                                                  AS documentno,
    accdetail.nominal                                                    AS accountno,
    -- invoice_description (correlated subquery, last column) inlined
    -- here to resolve the alias dep in Description
    accsummary.contno || ' ' || accsummary.an_client || ' ' ||
    COALESCE((
        SELECT MIN(inv.clientref)
        FROM public.invoice inv
        WHERE inv.invoice_number = accsummary.prov_inv_no
          AND inv.invoice_type   = accsummary.an_invtype
          AND inv.client         = accsummary.an_client
    ), '')                                                               AS description,
    COALESCE(
        TO_CHAR(invoice.custom_posting_date, 'DD/MM/YYYY'),
        TO_CHAR(invoice.invoice_date,        'DD/MM/YYYY'),
        '')                                                              AS postingdate,
    1                                                                    AS quantity,
    public.sp_belgian_decimal_numbers(
        (accdetail.ledamt * -1)::text, 2)                               AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    commodity_type.thirdparty_code2                                      AS shortcutdimension1code,
    accsummary.an_allocref                                               AS shortcutdimension2code,
    ''                                                                   AS shortcutdimension3code,
    accsummary.contno                                                    AS shortcutdimension4code,
    accsummary.an_client                                                 AS shortcutdimension5code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano,
    (SELECT MIN(inv.clientref)
     FROM public.invoice inv
     WHERE inv.invoice_number = accsummary.prov_inv_no
       AND inv.invoice_type   = accsummary.an_invtype
       AND inv.client         = accsummary.an_client)                   AS invoice_description
FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod = accdetail.accperiod
    AND accsummary.ledgernum = accdetail.ledgernum
JOIN public.invoice
    ON  accsummary.an_client   = invoice.client
    AND accsummary.an_invtype  = invoice.invoice_type
    AND accsummary.prov_inv_no = invoice.invoice_number
JOIN public.commodity_type
    ON accsummary.an_commodtype = commodity_type.code
CROSS JOIN public.params
WHERE accsummary.journals = 'INVC'
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_480_client_journal_view
-- Source: dba.Navision_480_Client_Journal
-- Expense journal lines (expense_note_type='480') for Navision.
-- Alias dep: ShortcutDimension2Code alias (expenses_detail.allocation_reference)
--   referenced in ShortcutDimension1Code LIKE condition → inlined.
-- FROM clause: accdetail LEFT OUTER JOIN master_contracts appears alongside
--   standalone master_contracts in the comma list — SAP treats these as one
--   instance; translated as a single LEFT JOIN in the PostgreSQL chain.
-- end if (with space) = endif; both valid in SAP SQL Anywhere.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_480_client_journal_view AS

SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    'MISC 480'                                                           AS journaltemplatename,
    'DEFAULT'                                                            AS journalbatchname,
    expenses_summary.alternative_client_nomcode || accdetail.currency    AS balaccountno,
    accsummary.exp_inv_no                                                AS documentno,
    CASE WHEN expenses_summary.alternative_client_nomcode = '40100'
         THEN 'Customer'
         ELSE 'Vendor'
    END                                                                  AS accounttype,
    accdetail.nominal                                                    AS accountno,
    expenses_detail.description,
    COALESCE(TO_CHAR(accsummary.leddate, 'DD/MM/YYYY'), '')             AS postingdate,
    1                                                                    AS quantity,
    public.sp_belgian_decimal_numbers(
        (accdetail.ledamt * -1)::text, 2)                               AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    -- ShortcutDimension2Code alias (expenses_detail.allocation_reference) inlined
    CASE WHEN expenses_detail.allocation_reference LIKE 'TERM%'
         THEN expenses_detail.allocation_reference
         ELSE commodity_type.thirdparty_code2
    END                                                                  AS shortcutdimension1code,
    expenses_detail.allocation_reference                                 AS shortcutdimension2code,
    CASE WHEN master_contracts.contract_type = 'S'
         THEN expenses_detail.contno
         ELSE ''
    END                                                                  AS shortcutdimension3code,
    CASE WHEN master_contracts.contract_type = 'P'
         THEN expenses_detail.contno
         ELSE ''
    END                                                                  AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    ''                                                                   AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano
FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod = accdetail.accperiod
    AND accsummary.ledgernum = accdetail.ledgernum
LEFT JOIN public.master_contracts
    ON accdetail.accdetail_contno = master_contracts.contno
JOIN public.expenses_summary
    ON  accsummary.exp_inv_no  = expenses_summary.expense_number
    AND accsummary.an_client   = expenses_summary.client
JOIN public.expenses_detail
    ON  expenses_summary.expense_number        = expenses_detail.expense_number
    AND expenses_summary.client                = expenses_detail.client
    AND accdetail.accdetail_charges_line       = expenses_detail.charges_line
JOIN public.commodity_type
    ON expenses_detail.commodity = commodity_type.code
CROSS JOIN public.params
WHERE accsummary.journals = 'INVC'
  AND expenses_summary.expense_note_type = '480'
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_480_journal_view
-- Source: dba.Navision_480_Journal
-- G/L expense journal lines (expense_note_type='480') for Navision.
-- Like navision_480_client_journal_view but:
--   - master_contracts is an inner join (accdetail_contno = contno in WHERE)
--   - AccountType fixed to 'G/L Account'
--   - Quantity: COALESCE(sp_belgian_decimal_numbers(quantity::text,2),'1')
--   - Extra filter: accdetail.client IS NULL
-- ShortcutDimension2Code alias dep inlined as in the client journal view.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_480_journal_view AS

SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    'MISC 480'                                                           AS journaltemplatename,
    'DEFAULT'                                                            AS journalbatchname,
    expenses_summary.alternative_client_nomcode || accdetail.currency    AS balaccountno,
    accsummary.exp_inv_no                                                AS documentno,
    'G/L Account'                                                        AS accounttype,
    accdetail.nominal                                                    AS accountno,
    expenses_detail.description,
    COALESCE(TO_CHAR(accsummary.leddate, 'DD/MM/YYYY'), '')             AS postingdate,
    COALESCE(
        public.sp_belgian_decimal_numbers(expenses_detail.quantity::text, 2),
        '1')                                                             AS quantity,
    public.sp_belgian_decimal_numbers(
        (accdetail.ledamt * -1)::text, 2)                               AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    -- ShortcutDimension2Code alias (expenses_detail.allocation_reference) inlined
    CASE WHEN expenses_detail.allocation_reference LIKE 'TERM%'
         THEN expenses_detail.allocation_reference
         ELSE commodity_type.thirdparty_code2
    END                                                                  AS shortcutdimension1code,
    expenses_detail.allocation_reference                                 AS shortcutdimension2code,
    CASE WHEN master_contracts.contract_type = 'S'
         THEN expenses_detail.contno
         ELSE ''
    END                                                                  AS shortcutdimension3code,
    CASE WHEN master_contracts.contract_type = 'P'
         THEN expenses_detail.contno
         ELSE ''
    END                                                                  AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    ''                                                                   AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano
FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod = accdetail.accperiod
    AND accsummary.ledgernum = accdetail.ledgernum
JOIN public.expenses_summary
    ON  accsummary.exp_inv_no = expenses_summary.expense_number
    AND accsummary.an_client  = expenses_summary.client
JOIN public.expenses_detail
    ON  expenses_summary.expense_number          = expenses_detail.expense_number
    AND expenses_summary.client                  = expenses_detail.client
    AND accdetail.accdetail_charges_line         = expenses_detail.charges_line
JOIN public.master_contracts
    ON accdetail.accdetail_contno = master_contracts.contno
JOIN public.commodity_type
    ON expenses_detail.commodity = commodity_type.code
CROSS JOIN public.params
WHERE accsummary.journals = 'INVC'
  AND expenses_summary.expense_note_type = '480'
  AND accdetail.client IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_481_483_journal_view
-- Source: dba.Navision_481_483_Journal
-- Bank journal lines (expense_note_type IN ('481','483')) for Navision.
-- Differences from 480 journal views:
--   - JournalTemplateName: 'B-'||expense_note_type (dynamic)
--   - JournalBatchName: accdetail.currency
--   - Adds BalAccountType column ('Bank Account')
--   - No charges_line join between accdetail and expenses_detail
--   - ShortcutDimension1Code: commodity_type.thirdparty_code2 (no LIKE branch)
--   - ShortcutDimension2Code: correlated MAX(accdetail_contno) subquery
--   - ShortcutDimension5Code: master_contracts.clientref2
-- No alias deps to resolve.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_481_483_journal_view AS

SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    'B-' || expenses_summary.expense_note_type                          AS journaltemplatename,
    accdetail.currency                                                   AS journalbatchname,
    'Bank Account'                                                       AS balaccounttype,
    expenses_summary.alternative_client_nomcode || accdetail.currency    AS balaccountno,
    accsummary.exp_inv_no                                                AS documentno,
    accdetail.nominal                                                    AS accountno,
    expenses_detail.description,
    COALESCE(TO_CHAR(accsummary.leddate, 'DD/MM/YYYY'), '')             AS postingdate,
    1                                                                    AS quantity,
    public.sp_belgian_decimal_numbers(
        (accdetail.ledamt * -1)::text, 2)                               AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    commodity_type.thirdparty_code2                                      AS shortcutdimension1code,
    (SELECT MAX(accd2.accdetail_contno)
     FROM public.accdetail accd2
     WHERE accd2.accperiod = accdetail.accperiod
       AND accd2.ledgernum = accdetail.ledgernum)                        AS shortcutdimension2code,
    ''                                                                   AS shortcutdimension3code,
    ''                                                                   AS shortcutdimension4code,
    master_contracts.clientref2                                          AS shortcutdimension5code,
    ''                                                                   AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano
FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod = accdetail.accperiod
    AND accsummary.ledgernum = accdetail.ledgernum
JOIN public.expenses_summary
    ON  accsummary.exp_inv_no = expenses_summary.expense_number
    AND accsummary.an_client  = expenses_summary.client
JOIN public.expenses_detail
    ON  expenses_summary.expense_number = expenses_detail.expense_number
    AND expenses_summary.client         = expenses_detail.client
JOIN public.master_contracts
    ON accdetail.accdetail_contno = master_contracts.contno
JOIN public.commodity_type
    ON expenses_detail.commodity = commodity_type.code
CROSS JOIN public.params
WHERE accsummary.journals = 'INVC'
  AND expenses_summary.expense_note_type IN ('481', '483')
  AND accdetail.client IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_490_journal_view
-- Source: dba.Navision_490_Journal
-- Terminal/termijn journal lines (journals='INVC') for Navision.
-- No expenses tables; commodity_type joined via master_contracts.commodtype.
-- Alias dep: ShortcutDimension2Code is a correlated MAX subquery;
--   referenced in ShortcutDimension1Code LIKE condition — subquery
--   inlined twice to resolve dep (CASE WHEN subquery THEN subquery ELSE ...).
-- ShortcutDimension4Code: separate correlated MAX(accdetail_contno) subquery.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_490_journal_view AS

SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    'TM 491'                                                             AS journaltemplatename,
    'TERMIJN'                                                            AS journalbatchname,
    accsummary.exp_inv_no                                                AS documentno,
    'G/L Account'                                                        AS accounttype,
    accdetail.nominal                                                    AS accountno,
    LEFT(accdetail.comments, 50)                                         AS description,
    COALESCE(TO_CHAR(accsummary.leddate, 'DD/MM/YYYY'), '')             AS postingdate,
    1                                                                    AS quantity,
    public.sp_belgian_decimal_numbers(
        (accdetail.ledamt * -1)::text, 2)                               AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    -- ShortcutDimension2Code is a correlated subquery — inlined twice
    -- here to resolve the LIKE alias dep in ShortcutDimension1Code
    CASE WHEN (SELECT MAX(accd2.accdetail_allocation_reference)
               FROM public.accdetail accd2
               WHERE accd2.accperiod = accdetail.accperiod
                 AND accd2.ledgernum = accdetail.ledgernum) LIKE 'TERM%'
         THEN (SELECT MAX(accd2.accdetail_allocation_reference)
               FROM public.accdetail accd2
               WHERE accd2.accperiod = accdetail.accperiod
                 AND accd2.ledgernum = accdetail.ledgernum)
         ELSE commodity_type.thirdparty_code2
    END                                                                  AS shortcutdimension1code,
    (SELECT MAX(accd2.accdetail_allocation_reference)
     FROM public.accdetail accd2
     WHERE accd2.accperiod = accdetail.accperiod
       AND accd2.ledgernum = accdetail.ledgernum)                        AS shortcutdimension2code,
    accsummary.contno                                                    AS shortcutdimension3code,
    (SELECT MAX(accd2.accdetail_contno)
     FROM public.accdetail accd2
     WHERE accd2.accperiod = accdetail.accperiod
       AND accd2.ledgernum = accdetail.ledgernum)                        AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    ''                                                                   AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano
FROM public.accsummary
JOIN public.accdetail
    ON  accsummary.accperiod = accdetail.accperiod
    AND accsummary.ledgernum = accdetail.ledgernum
JOIN public.master_contracts
    ON accsummary.contno = master_contracts.contno
JOIN public.commodity_type
    ON master_contracts.commodtype = commodity_type.code
CROSS JOIN public.params
WHERE accsummary.journals = 'INVC'
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_491_journal_view
-- Source: dba.Navision_491_Journal
-- Futures closeout (TERM 491) journal — two sides of the entry.
-- Branch 1 (NULL client / G/L side):
--   accsummary LEFT JOIN expenses_summary LEFT JOIN expenses_detail;
--   accdetail inner-joined via WHERE (accperiod/ledgernum);
--   accdetail.accdetail_charges_line = expenses_detail.charges_line in
--   WHERE effectively enforces the match (faithfully preserved as WHERE).
-- Branch 2 (client / counterparty side):
--   accsummary LEFT JOIN expenses_summary only; no expenses_detail.
--   Alias deps:
--     futures_closeout_sub_account = accsummary.analysis1 used inside
--       Client_Code correlated subquery WHERE → inlined as accsummary.analysis1.
--     Client_Code alias used as AccountNo → correlated subquery inlined again.
--   AccountType: nested IF with OR conditions → flat CASE WHEN.
--   expense_minimal_charges_line: correlated MIN subquery over expenses_detail.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_491_journal_view AS

-- Branch 1: NULL client side (G/L account lines)
SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    'TERM 491'                                                           AS journaltemplatename,
    'DEFAULT'                                                            AS journalbatchname,
    accsummary.exp_inv_no                                                AS documentno,
    NULL                                                                 AS client_code,
    accsummary.analysis1                                                 AS futures_closeout_sub_account,
    'G/L Account'                                                        AS accounttype,
    accdetail.nominal                                                    AS accountno,
    LEFT(expenses_detail.description, 50)                               AS description,
    COALESCE(TO_CHAR(accsummary.leddate, 'DD/MM/YYYY'), '')             AS postingdate,
    public.sp_belgian_decimal_numbers(
        expenses_detail.quantity::text, 2)                              AS quantity,
    public.sp_belgian_decimal_numbers(
        (accdetail.ledamt * -1)::text, 2)                               AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    expenses_detail.allocation_reference                                 AS shortcutdimension1code,
    expenses_detail.allocation_reference                                 AS shortcutdimension2code,
    accsummary.contno                                                    AS shortcutdimension3code,
    expenses_detail.contno                                               AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    ''                                                                   AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano,
    expenses_summary.expense_date,
    expenses_detail.contno                                               AS expense_contno,
    expenses_detail.allocation_reference                                 AS expense_allocation_reference,
    expenses_detail.commodity                                            AS expense_commodity_type,
    NULL                                                                 AS expense_minimal_charges_line
FROM public.accsummary
LEFT JOIN public.expenses_summary
    ON  accsummary.an_client   = expenses_summary.client
    AND accsummary.exp_inv_no  = expenses_summary.expense_number
LEFT JOIN public.expenses_detail
    ON  expenses_summary.client          = expenses_detail.client
    AND expenses_summary.expense_number  = expenses_detail.expense_number
JOIN public.accdetail
    ON  accsummary.accperiod = accdetail.accperiod
    AND accsummary.ledgernum = accdetail.ledgernum
CROSS JOIN public.params
WHERE accsummary.journals = 'INVC'
  AND accdetail.client IS NULL
  AND accdetail.accdetail_charges_line = expenses_detail.charges_line
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL)

UNION ALL

-- Branch 2: client / counterparty side
-- Client_Code: correlated lookup of nomcodes.description by accsummary.analysis1.
-- AccountNo = Client_Code: subquery inlined a second time to resolve alias dep.
-- AccountType: 'Bank Account' for specific terminal sub-accounts, else
--   Vendor/Customer based on ledamt sign.
SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    'TERM 491'                                                           AS journaltemplatename,
    'DEFAULT'                                                            AS journalbatchname,
    accsummary.exp_inv_no                                                AS documentno,
    -- client_code: nomcodes description looked up by accsummary.analysis1
    (SELECT nc.description
     FROM public.nomcodes nc
     WHERE nc.code = accsummary.analysis1)                              AS client_code,
    accsummary.analysis1                                                 AS futures_closeout_sub_account,
    CASE WHEN (expenses_summary.terminal_sub_account = 'TERMSGCF'
               AND expenses_summary.client = 'ASIACOFF')
           OR (expenses_summary.terminal_sub_account = 'SELLTMUS'
               AND expenses_summary.client = 'SELL')
         THEN 'Bank Account'
         WHEN accdetail.ledamt > 0 THEN 'Vendor'
         ELSE 'Customer'
    END                                                                  AS accounttype,
    -- accountno = client_code: correlated subquery inlined to resolve alias dep
    (SELECT nc.description
     FROM public.nomcodes nc
     WHERE nc.code = accsummary.analysis1)                              AS accountno,
    LEFT(expenses_summary.description, 50)                              AS description,
    COALESCE(TO_CHAR(accsummary.leddate, 'DD/MM/YYYY'), '')             AS postingdate,
    ''                                                                   AS quantity,
    public.sp_belgian_decimal_numbers(
        (accdetail.ledamt * -1)::text, 2)                               AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    ''                                                                   AS shortcutdimension1code,
    ''                                                                   AS shortcutdimension2code,
    ''                                                                   AS shortcutdimension3code,
    ''                                                                   AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    ''                                                                   AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano,
    expenses_summary.expense_date,
    accdetail.accdetail_contno                                           AS expense_contno,
    accdetail.accdetail_allocation_reference                             AS expense_allocation_reference,
    NULL                                                                 AS expense_commodity_type,
    (SELECT MIN(ed.charges_line)
     FROM public.expenses_detail ed
     WHERE ed.client          = expenses_summary.client
       AND ed.expense_number  = expenses_summary.expense_number)        AS expense_minimal_charges_line
FROM public.accsummary
LEFT JOIN public.expenses_summary
    ON  accsummary.an_client  = expenses_summary.client
    AND accsummary.exp_inv_no = expenses_summary.expense_number
JOIN public.accdetail
    ON  accsummary.accperiod = accdetail.accperiod
    AND accsummary.ledgernum = accdetail.ledgernum
CROSS JOIN public.params
WHERE accsummary.journals = 'INVC'
  AND accdetail.client IS NOT NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_expenseinvoice_view
-- Source: dba.Navision_ExpenseInvoice
-- Expense invoice header data for Navision purchase/sales import.
-- No alias deps. All address fields: LEFT(COALESCE(col,''),50).
-- expense_note_type IN ('200','201','206','220') → PURCH; else SALES.
-- 3-arg isnull(a,b,c) → COALESCE(a,b,c) for PostingDate.
-- CurrencyFactor: same 1/rate inversion pattern as other Navision views.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_expenseinvoice_view AS

SELECT
    expenses_summary.crdrind,
    expenses_summary.expense_number                                      AS no,
    CASE WHEN expenses_summary.expense_note_type IN ('200','201','206','220')
         THEN 'PURCH ' || expenses_summary.expense_note_type
         ELSE 'SALES ' || expenses_summary.expense_note_type
    END                                                                  AS journaltemplatename,
    expenses_summary.posted_ledref                                       AS invoice_posted_ledref,
    expenses_summary.client                                              AS buyfromvendorno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS buyfromvendorname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS buyfromaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS buyfromaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS buyfromcity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS buyfrompostcode,
    COALESCE(client.country, '')                                         AS buyfromcountryregioncode,
    expenses_summary.client                                              AS paytovendorno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS paytoname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS paytoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS paytoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS paytocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS paytopostcode,
    COALESCE(client.country, '')                                         AS paytocountryregioncode,
    expenses_summary.client                                              AS selltocustomerno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS selltocustomername,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS selltoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS selltoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS selltocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS selltopostcode,
    COALESCE(client.country, '')                                         AS selltocountryregioncode,
    expenses_summary.client                                              AS billtocustomerno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS billtoname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS billtoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS billtoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS billtocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS billtopostcode,
    COALESCE(client.country, '')                                         AS billtocountryregioncode,
    ''                                                                   AS yourreference,
    COALESCE(TO_CHAR(expenses_summary.expense_date,          'DD/MM/YYYY'), '') AS orderdate,
    COALESCE(
        TO_CHAR(expenses_summary.suggested_posted_date, 'DD/MM/YYYY'),
        TO_CHAR(expenses_summary.expense_date,          'DD/MM/YYYY'),
        '')                                                              AS postingdate,
    COALESCE(TO_CHAR(expenses_summary.expense_date,          'DD/MM/YYYY'), '') AS documentdate,
    COALESCE(TO_CHAR(expenses_summary.expense_date,          'DD/MM/YYYY'), '') AS shipmentdate,
    ''                                                                   AS requestedreceiptdate,
    COALESCE(TO_CHAR(expenses_summary.due_date,              'DD/MM/YYYY'), '') AS duedate,
    ''                                                                   AS paymenttermscode,
    0                                                                    AS paymentdiscount,
    ''                                                                   AS pmtdiscountdate,
    COALESCE(client.vendor_posting_group,             '')               AS vendorpostinggroup,
    COALESCE(client.customer_posting_group,           '')               AS customerpostinggroup,
    ''                                                                   AS customerpricgroup,
    ''                                                                   AS invoicedisccode,
    ''                                                                   AS customerdiscgroup,
    COALESCE(client.country,                          '')               AS locationcode,
    COALESCE(client.document_preferred_language,      '')               AS languagecode,
    COALESCE(client.general_bus_posting_group,        '')               AS genbuspostinggroup,
    COALESCE(client.vat_bus_posting_group,            '')               AS vatbuspostinggroup,
    CASE WHEN expenses_summary.currency = params.base_currency
         THEN ''
         ELSE expenses_summary.currency
    END                                                                  AS currencycode,
    CASE WHEN expenses_summary.currency = params.base_currency
         THEN ''
         WHEN expenses_summary.house_rate < 1
              THEN REPLACE((1.0 / expenses_summary.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / expenses_summary.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    COALESCE(LEFT(expenses_summary.description, 35), '')                AS vendorinvoiceno
FROM public.expenses_summary
JOIN public.client
    ON expenses_summary.client = client.code
CROSS JOIN public.params;


-- ------------------------------------------------------------
-- navision_expenseinvoice_line_view
-- Source: dba.Navision_ExpenseInvoice_Line
-- Expense invoice line details for Navision import.
-- Alias dep: UnitPrice alias referenced as UnitCost — both columns
--   emit the same sp_belgian_decimal_numbers(sp_curr_cvtunderlying(...))
--   expression; Amount is also the same expression (3 occurrences total).
-- FROM: expenses_detail is the LEFT JOIN root (sub_contracts →
--   master_contracts, commodity_type); all other tables inner-joined.
--   accdetail.accdetail_charges_line = expenses_detail.charges_line
--   kept in WHERE (connects two separately-anchored join branches).
-- ShortcutDimension3Code: '' for P or NULL; expenses_detail.contno for S.
-- ShortcutDimension4Code: '' for S or NULL; expenses_detail.contno for P.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_expenseinvoice_line_view AS

SELECT
    expenses_summary.expense_number,
    expenses_summary.crdrind,
    expenses_summary.client,
    expenses_summary.posted_ledref,
    accdetail.accperiod,
    accdetail.ledgernum,
    accdetail.linenum * 10000                                            AS lineno,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                    AS no,
    CASE WHEN expenses_summary.expense_note_type IN ('200', '220')
         THEN COALESCE(LEFT(expenses_detail.description, 50), '')
         ELSE expenses_summary.expense_number || ' ' ||
              COALESCE(expenses_detail.contno, '')
    END                                                                  AS description,
    ''                                                                   AS description2,
    1                                                                    AS quantity,
    -- UnitPrice: sp_curr_cvtunderlying converts amount to base currency
    public.sp_belgian_decimal_numbers(
        public.sp_curr_cvtunderlying(
            expenses_detail.amount, expenses_detail.currency)::text,
        2)                                                               AS unitprice,
    -- UnitCost: UnitPrice alias inlined (alias dep)
    public.sp_belgian_decimal_numbers(
        public.sp_curr_cvtunderlying(
            expenses_detail.amount, expenses_detail.currency)::text,
        2)                                                               AS unitcost,
    -- Amount: same expression (3rd occurrence)
    public.sp_belgian_decimal_numbers(
        public.sp_curr_cvtunderlying(
            expenses_detail.amount, expenses_detail.currency)::text,
        2)                                                               AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    CASE WHEN expenses_detail.allocation_reference LIKE 'TERM%'
         THEN expenses_detail.allocation_reference
         ELSE COALESCE(commodity_type.thirdparty_code2, '')
    END                                                                  AS shortcutdimension1code,
    COALESCE(expenses_detail.allocation_reference, '')                   AS shortcutdimension2code,
    CASE WHEN master_contracts.contract_type = 'P'
           OR master_contracts.contract_type IS NULL
         THEN ''
         ELSE expenses_detail.contno
    END                                                                  AS shortcutdimension3code,
    CASE WHEN master_contracts.contract_type = 'S'
           OR master_contracts.contract_type IS NULL
         THEN ''
         ELSE expenses_detail.contno
    END                                                                  AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    ''                                                                   AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' ||
        accdetail.ledgernum || '-' ||
        accdetail.linenum::text                                          AS cajano,
    COALESCE(expenses_detail.vatcode, '')                                AS genprodpostinggroup,
    COALESCE(expenses_detail.vatcode, '')                                AS vatprodpostinggroup
FROM public.expenses_summary
JOIN public.client
    ON client.code = expenses_summary.client
JOIN public.expenses_detail
    ON expenses_detail.client         = expenses_summary.client
    AND expenses_detail.expense_number = expenses_summary.expense_number
LEFT JOIN public.sub_contracts
    ON sub_contracts.contno = expenses_detail.contno
    AND sub_contracts.split = expenses_detail.split
LEFT JOIN public.master_contracts
    ON master_contracts.contno = sub_contracts.contno
LEFT JOIN public.commodity_type
    ON commodity_type.code = expenses_detail.commodity
JOIN public.accsummary
    ON accsummary.exp_inv_no = expenses_summary.expense_number
    AND accsummary.an_client = expenses_summary.client
JOIN public.accdetail
    ON accdetail.accperiod                   = accsummary.accperiod
    AND accdetail.ledgernum                  = accsummary.ledgernum
    AND accdetail.accdetail_expense_number   = expenses_summary.expense_number
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
WHERE accdetail.client IS NULL
  AND accdetail.accdetail_charges_line = expenses_detail.charges_line;


-- ------------------------------------------------------------
-- navision_purchaseinvoice_line_view
-- Source: dba.Navision_PurchaseInvoice_Line
-- 2-branch UNION ALL: trading lines (invoice_details_2) + charge lines (invoice_charges).
-- Both Description IF/ELSE branches are identical in each branch → plain expression.
-- Branch 2: UnitCost = Amount alias → Amount CASE expression inlined into UnitCost.
-- UnitPrice in branch 2 is commented out in source → excluded.
-- CajaNo: branch 1 uses TO_CHAR(leddate,'YYYYMM'), branch 2 uses accdetail.accperiod directly.
-- ORDER BY 23 DESC → ORDER BY cajano DESC (column 23 of result set).
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_purchaseinvoice_line_view AS

-- Branch 1: Trading lines (invoice_details_2)
SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.client,
    invoice.posted_ledref,
    accdetail.accperiod,
    accdetail.ledgernum,
    accdetail.linenum * 10000                                            AS lineno,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    commodity_type.thirdparty_code2 || ' ' || invoice_details_2.contno  AS description,
    ''                                                                   AS description2,
    public.sp_belgian_decimal_numbers(
        public.sp_convert_qty(invoice_details_2.invoiced_quantity, sub_contracts.quantunit, 'MT')::text,
        4)                                                               AS quantity,
    public.sp_belgian_decimal_numbers(
        (public.sp_curr_cvtunderlying(invoice_details_2.unit_price, sub_contracts.currency)
         * public.sp_convert_qty(1, 'MT', sub_contracts.priceunit))::text,
        2)                                                               AS unitcost,
    public.sp_belgian_decimal_numbers(
        (-1 * invoice_details_2.linevalue)::text,
        2)                                                               AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    invoice_details_2.allocation_reference                               AS shortcutdimension2code,
    ''                                                                   AS shortcutdimension3code,
    invoice_details_2.contno                                             AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    invoice.origin                                                        AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    COALESCE(invoice_details_2.vatcode, '')                             AS genprodpostinggroup,
    COALESCE(invoice_details_2.vatcode, '')                             AS vatprodpostinggroup
FROM public.invoice
JOIN public.invoice_details_2
    ON  invoice_details_2.invoice_number = invoice.invoice_number
    AND invoice_details_2.invoice_type   = invoice.invoice_type
    AND invoice_details_2.client         = invoice.client
JOIN public.client
    ON client.code = invoice.client
JOIN public.sub_contracts
    ON  sub_contracts.contno = invoice_details_2.contno
    AND sub_contracts.split  = invoice_details_2.split
JOIN public.accsummary
    ON accsummary.prov_inv_no = invoice.invoice_number
JOIN public.accdetail
    ON  accdetail.accperiod                      = accsummary.accperiod
    AND accdetail.ledgernum                      = accsummary.ledgernum
    AND accdetail.accdetail_contno               = invoice_details_2.contno
    AND accdetail.accdetail_split                = invoice_details_2.split
    AND accdetail.accdetail_allocation_reference = invoice_details_2.allocation_reference
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
WHERE accdetail.client IS NULL
  AND accdetail.accdetail_charges_line IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL)

UNION ALL

-- Branch 2: Charge lines (invoice_charges)
-- UnitCost: forward-alias ref to Amount → Amount CASE expression inlined.
SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.client,
    invoice.posted_ledref,
    accdetail.accperiod,
    accdetail.ledgernum,
    accdetail.linenum * 10000                                            AS lineno,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    UPPER(LEFT(invoice_charges.description, 50))                         AS description,
    ''                                                                   AS description2,
    '1'                                                                  AS quantity,
    CASE WHEN invoice_charges.crdrindicator = 'D'
         THEN public.sp_belgian_decimal_numbers((invoice_charges.linevalue * -1)::text, 2)
         ELSE public.sp_belgian_decimal_numbers(invoice_charges.linevalue::text, 2)
    END                                                                  AS unitcost,
    CASE WHEN invoice_charges.crdrindicator = 'D'
         THEN public.sp_belgian_decimal_numbers((invoice_charges.linevalue * -1)::text, 2)
         ELSE public.sp_belgian_decimal_numbers(invoice_charges.linevalue::text, 2)
    END                                                                  AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    invoice_charges.allocation_reference                                  AS shortcutdimension2code,
    ''                                                                   AS shortcutdimension3code,
    invoice_charges.contno                                               AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    invoice.origin                                                        AS shortcutdimension6code,
    accdetail.accperiod || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    COALESCE(client.vat_product_posting_group, '')                      AS genprodpostinggroup,
    COALESCE(client.vat_product_posting_group, '')                      AS vatprodpostinggroup
FROM public.invoice
JOIN public.invoice_charges
    ON  invoice_charges.invoice_number = invoice.invoice_number
    AND invoice_charges.invoice_type   = invoice.invoice_type
    AND invoice_charges.client         = invoice.client
JOIN public.client
    ON client.code = invoice.client
JOIN public.accsummary
    ON accsummary.prov_inv_no = invoice.invoice_number
JOIN public.accdetail
    ON  accdetail.accperiod              = accsummary.accperiod
    AND accdetail.ledgernum              = accsummary.ledgernum
    AND accdetail.accdetail_contno       = invoice_charges.contno
    AND accdetail.accdetail_split        = invoice_charges.split
    AND accdetail.accdetail_charges_line = invoice_charges.charges_line
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
WHERE accdetail.client IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL)

ORDER BY cajano DESC;


-- ------------------------------------------------------------
-- navision_purchaseinvoice_view
-- Source: dba.Navision_PurchaseInvoice
-- Provisional purchase invoice header for Navision import.
-- Simpler than the final-invoice variants: 3 tables only, no final_invoice.
-- JournalTemplateName is the literal 'PURCH 210'.
-- CurrencyCode/Factor on invoice.invoice_currency / invoice.house_rate.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_purchaseinvoice_view AS

SELECT
    invoice.invoice_type,
    invoice.invoice_number                                               AS no,
    'PURCH 210'                                                          AS journaltemplatename,
    invoice.posted_ledref                                                AS invoice_posted_ledref,
    invoice.client                                                       AS buyfromvendorno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS buyfromvendorname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS buyfromaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS buyfromaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS buyfromcity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS buyfrompostcode,
    COALESCE(client.country, '')                                         AS buyfromcountryregioncode,
    invoice.client                                                       AS paytovendorno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS paytoname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS paytoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS paytoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS paytocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS paytopostcode,
    COALESCE(client.country, '')                                         AS paytocountryregioncode,
    ''                                                                   AS yourreference,
    COALESCE(TO_CHAR(invoice.invoice_date,          'DD/MM/YYYY'), '')  AS orderdate,
    COALESCE(
        TO_CHAR(invoice.custom_posting_date, 'DD/MM/YYYY'),
        TO_CHAR(invoice.invoice_date,        'DD/MM/YYYY'),
        '')                                                              AS postingdate,
    COALESCE(TO_CHAR(invoice.invoice_date,          'DD/MM/YYYY'), '')  AS documentdate,
    ''                                                                   AS requestedreceiptdate,
    COALESCE(TO_CHAR(invoice.due_date,              'DD/MM/YYYY'), '')  AS duedate,
    ''                                                                   AS paymenttermscode,
    0                                                                    AS paymentdiscount,
    ''                                                                   AS pmtdiscountdate,
    COALESCE(client.customer_posting_group,      '')                    AS vendorpostinggroup,
    ''                                                                   AS invoicedisccode,
    COALESCE(client.document_preferred_language, '')                    AS languagecode,
    COALESCE(client.vat_bus_posting_group,       '')                    AS genbuspostinggroup,
    COALESCE(client.vat_bus_posting_group,       '')                    AS vatbuspostinggroup,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         ELSE invoice.invoice_currency
    END                                                                  AS currencycode,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         WHEN invoice.house_rate < 1
              THEN REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    COALESCE(invoice.clientref, '')                                      AS vendorinvoiceno
FROM public.invoice
JOIN public.client
    ON client.code = invoice.client
CROSS JOIN public.params;


-- ------------------------------------------------------------
-- navision_salesinvoice_view
-- Source: dba.Navision_SalesInvoice
-- Provisional sales invoice header for Navision import.
-- Mirror of navision_purchaseinvoice_view: SALES 310, Sellto/Billto customer blocks.
-- VATBusPostingGroup from invoice.s_invoice_vat_bus_posting_group (client variant commented
-- out in source). No VendorInvoiceNo column. No RequestedReceiptDate column.
-- BilltoName LEFT(...,5): original source has 5, not 50 — preserved as-is.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_salesinvoice_view AS

SELECT
    invoice.invoice_type,
    invoice.invoice_number                                               AS no,
    'SALES 310'                                                          AS journaltemplatename,
    invoice.posted_ledref                                                AS invoice_posted_ledref,
    invoice.client                                                       AS selltocustomerno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS selltocustomername,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS selltoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS selltoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS selltocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS selltopostcode,
    COALESCE(client.country, '')                                         AS selltocountryregioncode,
    invoice.client                                                       AS billtocustomerno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS billtoname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS billtoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS billtoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS billtocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS billtopostcode,
    COALESCE(client.country, '')                                         AS billtocountryregioncode,
    ''                                                                   AS yourreference,
    COALESCE(TO_CHAR(invoice.invoice_date,          'DD/MM/YYYY'), '')  AS orderdate,
    COALESCE(
        TO_CHAR(invoice.custom_posting_date, 'DD/MM/YYYY'),
        TO_CHAR(invoice.invoice_date,        'DD/MM/YYYY'),
        '')                                                              AS postingdate,
    COALESCE(TO_CHAR(invoice.invoice_date,          'DD/MM/YYYY'), '')  AS documentdate,
    COALESCE(TO_CHAR(invoice.invoice_date,          'DD/MM/YYYY'), '')  AS shipmentdate,
    COALESCE(TO_CHAR(invoice.due_date,              'DD/MM/YYYY'), '')  AS duedate,
    ''                                                                   AS paymenttermscode,
    0                                                                    AS paymentdiscount,
    ''                                                                   AS pmtdiscountdate,
    ''                                                                   AS locationcode,
    COALESCE(client.customer_posting_group,      '')                    AS customerpostinggroup,
    ''                                                                   AS customerpricecode,
    ''                                                                   AS invoicedisccode,
    ''                                                                   AS customerdiscgroup,
    COALESCE(client.document_preferred_language, '')                    AS languagecode,
    COALESCE(client.general_bus_posting_group,   '')                    AS genbuspostinggroup,
    COALESCE(invoice.s_invoice_vat_bus_posting_group, '')               AS vatbuspostinggroup,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         ELSE invoice.invoice_currency
    END                                                                  AS currencycode,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         WHEN invoice.house_rate < 1
              THEN REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor
FROM public.invoice
JOIN public.client
    ON client.code = invoice.client
CROSS JOIN public.params;


-- ------------------------------------------------------------
-- navision_salesinvoice_line_view
-- Source: dba.Navision_SalesInvoice_Line
-- 3-branch UNION ALL: stock lines, charge lines, US tariff lines.
-- No LineNo column in any branch (both linenum*10000 and row_number() commented out in source).
-- Branch 1 alias deps resolved:
--   stock_quantity_unit → stocks.quantity_unit (that stocks row is already in FROM).
--   total_invoice_stock_tonnage → CROSS JOIN LATERAL (computed once).
--   UnitPrice: (ratio×linevalue)/(ratio×qty) = linevalue/qty — ratio cancels, subquery avoided.
-- Branch 3 Description IF/ELSE branches differ → CASE WHEN.
-- ORDER BY 29,23 ASC → sort_order_flag, cajano ASC.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_salesinvoice_line_view AS

-- Branch 1: Stock / trading lines (invoice_stocks)
SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.client,
    invoice.posted_ledref,
    accdetail.accperiod,
    accdetail.ledgernum,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    commodity_type.thirdparty_code2 || ' ' || invoice_details_2.contno  AS description,
    ''                                                                   AS description2,
    public.sp_belgian_decimal_numbers(
        ((public.sp_convert_qty(invoice_stocks.stock_quantity, stocks.quantity_unit, 'MT')
          / tist.total_invoice_stock_tonnage)
         * public.sp_convert_qty(invoice_details_2.net_weight, invoice_details_2.delivered_weight_unit, 'MT'))::text,
        4)                                                               AS quantity,
    public.sp_belgian_decimal_numbers(
        (invoice_details_2.linevalue
         / public.sp_convert_qty(invoice_details_2.invoiced_quantity, sub_contracts.quantunit, 'MT'))::text,
        2)                                                               AS unitprice,
    '0,00'                                                               AS unitcost,
    public.sp_belgian_decimal_numbers(
        ((public.sp_convert_qty(invoice_stocks.stock_quantity, stocks.quantity_unit, 'MT')
          / tist.total_invoice_stock_tonnage)
         * invoice_details_2.linevalue)::text,
        2)                                                               AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    invoice_details_2.allocation_reference                               AS shortcutdimension2code,
    invoice_details_2.contno                                             AS shortcutdimension3code,
    invoice_stocks.contno                                                AS shortcutdimension4code,
    payment_instruction.name                                             AS shortcutdimension5code,
    stocks.origin                                                        AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    COALESCE(invoice_details_2.vatcode, '')                             AS genprodpostinggroup,
    COALESCE(invoice_details_2.vatcode, '')                             AS vatprodpostinggroup,
    stocks.quantity_unit                                                  AS stock_quantity_unit,
    invoice_stocks.contno                                                AS purch_contract,
    tist.total_invoice_stock_tonnage,
    'A' || invoice_stocks.stock_id::text                                AS sort_order_flag
FROM public.invoice
JOIN public.invoice_details_2
    ON  invoice_details_2.invoice_number = invoice.invoice_number
    AND invoice_details_2.invoice_type   = invoice.invoice_type
    AND invoice_details_2.client         = invoice.client
JOIN public.sub_contracts
    ON  sub_contracts.contno = invoice_details_2.contno
    AND sub_contracts.split  = invoice_details_2.split
JOIN public.invoice_stocks
    ON  invoice_stocks.invoice_number = invoice.invoice_number
    AND invoice_stocks.invoice_type   = invoice.invoice_type
    AND invoice_stocks.client         = invoice.client
JOIN public.stocks
    ON  stocks.contno               = invoice_stocks.contno
    AND stocks.split                = invoice_stocks.split
    AND stocks.stock_id             = invoice_stocks.stock_id
    AND stocks.allocation_reference = invoice_details_2.allocation_reference
JOIN public.client
    ON client.code = invoice.client
JOIN public.accsummary
    ON accsummary.prov_inv_no = invoice.invoice_number
JOIN public.accdetail
    ON  accdetail.accperiod                      = accsummary.accperiod
    AND accdetail.ledgernum                      = accsummary.ledgernum
    AND accdetail.accdetail_contno               = invoice_details_2.contno
    AND accdetail.accdetail_split                = invoice_details_2.split
    AND accdetail.accdetail_allocation_reference = invoice_details_2.allocation_reference
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
JOIN public.payment_instruction
    ON payment_instruction.code = invoice.payment_instruction
CROSS JOIN LATERAL (
    SELECT SUM(public.sp_convert_qty(is2.stock_quantity, s2.quantity_unit, 'MT')) AS total_invoice_stock_tonnage
    FROM public.invoice_stocks is2
    JOIN public.stocks s2
        ON  s2.contno   = is2.contno
        AND s2.split    = is2.split
        AND s2.stock_id = is2.stock_id
    WHERE is2.invoice_number      = invoice_stocks.invoice_number
      AND is2.invoice_type        = invoice_stocks.invoice_type
      AND is2.client              = invoice_stocks.client
      AND s2.allocation_reference = invoice_details_2.allocation_reference
) AS tist
WHERE accdetail.client IS NULL
  AND accdetail.accdetail_charges_line IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL)

UNION ALL

-- Branch 2: Charge lines (invoice_charges)
-- Amount has no crdrindicator sign flip (unlike UnitPrice) — faithful to source.
SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.client,
    invoice.posted_ledref,
    accdetail.accperiod,
    accdetail.ledgernum,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    UPPER(LEFT(invoice_charges.description, 50))                         AS description,
    ''                                                                   AS description2,
    '1'                                                                  AS quantity,
    CASE WHEN invoice_charges.crdrindicator = 'D'
         THEN public.sp_belgian_decimal_numbers((invoice_charges.linevalue * -1)::text, 2)
         ELSE public.sp_belgian_decimal_numbers(invoice_charges.linevalue::text, 2)
    END                                                                  AS unitprice,
    '0,00'                                                               AS unitcost,
    public.sp_belgian_decimal_numbers(invoice_charges.linevalue::text, 2) AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    invoice_charges.allocation_reference                                  AS shortcutdimension2code,
    invoice_charges.contno                                               AS shortcutdimension3code,
    ''                                                                   AS shortcutdimension4code,
    payment_instruction.name                                             AS shortcutdimension5code,
    invoice.origin                                                        AS shortcutdimension6code,
    accdetail.accperiod || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    COALESCE(invoice_charges.vatcode, '')                               AS genprodpostinggroup,
    COALESCE(invoice_charges.vatcode, '')                               AS vatprodpostinggroup,
    NULL                                                                 AS stock_quantity_unit,
    (SELECT MIN(is3.contno)
     FROM public.invoice_stocks is3
     WHERE is3.invoice_number = invoice.invoice_number
       AND is3.invoice_type   = invoice.invoice_type
       AND is3.client         = invoice.client)                          AS purch_contract,
    NULL                                                                 AS total_invoice_stock_tonnage,
    'B' || invoice_charges.charges_line::text                           AS sort_order_flag
FROM public.invoice
JOIN public.invoice_charges
    ON  invoice_charges.invoice_number = invoice.invoice_number
    AND invoice_charges.invoice_type   = invoice.invoice_type
    AND invoice_charges.client         = invoice.client
JOIN public.client
    ON client.code = invoice.client
JOIN public.accsummary
    ON accsummary.prov_inv_no = invoice.invoice_number
JOIN public.accdetail
    ON  accdetail.accperiod              = accsummary.accperiod
    AND accdetail.ledgernum              = accsummary.ledgernum
    AND accdetail.accdetail_contno       = invoice_charges.contno
    AND accdetail.accdetail_split        = invoice_charges.split
    AND accdetail.accdetail_charges_line = invoice_charges.charges_line
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
JOIN public.payment_instruction
    ON payment_instruction.code = invoice.payment_instruction
WHERE accdetail.client IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL)

UNION ALL

-- Branch 3: US Tariff lines (invoice_stocks_tariffs)
-- Description branches differ: reversed='Y' prefixes 'Reversal of US Tariff...'
SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.client,
    invoice.posted_ledref,
    accdetail.accperiod,
    accdetail.ledgernum,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    CASE WHEN accsummary.reversed = 'Y'
         THEN 'Reversal of US Tariff for invoice ' || invoice.invoice_number
         ELSE 'US Tariff for invoice ' || invoice.invoice_number
    END                                                                  AS description,
    ''                                                                   AS description2,
    '1'                                                                  AS quantity,
    public.sp_belgian_decimal_numbers(invoice_stocks_tariffs.tariff_total_amount::text, 2) AS unitprice,
    '0,00'                                                               AS unitcost,
    public.sp_belgian_decimal_numbers(invoice_stocks_tariffs.tariff_total_amount::text, 2) AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    accdetail.accdetail_allocation_reference                             AS shortcutdimension2code,
    accsummary.contno                                                    AS shortcutdimension3code,
    invoice_stocks_tariffs.contno                                        AS shortcutdimension4code,
    payment_instruction.name                                             AS shortcutdimension5code,
    invoice.origin                                                        AS shortcutdimension6code,
    accdetail.accperiod || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    'G0'                                                                 AS genprodpostinggroup,
    'G0'                                                                 AS vatprodpostinggroup,
    NULL                                                                 AS stock_quantity_unit,
    invoice_stocks_tariffs.contno                                        AS purch_contract,
    NULL                                                                 AS total_invoice_stock_tonnage,
    'C1'                                                                 AS sort_order_flag
FROM public.invoice
JOIN public.invoice_stocks_tariffs
    ON  invoice_stocks_tariffs.invoice_number = invoice.invoice_number
    AND invoice_stocks_tariffs.invoice_type   = invoice.invoice_type
    AND invoice_stocks_tariffs.client         = invoice.client
JOIN public.client
    ON client.code = invoice.client
JOIN public.accsummary
    ON accsummary.prov_inv_no = invoice.invoice_number
JOIN public.accdetail
    ON  accdetail.accperiod        = accsummary.accperiod
    AND accdetail.ledgernum        = accsummary.ledgernum
    AND accdetail.accdetail_contno = invoice_stocks_tariffs.contno
    AND accdetail.accdetail_split  = invoice_stocks_tariffs.split
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
JOIN public.payment_instruction
    ON payment_instruction.code = invoice.payment_instruction
WHERE accdetail.client IS NULL
  AND accdetail.accdetail_reserves_type = 'USTR'
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL)

ORDER BY sort_order_flag, cajano ASC;


-- ------------------------------------------------------------
-- navision_purchaseinvoice_return_view
-- Source: dba.Navision_PurchaseInvoice_Return
-- Purchase invoice return header for Navision import.
-- Adds invoice_return table (joined to invoice on client/invoice_type/invoice_number).
-- No = invoice_return.return_reference.
-- JournalTemplateName: 'PURCH ' || RIGHT(LEFT(return_reference,5),3) — chars 3-5.
-- OrderDate/PostingDate/DocumentDate all from invoice_return.return_date; no fallback chain.
-- DueDate = today() → TO_CHAR(CURRENT_DATE,'DD/MM/YYYY').
-- Address columns have no LEFT truncation in source — omitted.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_purchaseinvoice_return_view AS

SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice_return.return_reference                                       AS no,
    'PURCH ' || RIGHT(LEFT(invoice_return.return_reference, 5), 3)       AS journaltemplatename,
    invoice.posted_ledref                                                 AS invoice_posted_ledref,
    invoice.client                                                        AS buyfromvendorno,
    COALESCE(client.longname, '')                                         AS buyfromvendorname,
    COALESCE(client.addr1,    '')                                         AS buyfromaddress,
    COALESCE(client.addr2,    '')                                         AS buyfromaddress2,
    COALESCE(client.addr5,    '')                                         AS buyfromcity,
    COALESCE(client.addr4,    '')                                         AS buyfrompostcode,
    COALESCE(client.country,  '')                                         AS buyfromcountryregioncode,
    invoice.client                                                        AS paytovendorno,
    COALESCE(client.longname, '')                                         AS paytoname,
    COALESCE(client.addr1,    '')                                         AS paytoaddress,
    COALESCE(client.addr2,    '')                                         AS paytoaddress2,
    COALESCE(client.addr5,    '')                                         AS paytocity,
    COALESCE(client.addr4,    '')                                         AS paytopostcode,
    COALESCE(client.country,  '')                                         AS paytocountryregioncode,
    ''                                                                    AS yourreference,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS orderdate,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS postingdate,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS documentdate,
    ''                                                                    AS requestedreceiptdate,
    TO_CHAR(CURRENT_DATE, 'DD/MM/YYYY')                                   AS duedate,
    ''                                                                    AS paymenttermscode,
    0                                                                     AS paymentdiscount,
    ''                                                                     AS pmtdiscountdate,
    COALESCE(client.customer_posting_group,      '')                      AS vendorpostinggroup,
    ''                                                                    AS invoicedisccode,
    COALESCE(client.document_preferred_language, '')                      AS languagecode,
    COALESCE(client.vat_bus_posting_group,       '')                      AS genbuspostinggroup,
    COALESCE(client.vat_bus_posting_group,       '')                      AS vatbuspostinggroup,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         ELSE invoice.invoice_currency
    END                                                                   AS currencycode,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         WHEN invoice.house_rate < 1
              THEN REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
    END                                                                   AS currencyfactor,
    COALESCE(invoice.clientref, '')                                       AS vendorinvoiceno
FROM public.invoice
JOIN public.invoice_return
    ON  invoice_return.client         = invoice.client
    AND invoice_return.invoice_type   = invoice.invoice_type
    AND invoice_return.invoice_number = invoice.invoice_number
JOIN public.client
    ON client.code = invoice.client
CROSS JOIN public.params;


-- ------------------------------------------------------------
-- navision_purchaseinvoice_return_line_view
-- Source: dba.Navision_PurchaseInvoice_Return_Line
-- Extra column: accsummary.analysis1 at position 5.
-- No UnitPrice column; no ShortcutDimension6Code.
-- Description IF/ELSE branches identical → plain expression.
-- accsummary.journals='RTRN' in WHERE.
-- invoice_return.return_id = accsummary.charges_line added to accsummary JOIN ON.
-- Quantity from invoice_return.return_quantity; Amount = -1 * invoice_return.return_value.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_purchaseinvoice_return_line_view AS

SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.client,
    invoice.posted_ledref,
    accsummary.analysis1,
    accdetail.accperiod,
    accdetail.ledgernum,
    accdetail.linenum * 10000                                            AS lineno,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    'RETURN OF ' || invoice.invoice_number || ' ' || invoice_details_2.contno AS description,
    ''                                                                   AS description2,
    public.sp_belgian_decimal_numbers(
        public.sp_convert_qty(invoice_return.return_quantity, sub_contracts.quantunit, 'MT')::text,
        4)                                                               AS quantity,
    public.sp_belgian_decimal_numbers(
        (public.sp_curr_cvtunderlying(invoice_details_2.unit_price, sub_contracts.currency)
         * public.sp_convert_qty(1, 'MT', sub_contracts.priceunit))::text,
        2)                                                               AS unitcost,
    public.sp_belgian_decimal_numbers(
        (-1 * invoice_return.return_value)::text,
        2)                                                               AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    accdetail.accdetail_allocation_reference                             AS shortcutdimension2code,
    ''                                                                   AS shortcutdimension3code,
    accdetail.accdetail_contno                                           AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    COALESCE(client.vat_product_posting_group, '')                      AS genprodpostinggroup,
    COALESCE(client.vat_product_posting_group, '')                      AS vatprodpostinggroup
FROM public.invoice
JOIN public.invoice_return
    ON  invoice_return.client         = invoice.client
    AND invoice_return.invoice_type   = invoice.invoice_type
    AND invoice_return.invoice_number = invoice.invoice_number
JOIN public.invoice_details_2
    ON  invoice_details_2.invoice_number = invoice.invoice_number
    AND invoice_details_2.invoice_type   = invoice.invoice_type
    AND invoice_details_2.client         = invoice.client
JOIN public.sub_contracts
    ON  sub_contracts.contno = invoice_details_2.contno
    AND sub_contracts.split  = invoice_details_2.split
JOIN public.client
    ON client.code = invoice.client
JOIN public.accsummary
    ON  accsummary.prov_inv_no   = invoice.invoice_number
    AND accsummary.charges_line  = invoice_return.return_id
JOIN public.accdetail
    ON  accdetail.accperiod                      = accsummary.accperiod
    AND accdetail.ledgernum                      = accsummary.ledgernum
    AND accdetail.accdetail_contno               = invoice_details_2.contno
    AND accdetail.accdetail_split                = invoice_details_2.split
    AND accdetail.accdetail_allocation_reference = invoice_details_2.allocation_reference
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
WHERE accsummary.journals = 'RTRN'
  AND accdetail.client IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_salesinvoice_return_view
-- Source: dba.Navision_SalesInvoice_Return
-- Sales invoice return header for Navision import.
-- Mirror of navision_purchaseinvoice_return_view: SALES, Sellto/Billto customer blocks.
-- DueDate = invoice_return.return_date (not today() as in the purchase return).
-- GenBusPostingGroup and VATBusPostingGroup both from client.vat_bus_posting_group.
-- No RequestedReceiptDate column. No VendorInvoiceNo column.
-- Address columns have no LEFT truncation in source — omitted.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_salesinvoice_return_view AS

SELECT
    invoice.invoice_type,
    invoice.invoice_number,
    invoice_return.return_reference                                       AS no,
    'SALES ' || RIGHT(LEFT(invoice_return.return_reference, 5), 3)       AS journaltemplatename,
    invoice.posted_ledref                                                 AS invoice_posted_ledref,
    invoice.client                                                        AS selltocustomerno,
    COALESCE(client.longname, '')                                         AS selltocustomername,
    COALESCE(client.addr1,    '')                                         AS selltoaddress,
    COALESCE(client.addr2,    '')                                         AS selltoaddress2,
    COALESCE(client.addr5,    '')                                         AS selltocity,
    COALESCE(client.addr4,    '')                                         AS selltopostcode,
    COALESCE(client.country,  '')                                         AS selltocountryregioncode,
    invoice.client                                                        AS billtocustomerno,
    COALESCE(client.longname, '')                                         AS billtoname,
    COALESCE(client.addr1,    '')                                         AS billtoaddress,
    COALESCE(client.addr2,    '')                                         AS billtoaddress2,
    COALESCE(client.addr5,    '')                                         AS billtocity,
    COALESCE(client.addr4,    '')                                         AS billtopostcode,
    COALESCE(client.country,  '')                                         AS billtocountryregioncode,
    ''                                                                    AS yourreference,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS orderdate,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS postingdate,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS documentdate,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS shipmentdate,
    COALESCE(TO_CHAR(invoice_return.return_date, 'DD/MM/YYYY'), '')       AS duedate,
    ''                                                                    AS paymenttermscode,
    0                                                                     AS paymentdiscount,
    ''                                                                    AS pmtdiscountdate,
    ''                                                                    AS locationcode,
    COALESCE(client.customer_posting_group,      '')                      AS customerpostinggroup,
    ''                                                                    AS customerpricecode,
    ''                                                                    AS invoicedisccode,
    ''                                                                    AS customerdiscgroup,
    COALESCE(client.document_preferred_language, '')                      AS languagecode,
    COALESCE(client.vat_bus_posting_group,       '')                      AS genbuspostinggroup,
    COALESCE(client.vat_bus_posting_group,       '')                      AS vatbuspostinggroup,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         ELSE invoice.invoice_currency
    END                                                                   AS currencycode,
    CASE WHEN invoice.invoice_currency = params.base_currency
         THEN ''
         WHEN invoice.house_rate < 1
              THEN REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / invoice.house_rate)::text, '.', ',')
    END                                                                   AS currencyfactor
FROM public.invoice
JOIN public.invoice_return
    ON  invoice_return.client         = invoice.client
    AND invoice_return.invoice_type   = invoice.invoice_type
    AND invoice_return.invoice_number = invoice.invoice_number
JOIN public.client
    ON client.code = invoice.client
CROSS JOIN public.params;


-- ------------------------------------------------------------
-- navision_salesinvoice_return_line_view
-- Source: dba.Navision_SalesInvoice_Return_Line
-- No LineNo column. Description uses accdetail.accdetail_contno (not invoice_details_2.contno).
-- UnitPrice = formula; UnitCost = '0,00' (reversed vs. purchase return line).
-- Amount from invoice_details_2.linevalue (not invoice_return.return_value).
-- No accsummary.journals='RTRN' filter — scoped by charges_line = return_id join.
-- ORDER BY allocation_reference ASC.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_salesinvoice_return_line_view AS

SELECT
    invoice.invoice_number,
    invoice.invoice_type,
    invoice.client,
    invoice.posted_ledref,
    accsummary.analysis1,
    accdetail.accperiod,
    accdetail.ledgernum,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    'RETURN OF ' || invoice.invoice_number || ' ' || accdetail.accdetail_contno AS description,
    ''                                                                   AS description2,
    public.sp_belgian_decimal_numbers(
        public.sp_convert_qty(invoice_return.return_quantity, sub_contracts.quantunit, 'MT')::text,
        4)                                                               AS quantity,
    public.sp_belgian_decimal_numbers(
        (public.sp_curr_cvtunderlying(invoice_details_2.unit_price, sub_contracts.currency)
         * public.sp_convert_qty(1, 'MT', sub_contracts.priceunit))::text,
        2)                                                               AS unitprice,
    '0,00'                                                               AS unitcost,
    public.sp_belgian_decimal_numbers(invoice_details_2.linevalue::text, 2) AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    accdetail.accdetail_allocation_reference                             AS shortcutdimension2code,
    accdetail.accdetail_contno                                           AS shortcutdimension3code,
    ''                                                                   AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    COALESCE(client.vat_product_posting_group, '')                      AS genprodpostinggroup,
    COALESCE(client.vat_product_posting_group, '')                      AS vatprodpostinggroup
FROM public.invoice
JOIN public.invoice_return
    ON  invoice_return.client         = invoice.client
    AND invoice_return.invoice_type   = invoice.invoice_type
    AND invoice_return.invoice_number = invoice.invoice_number
JOIN public.invoice_details_2
    ON  invoice_details_2.invoice_number = invoice.invoice_number
    AND invoice_details_2.invoice_type   = invoice.invoice_type
    AND invoice_details_2.client         = invoice.client
JOIN public.sub_contracts
    ON  sub_contracts.contno = invoice_details_2.contno
    AND sub_contracts.split  = invoice_details_2.split
JOIN public.client
    ON client.code = invoice.client
JOIN public.accsummary
    ON  accsummary.prov_inv_no  = invoice.invoice_number
    AND accsummary.charges_line = invoice_return.return_id
JOIN public.accdetail
    ON  accdetail.accperiod                      = accsummary.accperiod
    AND accdetail.ledgernum                      = accsummary.ledgernum
    AND accdetail.accdetail_contno               = invoice_details_2.contno
    AND accdetail.accdetail_split                = invoice_details_2.split
    AND accdetail.accdetail_allocation_reference = invoice_details_2.allocation_reference
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
WHERE accdetail.client IS NULL
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL)
ORDER BY invoice_details_2.allocation_reference ASC;


-- ------------------------------------------------------------
-- navision_outbookingjournal_view
-- Source: dba.Navision_OutbookingJournal
-- Last Navision view. accsummary.journals = 'OUTB' only. No accdetail.client IS NULL filter.
-- 3-level alias chain TempQuantity → StringQuantity → Quantity resolved via CROSS JOIN LATERAL:
--   LATERAL computes tempquantity once; outer SELECT derives stringquantity and quantity from it.
-- ShortcutDimension2Code: nested 4-branch IF → flat CASE WHEN (OUTB EXP×nominal, stock×nominal).
-- CurrencyCode/Factor on accdetail (not invoice).
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_outbookingjournal_view AS

SELECT
    accsummary.accperiod,
    accsummary.ledgernum,
    'JNL 499'                                                            AS journaltemplatename,
    'DEFAULT'                                                            AS journalbatchname,
    accsummary.prov_inv_no                                               AS documentno,
    'G/L Account'                                                        AS accounttype,
    accdetail.nominal                                                     AS accountno,
    accsummary.prov_inv_no                                               AS description,
    COALESCE(TO_CHAR(accsummary.leddate, 'DD/MM/YYYY'), '')             AS postingdate,
    s_.tempquantity,
    s_.tempquantity::text                                                AS stringquantity,
    REPLACE(s_.tempquantity::text, '.', ',')                            AS quantity,
    public.sp_belgian_decimal_numbers((accdetail.ledamt * -1)::text, 2) AS amount,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         ELSE accdetail.currency
    END                                                                  AS currencycode,
    CASE WHEN accdetail.currency = params.base_currency
         THEN ''
         WHEN accdetail.house_rate < 1
              THEN REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / accdetail.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    commodity_type.thirdparty_code2                                      AS shortcutdimension1code,
    CASE WHEN LEFT(accdetail.comments, 8) = 'OUTB EXP' AND LEFT(accdetail.nominal, 1) = '3'
         THEN (SELECT ed.allocation_reference
               FROM public.expenses_detail ed
               WHERE ed.expense_number = accdetail.accdetail_expense_number
                 AND ed.client         = accsummary.an_client
                 AND ed.charges_line   = accdetail.accdetail_charges_line)
         WHEN LEFT(accdetail.comments, 8) = 'OUTB EXP'
         THEN accsummary.an_allocref
         WHEN LEFT(accdetail.nominal, 1) = '3'
         THEN (SELECT st.original_allocation_reference
               FROM public.stocks st
               WHERE st.contno   = accsummary.analysis2
                 AND st.split    = accsummary.analysis3
                 AND st.stock_id::text = accsummary.analysis4)
         ELSE accsummary.an_allocref
    END                                                                  AS shortcutdimension2code,
    accsummary.contno                                                    AS shortcutdimension3code,
    accdetail.accdetail_contno                                           AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano
FROM public.accsummary
JOIN public.accdetail
    ON  accdetail.accperiod = accsummary.accperiod
    AND accdetail.ledgernum = accsummary.ledgernum
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
CROSS JOIN public.params
CROSS JOIN LATERAL (
    SELECT
        CASE WHEN LEFT(accdetail.comments, 8) = 'OUTB EXP' THEN 0
             WHEN LEFT(accdetail.nominal, 1) = '3'          THEN accsummary.an_tonnage
             ELSE                                                accsummary.an_tonnage * -1
        END AS tempquantity
) AS s_
WHERE accsummary.journals = 'OUTB'
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_finalsalesinvoice_line_view
-- Source: dba.Navision_FinalSalesInvoice_Line
-- Line-level view for final sales invoices (accdetail_invoice_flag = 'SF').
-- IF/ELSE Description: both branches identical → plain expression, no CASE.
-- UnitPrice/UnitCost/Amount: same sp_belgian_decimal_numbers(abs(...)) inlined 3×.
-- All comma-joins → explicit JOINs.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_finalsalesinvoice_line_view AS

SELECT
    final_invoice.invoice_number,
    final_invoice.final_invoice_number,
    final_invoice.invoice_type,
    final_invoice.client,
    final_invoice.posted_ledref,
    accdetail.accperiod,
    accdetail.ledgernum,
    accdetail.linenum * 10000                                            AS lineno,
    'G/L Account'                                                        AS type,
    accdetail.nominal                                                     AS no,
    final_invoice.final_invoice_number || ' ' || final_invoice_details_2.contno AS description,
    ''                                                                   AS description2,
    1                                                                    AS quantity,
    public.sp_belgian_decimal_numbers(ABS(final_invoice_details_2.net_due_partial)::text, 2) AS unitprice,
    public.sp_belgian_decimal_numbers(ABS(final_invoice_details_2.net_due_partial)::text, 2) AS unitcost,
    public.sp_belgian_decimal_numbers(ABS(final_invoice_details_2.net_due_partial)::text, 2) AS amount,
    0                                                                    AS vat,
    0                                                                    AS linediscount,
    COALESCE(commodity_type.thirdparty_code2, '')                       AS shortcutdimension1code,
    final_invoice_details_2.allocation_reference                         AS shortcutdimension2code,
    final_invoice_details_2.contno                                       AS shortcutdimension3code,
    ''                                                                   AS shortcutdimension4code,
    ''                                                                   AS shortcutdimension5code,
    invoice.origin                                                        AS shortcutdimension6code,
    TO_CHAR(accsummary.leddate, 'YYYYMM') || '-' || accdetail.ledgernum || '-' || accdetail.linenum::text AS cajano,
    COALESCE(final_invoice_details_2.vatcode, '')                       AS genprodpostinggroup,
    COALESCE(final_invoice_details_2.vatcode, '')                       AS vatprodpostinggroup
FROM public.invoice
JOIN public.final_invoice
    ON  final_invoice.invoice_number = invoice.invoice_number
    AND final_invoice.invoice_type   = invoice.invoice_type
    AND final_invoice.client         = invoice.client
JOIN public.final_invoice_details_2
    ON  final_invoice_details_2.invoice_number = final_invoice.invoice_number
    AND final_invoice_details_2.invoice_type   = final_invoice.invoice_type
    AND final_invoice_details_2.client         = final_invoice.client
JOIN public.client
    ON client.code = invoice.client
JOIN public.sub_contracts
    ON  sub_contracts.contno = final_invoice_details_2.contno
    AND sub_contracts.split  = final_invoice_details_2.split
JOIN public.accsummary
    ON  accsummary.prov_inv_no = invoice.invoice_number
    AND accsummary.fin_inv_no  = final_invoice.final_invoice_number
JOIN public.accdetail
    ON  accdetail.accperiod                         = accsummary.accperiod
    AND accdetail.ledgernum                         = accsummary.ledgernum
    AND accdetail.accdetail_contno                  = final_invoice_details_2.contno
    AND accdetail.accdetail_split                   = final_invoice_details_2.split
    AND accdetail.accdetail_allocation_reference    = final_invoice_details_2.allocation_reference
    AND accdetail.accdetail_final_invoice_number    = final_invoice.final_invoice_number
JOIN public.commodity_type
    ON commodity_type.code = accsummary.an_commodtype
JOIN public.nomcodes
    ON nomcodes.code = accdetail.nominal
WHERE accdetail.client IS NULL
  AND accdetail.caja_project IS NULL
  AND accdetail.accdetail_invoice_flag = 'SF'
  AND (accdetail.vatcode <> 'TX' OR accdetail.vatcode IS NULL);


-- ------------------------------------------------------------
-- navision_finalsalesinvoice_view
-- Source: dba.Navision_FinalSalesInvoice
-- Final sales invoice header for Navision import.
-- Mirror of navision_finalpurchaseinvoice_view:
--   SALES prefix, Sellto/Billto customer blocks, extra fields
--   (ShipmentDate, LocationCode, CustomerPriceGroup, CustomerDiscGroup).
-- VATBusPostingGroup comes from invoice.s_invoice_vat_bus_posting_group.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_finalsalesinvoice_view AS

SELECT
    invoice.invoice_type,
    final_invoice.final_invoice_number                                   AS no,
    final_invoice.invoice_number,
    'SALES ' || final_invoice.final_invoice_journal                      AS journaltemplatename,
    final_invoice.posted_ledref                                          AS invoice_posted_ledref,
    final_invoice.client                                                 AS selltocustomerno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS selltocustomername,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS selltoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS selltoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS selltocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS selltopostcode,
    COALESCE(client.country, '')                                         AS selltocountryregioncode,
    final_invoice.client                                                 AS billtocustomerno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS billtoname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS billtoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS billtoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS billtocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS billtopostcode,
    COALESCE(client.country, '')                                         AS billtocountryregioncode,
    ''                                                                   AS yourreference,
    COALESCE(TO_CHAR(final_invoice.invoice_date,          'DD/MM/YYYY'), '') AS orderdate,
    COALESCE(
        TO_CHAR(final_invoice.custom_posting_date, 'DD/MM/YYYY'),
        TO_CHAR(final_invoice.invoice_date,        'DD/MM/YYYY'),
        '')                                                              AS postingdate,
    COALESCE(TO_CHAR(final_invoice.invoice_date,          'DD/MM/YYYY'), '') AS documentdate,
    COALESCE(TO_CHAR(final_invoice.invoice_date,          'DD/MM/YYYY'), '') AS shipmentdate,
    ''                                                                   AS requestedreceiptdate,
    COALESCE(TO_CHAR(final_invoice.due_date,              'DD/MM/YYYY'), '') AS duedate,
    ''                                                                   AS paymenttermscode,
    0                                                                    AS paymentdiscount,
    ''                                                                   AS pmtdiscountdate,
    ''                                                                   AS locationcode,
    COALESCE(client.customer_posting_group,       '')                   AS customerpostinggroup,
    ''                                                                   AS customerpricecode,
    ''                                                                   AS invoicedisccode,
    ''                                                                   AS customerdiscgroup,
    COALESCE(client.document_preferred_language,  '')                   AS languagecode,
    COALESCE(client.general_bus_posting_group,    '')                   AS genbuspostinggroup,
    COALESCE(invoice.s_invoice_vat_bus_posting_group, '')               AS vatbuspostinggroup,
    CASE WHEN final_invoice.invoice_currency = params.base_currency
         THEN ''
         ELSE final_invoice.invoice_currency
    END                                                                  AS currencycode,
    CASE WHEN final_invoice.invoice_currency = params.base_currency
         THEN ''
         WHEN final_invoice.house_rate < 1
              THEN REPLACE((1.0 / final_invoice.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / final_invoice.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    COALESCE(final_invoice.clientref, '')                               AS vendorinvoiceno
FROM public.invoice
JOIN public.final_invoice
    ON  final_invoice.client         = invoice.client
    AND final_invoice.invoice_type   = invoice.invoice_type
    AND final_invoice.invoice_number = invoice.invoice_number
JOIN public.client
    ON client.code = invoice.client
CROSS JOIN public.params;


-- ------------------------------------------------------------
-- navision_finalpurchaseinvoice_view
-- Source: dba.Navision_FinalPurchaseInvoice
-- Final purchase invoice header for Navision import.
-- No alias deps. Joins invoice to final_invoice (final_invoice carries
-- the same key: client + invoice_type + invoice_number).
-- 3-arg isnull for PostingDate: custom_posting_date fallback to invoice_date.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.navision_finalpurchaseinvoice_view AS

SELECT
    invoice.invoice_type,
    final_invoice.final_invoice_number                                   AS no,
    final_invoice.invoice_number,
    'PURCH ' || final_invoice.final_invoice_journal                      AS journaltemplatename,
    final_invoice.posted_ledref                                          AS invoice_posted_ledref,
    final_invoice.client                                                 AS buyfromvendorno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS buyfromvendorname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS buyfromaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS buyfromaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS buyfromcity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS buyfrompostcode,
    COALESCE(client.country, '')                                         AS buyfromcountryregioncode,
    final_invoice.client                                                 AS paytovendorno,
    LEFT(COALESCE(client.longname, ''), 50)                             AS paytoname,
    LEFT(COALESCE(client.addr1,    ''), 50)                             AS paytoaddress,
    LEFT(COALESCE(client.addr2,    ''), 50)                             AS paytoaddress2,
    LEFT(COALESCE(client.addr5,    ''), 50)                             AS paytocity,
    LEFT(COALESCE(client.addr4,    ''), 50)                             AS paytopostcode,
    COALESCE(client.country, '')                                         AS paytocountryregioncode,
    ''                                                                   AS yourreference,
    COALESCE(TO_CHAR(final_invoice.invoice_date,          'DD/MM/YYYY'), '') AS orderdate,
    COALESCE(
        TO_CHAR(final_invoice.custom_posting_date, 'DD/MM/YYYY'),
        TO_CHAR(final_invoice.invoice_date,        'DD/MM/YYYY'),
        '')                                                              AS postingdate,
    COALESCE(TO_CHAR(final_invoice.invoice_date,          'DD/MM/YYYY'), '') AS documentdate,
    ''                                                                   AS requestedreceiptdate,
    COALESCE(TO_CHAR(final_invoice.due_date,              'DD/MM/YYYY'), '') AS duedate,
    ''                                                                   AS paymenttermscode,
    0                                                                    AS paymentdiscount,
    ''                                                                   AS pmtdiscountdate,
    COALESCE(client.customer_posting_group,       '')                   AS vendorpostinggroup,
    ''                                                                   AS invoicedisccode,
    COALESCE(client.document_preferred_language,  '')                   AS languagecode,
    COALESCE(client.vat_bus_posting_group,        '')                   AS genbuspostinggroup,
    COALESCE(client.vat_bus_posting_group,        '')                   AS vatbuspostinggroup,
    CASE WHEN final_invoice.invoice_currency = params.base_currency
         THEN ''
         ELSE final_invoice.invoice_currency
    END                                                                  AS currencycode,
    CASE WHEN final_invoice.invoice_currency = params.base_currency
         THEN ''
         WHEN final_invoice.house_rate < 1
              THEN REPLACE((1.0 / final_invoice.house_rate)::text, '.', ',')
         ELSE '0' || REPLACE((1.0 / final_invoice.house_rate)::text, '.', ',')
    END                                                                  AS currencyfactor,
    COALESCE(final_invoice.clientref, '')                               AS vendorinvoiceno
FROM public.invoice
JOIN public.final_invoice
    ON  final_invoice.client         = invoice.client
    AND final_invoice.invoice_type   = invoice.invoice_type
    AND final_invoice.invoice_number = invoice.invoice_number
JOIN public.client
    ON client.code = invoice.client
CROSS JOIN public.params;
