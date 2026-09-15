-- ============================================================
-- hist_stocks_view
-- Source: dba.hist_stocks
-- Column-selection view over stocks_history.
-- ============================================================

CREATE OR REPLACE VIEW public.hist_stocks_view AS

SELECT
    hist_date,
    hist_time,
    hist_type,
    hist_user,
    contno,
    split,
    stock_id,
    shipment_id,
    quantity,
    quantity_unit,
    company,
    pcentre,
    commodity,
    commodity_type,
    origin,
    quality,
    packing,
    delivered_quantity,
    delivered_unit,
    delivered_weight,
    delivered_weight_unit
FROM public.stocks_history;
