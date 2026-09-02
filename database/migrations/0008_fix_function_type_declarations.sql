DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0008_fix_function_type_declarations') THEN
    RAISE NOTICE 'Migration 0008 already applied, skipping.';
    RETURN;
  END IF;

  -- Fix as_shipment_id parameter: char(8) -> char(10)
  CREATE OR REPLACE FUNCTION public.sp_sopex_construct_covering_letters(as_shipment_id character(10))
   RETURNS character varying
   LANGUAGE plpgsql
  AS $func$DECLARE
    shipmentletters CURSOR FOR
      SELECT shipment_letters.originals, shipment_letters.copies, shipment_letters.description
        FROM shipment_letters
        WHERE shipment_letters.shipment_id = as_shipment_id AND used = 1;
    ls_retval varchar(1024);
    ls_document char(64);
    ln_originals numeric(5);
    ls_originals_text char(64);
    ln_copies numeric(5);
    ls_copies_text char(64);
  BEGIN
    ls_retval := '';
    OPEN shipmentletters;
    FETCH NEXT FROM shipmentletters INTO ln_originals, ln_copies, ls_document;
    WHILE FOUND LOOP
      IF ln_originals = 0 THEN
        ls_originals_text := '';
      ELSIF ln_originals = 1 THEN
        ls_originals_text := '1 original';
      ELSE
        ls_originals_text := ln_originals::text || ' originals';
      END IF;
      IF ln_copies = 0 THEN
        ls_copies_text := '';
      ELSIF ln_copies = 1 THEN
        ls_copies_text := '1 copy';
      ELSE
        ls_copies_text := ln_copies::text || ' copies';
      END IF;
      IF ls_originals_text = '' AND ls_copies_text <> '' THEN
        ls_retval := ls_retval || ls_document || ' (' || ls_copies_text || ')' || E'\n';
      ELSIF ls_originals_text <> '' AND ls_copies_text <> '' THEN
        ls_retval := ls_retval || ls_document || ' (' || ls_originals_text || ' and ' || ls_copies_text || ')' || E'\n';
      ELSIF ls_originals_text <> '' AND ls_copies_text = '' THEN
        ls_retval := ls_retval || ls_document || ' (' || ls_originals_text || ')' || E'\n';
      END IF;
      FETCH NEXT FROM shipmentletters INTO ln_originals, ln_copies, ls_document;
    END LOOP;
    CLOSE shipmentletters;
    RETURN ls_retval;
  END;$func$;

  -- Fix ls_client local var: char(8) -> char(16)
  CREATE OR REPLACE FUNCTION public.sp_invoice_list_other_clients(as_invoice_number character, as_inv_type character, as_invoice_client character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    invoice_stocks_cur CURSOR FOR
      SELECT contno, split, stock_id
        FROM invoice_stocks
        WHERE invoice_number = as_invoice_number
          AND invoice_type = as_inv_type
          AND client = as_invoice_client;
    other_invoices CURSOR FOR
      SELECT inv_other.client
        FROM invoice AS inv_other, invoice_stocks AS inv_other_stocks
        WHERE inv_other.invoice_number = inv_other_stocks.invoice_number
          AND inv_other.invoice_type = inv_other_stocks.invoice_type
          AND inv_other.client = inv_other_stocks.client
          AND inv_other_stocks.contno = ls_contno
          AND inv_other_stocks.split = ls_split
          AND inv_other_stocks.stock_id = li_stock_id
          AND inv_other.invoice_type <> as_inv_type
        ORDER BY inv_other.client ASC;
    ls_client char(16);
    ls_client_list char(128);
    ls_contno char(10);
    ls_split char(3);
    li_stock_id integer;
    ls_stock_ids char(128);
  BEGIN
    ls_client_list := '';
    ls_stock_ids := '';
    OPEN invoice_stocks_cur;
    FETCH NEXT FROM invoice_stocks_cur INTO ls_contno, ls_split, li_stock_id;
    WHILE FOUND LOOP
      OPEN other_invoices;
      FETCH NEXT FROM other_invoices INTO ls_client;
      WHILE FOUND LOOP
        IF ls_client_list = '' THEN
          ls_client_list := ls_client_list || ls_client;
        ELSIF position(ls_client IN ls_client_list) = 0 THEN
          ls_client_list := ls_client_list || ', ' || ls_client;
        END IF;
        FETCH NEXT FROM other_invoices INTO ls_client;
      END LOOP;
      CLOSE other_invoices;
      FETCH NEXT FROM invoice_stocks_cur INTO ls_contno, ls_split, li_stock_id;
    END LOOP;
    CLOSE invoice_stocks_cur;
    RETURN ls_client_list;
  END;$func$;

  -- Fix ls_invoice_client local var: char(8) -> char(16)
  CREATE OR REPLACE FUNCTION public.sp_sopex_get_sum_invoice_value(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contracts_invoices CURSOR FOR
      SELECT invoice.invoice_number, invoice.invoice_type, invoice.client, invoice.invoice_value
        FROM invoice, invoice_details_2
        WHERE invoice.invoice_number = invoice_details_2.invoice_number
          AND invoice.invoice_type = invoice_details_2.invoice_type
          AND invoice.client = invoice_details_2.client
          AND invoice_details_2.contno = as_contno
          AND invoice_details_2.split = as_split
        GROUP BY invoice.invoice_number, invoice.invoice_type, invoice.client, invoice.invoice_value;
    ls_invoice_number char(10);
    ls_invoice_type char(1);
    ls_invoice_client char(16);
    ldc_invoice_value numeric(16,4);
    ldc_retval numeric(16,4);
  BEGIN
    ldc_retval := 0.0;
    OPEN contracts_invoices;
    FETCH NEXT FROM contracts_invoices INTO ls_invoice_number, ls_invoice_type, ls_invoice_client, ldc_invoice_value;
    WHILE FOUND LOOP
      ldc_retval := ldc_retval + ldc_invoice_value;
      FETCH NEXT FROM contracts_invoices INTO ls_invoice_number, ls_invoice_type, ls_invoice_client, ldc_invoice_value;
    END LOOP;
    CLOSE contracts_invoices;
    RETURN ldc_retval;
  END;$func$;

  -- Fix ls_invoice_client local var: char(10) -> char(16)
  CREATE OR REPLACE FUNCTION public.sp_sopex_sum_all_stocks_from_stock_alloc(as_allocation_reference character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    stock_alloc_stocks CURSOR FOR
      SELECT contno, split, original_invoice_number, original_invoice_type, original_client
        FROM stocks
        WHERE stocks.original_allocation_reference = as_allocation_reference
        ORDER BY original_invoice_number ASC;
    ln_total_stock NUMERIC(16,4);
    ls_purchase_contno char(10);
    ls_purchase_split char(3);
    ls_invoice_number char(10);
    ls_invoice_type char(1);
    ls_invoice_client char(16);
    ln_invoice_stock NUMERIC(16,4);
    ls_invoice_numbers_done char(128);
  BEGIN
    ln_total_stock := 0;
    ls_invoice_numbers_done := '';
    OPEN stock_alloc_stocks;
    FETCH NEXT FROM stock_alloc_stocks INTO ls_purchase_contno, ls_purchase_split, ls_invoice_number, ls_invoice_type, ls_invoice_client;
    WHILE FOUND LOOP
      IF position(ls_invoice_number IN ls_invoice_numbers_done) = 0 THEN
        SELECT sum(sp_convert_qty(invoice_details_2.invoiced_quantity, invoice_details_2.delivered_unit, 'MT'))
          INTO ln_invoice_stock
          FROM invoice_details_2
          WHERE ls_invoice_number = invoice_details_2.invoice_number
            AND ls_invoice_type = invoice_details_2.invoice_type
            AND ls_invoice_client = invoice_details_2.client
            AND ls_purchase_contno = invoice_details_2.contno
            AND ls_purchase_split = invoice_details_2.split
            AND invoice_details_2.invoice_type = 'P';
        ln_total_stock := ln_total_stock + ln_invoice_stock;
      END IF;
      IF ls_invoice_numbers_done = '' THEN
        ls_invoice_numbers_done := ls_invoice_number;
      ELSE
        ls_invoice_numbers_done := ls_invoice_numbers_done || ';' || ls_invoice_number;
      END IF;
      FETCH NEXT FROM stock_alloc_stocks INTO ls_purchase_contno, ls_purchase_split, ls_invoice_number, ls_invoice_type, ls_invoice_client;
    END LOOP;
    CLOSE stock_alloc_stocks;
    RETURN ln_total_stock;
  END;$func$;

  -- Fix ls_reserve_client local var: char(16) -> varchar(25)
  -- ' for ' prefix (5 chars) + 16-char client code = 21 chars; varchar(25) gives safe headroom
  CREATE OR REPLACE FUNCTION public.sp_tooltip_sopex_valuation_costs_test(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    reservelist CURSOR FOR
      SELECT reserves.reserve, reserves.amount, reserves.currency, reserves.unit,
             reserves.client, currency.ratetype
        FROM reserves, currency
        WHERE reserves.currency = currency.code
          AND reserves.contno = as_contno AND reserves.split = as_split;
    ls_return_text char(2048);
    ls_reserve_line char(64);
    ls_reserve_type char(4);
    ln_reserve_amount numeric(10,2);
    ln_reserve_amount_base numeric(10,2);
    ln_reserve_amount_base_total numeric(10,2);
    ls_reserve_currency char(3);
    ls_reserve_currency_ratetype char(1);
    ls_reserve_priceunit char(4);
    ls_reserve_client varchar(25);
    ln_contract_fx_rate numeric(10,6);
    ln_fx_conversion_rate numeric(10,6);
    ls_fx_conversion_rate char(8);
    ln_contract_currency char(3);
    ls_base_currency char(3);
  BEGIN
    SELECT params.base_currency INTO ls_base_currency FROM params;
    SELECT sub_contracts.currency, sub_contracts.est_fx_rate
      INTO ln_contract_currency, ln_contract_fx_rate
      FROM sub_contracts
      WHERE sub_contracts.contno = as_contno AND sub_contracts.split = as_split;
    ls_return_text := E'\n';
    ln_reserve_amount_base_total := 0;
    OPEN reservelist;
    FETCH NEXT FROM reservelist INTO ls_reserve_type, ln_reserve_amount, ls_reserve_currency, ls_reserve_priceunit, ls_reserve_client, ls_reserve_currency_ratetype;
    WHILE FOUND LOOP
      IF ls_reserve_currency <> ls_base_currency THEN
        IF ls_reserve_currency = ln_contract_currency THEN
          SELECT sp_get_outright_or_averaged_fixes_fx_rate(as_contno, as_split) INTO ln_fx_conversion_rate;
          IF ln_fx_conversion_rate IS NULL THEN
            SELECT sp_datedfxrate(ls_reserve_currency, ls_base_currency, current_date, current_date)
              INTO ln_fx_conversion_rate;
          END IF;
        ELSE
          SELECT sp_datedfxrate(ls_reserve_currency, ls_base_currency, current_date, current_date)
            INTO ln_fx_conversion_rate;
        END IF;
      ELSE
        ln_fx_conversion_rate := 1.0;
      END IF;
      ls_fx_conversion_rate := ln_fx_conversion_rate::text;
      IF left(ls_fx_conversion_rate, 1) = '.' THEN
        ls_fx_conversion_rate := '0' || ls_fx_conversion_rate;
      END IF;
      IF ls_reserve_client IS NULL THEN
        ls_reserve_client := '';
      ELSE
        ls_reserve_client := ' for ' || ls_reserve_client;
      END IF;
      IF ls_reserve_currency_ratetype = 'D' THEN
        ln_reserve_amount_base := ln_reserve_amount / ln_fx_conversion_rate;
      ELSE
        ln_reserve_amount_base := ln_reserve_amount * ln_fx_conversion_rate;
      END IF;
      ls_reserve_line := trunc(ln_reserve_amount_base, 2)::text || ' ' || ls_base_currency || '/' || ls_reserve_priceunit
        || '    (' || ls_reserve_type || ' ' || trunc(ln_reserve_amount, 2)::text || ' ' || ls_reserve_currency
        || '/' || ls_reserve_priceunit || ls_reserve_client || ' @ ' || ls_fx_conversion_rate || ')';
      ls_return_text := ls_return_text || ls_reserve_line || E'\n';
      ln_reserve_amount_base_total := ln_reserve_amount_base_total + ln_reserve_amount_base;
      FETCH NEXT FROM reservelist INTO ls_reserve_type, ln_reserve_amount, ls_reserve_currency, ls_reserve_priceunit, ls_reserve_client, ls_reserve_currency_ratetype;
    END LOOP;
    ls_return_text := ls_return_text || '-------' || E'\n' || trunc(ln_reserve_amount_base_total, 2)::text || ' ' || ls_base_currency || '/' || ls_reserve_priceunit || E'\n';
    CLOSE reservelist;
    RETURN ls_return_text;
  END;$func$;

  INSERT INTO schema_migrations (script_name) VALUES ('0008_fix_function_type_declarations');
  RAISE NOTICE 'Migration 0008 applied successfully.';
END;
$$;
