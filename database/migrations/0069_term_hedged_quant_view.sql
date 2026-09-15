-- ============================================================
-- term_hedged_quant_view
-- Source: dba.term_hedged_quant_view
-- Simple join of terminal_hedges and term_view.  No alias deps.
--
-- SAP → PostgreSQL translations:
--   sp_convert_qty → public.sp_convert_qty.
--   Schema prefix dba. removed.
--   Comma-join → explicit JOIN.
-- ============================================================

CREATE OR REPLACE VIEW public.term_hedged_quant_view AS

SELECT
    a.seqno,
    a.contno,
    a.futconts,
    b.quantity,
    b.termseqno,
    b.quantunit,
    b.termdate,
    public.sp_convert_qty(b.quantity, b.quantunit, a.mktunit) AS hedged_qty
FROM public.terminal_hedges b
JOIN public.term_view a
    ON  a.contdate = b.termdate
    AND a.seqno    = b.termseqno;
