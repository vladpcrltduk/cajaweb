-- ============================================================
-- powerbi_open_options_by_position
-- Source: dba.PowerBI_Open_Options_By_Position
-- Simple filtered passthrough from term_view (mktype='F', tradetype<>'F',
-- plots>0 or slots>0).  No alias deps or expression transformations.
--
-- SAP → PostgreSQL translations:
--   CAST(series AS numeric(10,2)) — valid in both; retained as-is.
--   ORDER BY retained (faithful to source).
-- ============================================================

CREATE OR REPLACE VIEW public.powerbi_open_options_by_position AS

SELECT
    tv.seqno,
    tv.contdate,
    tv.lots,
    tv.tprice,
    tv.plots,
    tv.slots,
    tv.commission,
    tv.commcurr,
    tv.commtype,
    tv.commpaidheld,
    tv.mktcurr,
    tv.othercurr,
    tv.pricefactor,
    tv.company,
    tv.pcentre,
    tv.commodity,
    tv.broker,
    tv.sub_account,
    tv.terminaltype                                AS sub_account2,
    tv.futconts,
    tv.prompt,
    tv.tradetype,
    tv.series,
    CAST(tv.series AS numeric(10, 2))             AS series_rounded,
    tv.contval,
    tv.commval,
    tv.contno,
    tv.valprice,
    tv.mktvalue,
    tv.varmarg,
    tv.lotfactor,
    tv.get_prompt,
    tv.sysdate,
    tv.currfactor
FROM public.term_view tv
WHERE tv.mktype    = 'F'
  AND tv.tradetype <> 'F'
  AND (tv.plots > 0 OR tv.slots > 0)
ORDER BY tv.futconts   ASC,
         tv.company    ASC,
         tv.pcentre    ASC,
         tv.commodity  ASC,
         tv.broker     ASC,
         tv.prompt     ASC,
         tv.tradetype  ASC,
         tv.series     ASC,
         tv.sub_account ASC,
         tv.seqno      ASC,
         tv.contdate   ASC;
