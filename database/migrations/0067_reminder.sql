-- ============================================================
-- reminder
-- Source: dba.reminder
-- 3-branch UNION ALL: contracts-to-be-fixed, FX positions, Treasury positions.
-- No alias deps.
--
-- SAP → PostgreSQL translations:
--   '+' string concat     → '||'.
--   string(x)             → x::text.
--   date(x)               → x::date.
--   IF dealratetype='M' THEN ... ELSE ... ENDIF → CASE WHEN ... END.
--   params.systemdate accessed via CROSS JOIN in each branch.
--   Comma-joins → explicit JOINs.
-- ============================================================

CREATE OR REPLACE VIEW public.reminder AS

-- Branch 1: Contracts to be fixed (from phys_avail + master_contracts)
SELECT
    'Contract-To-Be-Fixed'                                                AS type,
    a.contno || '/' || a.split
        || ' (' || b.commodity || '/' || b.commodtype || '/' || b.origin
        || '/' || b.quality   || '/' || b.priceterm   || '/' || b.dest
        || '/' || b.payterm   || ')'                                      AS description,
    a.unfixed_base                                                        AS amount,
    'MT'                                                                  AS unit,
    a.fixbydate                                                           AS deadline,
    b.client                                                              AS counterparty,
    a.contno                                                              AS recid
FROM public.phys_avail a
JOIN public.master_contracts b
    ON b.contno = a.contno
CROSS JOIN public.params p
WHERE a.fixbydate  >= p.systemdate
  AND a.unfixed_base <> 0

UNION ALL

-- Branch 2: Foreign-exchange positions (term_view mktype='X')
SELECT
    'Foreign-Exchange'                                                    AS type,
    a.contno
        || ' (' || a.futconts   || '/' || a.get_prompt || '/'
        || a.cp_signed_openlots::text || ' @ ' || a.tprice::text
        || ' ' || a.mktcurr || ')'                                       AS description,
    CASE WHEN a.dealratetype = 'M'
         THEN a.cp_signed_openlots * a.tprice
         ELSE a.cp_signed_openlots / a.tprice
    END                                                                   AS amount,
    a.othercurr                                                           AS unit,
    a.prompt::date                                                        AS deadline,
    a.broker                                                              AS counterparty,
    a.contno                                                              AS recid
FROM public.term_view a
CROSS JOIN public.params p
WHERE a.prompt::date >= p.systemdate
  AND a.mktype = 'X'

UNION ALL

-- Branch 3: Treasury positions (term_view mktype='T')
SELECT
    'Treasury'                                                            AS type,
    a.contno
        || ' (' || a.futconts   || '/' || a.get_prompt || '/'
        || a.cp_signed_openlots::text || ' @ ' || a.tprice::text
        || '%)'                                                           AS description,
    a.cp_signed_openlots                                                  AS amount,
    a.mktcurr                                                             AS unit,
    a.prompt::date                                                        AS deadline,
    a.broker                                                              AS counterparty,
    a.contno                                                              AS recid
FROM public.term_view a
CROSS JOIN public.params p
WHERE a.prompt::date >= p.systemdate
  AND a.mktype = 'T';
