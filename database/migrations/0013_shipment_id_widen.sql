-- Migration 0013: Widen shipment_id from char(10) to char(20)
-- Affects: 25 tables (shipment_id) + warrantinvoice.shipmentid,
--          19 FK constraints (fk_WarrantInvoice_shipment eliminated as mixed-case duplicate),
--          3 views, 4 functions

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0013_shipment_id_widen') THEN
    RAISE NOTICE 'Migration 0013 already applied, skipping.';
    RETURN;
  END IF;

  -- ============================================================
  -- STEP 1: Drop dependent views
  -- ============================================================
  DROP VIEW IF EXISTS public.hist_shipment CASCADE;
  DROP VIEW IF EXISTS public.phys_stocks CASCADE;
  DROP VIEW IF EXISTS public.powerbi_caja_stocks_by_warehouse CASCADE;

  -- ============================================================
  -- STEP 2: Drop FK constraints referencing shipment_id
  -- ============================================================
  ALTER TABLE public.alloc_shipment              DROP CONSTRAINT IF EXISTS fk_alloc_shipment_shipment;
  ALTER TABLE public.containers                  DROP CONSTRAINT IF EXISTS fk_containers_shipment;
  ALTER TABLE public.delivery_order              DROP CONSTRAINT IF EXISTS fk_delorder_shipment;
  ALTER TABLE public.expenses_detail             DROP CONSTRAINT IF EXISTS fk_expenses_detail_shipment;
  ALTER TABLE public.fixes                       DROP CONSTRAINT IF EXISTS fk_fixes_shipment;
  ALTER TABLE public.fixes_shipments             DROP CONSTRAINT IF EXISTS fk_fixes_shipments_shipment;
  ALTER TABLE public.invoice                     DROP CONSTRAINT IF EXISTS fk_invoice_shipment;
  ALTER TABLE public.invoice_allocation          DROP CONSTRAINT IF EXISTS fk_invalloc_shipment;
  ALTER TABLE public.invoice_document_details    DROP CONSTRAINT IF EXISTS "shipment_id";
  ALTER TABLE public.provisional_invoice_archive DROP CONSTRAINT IF EXISTS fk_invoice_shipment;
  ALTER TABLE public.sample_master               DROP CONSTRAINT IF EXISTS fk_sample_shipment;
  ALTER TABLE public.sample_request_detail       DROP CONSTRAINT IF EXISTS fk_sample_request_detail_shipment;
  ALTER TABLE public.shipment_contracts          DROP CONSTRAINT IF EXISTS fk_shipconts_shipment;
  ALTER TABLE public.shipment_letters            DROP CONSTRAINT IF EXISTS fk_shipment_letters_shipment;
  ALTER TABLE public.stocks                      DROP CONSTRAINT IF EXISTS fk_stock_shipment;
  ALTER TABLE public.terminal_hedges             DROP CONSTRAINT IF EXISTS fk_terminal_hedges_shipment;
  ALTER TABLE public.treasury_hedges             DROP CONSTRAINT IF EXISTS fk_treasury_hedges_shipment;
  -- warrantinvoice: drop both (mixed-case duplicate eliminated, lowercase re-added below)
  ALTER TABLE public.warrantinvoice              DROP CONSTRAINT IF EXISTS "fk_WarrantInvoice_shipment";
  ALTER TABLE public.warrantinvoice              DROP CONSTRAINT IF EXISTS fk_warrantinvoice_shipment;

  -- ============================================================
  -- STEP 3: Widen shipment_id in 25 tables + warrantinvoice.shipmentid
  -- ============================================================
  ALTER TABLE public.alloc_shipment                         ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.containers                             ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.delivery_order                         ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.doc_logging                            ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.expenses_detail                        ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.fixes                                  ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.fixes_shipments                        ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.invoice                                ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.invoice_allocation                     ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.invoice_allocation_history             ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.invoice_document_details               ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.master_contracts_history               ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.provisional_invoice_archive            ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.sample_master                          ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.sample_request_detail                  ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.shipment                               ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.shipment_contracts                     ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.shipment_history                       ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.shipment_letters                       ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.shipment_notes                         ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.stocks                                 ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.stocks_history                         ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.sub_contracts_history                  ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.terminal_hedges                        ALTER COLUMN shipment_id TYPE char(20);
  ALTER TABLE public.treasury_hedges                        ALTER COLUMN shipment_id TYPE char(20);
  -- warrantinvoice stores shipment_id under the column name shipmentid
  ALTER TABLE public.warrantinvoice                         ALTER COLUMN shipmentid TYPE char(20);

  -- ============================================================
  -- STEP 4: Re-add FK constraints (18; fk_WarrantInvoice_shipment eliminated)
  -- ============================================================
  ALTER TABLE public.alloc_shipment
    ADD CONSTRAINT fk_alloc_shipment_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.containers
    ADD CONSTRAINT fk_containers_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.delivery_order
    ADD CONSTRAINT fk_delorder_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.expenses_detail
    ADD CONSTRAINT fk_expenses_detail_shipment
      FOREIGN KEY (shipment_id, contno, split) REFERENCES public.shipment_contracts(shipment_id, contno, split);

  ALTER TABLE public.fixes
    ADD CONSTRAINT fk_fixes_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.fixes_shipments
    ADD CONSTRAINT fk_fixes_shipments_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.invoice
    ADD CONSTRAINT fk_invoice_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.invoice_allocation
    ADD CONSTRAINT fk_invalloc_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.invoice_document_details
    ADD CONSTRAINT shipment_id
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.provisional_invoice_archive
    ADD CONSTRAINT fk_invoice_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.sample_master
    ADD CONSTRAINT fk_sample_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.sample_request_detail
    ADD CONSTRAINT fk_sample_request_detail_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.shipment_contracts
    ADD CONSTRAINT fk_shipconts_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.shipment_letters
    ADD CONSTRAINT fk_shipment_letters_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.stocks
    ADD CONSTRAINT fk_stock_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.terminal_hedges
    ADD CONSTRAINT fk_terminal_hedges_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.treasury_hedges
    ADD CONSTRAINT fk_treasury_hedges_shipment
      FOREIGN KEY (shipment_id) REFERENCES public.shipment(shipment_id);

  ALTER TABLE public.warrantinvoice
    ADD CONSTRAINT fk_warrantinvoice_shipment
      FOREIGN KEY (shipmentid) REFERENCES public.shipment(shipment_id);

  -- ============================================================
  -- STEP 5: Update function local variables char(10) → char(20)
  -- ============================================================

  CREATE OR REPLACE FUNCTION public.sp_contract_shipment_eta_info(as_contno character, as_split character, as_mode character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    shipmentlist CURSOR FOR
      SELECT shipment.shipment_id, to_char(shipment.eta, 'DD/MM/YYYY'),
             cast(shipment_contracts.quantity AS integer)::text,
             unit.name_plural, shipment.destination, location.name,
             country.code, country.name
        FROM shipment
          LEFT OUTER JOIN location ON shipment.destination = location.code
          LEFT OUTER JOIN country ON location.country = country.code,
          shipment_contracts, sub_contracts, unit
        WHERE shipment.shipment_id = shipment_contracts.shipment_id
          AND shipment_contracts.contno = sub_contracts.contno
          AND shipment_contracts.split = sub_contracts.split
          AND sub_contracts.quantunit = unit.code
          AND shipment_contracts.contno = as_contno
          AND shipment_contracts.split = as_split
        ORDER BY shipment.eta ASC;
    ls_shipment_eta_list char(512);
    ls_shipment_eta_line char(64);
    ls_eta char(10);
    ls_quantity char(10);
    ls_unit char(32);
    ls_location_code char(4);
    ls_location_name char(32);
    ls_country_code char(4);
    ls_country_name char(32);
    li_shipment_id char(20);
    li_shipments integer;
  BEGIN
    ls_shipment_eta_list := '';
    OPEN shipmentlist;
    FETCH NEXT FROM shipmentlist INTO li_shipment_id, ls_eta, ls_quantity, ls_unit, ls_location_code, ls_location_name, ls_country_code, ls_country_name;
    IF ls_eta IS NULL OR ls_eta = '' THEN
      ls_eta := 'NO ETA ENTERED';
    END IF;
    IF ls_location_code IS NULL OR ls_location_code = '' THEN
      ls_eta := 'NO DEST ENTERED';
    END IF;
    WHILE FOUND LOOP
      IF as_mode = 'S' THEN
        ls_shipment_eta_line := 'ETA ' || ls_eta || ' to ' || ls_location_code || ', ' || ls_country_code || ' (' || ls_quantity || 'x' || ls_unit || ')';
        SELECT count(shipment.shipment_id) INTO li_shipments
          FROM shipment, shipment_contracts
          WHERE shipment.shipment_id = shipment_contracts.shipment_id
            AND shipment_contracts.contno = as_contno
            AND shipment_contracts.split = as_split;
        IF li_shipments > 1 THEN
          ls_shipment_eta_line := ls_shipment_eta_line || '*';
        END IF;
        ls_shipment_eta_list := ls_shipment_eta_line;
        EXIT;
      ELSE
        IF ls_shipment_eta_list <> '' THEN
          ls_shipment_eta_list := ls_shipment_eta_list || E'\n\n';
        ELSE
          ls_shipment_eta_list := ls_shipment_eta_list || E'\n';
        END IF;
        ls_shipment_eta_list := ls_shipment_eta_list || 'Shipment ' || li_shipment_id || ' ETA ' || ls_eta || ' (' || ls_quantity || 'x' || ls_unit || ')';
        IF ls_location_name IS NOT NULL THEN
          ls_shipment_eta_list := ls_shipment_eta_list || ' to ' || ls_location_name;
          IF ls_country_name IS NOT NULL THEN
            ls_shipment_eta_list := ls_shipment_eta_list || ', ' || ls_country_name;
          END IF;
        END IF;
        FETCH NEXT FROM shipmentlist INTO li_shipment_id, ls_eta, ls_quantity, ls_unit, ls_location_code, ls_location_name, ls_country_code, ls_country_name;
      END IF;
    END LOOP;
    CLOSE shipmentlist;
    RETURN ls_shipment_eta_list;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_contract_shipment_etd_info(as_contno character, as_split character, as_mode character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    shipmentlist CURSOR FOR
      SELECT shipment.shipment_id, to_char(shipment.etd, 'DD/MM/YYYY')
        FROM shipment, shipment_contracts
        WHERE shipment.shipment_id = shipment_contracts.shipment_id
          AND shipment_contracts.contno = as_contno
          AND shipment_contracts.split = as_split
        ORDER BY shipment.etd ASC;
    ls_shipment_etd_list char(512);
    ls_shipment_etd_line char(64);
    ls_etd char(10);
    li_shipment_id char(20);
    li_shipments integer;
  BEGIN
    ls_shipment_etd_list := '';
    OPEN shipmentlist;
    FETCH NEXT FROM shipmentlist INTO li_shipment_id, ls_etd;
    WHILE FOUND LOOP
      IF as_mode = 'S' THEN
        ls_shipment_etd_line := 'ETD ' || ls_etd;
        SELECT count(shipment.shipment_id) INTO li_shipments
          FROM shipment, shipment_contracts
          WHERE shipment.shipment_id = shipment_contracts.shipment_id
            AND shipment_contracts.contno = as_contno
            AND shipment_contracts.split = as_split;
        IF li_shipments > 1 THEN
          ls_shipment_etd_line := ls_shipment_etd_line || '*';
        END IF;
        ls_shipment_etd_list := ls_shipment_etd_line;
        EXIT;
      ELSE
        ls_shipment_etd_list := ls_shipment_etd_list || E'\n' || 'Shipment ' || li_shipment_id || ' ETD ' || ls_etd || E'\n';
        FETCH NEXT FROM shipmentlist INTO li_shipment_id, ls_etd;
      END IF;
    END LOOP;
    CLOSE shipmentlist;
    RETURN ls_shipment_etd_list;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_contract_shipment_eudr_info(as_contno character, as_split character, as_eudr_flag character, as_eudr_date_harvest character, as_mode character)
   RETURNS character varying
   LANGUAGE plpgsql
  AS $func$DECLARE
    shipmentlist CURSOR FOR
      SELECT shipment.shipment_id, shipment.eudr_shipment_flag,
             shipment.step_eudr_docs_requested, shipment.step_eudr_info_received,
             shipment.step_eudr_risk_analysis_ok, shipment.step_eudr_risk_analysis_ok_userid,
             to_char(shipment.step_eudr_risk_analysis_ok_histdate, 'DD/MM/YYYY'),
             shipment.step_eudr_risk_analysis_not_ok
        FROM shipment, shipment_contracts
        WHERE shipment.shipment_id = shipment_contracts.shipment_id
          AND shipment_contracts.contno = as_contno
          AND shipment_contracts.split = as_split
        ORDER BY shipment.shipment_id ASC;
    ls_return_eudr_text varchar(256);
    ls_shipment_id char(20);
    ls_shipment_eudr_flag char(1);
    ld_shipment_eudr_risk_analysis_requested date;
    ld_shipment_eudr_risk_analysis_received date;
    ld_shipment_eudr_risk_analysis_ok date;
    ld_shipment_eudr_risk_analysis_ok_user char(16);
    ld_shipment_eudr_risk_analysis_ok_histdate char(10);
    ld_shipment_eudr_risk_analysis_not_ok date;
    ls_risk_processed char(1);
    ls_risk_analysis_rejected char(1);
    li_shipment_counter integer;
  BEGIN
    IF as_mode = 'TEXT' THEN
      IF as_eudr_flag = 'N' THEN
        ls_return_eudr_text := 'BLK;';
      ELSE
        ls_risk_processed := 'N';
        ls_risk_analysis_rejected := 'N';
        li_shipment_counter := 0;
        ls_return_eudr_text := 'EUDR: YES - ' || as_eudr_date_harvest || E'\n\n';
        OPEN shipmentlist;
        FETCH NEXT FROM shipmentlist INTO ls_shipment_id, ls_shipment_eudr_flag,
          ld_shipment_eudr_risk_analysis_requested, ld_shipment_eudr_risk_analysis_received,
          ld_shipment_eudr_risk_analysis_ok, ld_shipment_eudr_risk_analysis_ok_user,
          ld_shipment_eudr_risk_analysis_ok_histdate, ld_shipment_eudr_risk_analysis_not_ok;
        WHILE FOUND LOOP
          IF ld_shipment_eudr_risk_analysis_ok IS NOT NULL THEN
            ls_risk_processed := 'Y';
            ls_risk_analysis_rejected := 'N';
            ls_return_eudr_text := ls_return_eudr_text || ls_shipment_id || ': Risk Analysis validated by ' || ld_shipment_eudr_risk_analysis_ok_user || ' on ' || ld_shipment_eudr_risk_analysis_ok_histdate || E'\n';
          ELSE
            IF ld_shipment_eudr_risk_analysis_not_ok IS NOT NULL THEN
              ls_risk_processed := 'Y';
              ls_risk_analysis_rejected := 'Y';
              ls_return_eudr_text := ls_return_eudr_text || ls_shipment_id || ': Risk Analysis rejected.' || E'\n';
            ELSE
              ls_risk_processed := 'N';
              ls_return_eudr_text := ls_return_eudr_text || ls_shipment_id || ': Risk Analysis not validated' || E'\n';
            END IF;
          END IF;
          li_shipment_counter := li_shipment_counter + 1;
          FETCH NEXT FROM shipmentlist INTO ls_shipment_id, ls_shipment_eudr_flag,
            ld_shipment_eudr_risk_analysis_requested, ld_shipment_eudr_risk_analysis_received,
            ld_shipment_eudr_risk_analysis_ok, ld_shipment_eudr_risk_analysis_ok_user,
            ld_shipment_eudr_risk_analysis_ok_histdate, ld_shipment_eudr_risk_analysis_not_ok;
        END LOOP;
        CLOSE shipmentlist;
        IF li_shipment_counter = 0 THEN
          ls_return_eudr_text := 'BLK;' || ls_return_eudr_text;
        ELSE
          IF ls_risk_processed = 'Y' THEN
            IF ls_risk_analysis_rejected = 'Y' THEN
              ls_return_eudr_text := 'RED;' || ls_return_eudr_text;
            ELSE
              ls_return_eudr_text := 'GRN;' || ls_return_eudr_text;
            END IF;
          ELSE
            ls_return_eudr_text := 'RED;' || ls_return_eudr_text;
          END IF;
        END IF;
      END IF;
    ELSE
      ls_return_eudr_text := '';
      IF as_eudr_flag <> 'N' THEN
        OPEN shipmentlist;
        FETCH NEXT FROM shipmentlist INTO ls_shipment_id, ls_shipment_eudr_flag,
          ld_shipment_eudr_risk_analysis_requested, ld_shipment_eudr_risk_analysis_received,
          ld_shipment_eudr_risk_analysis_ok, ld_shipment_eudr_risk_analysis_ok_user,
          ld_shipment_eudr_risk_analysis_ok_histdate, ld_shipment_eudr_risk_analysis_not_ok;
        WHILE FOUND LOOP
          IF ld_shipment_eudr_risk_analysis_ok IS NOT NULL THEN
            IF ls_return_eudr_text = '' THEN
              ls_return_eudr_text := 'CMPL';
            ELSE
              ls_return_eudr_text := ls_return_eudr_text || ';' || 'CMPL';
            END IF;
          ELSIF ld_shipment_eudr_risk_analysis_not_ok IS NOT NULL THEN
            IF ls_return_eudr_text = '' THEN
              ls_return_eudr_text := 'RJCT';
            ELSE
              ls_return_eudr_text := ls_return_eudr_text || ';' || 'RJCT';
            END IF;
          ELSIF ld_shipment_eudr_risk_analysis_received IS NOT NULL THEN
            IF ls_return_eudr_text = '' THEN
              ls_return_eudr_text := 'RCVD';
            ELSE
              ls_return_eudr_text := ls_return_eudr_text || ';' || 'RCVD';
            END IF;
          ELSIF ld_shipment_eudr_risk_analysis_requested IS NOT NULL THEN
            IF ls_return_eudr_text = '' THEN
              ls_return_eudr_text := 'REQD';
            ELSE
              ls_return_eudr_text := ls_return_eudr_text || ';' || 'REQD';
            END IF;
          ELSE
            IF ls_return_eudr_text = '' THEN
              ls_return_eudr_text := '-';
            ELSE
              ls_return_eudr_text := ls_return_eudr_text || ';' || '-';
            END IF;
          END IF;
          FETCH NEXT FROM shipmentlist INTO ls_shipment_id, ls_shipment_eudr_flag,
            ld_shipment_eudr_risk_analysis_requested, ld_shipment_eudr_risk_analysis_received,
            ld_shipment_eudr_risk_analysis_ok, ld_shipment_eudr_risk_analysis_ok_user,
            ld_shipment_eudr_risk_analysis_ok_histdate, ld_shipment_eudr_risk_analysis_not_ok;
        END LOOP;
        CLOSE shipmentlist;
      END IF;
    END IF;
    RETURN ls_return_eudr_text;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_list_marks(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
      ls_all_marks char(256);
      ls_marks char(256);
      ls_shipment_id char(20);
      ls_purch_contno char(20);
      ls_purch_split char(3);
      purchase_conts CURSOR FOR
        SELECT s_c_2.contno, s_c_2.split
          FROM shipment_contracts AS s_c_1, shipment_contracts AS s_c_2
          WHERE s_c_1.shipment_id = s_c_2.shipment_id
            AND s_c_2.contno LIKE 'P%'
            AND s_c_1.contno = as_contno
            AND s_c_1.split = as_split;
    BEGIN
      OPEN purchase_conts;
      FETCH NEXT FROM purchase_conts INTO ls_purch_contno, ls_purch_split;
      WHILE FOUND LOOP
        SELECT shipment.marks INTO ls_marks
          FROM shipment, shipment_contracts
          WHERE shipment.shipment_id = shipment_contracts.shipment_id
            AND shipment_contracts.contno = ls_purch_contno
            AND shipment_contracts.split = ls_purch_split
            AND shipment.shipment_id LIKE 'P%';
        IF ls_marks IS NULL THEN
          ls_marks := '';
        END IF;
        ls_all_marks := ls_all_marks || ls_marks || E'\r\n';
        FETCH NEXT FROM purchase_conts INTO ls_purch_contno, ls_purch_split;
      END LOOP;
      CLOSE purchase_conts;
      RETURN ls_all_marks;
    END;$func$;

  INSERT INTO schema_migrations (script_name) VALUES ('0013_shipment_id_widen');
  RAISE NOTICE 'Migration 0013 applied successfully.';
END;
$$;

-- ============================================================
-- Recreate 3 dependent views
-- ============================================================

CREATE OR REPLACE VIEW public.hist_shipment AS
 SELECT shipment_history.hist_date,
    shipment_history.hist_time,
    shipment_history.hist_type,
    shipment_history.hist_user,
    shipment_history.shipment_id,
    shipment_history.status,
    NULL::character(10) AS contno,
    NULL::character(3) AS split,
    NULL::integer AS stock_id,
    shipment_history.port_of_origin,
    shipment_history.etd,
    shipment_history.vessel,
    shipment_history.vessel_confirmed,
    shipment_history.modality,
    shipment_history.shipping_line,
    shipment_history.container_number,
    shipment_history.shipping_rate,
    shipment_history.shipping_rate_currency,
    shipment_history.shipping_rate_unit,
    shipment_history.insurance_rate,
    shipment_history.bl_number,
    shipment_history.bl_date,
    shipment_history.eta,
    shipment_history.destination,
    shipment_history.doc_received,
    shipment_history.sample_number,
    shipment_history.sample_received,
    shipment_history.sample_released,
    shipment_history.marks,
    shipment_history.custom_entry,
    shipment_history.custom_release,
    shipment_history.fda_release,
    shipment_history.warehouse,
    shipment_history.bank,
    shipment_history.bank_pledge_reference,
    shipment_history.warrant_number,
    shipment_history.warrant_weight,
    shipment_history.warrant_weight_unit,
    shipment_history.draft_number,
    shipment_history.do_out,
    shipment_history.notes,
    shipment_history.goods_lying
   FROM public.shipment_history
UNION ALL
 SELECT stocks_history.hist_date,
    stocks_history.hist_time,
    stocks_history.hist_type,
    stocks_history.hist_user,
    stocks_history.shipment_id,
    NULL::character(1) AS status,
    stocks_history.contno,
    stocks_history.split,
    stocks_history.stock_id,
    NULL::character(4) AS port_of_origin,
    NULL::date AS etd,
    NULL::character varying(128) AS vessel,
    NULL::character(1) AS vessel_confirmed,
    NULL::character(7) AS modality,
    NULL::character(20) AS shipping_line,
    NULL::character(20) AS container_number,
    NULL::numeric AS shipping_rate,
    NULL::character(3) AS shipping_rate_currency,
    NULL::character(4) AS shipping_rate_unit,
    NULL::numeric AS insurance_rate,
    NULL::character(20) AS bl_number,
    NULL::date AS bl_date,
    NULL::date AS eta,
    NULL::character(4) AS destination,
    NULL::date AS doc_received,
    NULL::character(10) AS sample_number,
    NULL::date AS sample_received,
    NULL::date AS sample_released,
    NULL::character varying(1024) AS marks,
    NULL::date AS custom_entry,
    NULL::date AS custom_release,
    NULL::date AS fda_release,
    NULL::character(8) AS warehouse,
    NULL::character(8) AS bank,
    NULL::character(10) AS bank_pledge_reference,
    NULL::character varying(128) AS warrant_number,
    NULL::numeric AS warrant_weight,
    NULL::character(4) AS warrant_weight_unit,
    NULL::character varying(128) AS draft_number,
    NULL::date AS do_out,
    NULL::character varying(1024) AS notes,
    NULL::character(2) AS goods_lying
   FROM public.stocks_history;

CREATE OR REPLACE VIEW public.phys_stocks AS
 SELECT a.contno,
    a.description,
    a.split,
    a.quantunit,
    s.stock_id,
    s.quantity,
    s.quantity_unit,
    s.commodity,
    s.commodity_type,
    s.origin,
    s.quality,
    s.shipment_id,
    s.status,
    s.warehouse,
    s.allocation_reference,
    public.sp_convert_qty(s.quantity, s.quantity_unit, a.quantunit) AS stock_qty,
    public.sp_convert_qty(s.quantity, s.quantity_unit, p.base_unit) AS stock_base_qty
   FROM (public.sub_contracts a
     LEFT JOIN public.stocks s ON (((a.contno = s.contno) AND (a.split = s.split)))),
    public.params p;

CREATE OR REPLACE VIEW public.powerbi_caja_stocks_by_warehouse AS
 SELECT stocks.contno,
    stocks.split,
    stocks.stock_id,
    public.sp_convert_qty(stocks.quantity, stocks.quantity_unit, params.base_unit) AS net_wgt,
    'MT'::text AS quantity_unit,
        CASE stocks.status
            WHEN 'A'::bpchar THEN 'Afloat'::text
            WHEN 'L'::bpchar THEN 'Landed'::text
            WHEN 'I'::bpchar THEN 'ISF Filled'::text
            WHEN 'G'::bpchar THEN 'Warehouse in origin'::text
            WHEN 'T'::bpchar THEN 'Sample approved/SI Sent'::text
            WHEN 'S'::bpchar THEN 'Sample approved'::text
            WHEN 'D'::bpchar THEN 'Pending Roaster Approval'::text
            WHEN 'R'::bpchar THEN 'Release waiting for B/L'::text
            WHEN 'F'::bpchar THEN 'Pending Final Fixation'::text
            WHEN 'B'::bpchar THEN 'Tolling'::text
            WHEN 'P'::bpchar THEN 'Warehouse Pending'::text
            WHEN 'W'::bpchar THEN 'Warehouse'::text
            WHEN 'N'::bpchar THEN 'No Sample'::text
            WHEN 'C'::bpchar THEN 'Completed'::text
            WHEN 'O'::bpchar THEN 'Other'::text
            ELSE NULL::text
        END AS stock_status,
    stocks.company,
    stocks.pcentre,
    stocks.commodity,
    stocks.commodity_type,
    stocks.origin,
    stocks.quality,
    stocks.allocation_reference,
    public.sp_allocation_check_if_only_stock(stocks.allocation_reference) AS stock_allocation,
    stocks.original_allocation_reference AS original_allocation,
    stocks.shipment_id,
    shipment.eta,
    shipment.arrived_instore_date,
    stocks.current_location,
    stocks.final_landing AS stock_in_date,
    stocks.status,
    stocks.original_client AS supplier,
    master_contracts.priceterm AS price_terms,
    ( SELECT params_1.base_unit
           FROM public.params params_1) AS base_unit,
    client.longname
   FROM ((public.stocks
     LEFT JOIN public.client ON ((stocks.warehouse = client.code)))
     LEFT JOIN public.shipment ON ((stocks.shipment_id = shipment.shipment_id))),
    public.sub_contracts,
    public.master_contracts,
    public.params
  WHERE ((sub_contracts.split = stocks.split) AND (sub_contracts.contno = stocks.contno) AND (sub_contracts.contno = master_contracts.contno) AND (public.sp_convert_qty(stocks.quantity, stocks.quantity_unit, params.base_unit) > (0)::numeric))
  ORDER BY client.longname, stocks.contno, stocks.split, stocks.stock_id;
