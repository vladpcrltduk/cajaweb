-- Migration 0010: Widen contno from char(10) to char(20) across all tables, views, and functions
-- Affects: 71 tables (contno column), 8 non-standard columns, 35 FK constraints, 51 views, 19 functions

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0010_contno_widen') THEN
    RAISE NOTICE 'Migration 0010 already applied, skipping.';
    RETURN;
  END IF;

  -- ============================================================
  -- STEP 1: Drop all 51 dependent views
  -- ============================================================
  DROP VIEW IF EXISTS public.alloc_contracts_view CASCADE;
  DROP VIEW IF EXISTS public.allocated_purch_quantity CASCADE;
  DROP VIEW IF EXISTS public.allocated_purch_quantity_extended CASCADE;
  DROP VIEW IF EXISTS public.bal_anal_view CASCADE;
  DROP VIEW IF EXISTS public.clt_accbals_view CASCADE;
  DROP VIEW IF EXISTS public.clt_accbals_view_no_pcentre CASCADE;
  DROP VIEW IF EXISTS public.dimensionvalue CASCADE;
  DROP VIEW IF EXISTS public.expenses_month_end_reports_view CASCADE;
  DROP VIEW IF EXISTS public.expenses_view CASCADE;
  DROP VIEW IF EXISTS public.final_invoice_details CASCADE;
  DROP VIEW IF EXISTS public.floating_stock_view CASCADE;
  DROP VIEW IF EXISTS public.forecast_report_outbooked_p_expenses_view CASCADE;
  DROP VIEW IF EXISTS public.fx_hedged_view CASCADE;
  DROP VIEW IF EXISTS public.fx_hedges_valn CASCADE;
  DROP VIEW IF EXISTS public.hist_shipment CASCADE;
  DROP VIEW IF EXISTS public.invoice_charges_view CASCADE;
  DROP VIEW IF EXISTS public.invoice_charges_view2 CASCADE;
  DROP VIEW IF EXISTS public.invoice_contracts_view CASCADE;
  DROP VIEW IF EXISTS public.invoice_details CASCADE;
  DROP VIEW IF EXISTS public.invoice_details_2_copy_of_original_view CASCADE;
  DROP VIEW IF EXISTS public.invoices_stocks_view CASCADE;
  DROP VIEW IF EXISTS public.leds_view CASCADE;
  DROP VIEW IF EXISTS public.nom_accbals_view CASCADE;
  DROP VIEW IF EXISTS public.phys_alloc CASCADE;
  DROP VIEW IF EXISTS public.phys_avail CASCADE;
  DROP VIEW IF EXISTS public.phys_avail3 CASCADE;
  DROP VIEW IF EXISTS public.phys_avail_valn_sopex CASCADE;
  DROP VIEW IF EXISTS public.phys_fixes CASCADE;
  DROP VIEW IF EXISTS public.phys_fxhedge_breakdown CASCADE;
  DROP VIEW IF EXISTS public.phys_open_view CASCADE;
  DROP VIEW IF EXISTS public.phys_org_contval CASCADE;
  DROP VIEW IF EXISTS public.phys_pricing CASCADE;
  DROP VIEW IF EXISTS public.phys_pricing2 CASCADE;
  DROP VIEW IF EXISTS public.phys_pricing3 CASCADE;
  DROP VIEW IF EXISTS public.phys_pricing_riskposn CASCADE;
  DROP VIEW IF EXISTS public.phys_pricing_valn_sopex CASCADE;
  DROP VIEW IF EXISTS public.phys_pricing_valn_sopex_full_report CASCADE;
  DROP VIEW IF EXISTS public.phys_splits_fxhedges CASCADE;
  DROP VIEW IF EXISTS public.phys_splits_termhedges CASCADE;
  DROP VIEW IF EXISTS public.phys_stocks CASCADE;
  DROP VIEW IF EXISTS public.phys_termhedge_breakdown CASCADE;
  DROP VIEW IF EXISTS public.phys_valn_view2 CASCADE;
  DROP VIEW IF EXISTS public.phys_valn_view3 CASCADE;
  DROP VIEW IF EXISTS public.physcont_view CASCADE;
  DROP VIEW IF EXISTS public.physical_long_short_position_view CASCADE;
  DROP VIEW IF EXISTS public.physical_trading_browser_underlying_level1_view CASCADE;
  DROP VIEW IF EXISTS public.physical_trading_browser_underlying_level2_view CASCADE;
  DROP VIEW IF EXISTS public.powerbi_caja_forex_deals CASCADE;
  DROP VIEW IF EXISTS public.powerbi_caja_stocks_by_warehouse CASCADE;
  DROP VIEW IF EXISTS public.powerbi_invoiced_contracts CASCADE;
  DROP VIEW IF EXISTS public.term_hedges_valn CASCADE;

  -- ============================================================
  -- STEP 2: Drop all FK constraints referencing contno columns
  -- ============================================================
  ALTER TABLE public.allocated_containers DROP CONSTRAINT IF EXISTS fk_allocated_containers_sub_contracts;
  ALTER TABLE public.allocated_contracts DROP CONSTRAINT IF EXISTS fk_alloccont_cont;
  ALTER TABLE public.bean_reception DROP CONSTRAINT IF EXISTS fk_sub_contracts_bean_reception;
  ALTER TABLE public.booking DROP CONSTRAINT IF EXISTS fk_booking_subcontracts;
  ALTER TABLE public.collateral_contracts DROP CONSTRAINT IF EXISTS fk_collateral_contracts_sub_contracts;
  ALTER TABLE public.containers DROP CONSTRAINT IF EXISTS fk_containers_sub_contracts;
  ALTER TABLE public.contract_auction_details DROP CONSTRAINT IF EXISTS fk_contract_auction_details_sub_contracts;
  ALTER TABLE public.contract_sample_link DROP CONSTRAINT IF EXISTS contno;
  ALTER TABLE public.contracts_deposits DROP CONSTRAINT IF EXISTS fk_contracts_deposits_sub_contracts;
  ALTER TABLE public.delivery_order DROP CONSTRAINT IF EXISTS fk_delorder_salescontno;
  ALTER TABLE public.delivery_order_lines DROP CONSTRAINT IF EXISTS fk_delordline_purchcontract;
  ALTER TABLE public.expenses_breakdown DROP CONSTRAINT IF EXISTS fk_expbdown_contract;
  ALTER TABLE public.expenses_detail DROP CONSTRAINT IF EXISTS fk_expenses_detail_sub_contracts;
  ALTER TABLE public.expenses_detail DROP CONSTRAINT IF EXISTS fk_expenses_sub_contracts_2;
  ALTER TABLE public.final_invoice_details_1 DROP CONSTRAINT IF EXISTS fk_fininvdets1_contract;
  ALTER TABLE public.fixes DROP CONSTRAINT IF EXISTS fk_fixes_contract;
  ALTER TABLE public.forex_hedges DROP CONSTRAINT IF EXISTS sub_contracts;
  ALTER TABLE public.invoice DROP CONSTRAINT IF EXISTS fk_invoice_sales_contract;
  ALTER TABLE public.invoice_details_1 DROP CONSTRAINT IF EXISTS fk_invdets1_contract;
  ALTER TABLE public.invoice_stocks_tariffs DROP CONSTRAINT IF EXISTS fk_tariffs_sub_contracts;
  ALTER TABLE public.land_transport_contracts DROP CONSTRAINT IF EXISTS fk_land_transport_contracts_sub_contracts;
  ALTER TABLE public.logistics_invoice_reminders DROP CONSTRAINT IF EXISTS fk_logistics_invoice_reminders_contract;
  ALTER TABLE public.provisional_invoice_archive DROP CONSTRAINT IF EXISTS fk_invoice_sales_contract;
  ALTER TABLE public.release_note_contracts DROP CONSTRAINT IF EXISTS fk_release_note_contracts_purch_sub_conts;
  ALTER TABLE public.release_note_contracts DROP CONSTRAINT IF EXISTS fk_release_note_contracts_sales_sub_conts;
  ALTER TABLE public.reserves DROP CONSTRAINT IF EXISTS fk_reserves_contract;
  ALTER TABLE public.sample_request_detail DROP CONSTRAINT IF EXISTS fk_sample_request_detail_sub_contracts;
  ALTER TABLE public.shipment DROP CONSTRAINT IF EXISTS fk_shipment_sales_contract;
  ALTER TABLE public.shipment_contracts DROP CONSTRAINT IF EXISTS fk_shipconts_contract;
  ALTER TABLE public.stocks DROP CONSTRAINT IF EXISTS fk_stock_contract;
  ALTER TABLE public.sub_contracts DROP CONSTRAINT IF EXISTS fk_subconts_contno;
  ALTER TABLE public.supply_chain_financing DROP CONSTRAINT IF EXISTS fk_supply_chain_financing_sub_contracts;
  ALTER TABLE public.terminal_hedges DROP CONSTRAINT IF EXISTS fk_thedges_contno;
  ALTER TABLE public.treasury_hedges DROP CONSTRAINT IF EXISTS sub_contracts;
  -- warrantinvoice has both mixed-case and lowercase variants; drop both, re-add only lowercase
  ALTER TABLE public.warrantinvoice DROP CONSTRAINT IF EXISTS "fk_WarrantInvoice_contract";
  ALTER TABLE public.warrantinvoice DROP CONSTRAINT IF EXISTS fk_warrantinvoice_contract;

  -- ============================================================
  -- STEP 3: Widen contno columns in all 71 tables
  -- ============================================================
  ALTER TABLE public.accsummary ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.allocated_containers ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.allocated_contracts ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.allocation_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.allocation_reallocation_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.bean_reception ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.bean_reception_deleted ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.bean_reception_group ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.bean_reception_group_deleted ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.booking ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.collateral_contracts ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.containers ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.contract_auction_details ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.contract_log ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.contract_sample_link ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.contracts_deposits ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.doc_logging ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.expenses_breakdown ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.expenses_detail ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.final_invoice_details_1 ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.final_invoice_details_2 ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.final_invoice_stocks ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.fixes ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.fixes_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.fixes_shipments ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.forex_hedges ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.forex_hedges_invoices_link ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.historical_report_snapshots_02_daily_valuation ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.historical_report_snapshots_05_alloc_pl ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.imported_contracts ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.invoice_charges ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.invoice_containers ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.invoice_details_1 ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.invoice_details_2 ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.invoice_return_stocks ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.invoice_stocks ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.invoice_stocks_tariffs ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.journal_sheet_detail ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.land_transport_contracts ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.logistics_invoice_reminders ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.master_contracts ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.master_contracts_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.phys_contract_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.phys_position_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.processjobs_stock ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.provisional_invoice_details_2_archive ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.reserve_temporary_payment ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.reserves ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.reserves_crdr ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.reserves_expenses ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.reserves_ledger_posting ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.reserves_ledger_posting_deleted ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.sample_request_detail ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.shipment_contracts ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.stock_quantity_adjustments ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.stocks ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.stocks_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.stocks_movement_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.sub_contracts ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.sub_contracts_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.supply_chain_financing ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.terminal_hedges ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.terminal_hedges_history ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.terminal_hedges_history_deleted ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.treasury_hedges ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.warrant ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.warrantarchive ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.warrantarchivelme ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.warrantinvoice ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.warrantlme ALTER COLUMN contno TYPE char(20);
  ALTER TABLE public.weight_note_detail ALTER COLUMN contno TYPE char(20);

  -- ============================================================
  -- STEP 4: Widen 8 non-standard columns that reference contno
  -- ============================================================
  ALTER TABLE public.delivery_order ALTER COLUMN scontno TYPE char(20);
  ALTER TABLE public.delivery_order_lines ALTER COLUMN pcontno TYPE char(20);
  ALTER TABLE public.invoice ALTER COLUMN sales_contract TYPE char(20);
  ALTER TABLE public.invoice_stocks_tariffs ALTER COLUMN sales_contno TYPE char(20);
  ALTER TABLE public.provisional_invoice_archive ALTER COLUMN sales_contract TYPE char(20);
  ALTER TABLE public.release_note_contracts ALTER COLUMN purch_contno TYPE char(20);
  ALTER TABLE public.release_note_contracts ALTER COLUMN sales_contno TYPE char(20);
  ALTER TABLE public.shipment ALTER COLUMN sales_contract TYPE char(20);

  -- ============================================================
  -- STEP 5: Re-add FK constraints (lowercase names only)
  -- ============================================================
  ALTER TABLE public.sub_contracts
    ADD CONSTRAINT fk_subconts_contno
      FOREIGN KEY (contno) REFERENCES public.master_contracts(contno) ON UPDATE CASCADE;

  ALTER TABLE public.allocated_containers
    ADD CONSTRAINT fk_allocated_containers_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.allocated_contracts
    ADD CONSTRAINT fk_alloccont_cont
      FOREIGN KEY (split, contno) REFERENCES public.sub_contracts(split, contno);

  ALTER TABLE public.bean_reception
    ADD CONSTRAINT fk_sub_contracts_bean_reception
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.booking
    ADD CONSTRAINT fk_booking_subcontracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.collateral_contracts
    ADD CONSTRAINT fk_collateral_contracts_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.containers
    ADD CONSTRAINT fk_containers_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.contract_auction_details
    ADD CONSTRAINT fk_contract_auction_details_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.contract_sample_link
    ADD CONSTRAINT contno
      FOREIGN KEY (contno) REFERENCES public.master_contracts(contno);

  ALTER TABLE public.contracts_deposits
    ADD CONSTRAINT fk_contracts_deposits_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.delivery_order
    ADD CONSTRAINT fk_delorder_salescontno
      FOREIGN KEY (scontno) REFERENCES public.master_contracts(contno);

  ALTER TABLE public.delivery_order_lines
    ADD CONSTRAINT fk_delordline_purchcontract
      FOREIGN KEY (pcontno, psplit) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.expenses_breakdown
    ADD CONSTRAINT fk_expbdown_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.expenses_detail
    ADD CONSTRAINT fk_expenses_detail_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.expenses_detail
    ADD CONSTRAINT fk_expenses_sub_contracts_2
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.final_invoice_details_1
    ADD CONSTRAINT fk_fininvdets1_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.fixes
    ADD CONSTRAINT fk_fixes_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.forex_hedges
    ADD CONSTRAINT sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.invoice
    ADD CONSTRAINT fk_invoice_sales_contract
      FOREIGN KEY (sales_contract) REFERENCES public.master_contracts(contno);

  ALTER TABLE public.invoice_details_1
    ADD CONSTRAINT fk_invdets1_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.invoice_stocks_tariffs
    ADD CONSTRAINT fk_tariffs_sub_contracts
      FOREIGN KEY (sales_contno, sales_split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.land_transport_contracts
    ADD CONSTRAINT fk_land_transport_contracts_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.logistics_invoice_reminders
    ADD CONSTRAINT fk_logistics_invoice_reminders_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.provisional_invoice_archive
    ADD CONSTRAINT fk_invoice_sales_contract
      FOREIGN KEY (sales_contract) REFERENCES public.master_contracts(contno);

  ALTER TABLE public.release_note_contracts
    ADD CONSTRAINT fk_release_note_contracts_purch_sub_conts
      FOREIGN KEY (purch_contno, purch_split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.release_note_contracts
    ADD CONSTRAINT fk_release_note_contracts_sales_sub_conts
      FOREIGN KEY (sales_contno, sales_split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.reserves
    ADD CONSTRAINT fk_reserves_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.sample_request_detail
    ADD CONSTRAINT fk_sample_request_detail_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.shipment
    ADD CONSTRAINT fk_shipment_sales_contract
      FOREIGN KEY (sales_contract) REFERENCES public.master_contracts(contno);

  ALTER TABLE public.shipment_contracts
    ADD CONSTRAINT fk_shipconts_contract
      FOREIGN KEY (split, contno) REFERENCES public.sub_contracts(split, contno);

  ALTER TABLE public.stocks
    ADD CONSTRAINT fk_stock_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split) ON DELETE CASCADE;

  ALTER TABLE public.supply_chain_financing
    ADD CONSTRAINT fk_supply_chain_financing_sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split) ON DELETE CASCADE;

  ALTER TABLE public.terminal_hedges
    ADD CONSTRAINT fk_thedges_contno
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.treasury_hedges
    ADD CONSTRAINT sub_contracts
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split);

  ALTER TABLE public.warrantinvoice
    ADD CONSTRAINT fk_warrantinvoice_contract
      FOREIGN KEY (contno, split) REFERENCES public.sub_contracts(contno, split) ON DELETE CASCADE;

  -- ============================================================
  -- STEP 6: Update 19 functions — widen contno local variables
  -- ============================================================

  CREATE OR REPLACE FUNCTION public.sp_allocation_check_if_balanced(as_allocation_reference character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    alloccontslist CURSOR FOR
      SELECT allocated_contracts.contno, allocated_contracts.split,
             allocated_contracts.quantity, master_contracts.contract_type
        FROM allocated_contracts, sub_contracts, master_contracts
        WHERE allocated_contracts.contno = sub_contracts.contno
          AND allocated_contracts.split = sub_contracts.split
          AND sub_contracts.contno = master_contracts.contno
          AND allocated_contracts.allocation_reference = as_allocation_reference;
    ln_total_purchase_allocation_quantity numeric(16,4);
    ln_total_sales_allocation_quantity numeric(16,4);
    ls_contno char(20);
    ls_split char(3);
    ln_allocated_quantity numeric(16,4);
    ls_contract_type char(1);
    ls_allocation_reference char(10);
    ls_return_flag char(1);
  BEGIN
    ln_total_purchase_allocation_quantity := 0;
    ln_total_sales_allocation_quantity := 0;
    OPEN alloccontslist;
    FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split, ln_allocated_quantity, ls_contract_type;
    WHILE FOUND LOOP
      IF ls_contract_type = 'P' THEN
        ln_total_purchase_allocation_quantity := ln_total_purchase_allocation_quantity + ln_allocated_quantity;
      ELSE
        ln_total_sales_allocation_quantity := ln_total_sales_allocation_quantity + ln_allocated_quantity;
      END IF;
      FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split, ln_allocated_quantity, ls_contract_type;
    END LOOP;
    CLOSE alloccontslist;
    IF ln_total_purchase_allocation_quantity = ln_total_sales_allocation_quantity THEN
      ls_return_flag := 'Y';
    ELSE
      ls_return_flag := 'N';
    END IF;
    RETURN ls_return_flag;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_check_if_fully_fixed(as_allocation_reference character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    alloccontslist CURSOR FOR
      SELECT allocated_contracts.contno, allocated_contracts.split
        FROM allocated_contracts
        WHERE allocated_contracts.allocation_reference = as_allocation_reference;
    ls_return_flag char(1);
    ls_is_this_a_stock_allocation char(1);
    ln_unfixed numeric(16,4);
    ls_contno char(20);
    ls_split char(3);
  BEGIN
    ln_unfixed := 0;
    ls_return_flag := 'Y';
    SELECT sp_allocation_check_if_only_stock(as_allocation_reference) INTO ls_is_this_a_stock_allocation;
    IF ls_is_this_a_stock_allocation = 'Y' THEN
      ls_return_flag := 'N';
    END IF;
    OPEN alloccontslist;
    FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split;
    WHILE FOUND LOOP
      SELECT phys_avail.unfixed INTO ln_unfixed
        FROM phys_avail
        WHERE phys_avail.contno = ls_contno AND phys_avail.split = ls_split;
      IF ln_unfixed > 0 THEN
        ls_return_flag := 'N';
      END IF;
      FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split;
    END LOOP;
    CLOSE alloccontslist;
    RETURN ls_return_flag;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_contracts_list_by_sales(as_allocation_reference character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    alloccontslist CURSOR FOR
      SELECT master_contracts.contract_type, allocated_contracts.contno, allocated_contracts.split
        FROM allocated_contracts, master_contracts
        WHERE allocated_contracts.contno = master_contracts.contno
          AND allocated_contracts.allocation_reference = as_allocation_reference
        ORDER BY master_contracts.contract_type DESC;
    ls_return_list char(512);
    ls_contno char(20);
    ls_split char(3);
    ls_contract_type char(1);
    li_count integer;
  BEGIN
    li_count := 0;
    ls_return_list := '';
    OPEN alloccontslist;
    FETCH NEXT FROM alloccontslist INTO ls_contract_type, ls_contno, ls_split;
    WHILE FOUND LOOP
      ls_return_list := ls_return_list || ls_contract_type || '-' || ls_contno || '-' || ls_split || ',';
      li_count := li_count + 1;
      FETCH NEXT FROM alloccontslist INTO ls_contract_type, ls_contno, ls_split;
    END LOOP;
    CLOSE alloccontslist;
    WHILE li_count < 11 LOOP
      ls_return_list := ls_return_list || ' -      -   ,';
      li_count := li_count + 1;
    END LOOP;
    RETURN ls_return_list;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_construct_sales_invoice_tariff_text(as_invoice_number character, as_invoice_client character, as_mode character)
   RETURNS character varying
   LANGUAGE plpgsql
  AS $func$DECLARE
    invoice_tariffs CURSOR FOR
      SELECT invoice_stocks_tariffs.contno, invoice_stocks_tariffs.split,
             invoice_stocks_tariffs.quantity_assigned, unit.name,
             invoice_stocks_tariffs.tariff_total_amount,
             invoice_stocks_tariffs.tariff_interest_rate,
             invoice_stocks_tariffs.days_financed,
             origin.longname, commodity_type.name
        FROM invoice_stocks_tariffs, stocks, origin, commodity_type, unit
        WHERE invoice_stocks_tariffs.contno = stocks.contno
          AND invoice_stocks_tariffs.split = stocks.split
          AND invoice_stocks_tariffs.stock_id = stocks.stock_id
          AND stocks.origin = origin.code
          AND stocks.commodity_type = commodity_type.code
          AND stocks.quantity_unit = unit.code
          AND invoice_stocks_tariffs.invoice_type = 'S'
          AND invoice_stocks_tariffs.client = as_invoice_client
          AND invoice_stocks_tariffs.invoice_number = as_invoice_number
        ORDER BY invoice_stocks_tariffs.contno ASC, invoice_stocks_tariffs.split ASC;
    ls_retval varchar(1024);
    ls_contno char(20);
    ls_split char(3);
    ls_quantity_unit char(32);
    ls_origin_name char(64);
    ls_commodtype_name char(32);
    ldc_quantity_assigned numeric(16,2);
    ldc_tariff_total_amount numeric(16,2);
    ldc_tariff_interest_rate numeric(16,2);
    ldc_days_financed numeric(16);
  BEGIN
    ls_retval := '';
    OPEN invoice_tariffs;
    FETCH NEXT FROM invoice_tariffs INTO ls_contno, ls_split, ldc_quantity_assigned, ls_quantity_unit, ldc_tariff_total_amount, ldc_tariff_interest_rate, ldc_days_financed, ls_origin_name, ls_commodtype_name;
    WHILE FOUND LOOP
      IF ls_retval <> '' THEN
        ls_retval := ls_retval || E'\n\n';
      END IF;
      IF as_mode = 'TEXT' THEN
        ls_retval := ls_retval || 'US Tariff for Purchases ';
      ELSE
        ls_retval := ls_retval || '$ ' || sp_format_number_with_commas(ldc_tariff_total_amount);
      END IF;
      FETCH NEXT FROM invoice_tariffs INTO ls_contno, ls_split, ldc_quantity_assigned, ls_quantity_unit, ldc_tariff_total_amount, ldc_tariff_interest_rate, ldc_days_financed, ls_origin_name, ls_commodtype_name;
    END LOOP;
    CLOSE invoice_tariffs;
    RETURN ls_retval;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_contno_are_all_allocations_fully_fixed(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    alloccontslist CURSOR FOR
      SELECT ac_1.contno, ac_1.split
        FROM allocated_contracts AS ac_1, allocated_contracts AS ac_2
        WHERE ac_2.allocation_reference = ac_1.allocation_reference
          AND ac_2.contno = as_contno AND ac_2.split = as_split;
    ls_return_flag char(1);
    ln_unfixed numeric(16,4);
    ls_other_contno char(20);
    ls_other_split char(3);
  BEGIN
    ls_return_flag := 'Y';
    OPEN alloccontslist;
    FETCH NEXT FROM alloccontslist INTO ls_other_contno, ls_other_split;
    WHILE FOUND LOOP
      SELECT phys_avail.unfixed INTO ln_unfixed
        FROM phys_avail
        WHERE phys_avail.contno = ls_other_contno AND phys_avail.split = ls_other_split;
      IF ln_unfixed > 0 THEN
        ls_return_flag := 'N';
      END IF;
      FETCH NEXT FROM alloccontslist INTO ls_other_contno, ls_other_split;
    END LOOP;
    CLOSE alloccontslist;
    RETURN ls_return_flag;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_contno_fully_allocated_fixed(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    alloccontslist CURSOR FOR
      SELECT ac_1.contno, ac_1.split
        FROM allocated_contracts AS ac_1, allocated_contracts AS ac_2
        WHERE ac_2.allocation_reference = ac_1.allocation_reference
          AND ac_2.contno = as_contno AND ac_2.split = as_split
          AND ac_1.contno <> as_contno;
    ls_return_flag char(4);
    ls_return_flag2 char(4);
    ls_unfixed_flag char(2);
    ls_unallocated_flag char(2);
    ln_unfixed numeric(16,4);
    ln_unallocated numeric(16,4);
    ls_other_contno char(20);
    ls_other_split char(3);
  BEGIN
    ls_return_flag := '';
    ls_return_flag2 := '';
    ls_unfixed_flag := '';
    ls_unallocated_flag := '';
    SELECT phys_avail.unfixed, phys_avail.unallocated INTO ln_unfixed, ln_unallocated
      FROM phys_avail
      WHERE phys_avail.contno = as_contno AND phys_avail.split = as_split;
    IF ln_unfixed = 0 THEN
      ls_unfixed_flag := 'FF';
    ELSE
      ls_unfixed_flag := 'UF';
    END IF;
    IF ln_unallocated = 0 THEN
      ls_unallocated_flag := 'FA';
    ELSE
      ls_unallocated_flag := 'UA';
    END IF;
    ls_return_flag := ls_unfixed_flag || ls_unallocated_flag;
    OPEN alloccontslist;
    FETCH NEXT FROM alloccontslist INTO ls_other_contno, ls_other_split;
    WHILE FOUND LOOP
      SELECT phys_avail.unfixed, phys_avail.unallocated INTO ln_unfixed, ln_unallocated
        FROM phys_avail
        WHERE phys_avail.contno = ls_other_contno AND phys_avail.split = ls_other_split;
      IF ln_unfixed = 0 THEN
        ls_unfixed_flag := 'FF';
      ELSE
        ls_unfixed_flag := 'UF';
      END IF;
      IF ln_unallocated = 0 THEN
        ls_unallocated_flag := 'FA';
      ELSE
        ls_unallocated_flag := 'UA';
      END IF;
      ls_return_flag2 := ls_unfixed_flag || ls_unallocated_flag;
      IF ls_return_flag = 'FFFA' AND ls_return_flag2 = 'FFFA' THEN
        ls_return_flag := 'FFFA';
      END IF;
      IF ls_return_flag = 'FFFA' AND ls_return_flag2 <> 'FFFA' THEN
        ls_return_flag := ls_return_flag2;
      END IF;
      FETCH NEXT FROM alloccontslist INTO ls_other_contno, ls_other_split;
    END LOOP;
    CLOSE alloccontslist;
    RETURN ls_return_flag;
  END;$func$;

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
    ls_contno char(20);
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

  CREATE OR REPLACE FUNCTION public.sp_is_allocation_fully_closed(as_allocation_reference character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    ls_return_flag char(1);
    ls_uninvoiced_flag char(1);
    ls_contno char(20);
    ls_split char(3);
    ln_invoiced numeric(16,4);
    ln_allocated numeric(16,4);
    ln_uninvoiced numeric(16,4);
    alloccontslist CURSOR FOR
      SELECT allocated_contracts.contno, allocated_contracts.split
        FROM allocated_contracts
        WHERE allocated_contracts.allocation_reference = as_allocation_reference;
  BEGIN
    ls_return_flag := '';
    ls_uninvoiced_flag := 'N';
    OPEN alloccontslist;
    FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split;
    WHILE FOUND LOOP
      SELECT sum(invoice_details_2.positional_quantity) INTO ln_invoiced
        FROM invoice_details_2
        WHERE invoice_details_2.contno = ls_contno
          AND invoice_details_2.split = ls_split
          AND invoice_details_2.allocation_reference = as_allocation_reference;
      SELECT allocated_contracts.quantity INTO ln_allocated
        FROM allocated_contracts
        WHERE allocated_contracts.contno = ls_contno
          AND allocated_contracts.split = ls_split
          AND allocated_contracts.allocation_reference = as_allocation_reference;
      IF ln_invoiced IS NULL THEN
        ln_invoiced := 0;
      END IF;
      ln_uninvoiced := ln_allocated - ln_invoiced;
      IF ln_uninvoiced > 0 THEN
        ls_uninvoiced_flag := 'Y';
      END IF;
      FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split;
    END LOOP;
    CLOSE alloccontslist;
    IF ls_uninvoiced_flag = 'Y' THEN
      ls_return_flag := 'N';
    ELSE
      ls_return_flag := 'Y';
    END IF;
    RETURN ls_return_flag;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_is_allocation_fully_fixed(as_allocation_reference character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    ls_return_flag char(1);
    ls_unfixed_flag char(1);
    ls_contno char(20);
    ls_split char(3);
    ln_unfixed numeric(16,4);
    alloccontslist CURSOR FOR
      SELECT allocated_contracts.contno, allocated_contracts.split
        FROM allocated_contracts
        WHERE allocated_contracts.allocation_reference = as_allocation_reference;
  BEGIN
    ls_return_flag := '';
    ls_unfixed_flag := 'N';
    OPEN alloccontslist;
    FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split;
    WHILE FOUND LOOP
      SELECT phys_avail.unfixed INTO ln_unfixed
        FROM phys_avail
        WHERE phys_avail.contno = ls_contno AND phys_avail.split = ls_split;
      IF ln_unfixed > 0 THEN
        ls_unfixed_flag := 'Y';
      END IF;
      FETCH NEXT FROM alloccontslist INTO ls_contno, ls_split;
    END LOOP;
    CLOSE alloccontslist;
    IF ls_unfixed_flag = 'Y' THEN
      ls_return_flag := 'N';
    ELSE
      ls_return_flag := 'Y';
    END IF;
    RETURN ls_return_flag;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_list_allocated_contracts_details(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    allocation_list CURSOR FOR
      SELECT allocation_reference
        FROM allocated_contracts
        WHERE contno = as_contno AND split = as_split;
    ls_alloc_ref char(10);
    ls_contno char(20);
    ls_split char(3);
    ls_unit_name char(32);
    ln_quantity numeric(16,2);
    ls_line_result char(128);
    ls_result char(2048);
    allocated_line_details CURSOR FOR
      SELECT allocated_contracts.contno, allocated_contracts.split,
             allocated_contracts.quantity, unit.name_plural
        FROM allocated_contracts, sub_contracts, unit
        WHERE allocated_contracts.contno = sub_contracts.contno
          AND allocated_contracts.split = sub_contracts.split
          AND sub_contracts.quantunit = unit.code
          AND allocated_contracts.allocation_reference = ls_alloc_ref
          AND allocated_contracts.contno <> as_contno
        ORDER BY allocated_contracts.contno ASC, allocated_contracts.split ASC,
                 allocated_contracts.contno ASC, allocated_contracts.allocation_reference ASC;
  BEGIN
    ls_result := E'\nContracts\n\n';
    OPEN allocation_list;
    FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    WHILE FOUND LOOP
      OPEN allocated_line_details;
      FETCH NEXT FROM allocated_line_details INTO ls_contno, ls_split, ln_quantity, ls_unit_name;
      WHILE FOUND LOOP
        ls_line_result := concat('  -', ls_contno, '-', ls_split, ' for ', ln_quantity::text, ' ', ls_unit_name, ', Alloc Ref: ', ls_alloc_ref, '.', E'          \n\n');
        ls_result := ls_result || ls_line_result;
        FETCH NEXT FROM allocated_line_details INTO ls_contno, ls_split, ln_quantity, ls_unit_name;
      END LOOP;
      CLOSE allocated_line_details;
      FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    END LOOP;
    CLOSE allocation_list;
    IF ls_result = E'\nContracts\n\n' THEN
      ls_result := E'\nNo allocated contracts      \n \n';
    ELSE
      ls_result := ls_result || E' \n';
    END IF;
    RETURN ls_result;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_list_allocated_contracts_details_fixed(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    allocation_list CURSOR FOR
      SELECT allocation_reference
        FROM allocated_contracts
        WHERE contno = as_contno AND split = as_split;
    ls_alloc_ref char(10);
    ls_contno char(20);
    ls_split char(3);
    ls_unit_name char(32);
    ln_quantity numeric(16,2);
    ls_line_result char(128);
    ls_result char(2048);
    allocated_line_details CURSOR FOR
      SELECT allocated_contracts.contno, allocated_contracts.split, allocated_contracts.quantity, unit.name_plural
        FROM allocation, allocated_contracts, sub_contracts, unit
        WHERE allocation.allocation_completed = 'N'
          AND allocation.allocation_reference = allocated_contracts.allocation_reference
          AND sp_allocation_check_if_fully_fixed(allocation.allocation_reference) = 'Y'
          AND sp_allocation_check_if_only_stock(allocation.allocation_reference) = 'N'
          AND allocated_contracts.contno = sub_contracts.contno
          AND allocated_contracts.split = sub_contracts.split
          AND sub_contracts.quantunit = unit.code
          AND allocated_contracts.allocation_reference = ls_alloc_ref
          AND allocated_contracts.contno <> as_contno
        ORDER BY allocated_contracts.contno ASC, allocated_contracts.split ASC,
                 allocated_contracts.contno ASC, allocated_contracts.allocation_reference ASC;
  BEGIN
    ls_result := E'\nAllocated Contracts:\n\n';
    OPEN allocation_list;
    FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    WHILE FOUND LOOP
      OPEN allocated_line_details;
      FETCH NEXT FROM allocated_line_details INTO ls_contno, ls_split, ln_quantity, ls_unit_name;
      WHILE FOUND LOOP
        ls_line_result := concat('  -', ls_contno, '-', ls_split, ' for ', ln_quantity::text, ' ', ls_unit_name, ', Alloc Ref: ', ls_alloc_ref, '.', E'          \n\n');
        ls_result := ls_result || ls_line_result;
        FETCH NEXT FROM allocated_line_details INTO ls_contno, ls_split, ln_quantity, ls_unit_name;
      END LOOP;
      CLOSE allocated_line_details;
      FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    END LOOP;
    CLOSE allocation_list;
    IF ls_result = E'\nAllocated Contracts:\n\n' THEN
      ls_result := E'\nNo allocated contracts      \n \n';
    ELSE
      ls_result := ls_result || E' \n';
    END IF;
    RETURN ls_result;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_list_allocated_contracts_details_fixed_invq(as_contno character, as_split character, as_quant_or_stock character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$
  DECLARE
    "ls_alloc_ref" char(10);
    "ls_contno" char(20);
    "ls_split" char(3);
    "ls_contract_type" char(1);
    "ln_quantity" numeric(16,4);
    "ln_total_quantity" numeric(16,4);
    "allocated_line_details" CURSOR FOR select "allocated_contracts"."contno","allocated_contracts"."split","allocated_contracts"."allocation_reference","master_contracts"."contract_type" from "allocation","allocated_contracts","master_contracts" where "allocation"."allocation_reference" = "allocated_contracts"."allocation_reference" and "allocation"."allocation_completed" = 'N' and "sp_allocation_check_if_fully_fixed"("allocated_contracts"."allocation_reference") = 'Y' and "sp_allocation_check_if_only_stock"("allocated_contracts"."allocation_reference") = 'N' and "allocated_contracts"."contno" = "as_contno" and "allocated_contracts"."split" = "as_split" and "allocated_contracts"."contno" = "master_contracts"."contno" order by "allocated_contracts"."contno" asc,"allocated_contracts"."split" asc;
  BEGIN
  "ln_total_quantity" := 0;
    open "allocated_line_details";
    FETCH NEXT FROM "allocated_line_details" INTO "ls_contno","ls_split","ls_alloc_ref","ls_contract_type";
    while FOUND loop
      if "as_quant_or_stock" = 'Q' then
        select COALESCE("sum"("positional_quantity"),0) into "ln_quantity" from "invoice_details_2" where "invoice_details_2"."contno" = "ls_contno" and "invoice_details_2"."split" = "ls_split" and "invoice_details_2"."allocation_reference" = "ls_alloc_ref";
      else
        select COALESCE("sum"("stocks"."quantity"),0) into "ln_quantity" from "stocks" where "stocks"."contno" = "ls_contno" and "stocks"."split" = "ls_split" and "stocks"."allocation_reference" = "ls_alloc_ref";
      end if;
      "ln_total_quantity" := "ln_total_quantity"+"ln_quantity";
    FETCH NEXT FROM "allocated_line_details" INTO "ls_contno","ls_split","ls_alloc_ref","ls_contract_type";
    end loop;
    close "allocated_line_details";
    return("ln_total_quantity");
  END;
  $func$;

  CREATE OR REPLACE FUNCTION public.sp_list_allocated_contracts_details_unfixed(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    allocation_list CURSOR FOR
      SELECT allocation_reference
        FROM allocated_contracts
        WHERE contno = as_contno AND split = as_split;
    ls_alloc_ref char(10);
    ls_contno char(20);
    ls_split char(3);
    ls_unit_name char(32);
    ln_quantity numeric(16,2);
    ls_line_result char(128);
    ls_result char(2048);
    allocated_line_details CURSOR FOR
      SELECT allocated_contracts.contno, allocated_contracts.split, allocated_contracts.quantity, unit.name_plural
        FROM allocation, allocated_contracts, sub_contracts, unit
        WHERE allocation.allocation_completed = 'N'
          AND allocation.allocation_reference = allocated_contracts.allocation_reference
          AND sp_allocation_check_if_fully_fixed(allocation.allocation_reference) = 'N'
          AND sp_allocation_check_if_only_stock(allocation.allocation_reference) = 'N'
          AND allocated_contracts.contno = sub_contracts.contno
          AND allocated_contracts.split = sub_contracts.split
          AND sub_contracts.quantunit = unit.code
          AND allocated_contracts.allocation_reference = ls_alloc_ref
          AND allocated_contracts.contno <> as_contno
        ORDER BY allocated_contracts.contno ASC, allocated_contracts.split ASC,
                 allocated_contracts.contno ASC, allocated_contracts.allocation_reference ASC;
  BEGIN
    ls_result := E'\nAllocated Contracts:\n\n';
    OPEN allocation_list;
    FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    WHILE FOUND LOOP
      OPEN allocated_line_details;
      FETCH NEXT FROM allocated_line_details INTO ls_contno, ls_split, ln_quantity, ls_unit_name;
      WHILE FOUND LOOP
        ls_line_result := concat('  -', ls_contno, '-', ls_split, ' for ', ln_quantity::text, ' ', ls_unit_name, ', Alloc Ref: ', ls_alloc_ref, '.', E'          \n\n');
        ls_result := ls_result || ls_line_result;
        FETCH NEXT FROM allocated_line_details INTO ls_contno, ls_split, ln_quantity, ls_unit_name;
      END LOOP;
      CLOSE allocated_line_details;
      FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    END LOOP;
    CLOSE allocation_list;
    IF ls_result = E'\nAllocated Contracts:\n\n' THEN
      ls_result := E'\nNo allocated contracts      \n \n';
    ELSE
      ls_result := ls_result || E' \n';
    END IF;
    RETURN ls_result;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_list_allocated_contracts_details_unfixed_invq(as_contno character, as_split character, as_quant_or_stock character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$
  DECLARE
    "ls_alloc_ref" char(10);
    "ls_contno" char(20);
    "ls_split" char(3);
    "ls_contract_type" char(1);
    "ln_quantity" numeric(16,4);
    "ln_total_quantity" numeric(16,4);
    "allocated_line_details" CURSOR FOR select "allocated_contracts"."contno","allocated_contracts"."split","allocated_contracts"."allocation_reference","master_contracts"."contract_type" from "allocation","allocated_contracts","master_contracts" where "allocation"."allocation_reference" = "allocated_contracts"."allocation_reference" and "allocation"."allocation_completed" = 'N' and(("sp_allocation_check_if_fully_fixed"("allocated_contracts"."allocation_reference") = 'N' and "sp_allocation_check_if_only_stock"("allocated_contracts"."allocation_reference") = 'N') or "sp_allocation_check_if_only_stock"("allocated_contracts"."allocation_reference") = 'Y') and "allocated_contracts"."contno" = "as_contno" and "allocated_contracts"."split" = "as_split" and "allocated_contracts"."contno" = "master_contracts"."contno" order by "allocated_contracts"."contno" asc,"allocated_contracts"."split" asc;
  BEGIN
  "ln_total_quantity" := 0;
    open "allocated_line_details";
    FETCH NEXT FROM "allocated_line_details" INTO "ls_contno","ls_split","ls_alloc_ref","ls_contract_type";
    while FOUND loop
      if "as_quant_or_stock" = 'Q' then
        select COALESCE("sum"("positional_quantity"),0) into "ln_quantity" from "invoice_details_2" where "invoice_details_2"."contno" = "ls_contno" and "invoice_details_2"."split" = "ls_split" and "invoice_details_2"."allocation_reference" = "ls_alloc_ref";
      else
        select COALESCE("sum"("stocks"."quantity"),0) into "ln_quantity" from "stocks" where "stocks"."contno" = "ls_contno" and "stocks"."split" = "ls_split" and "stocks"."allocation_reference" = "ls_alloc_ref";
      end if;
      "ln_total_quantity" := "ln_total_quantity"+"ln_quantity";
    FETCH NEXT FROM "allocated_line_details" INTO "ls_contno","ls_split","ls_alloc_ref","ls_contract_type";
    end loop;
    close "allocated_line_details";
    return("ln_total_quantity");
  END;
  $func$;

  CREATE OR REPLACE FUNCTION public.sp_list_marks(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    ls_all_marks char(256);
    ls_marks char(256);
    ls_shipment_id char(10);
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

  CREATE OR REPLACE FUNCTION public.sp_phys_total_alloc_unfixed(as_alloc_ref character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$
  DECLARE
    "ls_contno" char(20);
    "ls_split" char(3);
    "ln_total_unfixed" numeric(16,4);
    "ln_cont_unfixed" numeric(16,4);
    "allocation_list" CURSOR FOR select "contno","split" from "allocated_contracts" where "allocation_reference" = "as_alloc_ref";
  BEGIN
  "ln_total_unfixed" := 0.0;
    open "allocation_list";
    FETCH NEXT FROM "allocation_list" INTO "ls_contno","ls_split";
    while FOUND loop
      select "phys_avail"."unfixed" into "ln_cont_unfixed" from "phys_avail" where "phys_avail"."contno" = "ls_contno" and "phys_avail"."split" = "ls_split";
      "ln_total_unfixed" := "ln_total_unfixed"+"ln_cont_unfixed";
    FETCH NEXT FROM "allocation_list" INTO "ls_contno","ls_split";
    end loop;
    close "allocation_list";
    return "ln_total_unfixed";
  END;
  $func$;

  CREATE OR REPLACE FUNCTION public.sp_sopex_check_sale_is_it_last_stock(as_contno character, as_split character, ai_stockid integer, as_original_purchase_invno character, as_original_purchase_client character, as_original_purchase_invtype character, adc_stock_quantity numeric)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    purchase_invoice_contract_stocks CURSOR FOR
      SELECT stocks.contno,
             stocks.split,
             stocks.stock_id,
             stocks.quantity
        FROM stocks
        WHERE stocks.contno = as_contno
          AND stocks.split = as_split
          AND stocks.original_invoice_number = as_original_purchase_invno
          AND stocks.original_client = as_original_purchase_client
          AND stocks.original_invoice_type = as_original_purchase_invtype
          AND stocks.stock_id <> ai_stockid
          AND stocks.quantity > 0;
    ls_is_this_last_stock_being_sold char(1);
    ls_contno char(20);
    ls_split char(3);
    li_stockid integer;
    ln_stock_quantity numeric(16,4);
    ln_total_stock_quantity numeric(16,4);
    ln_this_stock_quantity numeric(16,4);
  BEGIN
    ls_is_this_last_stock_being_sold := 'N';
    ln_total_stock_quantity := 0;
    OPEN purchase_invoice_contract_stocks;
    FETCH NEXT FROM purchase_invoice_contract_stocks INTO ls_contno, ls_split, li_stockid, ln_stock_quantity;
    WHILE FOUND LOOP
      ln_total_stock_quantity := ln_total_stock_quantity + ln_stock_quantity;
      FETCH NEXT FROM purchase_invoice_contract_stocks INTO ls_contno, ls_split, li_stockid, ln_stock_quantity;
    END LOOP;
    CLOSE purchase_invoice_contract_stocks;
    IF ln_total_stock_quantity > 0 THEN
      ls_is_this_last_stock_being_sold := 'N';
    ELSE
      SELECT stocks.quantity INTO ln_this_stock_quantity
        FROM stocks
        WHERE stocks.contno = as_contno
          AND stocks.split = as_split
          AND stocks.stock_id = ai_stockid;
      IF adc_stock_quantity = ln_this_stock_quantity THEN
        ls_is_this_last_stock_being_sold := 'Y';
      ELSE
        ls_is_this_last_stock_being_sold := 'N';
      END IF;
    END IF;
    RETURN ls_is_this_last_stock_being_sold;
  END;$func$;

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
    ls_purchase_contno char(20);
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

  CREATE OR REPLACE FUNCTION public.sp_tooltip_sopex_allocation_description(as_alloc_ref character, as_stock_allocation character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    allocated_contracts_cur CURSOR FOR
      SELECT allocation.allocation_completed,
             to_char(allocation.allocation_completed_date, 'DD/MM/YYYY') AS completed_date,
             master_contracts.contract_type,
             allocated_contracts.contno,
             cast(trunc(sp_convert_qty(allocated_contracts.quantity, sub_contracts.quantunit, params.base_unit), 3) as numeric(10,3))::text AS tonnage,
             params.base_unit,
             '(' || allocated_contracts.quantity::text || ' ' || sub_contracts.quantunit || ')' AS quantity_in_unit
        FROM master_contracts, sub_contracts, allocation, allocated_contracts, params
        WHERE master_contracts.contno = sub_contracts.contno
          AND allocated_contracts.contno = sub_contracts.contno
          AND allocated_contracts.split = sub_contracts.split
          AND allocated_contracts.allocation_reference = allocation.allocation_reference
          AND allocation.allocation_reference = as_alloc_ref
        ORDER BY master_contracts.contract_type ASC, master_contracts.contno ASC;
    ls_return_text char(2048);
    ls_alloc_completed char(1);
    ls_alloc_completed_date char(10);
    ls_contract_type char(1);
    ls_contno char(20);
    ls_tonnage char(10);
    ls_base_unit char(4);
    ls_quantity_in_unit char(20);
  BEGIN
    ls_return_text := '';
    IF as_stock_allocation = 'Y' THEN
      ls_return_text := 'STOCK Allocation ' || as_alloc_ref || ':' || E'\n\n';
    ELSE
      ls_return_text := 'SALES Allocation ' || as_alloc_ref || ':' || E'\n\n';
    END IF;
    OPEN allocated_contracts_cur;
    FETCH NEXT FROM allocated_contracts_cur INTO ls_alloc_completed, ls_alloc_completed_date, ls_contract_type, ls_contno, ls_tonnage, ls_base_unit, ls_quantity_in_unit;
    WHILE FOUND LOOP
      ls_return_text := ls_return_text || ls_contract_type || ' ' || ls_contno || ' ' || ls_tonnage || ' ' || ls_base_unit || E'\n';
      FETCH NEXT FROM allocated_contracts_cur INTO ls_alloc_completed, ls_alloc_completed_date, ls_contract_type, ls_contno, ls_tonnage, ls_base_unit, ls_quantity_in_unit;
    END LOOP;
    CLOSE allocated_contracts_cur;
    ls_return_text := ls_return_text || '------------------------' || E'\n';
    IF as_stock_allocation = 'N' THEN
      IF ls_alloc_completed = 'N' THEN
        ls_return_text := ls_return_text || 'Allocation Realised: ' || 'NO';
      ELSE
        ls_return_text := ls_return_text || 'Allocation Realised: ' || 'YES, on ' || ls_alloc_completed_date || '.';
      END IF;
    END IF;
    RETURN ls_return_text;
  END;$func$;

  INSERT INTO schema_migrations (script_name) VALUES ('0010_contno_widen');
  RAISE NOTICE 'Migration 0010 applied successfully.';
END;
$$;






CREATE OR REPLACE VIEW public.alloc_contracts_view AS
 SELECT allocated_contracts.allocation_reference,
    sub_contracts.contno,
    sub_contracts.split,
    allocated_contracts.quantity,
    public.sp_convert_qty(allocated_contracts.quantity, sub_contracts.quantunit, params.base_unit) AS allocated_quant_base
   FROM public.allocated_contracts,
    public.sub_contracts,
    public.params
  WHERE ((allocated_contracts.contno = sub_contracts.contno) AND (allocated_contracts.split = sub_contracts.split));




CREATE OR REPLACE VIEW public.allocated_purch_quantity AS
 SELECT pac.allocation_reference AS alloc_ref,
    sac.contno,
    sac.split,
    sac.quantity,
    sc_sales.quantunit AS sales_unit,
    sc_purchases.quantunit AS purch_unit,
    public.sp_convert_qty(sac.quantity, sc_sales.quantunit, sc_purchases.quantunit) AS alloc_quant_purch
   FROM public.allocated_contracts sac,
    public.sub_contracts sc_sales,
    public.allocated_contracts pac,
    public.sub_contracts sc_purchases
  WHERE ((sac.contno = sc_sales.contno) AND (sac.split = sc_sales.split) AND (pac.contno = sc_purchases.contno) AND (pac.split = sc_purchases.split) AND (pac.allocation_reference = sac.allocation_reference) AND (sac.contno ~~ 'S%'::text) AND (pac.contno ~~ 'P%'::text));




CREATE OR REPLACE VIEW public.allocated_purch_quantity_extended AS
 WITH base AS (
         SELECT pac.allocation_reference AS alloc_ref,
            pac.contno AS purch_contno,
            pac.split AS purch_split,
            sac.contno AS sales_contno,
            sac.split AS sales_split,
            sac.quantity AS sales_allocated_quant,
            pac.quantity AS purch_allocated_quant,
            sc_sales.quantunit AS sales_unit,
            sc_purchases.quantunit AS purch_unit,
            public.sp_convert_qty(pac.quantity, sc_purchases.quantunit, params.base_unit) AS alloc_quant_purch_base,
            public.sp_convert_qty(sac.quantity, sc_sales.quantunit, params.base_unit) AS alloc_quant_sales_base,
            COALESCE(( SELECT sum(invoice_details_2.positional_quantity) AS sum
                   FROM public.invoice_details_2,
                    public.invoice,
                    public.invoice_stocks
                  WHERE ((invoice_details_2.contno = sac.contno) AND (invoice_details_2.split = sac.split) AND (invoice_details_2.allocation_reference = pac.allocation_reference) AND (invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client) AND (invoice.invoice_number = invoice_stocks.invoice_number) AND (invoice.invoice_type = invoice_stocks.invoice_type) AND (invoice.client = invoice_stocks.client) AND (invoice_stocks.contno = pac.contno) AND (invoice_stocks.split = pac.split) AND (invoice.posted_ledref IS NOT NULL))), (0)::numeric) AS sales_posted_quant
           FROM ((((public.allocated_contracts sac
             JOIN public.sub_contracts sc_sales ON (((sac.contno = sc_sales.contno) AND (sac.split = sc_sales.split))))
             JOIN public.allocated_contracts pac ON ((pac.allocation_reference = sac.allocation_reference)))
             JOIN public.sub_contracts sc_purchases ON (((pac.contno = sc_purchases.contno) AND (pac.split = sc_purchases.split))))
             CROSS JOIN public.params)
          WHERE ((sac.contno ~~ 'S%'::text) AND (pac.contno ~~ 'P%'::text))
        ), step2 AS (
         SELECT base.alloc_ref,
            base.purch_contno,
            base.purch_split,
            base.sales_contno,
            base.sales_split,
            base.sales_allocated_quant,
            base.purch_allocated_quant,
            base.sales_unit,
            base.purch_unit,
            base.alloc_quant_purch_base,
            base.alloc_quant_sales_base,
            base.sales_posted_quant,
                CASE
                    WHEN (base.alloc_quant_sales_base > base.alloc_quant_purch_base) THEN base.alloc_quant_purch_base
                    ELSE base.alloc_quant_sales_base
                END AS better_alloc_quant_sales_base,
            public.sp_convert_qty(base.sales_posted_quant, base.sales_unit, ( SELECT params.base_unit
                   FROM public.params
                 LIMIT 1)) AS sales_posted_quant_base
           FROM base
        ), step3 AS (
         SELECT step2.alloc_ref,
            step2.purch_contno,
            step2.purch_split,
            step2.sales_contno,
            step2.sales_split,
            step2.sales_allocated_quant,
            step2.purch_allocated_quant,
            step2.sales_unit,
            step2.purch_unit,
            step2.alloc_quant_purch_base,
            step2.alloc_quant_sales_base,
            step2.sales_posted_quant,
            step2.better_alloc_quant_sales_base,
            step2.sales_posted_quant_base,
                CASE
                    WHEN (step2.sales_posted_quant_base > step2.better_alloc_quant_sales_base) THEN (0)::numeric
                    ELSE (step2.better_alloc_quant_sales_base - step2.sales_posted_quant_base)
                END AS sales_unposted_quant_base
           FROM step2
        )
 SELECT alloc_ref,
    purch_contno,
    purch_split,
    sales_contno,
    sales_split,
    sales_allocated_quant,
    purch_allocated_quant,
    sales_unit,
    purch_unit,
    alloc_quant_purch_base,
    alloc_quant_sales_base,
    sales_posted_quant,
    better_alloc_quant_sales_base,
    sales_posted_quant_base,
    sales_unposted_quant_base,
        CASE
            WHEN (sales_unposted_quant_base > better_alloc_quant_sales_base) THEN better_alloc_quant_sales_base
            ELSE sales_unposted_quant_base
        END AS better_sales_unposted_quant_base
   FROM step3;




CREATE OR REPLACE VIEW public.bal_anal_view AS
 WITH base AS (
         SELECT 'NV Group Sopex SA'::text AS database_company,
            accdetail.accperiod,
            accdetail.ledgernum,
            accsummary.leddate AS entry_date,
                CASE
                    WHEN (accdetail.accdetail_final_invoice_number IS NOT NULL) THEN ( SELECT final_invoice.posted_date
                       FROM public.final_invoice
                      WHERE ((final_invoice.final_invoice_number = accdetail.accdetail_final_invoice_number) AND (final_invoice.posted_ledref = accdetail.ledgernum)))
                    WHEN ((accdetail.accdetail_invoice_number IS NOT NULL) AND (accdetail.accdetail_final_invoice_number IS NULL)) THEN ( SELECT invoice.posted_date
                       FROM public.invoice
                      WHERE ((invoice.invoice_number = accdetail.accdetail_invoice_number) AND (invoice.posted_ledref = accdetail.ledgernum)))
                    WHEN (accdetail.accdetail_expense_number IS NOT NULL) THEN ( SELECT expenses_summary.posted_date
                       FROM public.expenses_summary
                      WHERE ((expenses_summary.expense_number = accdetail.accdetail_expense_number) AND (expenses_summary.posted_ledref = accdetail.ledgernum)))
                    ELSE NULL::date
                END AS posted_date_temp,
            accsummary.company,
            COALESCE(
                CASE
                    WHEN (accdetail.accdetail_expense_number IS NOT NULL) THEN ( SELECT expenses_summary.expense_note_type
                       FROM public.expenses_summary
                      WHERE ((expenses_summary.expense_number = accdetail.accdetail_expense_number) AND (expenses_summary.client = accsummary.an_client) AND (expenses_summary.posted_ledref = accdetail.ledgernum)))
                    ELSE NULL::bpchar
                END, 'ALL_JOURNALS'::bpchar) AS temporary_postings_journal,
            accdetail.ledamt AS original_amount,
            accdetail.house_rate,
                CASE
                    WHEN (currency.ratetype = 'M'::bpchar) THEN (accdetail.ledamt * accdetail.house_rate)
                    ELSE (accdetail.ledamt / accdetail.house_rate)
                END AS base_amount,
            accdetail.comments AS description,
            accdetail.accdetail_invoice_number AS invoice_number,
            accdetail.accdetail_final_invoice_number AS final_invoice_number,
            accdetail.accdetail_expense_number AS expense_number,
            accdetail.accdetail_reserves_type AS expense_type,
            accsummary.prov_inv_no AS navision_invoice_number,
            accdetail.accdetail_allocation_reference AS allocation_reference,
            allocation.commodity_type,
            allocation.allocation_completed,
            allocation.allocation_completed_date,
            accdetail.nominal
           FROM (((public.accsummary
             CROSS JOIN public.currency)
             JOIN public.accdetail ON (((accsummary.accperiod = accdetail.accperiod) AND (accsummary.ledgernum = accdetail.ledgernum))))
             LEFT JOIN public.allocation ON ((accdetail.accdetail_allocation_reference = allocation.allocation_reference)))
          WHERE ((accdetail.currency = currency.code) AND (accdetail.accdetail_invoice_flag = ANY (ARRAY['PI'::bpchar, 'PF'::bpchar, 'EXP'::bpchar, 'SI'::bpchar, 'SF'::bpchar])))
        ), with_posted_date AS (
         SELECT base.database_company,
            base.accperiod,
            base.ledgernum,
            base.entry_date,
            base.posted_date_temp,
            base.company,
            base.temporary_postings_journal,
            base.original_amount,
            base.house_rate,
            base.base_amount,
            base.description,
            base.invoice_number,
            base.final_invoice_number,
            base.expense_number,
            base.expense_type,
            base.navision_invoice_number,
            base.allocation_reference,
            base.commodity_type,
            base.allocation_completed,
            base.allocation_completed_date,
            base.nominal,
            COALESCE(base.posted_date_temp, base.entry_date) AS posted_date
           FROM base
        ), with_journal AS (
         SELECT with_posted_date.database_company,
            with_posted_date.accperiod,
            with_posted_date.ledgernum,
            with_posted_date.entry_date,
            with_posted_date.posted_date_temp,
            with_posted_date.company,
            with_posted_date.temporary_postings_journal,
            with_posted_date.original_amount,
            with_posted_date.house_rate,
            with_posted_date.base_amount,
            with_posted_date.description,
            with_posted_date.invoice_number,
            with_posted_date.final_invoice_number,
            with_posted_date.expense_number,
            with_posted_date.expense_type,
            with_posted_date.navision_invoice_number,
            with_posted_date.allocation_reference,
            with_posted_date.commodity_type,
            with_posted_date.allocation_completed,
            with_posted_date.allocation_completed_date,
            with_posted_date.nominal,
            with_posted_date.posted_date,
                CASE
                    WHEN (with_posted_date.temporary_postings_journal = '490'::bpchar) THEN 'Futures'::text
                    ELSE 'Physical'::text
                END AS posting_journal
           FROM with_posted_date
        )
 SELECT with_journal.database_company,
    with_journal.accperiod,
    with_journal.ledgernum,
    with_journal.entry_date,
    with_journal.posted_date_temp,
    with_journal.posted_date,
    with_journal.company,
    '60'::text AS nominal_order_flag,
    with_journal.temporary_postings_journal,
    with_journal.posting_journal,
    with_journal.original_amount,
    with_journal.house_rate,
    with_journal.base_amount,
    with_journal.description,
    with_journal.invoice_number,
    with_journal.final_invoice_number,
    with_journal.expense_number,
    with_journal.expense_type,
    with_journal.navision_invoice_number,
    with_journal.allocation_reference,
    with_journal.commodity_type,
    with_journal.allocation_completed,
    with_journal.allocation_completed_date
   FROM with_journal
  WHERE (with_journal.nominal ~~ '60%'::text)
UNION ALL
 SELECT with_journal.database_company,
    with_journal.accperiod,
    with_journal.ledgernum,
    with_journal.entry_date,
    with_journal.posted_date_temp,
    with_journal.posted_date,
    with_journal.company,
    '70'::text AS nominal_order_flag,
    with_journal.temporary_postings_journal,
    with_journal.posting_journal,
    with_journal.original_amount,
    with_journal.house_rate,
    with_journal.base_amount,
    with_journal.description,
    with_journal.invoice_number,
    with_journal.final_invoice_number,
    with_journal.expense_number,
    with_journal.expense_type,
    with_journal.navision_invoice_number,
    with_journal.allocation_reference,
    with_journal.commodity_type,
    with_journal.allocation_completed,
    with_journal.allocation_completed_date
   FROM with_journal
  WHERE (with_journal.nominal ~~ '70%'::text);




CREATE OR REPLACE VIEW public.clt_accbals_view AS
 SELECT accsummary.company,
    accsummary.pcentre,
    accdetail.client,
    accdetail.currency,
    sum(accdetail.ledamt) AS balance
   FROM public.accsummary,
    public.accdetail
  WHERE ((accsummary.accperiod = accdetail.accperiod) AND (accsummary.ledgernum = accdetail.ledgernum) AND (accdetail.client IS NOT NULL))
  GROUP BY accsummary.company, accsummary.pcentre, accdetail.client, accdetail.currency;




CREATE OR REPLACE VIEW public.clt_accbals_view_no_pcentre AS
 SELECT accsummary.company,
    accdetail.client,
    accdetail.currency,
    sum(accdetail.ledamt) AS balance
   FROM public.accsummary,
    public.accdetail
  WHERE ((accsummary.accperiod = accdetail.accperiod) AND (accsummary.ledgernum = accdetail.ledgernum) AND (accdetail.client IS NOT NULL))
  GROUP BY accsummary.company, accdetail.client, accdetail.currency;




CREATE OR REPLACE VIEW public.dimensionvalue AS
 SELECT master_contracts.company,
    sub_contracts.contno,
    sub_contracts.split,
        CASE
            WHEN (master_contracts.company = '02'::bpchar) THEN
            CASE
                WHEN (master_contracts.contract_type = 'P'::bpchar) THEN ' P CONTRACT'::text
                ELSE 'SALES CTR'::text
            END
            ELSE
            CASE
                WHEN (master_contracts.contract_type = 'P'::bpchar) THEN 'P-CONTRACT'::text
                ELSE 'S-CONTRACT'::text
            END
        END AS dimensioncode,
    sub_contracts.contno AS code,
    (((((((sub_contracts.contno)::text || ' '::text) || (sub_contracts.client)::text) || ' '::text) || (public.sp_convert_qty(sub_contracts.orgunquant, sub_contracts.quantunit, params.base_unit))::numeric(10,2)) || ' MT'::text) || COALESCE((', '::text || (master_contracts.clientref2)::text), ''::text)) AS name
   FROM ((public.master_contracts
     CROSS JOIN public.params)
     JOIN public.sub_contracts ON ((master_contracts.contno = sub_contracts.contno)));




CREATE OR REPLACE VIEW public.expenses_month_end_reports_view AS
 SELECT '01'::text AS order_flag,
    'Expense Invoice:'::text AS order_label,
    allocation.allocation_reference,
    allocation.company AS allocation_company,
    allocation.pcentre AS allocation_pcentre,
    allocation.commodity AS allocation_commodity,
        CASE
            WHEN (allocation.commodity = 'CC'::bpchar) THEN 'Cocoa'::bpchar
            ELSE COALESCE(expenses_detail.commodity, allocation.commodity_type)
        END AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM public.allocation_history
          WHERE ((allocation_history.allocation_reference = allocation.allocation_reference) AND (allocation_history.hist_type = 'AN'::bpchar))) AS allocation_date,
    ( SELECT sum(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM public.allocated_contracts a_c,
            public.sub_contracts s_c,
            public.master_contracts m_c
          WHERE ((a_c.allocation_reference = allocated_contracts.allocation_reference) AND (s_c.contno = a_c.contno) AND (a_c.split = s_c.split) AND (s_c.contno = m_c.contno) AND (m_c.contract_type = 'S'::bpchar))) AS allocation_total_sales_quantity,
    public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN (public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > (0)::numeric) THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    allocated_contracts.contno,
    allocated_contracts.split,
    master_contracts.priceterm,
    master_contracts.contdate AS contract_date,
        CASE
            WHEN (master_contracts.contract_type = 'P'::bpchar) THEN 'PURCHASE'::text
            ELSE 'SALES'::text
        END AS contract_type_label,
    sub_contracts.client AS contract_client,
    (('-1'::integer)::numeric * ( SELECT sum(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM public.allocated_contracts a_c,
            public.sub_contracts s_c,
            public.master_contracts m_c
          WHERE ((a_c.allocation_reference = allocated_contracts.allocation_reference) AND (s_c.contno = a_c.contno) AND (a_c.split = s_c.split) AND (s_c.contno = m_c.contno) AND (m_c.contract_type = 'S'::bpchar)))) AS allocated_quantity,
    expenses_summary.expense_note_type AS expense_journal,
    expenses_summary.expense_number,
    expenses_summary.client AS expense_client,
    expenses_summary.description AS expense_description,
    expenses_detail.expense_type,
    public.sp_allocation_retrieve_sales_priceterms(allocation.allocation_reference) AS sales_priceterm,
    expenses_detail.description AS expense_text,
    expenses_detail.nominal_account AS expense_nominal,
    expenses_summary.currency AS expense_currency,
        CASE
            WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
            ELSE (expenses_detail.linevalue * ('-1'::integer)::numeric)
        END AS expense_value,
    expenses_detail.quantity,
    expenses_summary.posted_date,
    expenses_summary.house_rate AS expenses_house_rate,
        CASE
            WHEN (currency.ratetype = 'D'::bpchar) THEN (
            CASE
                WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                ELSE (expenses_detail.linevalue * ('-1'::integer)::numeric)
            END / expenses_summary.house_rate)
            ELSE (
            CASE
                WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                ELSE (expenses_detail.linevalue * ('-1'::integer)::numeric)
            END * expenses_summary.house_rate)
        END AS base_expense_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
        CASE
            WHEN (public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency) THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor
   FROM (((((((public.allocation
     JOIN public.allocated_contracts ON ((allocation.allocation_reference = allocated_contracts.allocation_reference)))
     JOIN public.sub_contracts ON (((sub_contracts.contno = allocated_contracts.contno) AND (sub_contracts.split = allocated_contracts.split))))
     JOIN public.master_contracts ON ((sub_contracts.contno = master_contracts.contno)))
     JOIN public.expenses_detail ON (((expenses_detail.contno = sub_contracts.contno) AND (expenses_detail.split = sub_contracts.split) AND (expenses_detail.allocation_reference = allocation.allocation_reference))))
     JOIN public.expenses_summary ON (((expenses_summary.expense_number = expenses_detail.expense_number) AND (expenses_summary.client = expenses_detail.client))))
     JOIN public.currency ON ((expenses_summary.currency = currency.code)))
     CROSS JOIN public.params)
UNION ALL
 SELECT '02'::text AS order_flag,
    'Final Invoice:'::text AS order_label,
    allocation.allocation_reference,
    allocation.company AS allocation_company,
    allocation.pcentre AS allocation_pcentre,
    allocation.commodity AS allocation_commodity,
        CASE
            WHEN (allocation.commodity = 'CC'::bpchar) THEN 'Cocoa'::bpchar
            ELSE allocation.commodity_type
        END AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM public.allocation_history
          WHERE ((allocation_history.allocation_reference = allocation.allocation_reference) AND (allocation_history.hist_type = 'AN'::bpchar))) AS allocation_date,
    ( SELECT sum(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM public.allocated_contracts a_c,
            public.sub_contracts s_c,
            public.master_contracts m_c
          WHERE ((a_c.allocation_reference = allocated_contracts.allocation_reference) AND (s_c.contno = a_c.contno) AND (a_c.split = s_c.split) AND (s_c.contno = m_c.contno) AND (m_c.contract_type = 'S'::bpchar))) AS allocation_total_sales_quantity,
    public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN (public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > (0)::numeric) THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    allocated_contracts.contno,
    allocated_contracts.split,
    master_contracts.priceterm,
    master_contracts.contdate AS contract_date,
        CASE
            WHEN (master_contracts.contract_type = 'P'::bpchar) THEN 'PURCHASE'::text
            ELSE 'SALES'::text
        END AS contract_type_label,
    sub_contracts.client AS contract_client,
    (('-1'::integer)::numeric * ( SELECT sum(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM public.allocated_contracts a_c,
            public.sub_contracts s_c,
            public.master_contracts m_c
          WHERE ((a_c.allocation_reference = allocated_contracts.allocation_reference) AND (s_c.contno = a_c.contno) AND (a_c.split = s_c.split) AND (s_c.contno = m_c.contno) AND (m_c.contract_type = 'S'::bpchar)))) AS allocated_quantity,
    final_invoice.final_invoice_journal AS expense_journal,
    final_invoice.final_invoice_number AS expense_number,
    final_invoice.client AS expense_client,
    final_invoice.notes AS expense_description,
    'FINV'::bpchar AS expense_type,
    public.sp_allocation_retrieve_sales_priceterms(allocation.allocation_reference) AS sales_priceterm,
    ('Final Invoice for invoice '::text || (final_invoice.invoice_number)::text) AS expense_text,
    final_invoice_details_2.nomcode AS expense_nominal,
    final_invoice.invoice_currency AS expense_currency,
        CASE
            WHEN (final_invoice.posted_ledref IS NULL) THEN (0)::numeric
            ELSE final_invoice_details_2.net_due_partial
        END AS expense_value,
    final_invoice_details_2.invoiced_quantity AS quantity,
    final_invoice.posted_date,
    final_invoice.house_rate AS expenses_house_rate,
        CASE
            WHEN (currency.ratetype = 'D'::bpchar) THEN (
            CASE
                WHEN (final_invoice.posted_ledref IS NULL) THEN (0)::numeric
                ELSE final_invoice_details_2.net_due_partial
            END / final_invoice.house_rate)
            ELSE (
            CASE
                WHEN (final_invoice.posted_ledref IS NULL) THEN (0)::numeric
                ELSE final_invoice_details_2.net_due_partial
            END * final_invoice.house_rate)
        END AS base_expense_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
        CASE
            WHEN (public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency) THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor
   FROM (((((((public.allocation
     JOIN public.allocated_contracts ON ((allocation.allocation_reference = allocated_contracts.allocation_reference)))
     JOIN public.sub_contracts ON (((sub_contracts.contno = allocated_contracts.contno) AND (sub_contracts.split = allocated_contracts.split))))
     JOIN public.master_contracts ON ((sub_contracts.contno = master_contracts.contno)))
     JOIN public.final_invoice_details_2 ON (((final_invoice_details_2.contno = sub_contracts.contno) AND (final_invoice_details_2.split = sub_contracts.split) AND (final_invoice_details_2.allocation_reference = allocation.allocation_reference))))
     JOIN public.final_invoice ON (((final_invoice.invoice_number = final_invoice_details_2.invoice_number) AND (final_invoice.invoice_type = final_invoice_details_2.invoice_type) AND (final_invoice.client = final_invoice_details_2.client))))
     JOIN public.currency ON ((final_invoice.invoice_currency = currency.code)))
     CROSS JOIN public.params);




CREATE OR REPLACE VIEW public.expenses_view AS
 SELECT params.systemdate,
    params.coname AS our_name,
    params.colongname AS our_longname,
    params.invoice_end_clause,
    clause.longname AS invoice_end_clause_longname,
        CASE
            WHEN (company.addr1 IS NULL) THEN ''::character varying
            ELSE company.addr1
        END AS our_addr1,
        CASE
            WHEN (company.addr2 IS NULL) THEN ''::character varying
            ELSE company.addr2
        END AS our_addr2,
        CASE
            WHEN (company.addr3 IS NULL) THEN ''::character varying
            ELSE company.addr3
        END AS our_addr3,
        CASE
            WHEN (company.addr4 IS NULL) THEN ''::character varying
            ELSE company.addr4
        END AS our_addr4,
        CASE
            WHEN (company.addr5 IS NULL) THEN ''::character varying
            ELSE company.addr5
        END AS our_addr5,
        CASE
            WHEN (company.addr6 IS NULL) THEN ''::character varying
            ELSE company.addr6
        END AS our_addr6,
        CASE
            WHEN (company.vatno IS NULL) THEN ''::character varying
            ELSE company.vatno
        END AS our_vatno,
        CASE
            WHEN (company.regno IS NULL) THEN ''::character varying
            ELSE company.regno
        END AS our_regno,
    client.name AS client_name,
    client.longname AS client_longname,
        CASE
            WHEN (client.addr1 IS NULL) THEN ''::character varying
            ELSE client.addr1
        END AS client_addr1,
        CASE
            WHEN (client.addr2 IS NULL) THEN ''::character varying
            ELSE client.addr2
        END AS client_addr2,
        CASE
            WHEN (client.addr3 IS NULL) THEN ''::character varying
            ELSE client.addr3
        END AS client_addr3,
        CASE
            WHEN (client.addr4 IS NULL) THEN ''::character varying
            ELSE client.addr4
        END AS client_addr4,
        CASE
            WHEN (client.addr5 IS NULL) THEN ''::character varying
            ELSE client.addr5
        END AS client_addr5,
        CASE
            WHEN (client.addr6 IS NULL) THEN ''::character varying
            ELSE client.addr6
        END AS client_addr6,
        CASE
            WHEN (client.vatno IS NULL) THEN ''::character varying
            ELSE client.vatno
        END AS client_vatno,
    expenses_summary.allocation_reference,
    expenses_summary.client,
    expenses_summary.expense_number,
    expenses_summary.expense_date,
    expenses_summary.company,
    expenses_summary.pcentre,
    expenses_summary.commodity,
    expenses_summary.commodtype,
    expenses_summary.origin,
    expenses_summary.expense_type AS expense_inv_type,
    expenses_summary.due_date,
    expenses_summary.posted_date,
    expenses_summary.posted_ledref,
    expenses_summary.total_value,
    expenses_summary.currency,
    expenses_summary.payment_instruction,
    payment_instruction.name AS payinstruct_name,
    payment_instruction.longname AS payinstruct_longname,
    expenses_summary.crdrind,
    expenses_summary.description,
    expenses_summary.pay_amount,
    expenses_summary.pay_date,
    expenses_summary.pay_ledref,
    expenses_detail.expense_type,
    reserves_types.name AS reserve_name,
    reserves_types.longname AS reserve_longname,
    expenses_detail.crdrindicator,
    expenses_detail.amount_indicator,
    expenses_detail.amount,
    expenses_detail.currency AS exp_currency,
    expenses_detail.price_unit,
    expenses_detail.exchange_rate,
    expenses_detail.nominal_account,
    expenses_detail.description AS det_description,
    expenses_detail.linevalue
   FROM (((((((public.params
     CROSS JOIN public.expenses_summary)
     CROSS JOIN public.expenses_detail)
     LEFT JOIN public.clause ON ((params.invoice_end_clause = clause.code)))
     LEFT JOIN public.reserves_types ON ((expenses_detail.expense_type = reserves_types.code)))
     LEFT JOIN public.client ON ((expenses_summary.client = client.code)))
     LEFT JOIN public.payment_instruction ON ((expenses_summary.payment_instruction = payment_instruction.code)))
     LEFT JOIN public.company ON ((expenses_summary.company = company.code)))
  WHERE ((expenses_summary.client = expenses_detail.client) AND (expenses_summary.expense_number = expenses_detail.expense_number));




CREATE OR REPLACE VIEW public.final_invoice_details AS
 SELECT final_invoice_details_1.invoice_type,
    final_invoice_details_1.client,
    final_invoice_details_1.invoice_number,
    final_invoice_details_1.contno,
    final_invoice_details_1.split,
    final_invoice_details_1.invoiced_quantity,
    final_invoice_details_1.positional_quantity,
    final_invoice_details_1.delivered_unit,
    final_invoice_details_1.delivered_quantity,
    final_invoice_details_1.stock_quantity,
    final_invoice_details_1.net_weight,
    final_invoice_details_1.gross_weight,
    final_invoice_details_1.tare,
    final_invoice_details_1.unit_price,
    final_invoice_details_1.description,
    final_invoice_details_1.exchange_rate,
    final_invoice_details_1.linevalue,
    final_invoice_details_1.fands_wgt,
    final_invoice_details_1.slack_wgt,
    final_invoice_details_1.dmgdtrnslack_wgt,
    final_invoice_details_1.short_wgt,
    final_invoice_details_1.dmgdfull_wgt,
    final_invoice_details_1.fands_bag,
    final_invoice_details_1.slack_bag,
    final_invoice_details_1.dmgdtrnslack_bag,
    final_invoice_details_1.short_bag,
    final_invoice_details_1.dmgdfull_bag,
    final_invoice_details_1.samples,
    final_invoice_details_1.tare_wgt,
    final_invoice_details_1.delivered_weight_unit,
    final_invoice_details_1.franchise,
    final_invoice_details_1.franchise_wgt,
    final_invoice_details_1.invoice_unit_price,
    final_invoice_details_1.nomcode,
    final_invoice_details_1.net_due_partial,
    final_invoice_details_1.vatcode
   FROM public.final_invoice_details_1
UNION ALL
 SELECT final_invoice_details_2.invoice_type,
    final_invoice_details_2.client,
    final_invoice_details_2.invoice_number,
    final_invoice_details_2.contno,
    final_invoice_details_2.split,
    final_invoice_details_2.invoiced_quantity,
    final_invoice_details_2.positional_quantity,
    final_invoice_details_2.delivered_unit,
    final_invoice_details_2.delivered_quantity,
    final_invoice_details_2.stock_quantity,
    final_invoice_details_2.net_weight,
    final_invoice_details_2.gross_weight,
    final_invoice_details_2.tare,
    final_invoice_details_2.unit_price,
    final_invoice_details_2.description,
    final_invoice_details_2.exchange_rate,
    final_invoice_details_2.linevalue,
    final_invoice_details_2.fands_wgt,
    final_invoice_details_2.slack_wgt,
    final_invoice_details_2.dmgdtrnslack_wgt,
    final_invoice_details_2.short_wgt,
    final_invoice_details_2.dmgdfull_wgt,
    final_invoice_details_2.fands_bag,
    final_invoice_details_2.slack_bag,
    final_invoice_details_2.dmgdtrnslack_bag,
    final_invoice_details_2.short_bag,
    final_invoice_details_2.dmgdfull_bag,
    final_invoice_details_2.samples,
    final_invoice_details_2.tare_wgt,
    final_invoice_details_2.delivered_weight_unit,
    final_invoice_details_2.franchise,
    final_invoice_details_2.franchise_wgt,
    final_invoice_details_2.invoice_unit_price,
    final_invoice_details_2.nomcode,
    final_invoice_details_2.net_due_partial,
    final_invoice_details_2.vatcode
   FROM public.final_invoice_details_2;




CREATE OR REPLACE VIEW public.floating_stock_view AS
 SELECT master_purchases.commodtype AS p_type,
    master_purchases.origin AS p_origin,
    master_purchases.company AS p_company,
    master_purchases.contno AS p_contract,
    sub_purchases.split AS p_split,
    master_purchases.client AS p_supplier,
    allocated_purchases.allocation_reference,
    invoice_details_2_purchases.invoiced_quantity AS p_quantity,
    sub_purchases.quantunit AS p_unit,
    public.sp_convert_qty(invoice_details_2_purchases.invoiced_quantity, sub_purchases.quantunit, 'MT'::bpchar) AS p_tonnage,
    invoice_details_2_purchases.invoice_number AS purchase_invoice,
    invoice_details_2_purchases.linevalue AS purchase_invoice_amount,
    invoice_purchases.invoice_currency AS purchase_invoice_currency,
        CASE
            WHEN (public.sp_allocation_check_if_only_stock(allocated_purchases.allocation_reference) = 'Y'::bpchar) THEN 'STOCK'::text
            ELSE 'SALES'::text
        END AS allocation_status,
    NULL::bpchar AS sales_invoice,
    NULL::bpchar AS sales_contract,
    NULL::bpchar AS sales_split,
    NULL::bpchar AS sales_shipment_period,
    NULL::bpchar AS sales_counterparty,
    ( SELECT sum(stocks.quantity) AS sum
           FROM public.stocks
          WHERE ((stocks.contno = sub_purchases.contno) AND (stocks.split = sub_purchases.split) AND (stocks.allocation_reference = allocated_purchases.allocation_reference) AND (stocks.original_invoice_number = invoice_purchases.invoice_number))) AS stock_quantity,
    ( SELECT string_agg(DISTINCT (stocks.warehouse)::text, ' '::text) AS string_agg
           FROM public.stocks
          WHERE ((stocks.contno = sub_purchases.contno) AND (stocks.split = sub_purchases.split) AND (stocks.allocation_reference = allocated_purchases.allocation_reference))) AS stock_warehouse,
    NULL::numeric AS sales_invoice_amount,
    NULL::bpchar AS sales_invoice_currency
   FROM ((((((public.allocation
     JOIN public.allocated_contracts allocated_purchases ON ((allocated_purchases.allocation_reference = allocation.allocation_reference)))
     JOIN public.sub_contracts sub_purchases ON (((allocated_purchases.contno = sub_purchases.contno) AND (allocated_purchases.split = sub_purchases.split))))
     JOIN public.master_contracts master_purchases ON ((sub_purchases.contno = master_purchases.contno)))
     JOIN public.invoice_details_2 invoice_details_2_purchases ON (((sub_purchases.contno = invoice_details_2_purchases.contno) AND (sub_purchases.split = invoice_details_2_purchases.split) AND (allocated_purchases.allocation_reference = invoice_details_2_purchases.allocation_reference))))
     JOIN public.invoice invoice_purchases ON (((invoice_details_2_purchases.invoice_number = invoice_purchases.invoice_number) AND (invoice_details_2_purchases.invoice_type = invoice_purchases.invoice_type) AND (invoice_details_2_purchases.client = invoice_purchases.client))))
     CROSS JOIN public.params)
  WHERE ((master_purchases.contract_type = 'P'::bpchar) AND (allocation.allocation_completed = 'N'::bpchar) AND (public.sp_allocation_check_if_only_stock(allocated_purchases.allocation_reference) = 'Y'::bpchar) AND (invoice_details_2_purchases.invoiced_quantity > (0)::numeric))
UNION ALL
 SELECT master_purchases.commodtype AS p_type,
    master_purchases.origin AS p_origin,
    master_purchases.company AS p_company,
    master_purchases.contno AS p_contract,
    sub_purchases.split AS p_split,
    master_purchases.client AS p_supplier,
    allocated_purchases.allocation_reference,
    invoice_details_2_purchases.invoiced_quantity AS p_quantity,
    sub_purchases.quantunit AS p_unit,
    public.sp_convert_qty(invoice_details_2_purchases.invoiced_quantity, sub_purchases.quantunit, 'MT'::bpchar) AS p_tonnage,
    invoice_details_2_purchases.invoice_number AS purchase_invoice,
    invoice_details_2_purchases.linevalue AS purchase_invoice_amount,
    invoice_purchases.invoice_currency AS purchase_invoice_currency,
        CASE
            WHEN (public.sp_allocation_check_if_only_stock(allocated_purchases.allocation_reference) = 'Y'::bpchar) THEN 'STOCK'::text
            ELSE 'SALES'::text
        END AS allocation_status,
    invoice_details_2_sales.invoice_number AS sales_invoice,
    invoice_details_2_sales.contno AS sales_contract,
    invoice_details_2_sales.split AS sales_split,
    sub_sales.shipment AS sales_shipment_period,
    invoice_details_2_sales.client AS sales_counterparty,
    ( SELECT COALESCE(sum(invoice_stocks.stock_quantity), (0)::numeric) AS "coalesce"
           FROM ((public.invoice_stocks
             JOIN public.stocks ON (((invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id))))
             JOIN public.invoice s_invoice ON (((invoice_stocks.invoice_number = s_invoice.invoice_number) AND (invoice_stocks.client = s_invoice.client) AND (invoice_stocks.invoice_type = s_invoice.invoice_type))))
          WHERE ((invoice_stocks.invoice_number = invoice_details_2_sales.invoice_number) AND (invoice_stocks.invoice_type = invoice_details_2_sales.invoice_type) AND (invoice_stocks.client = invoice_details_2_sales.client) AND (invoice_stocks.contno = sub_purchases.contno) AND (invoice_stocks.split = sub_purchases.split) AND (stocks.allocation_reference = invoice_details_2_sales.allocation_reference) AND (s_invoice.posted_ledref IS NOT NULL))) AS stock_quantity,
    ( SELECT string_agg(DISTINCT (stocks.warehouse)::text, ' '::text) AS string_agg
           FROM (public.invoice_stocks
             JOIN public.stocks ON (((invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id))))
          WHERE ((invoice_stocks.invoice_number = invoice_details_2_sales.invoice_number) AND (invoice_stocks.invoice_type = invoice_details_2_sales.invoice_type) AND (invoice_stocks.client = invoice_details_2_sales.client) AND (invoice_stocks.contno = sub_purchases.contno) AND (invoice_stocks.split = sub_purchases.split) AND (stocks.allocation_reference = invoice_details_2_sales.allocation_reference))) AS stock_warehouse,
    invoice_details_2_sales.linevalue AS sales_invoice_amount,
    invoice_sales.invoice_currency AS sales_invoice_currency
   FROM (((((((((((public.allocation
     JOIN public.allocated_contracts allocated_purchases ON ((allocated_purchases.allocation_reference = allocation.allocation_reference)))
     JOIN public.sub_contracts sub_purchases ON (((allocated_purchases.contno = sub_purchases.contno) AND (allocated_purchases.split = sub_purchases.split))))
     JOIN public.master_contracts master_purchases ON ((sub_purchases.contno = master_purchases.contno)))
     JOIN public.invoice_details_2 invoice_details_2_purchases ON (((sub_purchases.contno = invoice_details_2_purchases.contno) AND (sub_purchases.split = invoice_details_2_purchases.split) AND (allocated_purchases.allocation_reference = invoice_details_2_purchases.allocation_reference))))
     JOIN public.invoice invoice_purchases ON (((invoice_details_2_purchases.invoice_number = invoice_purchases.invoice_number) AND (invoice_details_2_purchases.invoice_type = invoice_purchases.invoice_type) AND (invoice_details_2_purchases.client = invoice_purchases.client))))
     JOIN public.allocated_contracts allocated_sales ON ((allocated_purchases.allocation_reference = allocated_sales.allocation_reference)))
     LEFT JOIN public.invoice_details_2 invoice_details_2_sales ON (((allocated_sales.contno = invoice_details_2_sales.contno) AND (allocated_sales.split = invoice_details_2_sales.split) AND (allocated_sales.allocation_reference = invoice_details_2_sales.allocation_reference))))
     LEFT JOIN public.invoice invoice_sales ON (((invoice_details_2_sales.invoice_number = invoice_sales.invoice_number) AND (invoice_details_2_sales.invoice_type = invoice_sales.invoice_type) AND (invoice_details_2_sales.client = invoice_sales.client) AND (invoice_sales.posted_ledref IS NOT NULL))))
     JOIN public.sub_contracts sub_sales ON (((allocated_sales.contno = sub_sales.contno) AND (allocated_sales.split = sub_sales.split))))
     JOIN public.master_contracts master_sales ON ((sub_sales.contno = master_sales.contno)))
     CROSS JOIN public.params)
  WHERE ((master_purchases.contract_type = 'P'::bpchar) AND (allocation.allocation_completed = 'N'::bpchar) AND (public.sp_allocation_check_if_only_stock(allocated_purchases.allocation_reference) = 'N'::bpchar) AND (master_sales.contract_type = 'S'::bpchar) AND (invoice_details_2_purchases.invoiced_quantity > (0)::numeric) AND (COALESCE(( SELECT sum(invoice_stocks.stock_quantity) AS sum
           FROM ((public.invoice_stocks
             JOIN public.stocks ON (((invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id))))
             JOIN public.invoice s_invoice ON (((invoice_stocks.invoice_number = s_invoice.invoice_number) AND (invoice_stocks.client = s_invoice.client) AND (invoice_stocks.invoice_type = s_invoice.invoice_type))))
          WHERE ((invoice_stocks.invoice_number = invoice_details_2_sales.invoice_number) AND (invoice_stocks.invoice_type = invoice_details_2_sales.invoice_type) AND (invoice_stocks.client = invoice_details_2_sales.client) AND (invoice_stocks.contno = sub_purchases.contno) AND (invoice_stocks.split = sub_purchases.split) AND (stocks.allocation_reference = invoice_details_2_sales.allocation_reference) AND (s_invoice.posted_ledref IS NOT NULL))), (0)::numeric) > (0)::numeric))
UNION ALL
 SELECT master_purchases.commodtype AS p_type,
    master_purchases.origin AS p_origin,
    master_purchases.company AS p_company,
    master_purchases.contno AS p_contract,
    sub_purchases.split AS p_split,
    master_purchases.client AS p_supplier,
    allocated_purchases.allocation_reference,
    invoice_details_2_purchases.invoiced_quantity AS p_quantity,
    sub_purchases.quantunit AS p_unit,
    public.sp_convert_qty(invoice_details_2_purchases.invoiced_quantity, sub_purchases.quantunit, 'MT'::bpchar) AS p_tonnage,
    invoice_details_2_purchases.invoice_number AS purchase_invoice,
    invoice_details_2_purchases.linevalue AS purchase_invoice_amount,
    invoice_purchases.invoice_currency AS purchase_invoice_currency,
        CASE
            WHEN (public.sp_allocation_check_if_only_stock(allocated_purchases.allocation_reference) = 'Y'::bpchar) THEN 'STOCK'::text
            ELSE 'SALES'::text
        END AS allocation_status,
    NULL::bpchar AS sales_invoice,
    allocated_sales.contno AS sales_contract,
    allocated_sales.split AS sales_split,
    sub_sales.shipment AS sales_shipment_period,
    sub_sales.client AS sales_counterparty,
    COALESCE(( SELECT sum(stocks.quantity) AS sum
           FROM public.stocks
          WHERE ((stocks.contno = sub_purchases.contno) AND (stocks.split = sub_purchases.split) AND (stocks.allocation_reference = allocated_sales.allocation_reference))), (0)::numeric) AS stock_quantity,
    ( SELECT string_agg(DISTINCT (stocks.warehouse)::text, ' '::text) AS string_agg
           FROM public.stocks
          WHERE ((stocks.contno = sub_purchases.contno) AND (stocks.split = sub_purchases.split) AND (stocks.allocation_reference = allocated_sales.allocation_reference))) AS stock_warehouse,
    NULL::numeric AS sales_invoice_amount,
    NULL::bpchar AS sales_invoice_currency
   FROM (((((((((public.allocation
     JOIN public.allocated_contracts allocated_purchases ON ((allocated_purchases.allocation_reference = allocation.allocation_reference)))
     JOIN public.sub_contracts sub_purchases ON (((allocated_purchases.contno = sub_purchases.contno) AND (allocated_purchases.split = sub_purchases.split))))
     JOIN public.master_contracts master_purchases ON ((sub_purchases.contno = master_purchases.contno)))
     JOIN public.invoice_details_2 invoice_details_2_purchases ON (((sub_purchases.contno = invoice_details_2_purchases.contno) AND (sub_purchases.split = invoice_details_2_purchases.split) AND (allocated_purchases.allocation_reference = invoice_details_2_purchases.allocation_reference))))
     JOIN public.invoice invoice_purchases ON (((invoice_details_2_purchases.invoice_number = invoice_purchases.invoice_number) AND (invoice_details_2_purchases.invoice_type = invoice_purchases.invoice_type) AND (invoice_details_2_purchases.client = invoice_purchases.client))))
     JOIN public.allocated_contracts allocated_sales ON ((allocated_purchases.allocation_reference = allocated_sales.allocation_reference)))
     JOIN public.sub_contracts sub_sales ON (((allocated_sales.contno = sub_sales.contno) AND (allocated_sales.split = sub_sales.split))))
     JOIN public.master_contracts master_sales ON ((sub_sales.contno = master_sales.contno)))
     CROSS JOIN public.params)
  WHERE ((master_purchases.contract_type = 'P'::bpchar) AND (allocation.allocation_completed = 'N'::bpchar) AND (public.sp_allocation_check_if_only_stock(allocated_purchases.allocation_reference) = 'N'::bpchar) AND (master_sales.contract_type = 'S'::bpchar) AND (invoice_details_2_purchases.invoiced_quantity > (0)::numeric) AND (COALESCE(( SELECT sum(stocks.quantity) AS sum
           FROM public.stocks
          WHERE ((stocks.contno = sub_purchases.contno) AND (stocks.split = sub_purchases.split) AND (stocks.allocation_reference = allocated_sales.allocation_reference))), (0)::numeric) > (0)::numeric))
  ORDER BY 1, 2, 3;




CREATE OR REPLACE VIEW public.forecast_report_outbooked_p_expenses_view AS
 SELECT '02'::text AS order_flag,
    'P Contract:'::text AS order_label,
    allocation.allocation_reference,
    accsummary.company AS allocation_company,
    accsummary.pcentre AS allocation_pcentre,
    accsummary.an_commodity AS allocation_commodity,
    accsummary.an_commodtype AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM public.allocation_history
          WHERE ((allocation_history.allocation_reference = allocation.allocation_reference) AND (allocation_history.hist_type = 'AN'::bpchar))) AS allocation_date,
    ( SELECT sum(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM public.allocated_contracts a_c,
            public.sub_contracts s_c,
            public.master_contracts m_c
          WHERE ((allocated_contracts.allocation_reference = a_c.allocation_reference) AND (s_c.contno = a_c.contno) AND (a_c.split = s_c.split) AND (s_c.contno = m_c.contno) AND (m_c.contract_type = 'S'::bpchar))) AS allocation_total_sales_quantity,
    public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN (public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > (0)::numeric) THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    accdetail.accdetail_contno AS contno,
    accdetail.accdetail_split AS split,
    master_contracts.priceterm,
    master_contracts.contdate AS record_date,
    sub_contracts.client AS contract_client,
    (('-1'::integer)::numeric * public.sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM public.allocated_contracts a_c
          WHERE ((a_c.allocation_reference = a_c.allocation_reference) AND (allocated_contracts.contno = a_c.contno) AND (a_c.split = sub_contracts.split) AND (master_contracts.contract_type = 'S'::bpchar))), sub_contracts.quantunit, 'MT'::bpchar)) AS allocated_quantity,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END AS price_curr_unit,
    sub_contracts.currency,
    sub_contracts.priceunit,
    (
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END * (('-1'::integer)::numeric * public.sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM public.allocated_contracts a_c
          WHERE ((a_c.allocation_reference = a_c.allocation_reference) AND (allocated_contracts.contno = a_c.contno) AND (a_c.split = sub_contracts.split) AND (master_contracts.contract_type = 'S'::bpchar))), sub_contracts.quantunit, 'MT'::bpchar))) AS total_forecast,
    ((
        CASE
            WHEN (public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency) THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END *
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END) * (('-1'::integer)::numeric * public.sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM public.allocated_contracts a_c
          WHERE ((a_c.allocation_reference = a_c.allocation_reference) AND (allocated_contracts.contno = a_c.contno) AND (a_c.split = sub_contracts.split) AND (master_contracts.contract_type = 'S'::bpchar))), sub_contracts.quantunit, 'MT'::bpchar))) AS total_forecast_base_curr,
    'Purch Expenses:'::text AS invoice_heading,
    '04'::text AS invoice_order,
    expenses_summary.expense_note_type AS invoice_flag,
    ((expenses_summary.expense_number)::text || ' (OUTB)'::text) AS invoice_number,
    accsummary.leddate AS invoice_date,
    expenses_summary.client AS invoice_client,
    (((expenses_detail.description)::text || '                   '::text) || (accdetail.ledgernum)::text) AS invoice_text,
    NULL::numeric AS invoiced_quantity,
    NULL::text AS invoice_unit_price,
    accdetail.currency AS invoice_currency,
    NULL::text AS invoice_priceunit,
    accdetail.ledamt AS invoice_value,
        CASE
            WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
            ELSE accdetail.ledamt
        END AS signed_invoice_value,
    accsummary.leddate AS posted_date,
        CASE
            WHEN (currency.ratetype = 'D'::bpchar) THEN (
            CASE
                WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                ELSE accdetail.ledamt
            END / expenses_summary.house_rate)
            ELSE (
            CASE
                WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                ELSE accdetail.ledamt
            END * expenses_summary.house_rate)
        END AS posted_invoice_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
    expenses_summary.house_rate AS invoice_house_rate,
        CASE
            WHEN (public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency) THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor,
    0 AS manual_outb_expense_amount,
    (expenses_detail.charges_line)::text AS merged_line_splitter,
    allocation.suggest_completed,
    ( SELECT string_agg(DISTINCT (s_c.origin)::text, ' '::text) AS string_agg
           FROM public.sub_contracts s_c,
            public.allocated_contracts a_c
          WHERE ((a_c.allocation_reference = allocation.allocation_reference) AND (a_c.contno = s_c.contno) AND (a_c.split = s_c.split))) AS origin
   FROM (((((((((public.accsummary
     JOIN public.accdetail ON (((accsummary.accperiod = accdetail.accperiod) AND (accsummary.ledgernum = accdetail.ledgernum))))
     JOIN public.allocation ON ((allocation.allocation_reference = accdetail.accdetail_allocation_reference)))
     JOIN public.allocated_contracts ON (((allocation.allocation_reference = allocated_contracts.allocation_reference) AND (allocated_contracts.contno = accdetail.accdetail_contno) AND (allocated_contracts.split = accdetail.accdetail_split))))
     JOIN public.sub_contracts ON (((sub_contracts.contno = allocated_contracts.contno) AND (sub_contracts.split = allocated_contracts.split) AND (sub_contracts.contno = accdetail.accdetail_contno) AND (sub_contracts.split = accdetail.accdetail_split))))
     JOIN public.master_contracts ON ((sub_contracts.contno = master_contracts.contno)))
     JOIN public.expenses_summary ON (((accdetail.accdetail_expense_number = expenses_summary.expense_number) AND (accsummary.an_client = expenses_summary.client))))
     JOIN public.expenses_detail ON (((expenses_summary.expense_number = expenses_detail.expense_number) AND (expenses_summary.client = expenses_detail.client) AND (expenses_detail.charges_line = accdetail.accdetail_charges_line) AND (expenses_detail.expense_type = accdetail.accdetail_reserves_type) AND (expenses_detail.contno = sub_contracts.contno) AND (expenses_detail.split = sub_contracts.split))))
     JOIN public.currency ON ((expenses_summary.currency = currency.code)))
     CROSS JOIN public.params)
  WHERE ((accdetail.accdetail_invoice_flag = 'EXP'::bpchar) AND (master_contracts.contract_type = 'P'::bpchar) AND ((accdetail.nominal ~~ '6%'::text) OR (accdetail.nominal ~~ '7%'::text)) AND (accdetail.caja_project = 'OUTB'::bpchar) AND (allocation.allocation_reference !~~ '81200%'::text))
UNION ALL
 SELECT '02'::text AS order_flag,
    'P Contract:'::text AS order_label,
    allocation.allocation_reference,
    allocation.company AS allocation_company,
    allocation.pcentre AS allocation_pcentre,
    allocation.commodity AS allocation_commodity,
    COALESCE(expenses_detail.commodity, allocation.commodity_type) AS allocation_commodity_type,
    ( SELECT min(allocation_history.hist_date) AS min
           FROM public.allocation_history
          WHERE ((allocation_history.allocation_reference = allocation.allocation_reference) AND (allocation_history.hist_type = 'AN'::bpchar))) AS allocation_date,
    ( SELECT sum(public.sp_convert_qty(a_c.quantity, s_c.quantunit, 'MT'::bpchar)) AS sum
           FROM public.allocated_contracts a_c,
            public.sub_contracts s_c,
            public.master_contracts m_c
          WHERE ((allocated_contracts.allocation_reference = a_c.allocation_reference) AND (s_c.contno = a_c.contno) AND (a_c.split = s_c.split) AND (s_c.contno = m_c.contno) AND (m_c.contract_type = 'S'::bpchar))) AS allocation_total_sales_quantity,
    public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) AS allocation_total_unfixed,
        CASE
            WHEN (public.sp_phys_total_alloc_unfixed(allocation.allocation_reference) > (0)::numeric) THEN 'Unfixed'::text
            ELSE 'Fixed'::text
        END AS allocation_fixed_flag,
    sub_contracts.contno,
    sub_contracts.split,
    master_contracts.priceterm,
    master_contracts.contdate AS record_date,
    sub_contracts.client AS contract_client,
    (('-1'::integer)::numeric * public.sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM public.allocated_contracts a_c
          WHERE ((allocated_contracts.allocation_reference = a_c.allocation_reference) AND (allocated_contracts.contno = a_c.contno) AND (a_c.split = sub_contracts.split) AND (master_contracts.contract_type = 'S'::bpchar))), sub_contracts.quantunit, 'MT'::bpchar)) AS allocated_quantity,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END AS price_curr_unit,
    sub_contracts.currency,
    sub_contracts.priceunit,
    (
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END * (('-1'::integer)::numeric * public.sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM public.allocated_contracts a_c
          WHERE ((allocated_contracts.allocation_reference = a_c.allocation_reference) AND (allocated_contracts.contno = a_c.contno) AND (a_c.split = sub_contracts.split) AND (master_contracts.contract_type = 'S'::bpchar))), sub_contracts.quantunit, 'MT'::bpchar))) AS total_forecast,
    ((
        CASE
            WHEN (public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency) THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END *
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split)
            ELSE sub_contracts.unitprice
        END) * (('-1'::integer)::numeric * public.sp_convert_qty(( SELECT sum(a_c.quantity) AS sum
           FROM public.allocated_contracts a_c
          WHERE ((allocated_contracts.allocation_reference = a_c.allocation_reference) AND (allocated_contracts.contno = a_c.contno) AND (a_c.split = sub_contracts.split) AND (master_contracts.contract_type = 'S'::bpchar))), sub_contracts.quantunit, 'MT'::bpchar))) AS total_forecast_base_curr,
    'Purch Expenses:'::text AS invoice_heading,
    '05'::text AS invoice_order,
    expenses_summary.expense_note_type AS invoice_flag,
    expenses_summary.expense_number AS invoice_number,
    expenses_summary.posted_date AS invoice_date,
    expenses_summary.client AS invoice_client,
    expenses_detail.description AS invoice_text,
    (('-1'::integer)::numeric * expenses_detail.quantity) AS invoiced_quantity,
    NULL::text AS invoice_unit_price,
    expenses_detail.currency AS invoice_currency,
    NULL::text AS invoice_priceunit,
        CASE
            WHEN ((expenses_detail.nominal_account ~~ '6%'::text) OR (expenses_detail.nominal_account ~~ '7%'::text)) THEN (('-1'::integer)::numeric * expenses_detail.linevalue)
            ELSE public.sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
        END AS invoice_value,
        CASE
            WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
            ELSE
            CASE
                WHEN ((expenses_detail.nominal_account ~~ '6%'::text) OR (expenses_detail.nominal_account ~~ '7%'::text)) THEN (('-1'::integer)::numeric * expenses_detail.linevalue)
                ELSE public.sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
            END
        END AS signed_invoice_value,
    expenses_summary.posted_date,
        CASE
            WHEN (currency.ratetype = 'D'::bpchar) THEN (
            CASE
                WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                ELSE
                CASE
                    WHEN ((expenses_detail.nominal_account ~~ '6%'::text) OR (expenses_detail.nominal_account ~~ '7%'::text)) THEN (('-1'::integer)::numeric * expenses_detail.linevalue)
                    ELSE public.sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                END
            END / expenses_summary.house_rate)
            ELSE (
            CASE
                WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                ELSE
                CASE
                    WHEN ((expenses_detail.nominal_account ~~ '6%'::text) OR (expenses_detail.nominal_account ~~ '7%'::text)) THEN (('-1'::integer)::numeric * expenses_detail.linevalue)
                    ELSE public.sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                END
            END * expenses_summary.house_rate)
        END AS posted_invoice_value,
    master_contracts.contract_type,
    allocation.allocation_completed,
    allocation.allocation_completed_date,
    expenses_summary.house_rate AS invoice_house_rate,
        CASE
            WHEN (public.sp_curr_getunderlying(sub_contracts.currency) = params.base_currency) THEN public.sp_datedfxrate(sub_contracts.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(sub_contracts.contno, sub_contracts.split)
        END AS contract_currency_to_basecurr_conversion_factor,
        CASE
            WHEN (expenses_detail.nominal_account = '60002'::bpchar) THEN
            CASE
                WHEN (currency.ratetype = 'D'::bpchar) THEN (
                CASE
                    WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                    ELSE
                    CASE
                        WHEN ((expenses_detail.nominal_account ~~ '6%'::text) OR (expenses_detail.nominal_account ~~ '7%'::text)) THEN (('-1'::integer)::numeric * expenses_detail.linevalue)
                        ELSE public.sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                    END
                END / expenses_summary.house_rate)
                ELSE (
                CASE
                    WHEN (expenses_summary.posted_ledref IS NULL) THEN (0)::numeric
                    ELSE
                    CASE
                        WHEN ((expenses_detail.nominal_account ~~ '6%'::text) OR (expenses_detail.nominal_account ~~ '7%'::text)) THEN (('-1'::integer)::numeric * expenses_detail.linevalue)
                        ELSE public.sp_get_realised_invoice_value('E'::bpchar, expenses_detail.expense_number, expenses_detail.client, expenses_detail.charges_line, expenses_detail.contno, expenses_detail.split)
                    END
                END * expenses_summary.house_rate)
            END
            ELSE (0)::numeric
        END AS manual_outb_expense_amount,
    (expenses_detail.charges_line)::text AS merged_line_splitter,
    allocation.suggest_completed,
    ( SELECT string_agg(DISTINCT (s_c.origin)::text, ' '::text) AS string_agg
           FROM public.sub_contracts s_c,
            public.allocated_contracts a_c
          WHERE ((a_c.allocation_reference = allocation.allocation_reference) AND (a_c.contno = s_c.contno) AND (a_c.split = s_c.split))) AS origin
   FROM (((((((public.allocation
     JOIN public.allocated_contracts ON ((allocation.allocation_reference = allocated_contracts.allocation_reference)))
     JOIN public.expenses_detail ON (((allocated_contracts.contno = expenses_detail.contno) AND (allocated_contracts.split = expenses_detail.split) AND (allocated_contracts.allocation_reference = expenses_detail.allocation_reference))))
     JOIN public.expenses_summary ON (((expenses_detail.expense_number = expenses_summary.expense_number) AND (expenses_detail.client = expenses_summary.client))))
     JOIN public.currency ON ((expenses_summary.currency = currency.code)))
     JOIN public.sub_contracts ON (((sub_contracts.contno = allocated_contracts.contno) AND (sub_contracts.split = allocated_contracts.split))))
     JOIN public.master_contracts ON ((sub_contracts.contno = master_contracts.contno)))
     CROSS JOIN public.params)
  WHERE ((master_contracts.contract_type = 'P'::bpchar) AND ((expenses_detail.nominal_account ~~ '6%'::text) OR (expenses_detail.nominal_account ~~ '7%'::text)) AND (expenses_detail.nominal_account <> '60130'::bpchar));




CREATE OR REPLACE VIEW public.fx_hedged_view AS
 SELECT contdate,
    seqno,
    contno,
    commodity,
    futconts,
    get_prompt,
    tprice,
    lots,
    hedgeable,
    mktcurr,
    othercurr,
    dealratetype,
    ( SELECT sum(b.quantity) AS sum
           FROM public.forex_hedges b
          WHERE ((b.termdate = a.contdate) AND (b.termseqno = a.seqno))) AS hedged,
    (hedgeable -
        CASE
            WHEN (( SELECT sum(b.quantity) AS sum
               FROM public.forex_hedges b
              WHERE ((b.termdate = a.contdate) AND (b.termseqno = a.seqno))) IS NULL) THEN (0)::numeric
            ELSE ( SELECT sum(b.quantity) AS sum
               FROM public.forex_hedges b
              WHERE ((b.termdate = a.contdate) AND (b.termseqno = a.seqno)))
        END) AS unhedged
   FROM public.term_view a
  WHERE ((hedge = 'Y'::bpchar) AND (tradetype = 'X'::bpchar));




CREATE OR REPLACE VIEW public.fx_hedges_valn AS
 SELECT a.contno,
    a.split,
    a.termdate,
    a.termseqno,
    a.quantity,
    b.futconts,
    b.prompt,
    b.tprice AS hedgeprice,
    b.busdate AS closedate,
        CASE
            WHEN (b.dealratetype = 'M'::bpchar) THEN public.sp_datedfxrate(b.mktcurr, b.othercurr, b.busdate, (b.prompt)::date)
            ELSE public.sp_datedfxrate(b.othercurr, b.mktcurr, b.busdate, (b.prompt)::date)
        END AS closing,
    b.plots,
    b.slots,
    c.lots AS origlots,
    b.lotfactor,
    b.pricefactor,
    b.mktcurr,
    b.othercurr,
    b.dealratetype
   FROM ((public.forex_hedges a
     JOIN public.termclosed_view b ON (((b.contdate = a.termdate) AND (b.seqno = a.termseqno))))
     JOIN public.terminal c ON (((c.contdate = b.contdate) AND (c.seqno = b.seqno))))
  WHERE (b.histaction = 'S'::bpchar)
UNION
 SELECT a.contno,
    a.split,
    a.termdate,
    a.termseqno,
    a.quantity,
    b.futconts,
    b.prompt,
    b.tprice AS hedgeprice,
    params.systemdate AS closedate,
        CASE
            WHEN (b.dealratetype = 'M'::bpchar) THEN public.sp_datedfxrate(b.mktcurr, b.othercurr, params.systemdate, (b.prompt)::date)
            ELSE public.sp_datedfxrate(b.othercurr, b.mktcurr, params.systemdate, (b.prompt)::date)
        END AS closing,
    b.plots,
    b.slots,
    b.lots AS origlots,
    b.lotfactor,
    b.pricefactor,
    b.mktcurr,
    b.othercurr,
    b.dealratetype
   FROM ((public.forex_hedges a
     JOIN public.term_view b ON (((b.contdate = a.termdate) AND (b.seqno = a.termseqno))))
     CROSS JOIN public.params);




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




CREATE OR REPLACE VIEW public.invoice_charges_view AS
 SELECT params.systemdate,
    params.coname AS our_name,
    params.colongname AS our_longname,
    params.invoice_end_clause,
    clause.longname AS invoice_end_clause_longname,
        CASE
            WHEN (params.coaddr1 IS NULL) THEN ''::character varying
            ELSE params.coaddr1
        END AS our_addr1,
        CASE
            WHEN (params.coaddr2 IS NULL) THEN ''::character varying
            ELSE params.coaddr2
        END AS our_addr2,
        CASE
            WHEN (params.coaddr3 IS NULL) THEN ''::character varying
            ELSE params.coaddr3
        END AS our_addr3,
        CASE
            WHEN (params.coaddr4 IS NULL) THEN ''::character varying
            ELSE params.coaddr4
        END AS our_addr4,
        CASE
            WHEN (params.coaddr5 IS NULL) THEN ''::character varying
            ELSE params.coaddr5
        END AS our_addr5,
        CASE
            WHEN (params.coaddr6 IS NULL) THEN ''::character varying
            ELSE params.coaddr6
        END AS our_addr6,
    client.name AS client_name,
    client.longname AS client_longname,
        CASE
            WHEN (client.addr1 IS NULL) THEN ''::character varying
            ELSE client.addr1
        END AS client_addr1,
        CASE
            WHEN (client.addr2 IS NULL) THEN ''::character varying
            ELSE client.addr2
        END AS client_addr2,
        CASE
            WHEN (client.addr3 IS NULL) THEN ''::character varying
            ELSE client.addr3
        END AS client_addr3,
        CASE
            WHEN (client.addr4 IS NULL) THEN ''::character varying
            ELSE client.addr4
        END AS client_addr4,
        CASE
            WHEN (client.addr5 IS NULL) THEN ''::character varying
            ELSE client.addr5
        END AS client_addr5,
        CASE
            WHEN (client.addr6 IS NULL) THEN ''::character varying
            ELSE client.addr6
        END AS client_addr6,
    invoice.allocation_reference,
    invoice.invoice_type,
    invoice.client,
    invoice.invoice_number,
    invoice.invoice_date,
    invoice.company,
    invoice.pcentre,
    invoice.commodity,
    invoice.commodity_type,
    invoice.origin,
    invoice.total_tonnage,
    invoice.percentage_invoiced,
    invoice.commission_rate,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.posted_date,
    invoice.posted_ledref,
    invoice.description AS cp_inv_desc,
    invoice.marks,
    invoice.weights,
    invoice.goods_lying,
    invoice.vessel,
    invoice.warehouse,
    invoice.warrant_number,
    invoice.draft_number,
    invoice.price_terms,
    invoice.price_terms_location,
    invoice.bl_number,
    invoice.bl_date,
    invoice.port_of_origin,
    invoice.payment_terms,
    payment_term.name AS payterm_name,
    payment_term.longname AS payterm_longname,
    invoice.payment_instruction,
    payment_instruction.name AS payinstruct_name,
    payment_instruction.longname AS payinstruct_longname,
    invoice.due_date,
    invoice_charges.charges_line,
    invoice_charges.expenses_type,
    invoice_charges.crdrindicator,
    invoice_charges.amount_indicator,
    invoice_charges.amount,
    invoice_charges.currency AS cp_charge_currency,
    invoice_charges.price_unit,
    invoice_charges.description AS cp_charges_desc,
    invoice_charges.exchange_rate AS cp_charge_exgrate,
    invoice_charges.nominal_account,
    invoice_charges.linevalue AS cp_charge_linevalue
   FROM ((((((public.params
     CROSS JOIN public.invoice)
     CROSS JOIN public.invoice_charges)
     LEFT JOIN public.clause ON ((params.invoice_end_clause = clause.code)))
     LEFT JOIN public.client ON ((invoice.client = client.code)))
     LEFT JOIN public.payment_term ON ((invoice.payment_terms = payment_term.code)))
     LEFT JOIN public.payment_instruction ON ((invoice.payment_instruction = payment_instruction.code)))
  WHERE ((invoice.invoice_type = invoice_charges.invoice_type) AND (invoice.client = invoice_charges.client) AND (invoice.invoice_number = invoice_charges.invoice_number));




CREATE OR REPLACE VIEW public.invoice_charges_view2 AS
 SELECT params.systemdate,
    params.coname AS our_name,
    params.colongname AS our_longname,
    params.invoice_end_clause,
    clause.longname AS invoice_end_clause_longname,
        CASE
            WHEN (params.coaddr1 IS NULL) THEN ''::character varying
            ELSE params.coaddr1
        END AS our_addr1,
        CASE
            WHEN (params.coaddr2 IS NULL) THEN ''::character varying
            ELSE params.coaddr2
        END AS our_addr2,
        CASE
            WHEN (params.coaddr3 IS NULL) THEN ''::character varying
            ELSE params.coaddr3
        END AS our_addr3,
        CASE
            WHEN (params.coaddr4 IS NULL) THEN ''::character varying
            ELSE params.coaddr4
        END AS our_addr4,
        CASE
            WHEN (params.coaddr5 IS NULL) THEN ''::character varying
            ELSE params.coaddr5
        END AS our_addr5,
        CASE
            WHEN (params.coaddr6 IS NULL) THEN ''::character varying
            ELSE params.coaddr6
        END AS our_addr6,
    client.name AS client_name,
    client.longname AS client_longname,
        CASE
            WHEN (client.addr1 IS NULL) THEN ''::character varying
            ELSE client.addr1
        END AS client_addr1,
        CASE
            WHEN (client.addr2 IS NULL) THEN ''::character varying
            ELSE client.addr2
        END AS client_addr2,
        CASE
            WHEN (client.addr3 IS NULL) THEN ''::character varying
            ELSE client.addr3
        END AS client_addr3,
        CASE
            WHEN (client.addr4 IS NULL) THEN ''::character varying
            ELSE client.addr4
        END AS client_addr4,
        CASE
            WHEN (client.addr5 IS NULL) THEN ''::character varying
            ELSE client.addr5
        END AS client_addr5,
        CASE
            WHEN (client.addr6 IS NULL) THEN ''::character varying
            ELSE client.addr6
        END AS client_addr6,
    invoice.allocation_reference,
    invoice.invoice_type,
    invoice.client,
    invoice.invoice_number,
    invoice.invoice_date,
    invoice.company,
    invoice.pcentre,
    invoice.commodity,
    invoice.commodity_type,
    invoice.origin,
    invoice.total_tonnage,
    invoice.percentage_invoiced,
    invoice.commission_rate,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.posted_date,
    invoice.posted_ledref,
    invoice.description AS cp_inv_desc,
    invoice.marks,
    invoice.weights,
    invoice.goods_lying,
    invoice.vessel,
    invoice.warehouse,
    invoice.warrant_number,
    invoice.draft_number,
    invoice.price_terms,
    invoice.price_terms_location,
    invoice.payment_terms,
    payment_term.name AS payterm_name,
    payment_term.longname AS payterm_longname,
    invoice.payment_instruction,
    payment_instruction.name AS payinstruct_name,
    payment_instruction.longname AS payinstruct_longname,
    invoice.due_date,
    invoice_charges.charges_line,
    invoice_charges.expenses_type,
    invoice_charges.crdrindicator,
    invoice_charges.amount_indicator,
    invoice_charges.amount,
    invoice_charges.currency AS cp_charge_currency,
    invoice_charges.price_unit,
    invoice_charges.description AS cp_charges_desc,
    invoice_charges.exchange_rate AS cp_charge_exgrate,
    invoice_charges.nominal_account,
    invoice_charges.linevalue AS cp_charge_linevalue
   FROM ((((((public.params
     CROSS JOIN public.invoice)
     CROSS JOIN public.invoice_charges)
     LEFT JOIN public.clause ON ((params.invoice_end_clause = clause.code)))
     LEFT JOIN public.client ON ((invoice.client = client.code)))
     LEFT JOIN public.payment_term ON ((invoice.payment_terms = payment_term.code)))
     LEFT JOIN public.payment_instruction ON ((invoice.payment_instruction = payment_instruction.code)))
  WHERE ((invoice.invoice_type = invoice_charges.invoice_type) AND (invoice.client = invoice_charges.client) AND (invoice.invoice_number = invoice_charges.invoice_number));




CREATE OR REPLACE VIEW public.invoice_details AS
 SELECT invoice_details_1.invoice_type,
    invoice_details_1.client,
    invoice_details_1.invoice_number,
    invoice_details_1.contno,
    invoice_details_1.split,
    invoice_details_1.invoiced_quantity,
    invoice_details_1.positional_quantity,
    invoice_details_1.delivered_unit,
    invoice_details_1.delivered_quantity,
    invoice_details_1.stock_quantity,
    invoice_details_1.net_weight,
    invoice_details_1.gross_weight,
    invoice_details_1.tare,
    invoice_details_1.unit_price,
    invoice_details_1.description,
    invoice_details_1.exchange_rate,
    invoice_details_1.linevalue,
    invoice_details_1.delivered_weight_unit,
    invoice_details_1.fands_wgt,
    invoice_details_1.slack_wgt,
    invoice_details_1.dmgdfull_wgt,
    invoice_details_1.short_wgt,
    invoice_details_1.dmgdtrnslack_bag,
    invoice_details_1.fands_bag,
    invoice_details_1.slack_bag,
    invoice_details_1.dmgdfull_bag,
    invoice_details_1.short_bag,
    invoice_details_1.dmgdtrnslack_wgt,
    invoice_details_1.samples,
    invoice_details_1.tare_wgt,
    invoice_details_1.nomcode,
    public.sp_convert_qty(invoice_details_1.invoiced_quantity, invoice_details_1.delivered_unit, 'MT'::bpchar) AS invoiced_quantity_tonnage,
    public.sp_convert_qty(invoice_details_1.positional_quantity, invoice_details_1.delivered_unit, 'MT'::bpchar) AS position_quantity_tonnage,
    invoice_details_1.invoice_unit_price,
    invoice_details_1.vatcode,
    invoice_details_1.freight_value
   FROM public.invoice_details_1
UNION
 SELECT invoice_details_2.invoice_type,
    invoice_details_2.client,
    invoice_details_2.invoice_number,
    invoice_details_2.contno,
    invoice_details_2.split,
    invoice_details_2.invoiced_quantity,
    invoice_details_2.positional_quantity,
    invoice_details_2.delivered_unit,
    invoice_details_2.delivered_quantity,
    invoice_details_2.stock_quantity,
    invoice_details_2.net_weight,
    invoice_details_2.gross_weight,
    invoice_details_2.tare,
    invoice_details_2.unit_price,
    invoice_details_2.description,
    invoice_details_2.exchange_rate,
    invoice_details_2.linevalue,
    invoice_details_2.delivered_weight_unit,
    invoice_details_2.fands_wgt,
    invoice_details_2.slack_wgt,
    invoice_details_2.dmgdfull_wgt,
    invoice_details_2.short_wgt,
    invoice_details_2.dmgdtrnslack_bag,
    invoice_details_2.fands_bag,
    invoice_details_2.slack_bag,
    invoice_details_2.dmgdfull_bag,
    invoice_details_2.short_bag,
    invoice_details_2.dmgdtrnslack_wgt,
    invoice_details_2.samples,
    invoice_details_2.tare_wgt,
    invoice_details_2.nomcode,
    public.sp_convert_qty(invoice_details_2.invoiced_quantity, invoice_details_2.delivered_unit, 'MT'::bpchar) AS invoiced_quantity_tonnage,
    public.sp_convert_qty(invoice_details_2.positional_quantity, invoice_details_2.delivered_unit, 'MT'::bpchar) AS position_quantity_tonnage,
    invoice_details_2.invoice_unit_price,
    invoice_details_2.vatcode,
    invoice_details_2.freight_value
   FROM public.invoice_details_2;




CREATE OR REPLACE VIEW public.invoice_contracts_view AS
 SELECT params.systemdate,
    company.name AS our_name,
    company.longname AS our_longname,
        CASE
            WHEN (company.addr1 IS NULL) THEN ''::character varying
            ELSE company.addr1
        END AS our_addr1,
        CASE
            WHEN (company.addr2 IS NULL) THEN ''::character varying
            ELSE company.addr2
        END AS our_addr2,
        CASE
            WHEN (company.addr3 IS NULL) THEN ''::character varying
            ELSE company.addr3
        END AS our_addr3,
        CASE
            WHEN (company.addr4 IS NULL) THEN ''::character varying
            ELSE company.addr4
        END AS our_addr4,
        CASE
            WHEN (company.addr5 IS NULL) THEN ''::character varying
            ELSE company.addr5
        END AS our_addr5,
        CASE
            WHEN (company.addr6 IS NULL) THEN ''::character varying
            ELSE company.addr6
        END AS our_addr6,
    client.name AS client_name,
    client.longname AS client_longname,
        CASE
            WHEN (client.addr1 IS NULL) THEN ''::character varying
            ELSE client.addr1
        END AS client_addr1,
        CASE
            WHEN (client.addr2 IS NULL) THEN ''::character varying
            ELSE client.addr2
        END AS client_addr2,
        CASE
            WHEN (client.addr3 IS NULL) THEN ''::character varying
            ELSE client.addr3
        END AS client_addr3,
        CASE
            WHEN (client.addr4 IS NULL) THEN ''::character varying
            ELSE client.addr4
        END AS client_addr4,
        CASE
            WHEN (client.addr5 IS NULL) THEN ''::character varying
            ELSE client.addr5
        END AS client_addr5,
        CASE
            WHEN (client.addr6 IS NULL) THEN ''::character varying
            ELSE client.addr6
        END AS client_addr6,
    invoice.allocation_reference,
    invoice.invoice_type,
    invoice.client,
    invoice.invoice_number,
    invoice.invoice_date,
    invoice.company,
    invoice.pcentre,
    invoice.commodity,
    invoice.commodity_type,
    invoice.origin,
    invoice.total_tonnage,
    invoice.percentage_invoiced,
    invoice.commission_rate,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.posted_date,
    invoice.posted_ledref,
    invoice.description AS cp_inv_desc,
    invoice.marks,
    invoice.weights,
    invoice.goods_lying,
    invoice.vessel,
    invoice.warehouse,
    invoice.warrant_number,
    invoice.draft_number,
    invoice.price_terms,
    invoice.price_terms_location,
    invoice.payment_terms,
    invoice.bl_number,
    invoice.bl_date,
    invoice.port_of_origin,
    invoice.destination,
    payment_term.name AS payterm_name,
    payment_term.longname AS payterm_longname,
    invoice.payment_instruction,
    payment_instruction.name AS payinstruct_name,
    payment_instruction.longname AS payinstruct_longname,
    invoice.due_date,
    invoice_details.contno,
    invoice_details.split,
    invoice_details.invoiced_quantity,
    invoice_details.positional_quantity,
    invoice_details.delivered_unit,
    invoice_details.delivered_quantity,
    invoice_details.stock_quantity,
    invoice_details.net_weight,
    invoice_details.gross_weight,
    invoice_details.tare,
    invoice_details.unit_price,
    invoice_details.description AS cp_invdet_desc,
    invoice_details.exchange_rate AS cp_invdet_exgrate,
    invoice_details.linevalue AS cp_invdet_linevalue,
    master_contracts.commodity AS master_commodity,
    commodity.name AS commodity_name,
    commodity.longname AS commodity_longname,
    master_contracts.commodtype,
    commodity_type.name AS commodtype_name,
    commodity_type.longname AS commodtype_longname,
    master_contracts.origin AS master_origin,
    origin.name AS origin_name,
    origin.longname AS origin_longname,
    sub_contracts.quantunit,
    quantunit.name AS quantunit_name,
    quantunit.longname AS quantunit_longname,
    sub_contracts.priceunit,
    priceunit.name AS priceunit_name,
    priceunit.longname AS priceunit_longname,
    sub_contracts.currency,
    (((((origin.longname)::text || ' '::text) || (commodity_type.longname)::text) || ' '::text) || (commodity.longname)::text) AS cp_contdesc,
    invoice.clientref
   FROM (((((((((((((public.params
     CROSS JOIN public.invoice)
     CROSS JOIN public.invoice_details)
     CROSS JOIN public.client)
     CROSS JOIN public.master_contracts)
     CROSS JOIN public.sub_contracts)
     CROSS JOIN public.unit quantunit)
     CROSS JOIN public.unit priceunit)
     CROSS JOIN public.commodity)
     CROSS JOIN public.commodity_type)
     CROSS JOIN public.origin)
     CROSS JOIN public.company)
     LEFT JOIN public.payment_term ON ((invoice.payment_terms = payment_term.code)))
     LEFT JOIN public.payment_instruction ON ((invoice.payment_instruction = payment_instruction.code)))
  WHERE ((invoice.invoice_type = invoice_details.invoice_type) AND (invoice.client = invoice_details.client) AND (invoice.invoice_number = invoice_details.invoice_number) AND (sub_contracts.contno = master_contracts.contno) AND (invoice_details.contno = sub_contracts.contno) AND (invoice_details.split = sub_contracts.split) AND (master_contracts.commodity = commodity.code) AND (master_contracts.commodtype = commodity_type.code) AND (master_contracts.origin = origin.code) AND (sub_contracts.quantunit = quantunit.code) AND (sub_contracts.priceunit = priceunit.code) AND (invoice.client = client.code) AND (invoice.company = company.code));




CREATE OR REPLACE VIEW public.invoice_details_2_copy_of_original_view AS
 SELECT stocks.contno,
    stocks.split,
    sum(stocks.net_shipped_weight) AS stock_quantity,
    stocks.original_allocation_reference,
    stocks.original_invoice_number,
    stocks.original_invoice_type,
    stocks.original_client
   FROM public.stocks,
    public.invoice_stocks
  WHERE ((stocks.original_invoice_number = invoice_stocks.invoice_number) AND (stocks.original_invoice_type = invoice_stocks.invoice_type) AND (stocks.original_client = invoice_stocks.client) AND (stocks.contno = invoice_stocks.contno) AND (stocks.split = invoice_stocks.split) AND (stocks.stock_id = invoice_stocks.stock_id))
  GROUP BY stocks.contno, stocks.split, stocks.original_allocation_reference, stocks.original_invoice_number, stocks.original_invoice_type, stocks.original_client
  ORDER BY stocks.contno, stocks.split, stocks.original_allocation_reference, stocks.original_invoice_number, stocks.original_invoice_type, stocks.original_client;




CREATE OR REPLACE VIEW public.invoices_stocks_view AS
 SELECT params.base_unit,
    invoice_stocks.invoice_number,
    invoice_stocks.client,
    invoice_stocks.invoice_type,
    invoice_stocks.contno,
    invoice_stocks.split,
    invoice_stocks.stock_id,
    invoice_stocks.stock_quantity,
    stocks.allocation_reference,
    stocks.quantity_unit,
    public.sp_convert_qty(invoice_stocks.stock_quantity, stocks.quantity_unit, params.base_unit) AS invoices_stock_base
   FROM public.invoice_stocks,
    public.invoice,
    public.stocks,
    public.params
  WHERE ((invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id) AND (invoice_stocks.invoice_number = invoice.invoice_number) AND (invoice_stocks.client = invoice.client) AND (invoice_stocks.invoice_type = invoice.invoice_type));




CREATE OR REPLACE VIEW public.leds_view AS
 SELECT accsummary.accperiod,
    accsummary.ledgernum,
    accsummary.leddate,
    accsummary.journals,
    accsummary.pcentre,
    accsummary.company,
    accsummary.project,
    accsummary.duedate,
    accsummary.refno,
    accsummary.analysis1,
    accsummary.analysis2,
    accsummary.analysis3,
    accsummary.analysis4,
    accsummary.analysis5,
    accsummary.sett_batchref,
    accsummary.system_generated,
    accsummary.userid,
    accsummary.histdate,
    accsummary.histtime,
    accsummary.reversed,
    accdetail.linenum,
    accdetail.currency,
    accdetail.client,
    accdetail.nominal,
    accdetail.ledamt,
    accdetail.vatcode,
    accdetail.comments,
    accdetail.matchref,
    accdetail.exported,
    public.sp_cr_or_dr(accdetail.ledamt, 'C'::bpchar) AS creditamt,
    public.sp_cr_or_dr(accdetail.ledamt, 'D'::bpchar) AS debitamt,
    public.sp_c_or_d(accdetail.ledamt) AS crind,
    acctypes.type,
    accdetail.house_rate,
    nomcodes.longname AS nominalname,
    nomcodes.isdebtlist,
    nomcodes.preventfxreval,
    nomcodes.preventpost,
    accsummary.an_client,
    accsummary.an_commodity,
    accsummary.an_commodtype,
    accsummary.an_origin,
    accsummary.an_futconts,
    accsummary.an_prompt,
    accsummary.an_tradetype,
    accsummary.an_series,
    accsummary.an_allocref,
    accsummary.an_invtype,
    accsummary.an_conttype,
    accsummary.an_vessel,
        CASE
            WHEN (currency.ratetype = 'M'::bpchar) THEN (accdetail.ledamt * accdetail.house_rate)
            ELSE (accdetail.ledamt / accdetail.house_rate)
        END AS base_amt,
    accdetail.subsidiary
   FROM public.accsummary,
    public.accdetail,
    public.nomcodes,
    public.acctypes,
    public.currency
  WHERE ((accsummary.ledgernum = accdetail.ledgernum) AND (accsummary.accperiod = accdetail.accperiod) AND (nomcodes.code = accdetail.nominal) AND (currency.code = accdetail.currency) AND (acctypes.accnt_type = nomcodes.accnt_type));




CREATE OR REPLACE VIEW public.nom_accbals_view AS
 SELECT accsummary.company,
    accsummary.pcentre,
    accdetail.nominal,
    accdetail.currency,
    sum(accdetail.ledamt) AS balance
   FROM public.accsummary,
    public.accdetail
  WHERE ((accsummary.accperiod = accdetail.accperiod) AND (accsummary.ledgernum = accdetail.ledgernum) AND (accdetail.client IS NULL))
  GROUP BY accsummary.company, accsummary.pcentre, accdetail.currency, accdetail.nominal;




CREATE OR REPLACE VIEW public.phys_alloc AS
 SELECT contno,
    split,
    allocation_reference,
    COALESCE(( SELECT sum(id_2.positional_quantity) AS sum
           FROM (public.invoice i
             JOIN public.invoice_details_2 id_2 ON (((i.client = id_2.client) AND (i.invoice_number = id_2.invoice_number) AND (i.invoice_type = id_2.invoice_type))))
          WHERE ((ac.allocation_reference = id_2.allocation_reference) AND (ac.contno = id_2.contno) AND (ac.split = id_2.split) AND (i.posted_ledref IS NOT NULL))), (0)::numeric) AS inv_allocated,
    (quantity - COALESCE(( SELECT sum(id_2.positional_quantity) AS sum
           FROM (public.invoice i
             JOIN public.invoice_details_2 id_2 ON (((i.client = id_2.client) AND (i.invoice_number = id_2.invoice_number) AND (i.invoice_type = id_2.invoice_type))))
          WHERE ((ac.allocation_reference = id_2.allocation_reference) AND (ac.contno = id_2.contno) AND (ac.split = id_2.split) AND (i.posted_ledref IS NOT NULL))), (0)::numeric)) AS inv_unallocated
   FROM public.allocated_contracts ac;




CREATE OR REPLACE VIEW public.phys_fixes AS
 SELECT a.contno,
    a.split,
    a.quantunit,
    e.fixid,
    e.fixdate,
    public.sp_convert_qty(e.quantity, e.quantunit, a.quantunit) AS fixed_qty
   FROM (public.sub_contracts a
     LEFT JOIN public.fixes e ON (((a.contno = e.contno) AND (a.split = e.split))));




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




CREATE OR REPLACE VIEW public.phys_avail AS
 SELECT a.contno,
    a.split,
    b.contract_type,
    a.orgunquant AS original,
    a.quantunit,
    a.unquantity AS openqnt,
    (a.orgunquant - a.unquantity) AS moved,
    COALESCE(( SELECT sum(c.quantity) AS sum
           FROM public.allocated_contracts c
          WHERE ((c.contno = a.contno) AND (c.split = a.split))), (0)::numeric) AS allocated,
    (a.orgunquant - COALESCE(( SELECT sum(c.quantity) AS sum
           FROM public.allocated_contracts c
          WHERE ((c.contno = a.contno) AND (c.split = a.split))), (0)::numeric)) AS unallocated,
    COALESCE(( SELECT sum(c.quantity) AS sum
           FROM public.shipment_contracts c
          WHERE ((c.contno = a.contno) AND (c.split = a.split))), (0)::numeric) AS shipped,
    (a.orgunquant - COALESCE(( SELECT sum(c.quantity) AS sum
           FROM public.shipment_contracts c
          WHERE ((c.contno = a.contno) AND (c.split = a.split))), (0)::numeric)) AS unshipped,
    COALESCE(( SELECT sum(d.positional_quantity) AS sum
           FROM public.invoice_details_2 d
          WHERE ((d.contno = a.contno) AND (d.split = a.split))), (0)::numeric) AS invoiced,
    (a.orgunquant - a.unquantity) AS invposted,
    COALESCE(( SELECT sum(f.quantity) AS sum
           FROM public.booking f
          WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric) AS booked,
    (a.orgunquant - COALESCE(( SELECT sum(f.quantity) AS sum
           FROM public.booking f
          WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric)) AS unbooked,
    a.cleared_quantity,
    (COALESCE(( SELECT sum(d.positional_quantity) AS sum
           FROM public.invoice_details_2 d
          WHERE ((d.contno = a.contno) AND (d.split = a.split))), (0)::numeric) - (a.orgunquant - a.unquantity)) AS invunposted,
    ((a.orgunquant - COALESCE(( SELECT sum(d.positional_quantity) AS sum
           FROM public.invoice_details_2 d
          WHERE ((d.contno = a.contno) AND (d.split = a.split))), (0)::numeric)) - a.cleared_quantity) AS uninvoiced,
    a.price_fixing,
    COALESCE(( SELECT sum(f.fixed_qty) AS sum
           FROM public.phys_fixes f
          WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)) AS fixed,
        CASE
            WHEN (a.price_fixing = 'Y'::bpchar) THEN (a.orgunquant - COALESCE(( SELECT sum(f.fixed_qty) AS sum
               FROM public.phys_fixes f
              WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)))
            ELSE (0)::numeric(16,4)
        END AS unfixed,
    COALESCE(( SELECT sum(f.lots) AS sum
           FROM public.fixes f
          WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric) AS fixedlots,
        CASE
            WHEN (a.price_fixing = 'Y'::bpchar) THEN (a.pflots - COALESCE(( SELECT sum(f.lots) AS sum
               FROM public.fixes f
              WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric))
            ELSE (0)::numeric
        END AS unfixedlots,
    public.sp_convert_qty(COALESCE(( SELECT sum(f.fixed_qty) AS sum
           FROM public.phys_fixes f
          WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)), a.quantunit, params.base_unit) AS fixed_base,
    public.sp_convert_qty(
        CASE
            WHEN (a.price_fixing = 'Y'::bpchar) THEN (a.orgunquant - COALESCE(( SELECT sum(f.fixed_qty) AS sum
               FROM public.phys_fixes f
              WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)))
            ELSE (0)::numeric(16,4)
        END, a.quantunit, params.base_unit) AS unfixed_base,
    a.fixbydate,
    COALESCE(( SELECT sum(s.stock_qty) AS sum
           FROM public.phys_stocks s
          WHERE ((s.contno = a.contno) AND (s.split = a.split))), (0)::numeric) AS stock,
    COALESCE(( SELECT sum(ist.stock_quantity) AS sum
           FROM public.invoice_stocks ist
          WHERE ((ist.contno = a.contno) AND (ist.split = a.split) AND (ist.invoice_type = 'P'::bpchar))), (0)::numeric) AS inv_stock,
    b.weights
   FROM ((public.sub_contracts a
     JOIN public.master_contracts b ON ((b.contno = a.contno)))
     CROSS JOIN public.params);




CREATE OR REPLACE VIEW public.phys_avail3 AS
 SELECT contno,
    split,
    COALESCE(( SELECT sum(pa.inv_unallocated) AS sum
           FROM public.phys_alloc pa
          WHERE ((pa.contno = sc.contno) AND (pa.split = sc.split))), (0)::numeric) AS phys_allocated,
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM public.fixes f
              WHERE ((f.contno = sc.contno) AND (f.split = sc.split)))) THEN 1
            ELSE 0
        END AS fixed,
    unquantity AS openqnt,
    orgunquant AS original
   FROM public.sub_contracts sc;




CREATE OR REPLACE VIEW public.phys_avail_valn_sopex AS
 SELECT a.contno,
    a.split,
    b.contract_type,
    a.orgunquant AS original,
    a.quantunit,
    a.orgunquant AS openqnt,
    a.price_fixing,
    COALESCE(( SELECT sum(f.fixed_qty) AS sum
           FROM public.phys_fixes f
          WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)) AS fixed,
        CASE
            WHEN (a.price_fixing = 'Y'::bpchar) THEN (a.orgunquant - COALESCE(( SELECT sum(f.fixed_qty) AS sum
               FROM public.phys_fixes f
              WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)))
            ELSE (0)::numeric(16,4)
        END AS unfixed,
    public.sp_convert_qty(COALESCE(( SELECT sum(f.fixed_qty) AS sum
           FROM public.phys_fixes f
          WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)), a.quantunit, params.base_unit) AS fixed_base,
    public.sp_convert_qty(
        CASE
            WHEN (a.price_fixing = 'Y'::bpchar) THEN (a.orgunquant - COALESCE(( SELECT sum(f.fixed_qty) AS sum
               FROM public.phys_fixes f
              WHERE ((f.contno = a.contno) AND (f.split = a.split))), (0)::numeric(16,4)))
            ELSE (0)::numeric(16,4)
        END, a.quantunit, params.base_unit) AS unfixed_base
   FROM ((public.sub_contracts a
     JOIN public.master_contracts b ON ((b.contno = a.contno)))
     CROSS JOIN public.params);




CREATE OR REPLACE VIEW public.phys_fxhedge_breakdown AS
 SELECT c.contno,
    c.split,
    a.contdate,
    a.seqno,
    a.contno AS termcontno,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tradetype,
    a.tprice,
    a.lots,
    a.hedgeable,
    a.mktcurr,
    a.othercurr,
    a.dealratetype,
    b.quantity AS hedgedqty
   FROM ((public.sub_contracts c
     LEFT JOIN public.forex_hedges b ON (((c.contno = b.contno) AND (c.split = b.split))))
     LEFT JOIN public.term_view a ON (((b.termdate = a.contdate) AND (b.termseqno = a.seqno))))
  WHERE ((a.hedge = 'Y'::bpchar) AND (a.tradetype = 'X'::bpchar));




CREATE OR REPLACE VIEW public.phys_open_view AS
 SELECT b.contno,
    b.split,
    h.systemdate,
    a.company,
    a.pcentre,
    a.commodity,
    a.commodtype,
    a.origin,
    b.valuedin,
    a.contract_type,
    b.orgunquant AS original,
    b.quantunit,
    b.unquantity AS openqnt,
    (b.orgunquant - b.unquantity) AS moved,
    COALESCE(( SELECT sum(c.quantity) AS sum
           FROM public.allocated_contracts c
          WHERE ((c.contno = b.contno) AND (c.split = b.split))), (0)::numeric) AS allocated,
    (b.orgunquant - COALESCE(( SELECT sum(c.quantity) AS sum
           FROM public.allocated_contracts c
          WHERE ((c.contno = b.contno) AND (c.split = b.split))), (0)::numeric)) AS unallocated,
    COALESCE(( SELECT sum(d.positional_quantity) AS sum
           FROM public.invoice_details d
          WHERE ((d.contno = b.contno) AND (d.split = b.split))), (0)::numeric) AS invoiced,
    (b.orgunquant - b.unquantity) AS invposted,
    (COALESCE(( SELECT sum(d.positional_quantity) AS sum
           FROM public.invoice_details d
          WHERE ((d.contno = b.contno) AND (d.split = b.split))), (0)::numeric) - (b.orgunquant - b.unquantity)) AS invunposted,
    (b.orgunquant - COALESCE(( SELECT sum(d.positional_quantity) AS sum
           FROM public.invoice_details d
          WHERE ((d.contno = b.contno) AND (d.split = b.split))), (0)::numeric)) AS uninvoiced,
    b.price_fixing,
    COALESCE(( SELECT sum(f.fixed_qty) AS sum
           FROM public.phys_fixes f
          WHERE ((f.contno = b.contno) AND (f.split = b.split))), (0)::numeric(16,4)) AS fixed,
        CASE
            WHEN (b.price_fixing = 'Y'::bpchar) THEN (b.orgunquant - COALESCE(( SELECT sum(f.fixed_qty) AS sum
               FROM public.phys_fixes f
              WHERE ((f.contno = b.contno) AND (f.split = b.split))), (0)::numeric(16,4)))
            ELSE (0)::numeric(16,4)
        END AS unfixed,
    COALESCE(( SELECT sum(f.lots) AS sum
           FROM public.fixes f
          WHERE ((f.contno = b.contno) AND (f.split = b.split))), (0)::numeric) AS fixedlots,
        CASE
            WHEN (b.price_fixing = 'Y'::bpchar) THEN (b.pflots - COALESCE(( SELECT sum(f.lots) AS sum
               FROM public.fixes f
              WHERE ((f.contno = b.contno) AND (f.split = b.split))), (0)::numeric))
            ELSE (0)::numeric
        END AS unfixedlots,
    COALESCE(( SELECT sum(s.stock_qty) AS sum
           FROM public.phys_stocks s
          WHERE ((s.contno = b.contno) AND (s.split = b.split))), (0)::numeric) AS stock
   FROM ((public.master_contracts a
     JOIN public.sub_contracts b ON ((a.contno = b.contno)))
     CROSS JOIN public.params h);




CREATE OR REPLACE VIEW public.phys_org_contval AS
 WITH fixes_qty AS (
         SELECT fixes.contno,
            fixes.split,
            sum(fixes.quantity) AS quantity
           FROM public.fixes
          GROUP BY fixes.contno, fixes.split
        )
 SELECT sc.contno,
    sc.split,
    sc.orgunquant AS quantity,
    sc.quantunit,
    sc.unitprice,
    sc.currency,
    sc.priceunit,
    (public.sp_convert_qty(sc.orgunquant, sc.quantunit, sc.priceunit) * sc.unitprice) AS contvalue,
    public.sp_convert_qty(sc.orgunquant, sc.quantunit, params.base_unit) AS baseorgqty
   FROM (public.sub_contracts sc
     CROSS JOIN public.params)
  WHERE ((sc.price_fixing = 'N'::bpchar) AND (sc.orgunquant > (0)::numeric) AND (sc.currency <> params.base_currency))
UNION
 SELECT sc.contno,
    sc.split,
    fq.quantity,
    sc.quantunit,
    public.sp_phys_avefixprice(sc.contno, sc.split) AS unitprice,
    sc.currency,
    sc.priceunit,
    (public.sp_convert_qty(fq.quantity, sc.quantunit, sc.priceunit) * public.sp_phys_avefixprice(sc.contno, sc.split)) AS contvalue,
    public.sp_convert_qty(fq.quantity, sc.quantunit, params.base_unit) AS baseorgqty
   FROM ((public.sub_contracts sc
     CROSS JOIN public.params)
     LEFT JOIN fixes_qty fq ON (((fq.contno = sc.contno) AND (fq.split = sc.split))))
  WHERE ((sc.price_fixing = 'Y'::bpchar) AND (sc.orgunquant > (0)::numeric) AND (sc.currency <> params.base_currency));




CREATE OR REPLACE VIEW public.phys_pricing AS
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'FW_FIX'::text AS flag,
    b.original,
    b.quantunit,
    b.openqnt,
    a.price_fixing,
    b.unfixed,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'N'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'FW_PFUNFIX'::text AS flag,
    b.original,
    b.quantunit,
        CASE
            WHEN (b.openqnt < b.unfixed) THEN b.openqnt
            ELSE b.unfixed
        END AS openqnt,
    a.price_fixing,
    b.unfixed,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'FW_PFFIX'::text AS flag,
    b.original,
    b.quantunit,
        CASE
            WHEN ((b.openqnt - b.unfixed) > (0)::numeric) THEN (b.openqnt - b.unfixed)
            ELSE (0)::numeric
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    b.unfixed,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty((b.openqnt - b.unfixed), b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty((b.openqnt - b.unfixed), b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'ST_FIX'::text AS flag,
    b.original,
    b.quantunit,
    b.stock AS openqnt,
    a.price_fixing,
    b.unfixed,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.stock, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(b.stock, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'N'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'ST_PFUNFIX'::text AS flag,
    b.original,
    b.quantunit,
        CASE
            WHEN ((b.stock - b.fixed) > (0)::numeric) THEN (b.stock - b.fixed)
            ELSE (0)::numeric
        END AS openqnt,
    a.price_fixing,
    b.unfixed,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty((b.stock - b.fixed), b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty((b.stock - b.fixed), b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'ST_PFFIX'::text AS flag,
    b.original,
    b.quantunit,
        CASE
            WHEN (b.stock < b.fixed) THEN b.stock
            ELSE b.fixed
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    b.unfixed,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.fixed, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(b.fixed, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar);




CREATE OR REPLACE VIEW public.phys_pricing2 AS
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'Y'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN ((b.openqnt - b.unallocated) > (0)::numeric) THEN (b.openqnt - b.unallocated)
            ELSE (0)::numeric
        END AS openqnt,
    a.price_fixing,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'N'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'Y'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN ((
            CASE
                WHEN (b.openqnt < b.unfixed) THEN b.openqnt
                ELSE b.unfixed
            END - b.unallocated) > (0)::numeric) THEN (
            CASE
                WHEN (b.openqnt < b.unfixed) THEN b.openqnt
                ELSE b.unfixed
            END - b.unallocated)
            ELSE (0)::numeric
        END AS openqnt,
    a.price_fixing,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'Y'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN ((
            CASE
                WHEN ((b.openqnt - b.unfixed) > (0)::numeric) THEN (b.openqnt - b.unfixed)
                ELSE (0)::numeric
            END - b.unallocated) > (0)::numeric) THEN (
            CASE
                WHEN ((b.openqnt - b.unfixed) > (0)::numeric) THEN (b.openqnt - b.unfixed)
                ELSE (0)::numeric
            END - b.unallocated)
            ELSE (0)::numeric
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'Y'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN ((b.stock - b.unallocated) > (0)::numeric) THEN (b.stock - b.unallocated)
            ELSE (0)::numeric
        END AS openqnt,
    a.price_fixing,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'N'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'Y'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN ((
            CASE
                WHEN ((b.stock - b.fixed) > (0)::numeric) THEN (b.stock - b.fixed)
                ELSE (0)::numeric
            END - b.unallocated) > (0)::numeric) THEN (
            CASE
                WHEN ((b.stock - b.fixed) > (0)::numeric) THEN (b.stock - b.fixed)
                ELSE (0)::numeric
            END - b.unallocated)
            ELSE (0)::numeric
        END AS openqnt,
    a.price_fixing,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'Y'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN ((
            CASE
                WHEN (b.stock < b.fixed) THEN b.stock
                ELSE b.fixed
            END - b.unallocated) > (0)::numeric) THEN (
            CASE
                WHEN (b.stock < b.fixed) THEN b.stock
                ELSE b.fixed
            END - b.unallocated)
            ELSE (0)::numeric
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'N'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN (b.openqnt > b.unallocated) THEN b.unallocated
            ELSE b.openqnt
        END AS openqnt,
    a.price_fixing,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'N'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'N'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN (
            CASE
                WHEN (b.openqnt < b.unfixed) THEN b.openqnt
                ELSE b.unfixed
            END > b.unallocated) THEN b.unallocated
            ELSE
            CASE
                WHEN (b.openqnt < b.unfixed) THEN b.openqnt
                ELSE b.unfixed
            END
        END AS openqnt,
    a.price_fixing,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    'N'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN (
            CASE
                WHEN ((b.openqnt - b.unfixed) > (0)::numeric) THEN (b.openqnt - b.unfixed)
                ELSE (0)::numeric
            END > b.unallocated) THEN b.unallocated
            ELSE
            CASE
                WHEN ((b.openqnt - b.unfixed) > (0)::numeric) THEN (b.openqnt - b.unfixed)
                ELSE (0)::numeric
            END
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'N'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN (b.stock > b.unallocated) THEN b.unallocated
            ELSE b.stock
        END AS openqnt,
    a.price_fixing,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'N'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'N'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN (
            CASE
                WHEN ((b.stock - b.fixed) > (0)::numeric) THEN (b.stock - b.fixed)
                ELSE (0)::numeric
            END > b.unallocated) THEN b.unallocated
            ELSE
            CASE
                WHEN ((b.stock - b.fixed) > (0)::numeric) THEN (b.stock - b.fixed)
                ELSE (0)::numeric
            END
        END AS openqnt,
    a.price_fixing,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar)
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    'N'::text AS allocated,
    b.original,
    b.quantunit,
        CASE
            WHEN (
            CASE
                WHEN (b.stock < b.fixed) THEN b.stock
                ELSE b.fixed
            END > b.unallocated) THEN b.unallocated
            ELSE
            CASE
                WHEN (b.stock < b.fixed) THEN b.stock
                ELSE b.fixed
            END
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit
   FROM ((public.sub_contracts a
     JOIN public.phys_avail b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
  WHERE (a.price_fixing = 'Y'::bpchar);




CREATE OR REPLACE VIEW public.phys_pricing3 AS
 SELECT 'FORWARD'::text AS status,
    pa.allocation_reference,
    pa.contno,
    pa.split,
    NULL::integer AS stock_id,
    pa.inv_unallocated AS openqnt,
    sc.price_fixing,
    sc.unitprice,
    sc.currency,
    sc.priceunit,
    sc.pfcontract,
    sc.pfposition,
    sc.pfdifftype,
    sc.pfdiffer,
    sc.pfoption,
    sc.pfdiffcurr,
    sc.pfdiffunit
   FROM (public.phys_alloc pa
     JOIN public.sub_contracts sc ON (((pa.contno = sc.contno) AND (pa.split = sc.split))))
  WHERE (sc.price_fixing = 'N'::bpchar)
UNION
 SELECT 'FORWARD'::text AS status,
    NULL::text AS allocation_reference,
    pa.contno,
    pa.split,
    NULL::integer AS stock_id,
        CASE
            WHEN ((pa.openqnt - pa.phys_allocated) > (0)::numeric) THEN (pa.openqnt - pa.phys_allocated)
            ELSE (0)::numeric
        END AS openqnt,
    sc.price_fixing,
    sc.unitprice,
    sc.currency,
    sc.priceunit,
    sc.pfcontract,
    sc.pfposition,
    sc.pfdifftype,
    sc.pfdiffer,
    sc.pfoption,
    sc.pfdiffcurr,
    sc.pfdiffunit
   FROM (public.phys_avail3 pa
     JOIN public.sub_contracts sc ON (((pa.contno = sc.contno) AND (pa.split = sc.split))))
  WHERE (sc.price_fixing = 'N'::bpchar)
UNION
 SELECT 'STOCK'::text AS status,
    s.allocation_reference,
    s.contno,
    s.split,
    s.stock_id,
    s.quantity AS openqnt,
    sc.price_fixing,
    sc.unitprice,
    sc.currency,
    sc.priceunit,
    sc.pfcontract,
    sc.pfposition,
    sc.pfdifftype,
    sc.pfdiffer,
    sc.pfoption,
    sc.pfdiffcurr,
    sc.pfdiffunit
   FROM (public.stocks s
     JOIN public.sub_contracts sc ON (((s.contno = sc.contno) AND (s.split = sc.split))))
  WHERE (sc.price_fixing = 'N'::bpchar)
UNION
 SELECT 'FORWARD'::text AS status,
    pac.allocation_reference,
    pac.contno,
    pac.split,
    NULL::integer AS stock_id,
    pac.inv_unallocated AS openqnt,
    sc.price_fixing,
    NULL::numeric AS unitprice,
    sc.currency,
    sc.priceunit,
    sc.pfcontract,
    sc.pfposition,
    sc.pfdifftype,
    sc.pfdiffer,
    sc.pfoption,
    sc.pfdiffcurr,
    sc.pfdiffunit
   FROM ((public.phys_alloc pac
     JOIN public.sub_contracts sc ON (((pac.contno = sc.contno) AND (pac.split = sc.split))))
     JOIN public.phys_avail3 pa ON (((pa.contno = sc.contno) AND (pa.split = sc.split))))
  WHERE ((sc.price_fixing = 'Y'::bpchar) AND (pa.fixed = 0))
UNION
 SELECT 'FORWARD'::text AS status,
    NULL::text AS allocation_reference,
    pa.contno,
    pa.split,
    NULL::integer AS stock_id,
        CASE
            WHEN ((pa.openqnt - pa.phys_allocated) > (0)::numeric) THEN (pa.openqnt - pa.phys_allocated)
            ELSE (0)::numeric
        END AS openqnt,
    sc.price_fixing,
    NULL::numeric AS unitprice,
    sc.currency,
    sc.priceunit,
    sc.pfcontract,
    sc.pfposition,
    sc.pfdifftype,
    sc.pfdiffer,
    sc.pfoption,
    sc.pfdiffcurr,
    sc.pfdiffunit
   FROM (public.phys_avail3 pa
     JOIN public.sub_contracts sc ON (((pa.contno = sc.contno) AND (pa.split = sc.split))))
  WHERE ((sc.price_fixing = 'Y'::bpchar) AND (pa.fixed = 0))
UNION
 SELECT 'STOCK'::text AS status,
    s.allocation_reference,
    s.contno,
    s.split,
    s.stock_id,
    s.quantity AS openqnt,
    sc.price_fixing,
    NULL::numeric AS unitprice,
    sc.currency,
    sc.priceunit,
    sc.pfcontract,
    sc.pfposition,
    sc.pfdifftype,
    sc.pfdiffer,
    sc.pfoption,
    sc.pfdiffcurr,
    sc.pfdiffunit
   FROM ((public.stocks s
     JOIN public.sub_contracts sc ON (((s.contno = sc.contno) AND (s.split = sc.split))))
     JOIN public.phys_avail3 pa ON (((sc.contno = pa.contno) AND (sc.split = pa.split))))
  WHERE ((sc.price_fixing = 'Y'::bpchar) AND (pa.fixed = 0))
UNION
 SELECT 'FORWARD'::text AS status,
    pac.allocation_reference,
    pac.contno,
    pac.split,
    NULL::numeric AS stock_id,
    pac.inv_unallocated AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(sc.contno, sc.split) AS unitprice,
    sc.currency,
    sc.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit
   FROM ((public.phys_alloc pac
     JOIN public.sub_contracts sc ON (((pac.contno = sc.contno) AND (pac.split = sc.split))))
     JOIN public.phys_avail3 pa ON (((pa.contno = sc.contno) AND (pa.split = sc.split))))
  WHERE ((sc.price_fixing = 'Y'::bpchar) AND (pa.fixed = 1))
UNION
 SELECT 'FORWARD'::text AS status,
    NULL::text AS allocation_reference,
    pa.contno,
    pa.split,
    NULL::integer AS stock_id,
        CASE
            WHEN ((pa.openqnt - pa.phys_allocated) > (0)::numeric) THEN (pa.openqnt - pa.phys_allocated)
            ELSE (0)::numeric
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(sc.contno, sc.split) AS unitprice,
    sc.currency,
    sc.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit
   FROM (public.phys_avail3 pa
     JOIN public.sub_contracts sc ON (((pa.contno = sc.contno) AND (pa.split = sc.split))))
  WHERE ((sc.price_fixing = 'Y'::bpchar) AND (pa.fixed = 1))
UNION
 SELECT 'STOCK'::text AS status,
    s.allocation_reference,
    s.contno,
    s.split,
    s.stock_id,
    s.quantity AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(sc.contno, sc.split) AS unitprice,
    sc.currency,
    sc.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit
   FROM ((public.stocks s
     JOIN public.sub_contracts sc ON (((s.contno = sc.contno) AND (s.split = sc.split))))
     JOIN public.phys_avail3 pa ON (((sc.contno = pa.contno) AND (sc.split = pa.split))))
  WHERE ((sc.price_fixing = 'Y'::bpchar) AND (pa.fixed = 1));




CREATE OR REPLACE VIEW public.phys_pricing_riskposn AS
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    b.original,
    b.quantunit,
    b.openqnt,
    a.price_fixing,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    a.valn_type,
    a.vlcontract,
    a.vlposition,
    c.pcentre,
    c.commodity,
    a.valuedin,
    c.commodtype,
    a.origin,
    a.quality
   FROM public.sub_contracts a,
    public.phys_avail b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'N'::bpchar) AND (c.contno = a.contno))
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    b.original,
    b.quantunit,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN
            CASE
                WHEN (b.openqnt < b.unfixed) THEN b.openqnt
                ELSE b.unfixed
            END
            ELSE b.unfixed
        END AS openqnt,
    a.price_fixing,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    a.valn_type,
    a.vlcontract,
    a.vlposition,
    c.pcentre,
    c.commodity,
    a.valuedin,
    c.commodtype,
    a.origin,
    a.quality
   FROM public.sub_contracts a,
    public.phys_avail b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'Y'::bpchar) AND (c.contno = a.contno))
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'FORWARD'::text AS status,
    b.original,
    b.quantunit,
        CASE
            WHEN ((b.openqnt - b.unfixed) > (0)::numeric) THEN (b.openqnt - b.unfixed)
            ELSE (0)::numeric
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit,
    c.company,
    a.valn_type,
    a.vlcontract,
    a.vlposition,
    c.pcentre,
    c.commodity,
    a.valuedin,
    c.commodtype,
    a.origin,
    a.quality
   FROM public.sub_contracts a,
    public.phys_avail b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'Y'::bpchar) AND (c.contno = a.contno))
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    b.original,
    b.quantunit,
    b.stock AS openqnt,
    a.price_fixing,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    a.valn_type,
    a.vlcontract,
    a.vlposition,
    c.pcentre,
    c.commodity,
    a.valuedin,
    c.commodtype,
    a.origin,
    a.quality
   FROM public.sub_contracts a,
    public.phys_avail b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'N'::bpchar) AND (c.contno = a.contno))
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    b.original,
    b.quantunit,
        CASE
            WHEN ((b.moved - b.fixed) > (0)::numeric) THEN (b.moved - b.fixed)
            ELSE (0)::numeric
        END AS openqnt,
    a.price_fixing,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    a.valn_type,
    a.vlcontract,
    a.vlposition,
    c.pcentre,
    c.commodity,
    a.valuedin,
    c.commodtype,
    a.origin,
    a.quality
   FROM public.sub_contracts a,
    public.phys_avail b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'Y'::bpchar) AND (c.contno = a.contno))
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'STOCK'::text AS status,
    b.original,
    b.quantunit,
        CASE
            WHEN (b.stock < b.fixed) THEN b.stock
            ELSE b.fixed
        END AS openqnt,
    'N'::bpchar AS price_fixing,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit,
    c.company,
    a.valn_type,
    a.vlcontract,
    a.vlposition,
    c.pcentre,
    c.commodity,
    a.valuedin,
    c.commodtype,
    a.origin,
    a.quality
   FROM public.sub_contracts a,
    public.phys_avail b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'Y'::bpchar) AND (c.contno = a.contno));




CREATE OR REPLACE VIEW public.phys_pricing_valn_sopex AS
 SELECT c.contract_type,
    a.contno,
    a.split,
    'TOTAL'::text AS status,
    'FIX'::text AS flag,
    b.original,
    b.quantunit,
    b.openqnt,
    a.price_fixing,
    b.unfixed,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.shipment,
    a.shipordelv,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.price_fixing AS original_price_fixing,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    a.pfposition AS original_pfposition,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm,
    a.tracking_unpriced,
    a.certification,
    a.eudr_flag
   FROM public.sub_contracts a,
    public.phys_avail_valn_sopex b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'N'::bpchar) AND (c.contno = a.contno))
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'TOTAL'::text AS status,
    'PFUNFIX'::text AS flag,
    b.original,
    b.quantunit,
    b.unfixed AS openqnt,
    a.price_fixing,
    b.unfixed,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.shipment,
    a.shipordelv,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.price_fixing AS original_price_fixing,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    a.pfposition AS original_pfposition,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm,
    a.tracking_unpriced,
    a.certification,
    a.eudr_flag
   FROM public.sub_contracts a,
    public.phys_avail_valn_sopex b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'Y'::bpchar) AND (c.contno = a.contno))
UNION
 SELECT c.contract_type,
    a.contno,
    a.split,
    'TOTAL'::text AS status,
    'PFFIX'::text AS flag,
    b.original,
    b.quantunit,
    b.fixed AS openqnt,
    'N'::bpchar AS price_fixing,
    b.unfixed,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.shipment,
    a.shipordelv,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.price_fixing AS original_price_fixing,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    a.pfposition AS original_pfposition,
    c.priceterm,
    c.prcstlocn AS prcst_location,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(b.openqnt, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS openqnt_tonnage,
    a.estmarket,
    a.payterm,
    a.tracking_unpriced,
    a.certification,
    a.eudr_flag
   FROM public.sub_contracts a,
    public.phys_avail_valn_sopex b,
    public.master_contracts c
  WHERE ((a.contno = b.contno) AND (a.split = b.split) AND (a.price_fixing = 'Y'::bpchar) AND (c.contno = a.contno));




CREATE OR REPLACE VIEW public.phys_pricing_valn_sopex_full_report AS
 WITH true_open_cte AS (
         SELECT a.contno,
            a.split,
                CASE
                    WHEN (b.unfixed > (0)::numeric) THEN b.openqnt
                    ELSE (b.openqnt - public.sp_allocation_calculate_only_normal_alloc_quantity(a.contno, a.split))
                END AS true_open_fix,
                CASE
                    WHEN (b.unfixed > (0)::numeric) THEN b.unfixed
                    ELSE (b.unfixed - public.sp_allocation_calculate_only_normal_alloc_quantity(a.contno, a.split))
                END AS true_open_pfunfix,
                CASE
                    WHEN (b.unfixed > (0)::numeric) THEN b.fixed
                    ELSE (b.fixed - public.sp_allocation_calculate_only_normal_alloc_quantity(a.contno, a.split))
                END AS true_open_pffix
           FROM (public.sub_contracts a
             JOIN public.phys_avail_valn_sopex b ON (((a.contno = b.contno) AND (a.split = b.split))))
        )
 SELECT c.contract_type,
    a.contno,
    a.split,
    'TOTAL'::text AS status,
    'FIX'::text AS flag,
    b.original,
    b.quantunit,
    b.openqnt,
    a.price_fixing,
    b.unfixed,
    a.unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.shipment,
    a.shipordelv,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.price_fixing AS original_price_fixing,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    a.pfposition AS original_pfposition,
    c.priceterm,
    c.prcstlocn AS prcst_location,
    t.true_open_fix AS true_open,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(t.true_open_fix, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(t.true_open_fix, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS base_openqnt,
    a.estmarket,
    a.payterm,
    a.tracking_unpriced,
    a.certification,
    a.eudr_flag,
    NULL::text AS price_fixing_diff_string,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN public.sp_pricestr_mmyy((
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit)
            ELSE public.sp_pricestr_mmyy((
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit)
        END AS valn_string,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlposition
            ELSE a.vlposition
        END AS chosen_vlposition,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlcontract
            ELSE a.vlcontract
        END AS chosen_vlcontract,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldifftype
            ELSE a.vldifftype
        END AS chosen_vldifftype,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffer
            ELSE a.vldiffer
        END AS chosen_vldiffer,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffcurr
            ELSE a.vldiffcurr
        END AS chosen_vldiffcurr,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffunit
            ELSE a.vldiffunit
        END AS chosen_vldiffunit,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlposition
            ELSE a.vlposition
        END AS valn_month,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN (('-1'::integer)::numeric * public.sp_calc_value(t.true_open_fix, a.quantunit, a.price_fixing, a.unitprice, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit, params.base_currency, params.systemdate))
            ELSE public.sp_calc_value(t.true_open_fix, a.quantunit, a.price_fixing, a.unitprice, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit, params.base_currency, params.systemdate)
        END AS phys_value,
    (
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN public.sp_calc_value(t.true_open_fix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit, params.base_currency, params.systemdate)
            ELSE public.sp_calc_value(t.true_open_fix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit, params.base_currency, params.systemdate)
        END * (
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
            ELSE 1
        END)::numeric) AS valn_value,
    public.sp_get_total_reserves_in_base(a.contno, a.split) AS costs_per_base_unit,
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END AS unit_to_mt_conversation_factor,
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END AS currency_to_basecurr_conversion_factor,
    ((a.unitprice *
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END) *
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END) AS unit_price_basecurr_mt,
    (COALESCE(NULLIF(((a.unitprice *
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END) *
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END), NULL::numeric), (((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
            ELSE 1
        END)::numeric * public.sp_calc_value(t.true_open_fix, a.quantunit, a.price_fixing, a.unitprice, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit, params.base_currency, params.systemdate)) / NULLIF(((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN 1
            ELSE '-1'::integer
        END)::numeric * public.sp_convert_qty(t.true_open_fix, b.quantunit, 'MT'::bpchar)), (0)::numeric))) + COALESCE(public.sp_get_total_reserves_in_base(a.contno, a.split), (0)::numeric)) AS final_price_basecurr_mt,
    ((
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN public.sp_calc_value(t.true_open_fix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit, params.base_currency, params.systemdate)
            ELSE public.sp_calc_value(t.true_open_fix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit, params.base_currency, params.systemdate)
        END * (
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
            ELSE 1
        END)::numeric) / NULLIF(((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN 1
            ELSE '-1'::integer
        END)::numeric * public.sp_convert_qty(t.true_open_fix, b.quantunit, 'MT'::bpchar)), (0)::numeric)) AS valuation_price_basecurr_mt
   FROM (((((public.sub_contracts a
     JOIN public.phys_avail_valn_sopex b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
     JOIN public.val_differentials d ON (((c.company = d.company) AND (c.pcentre = d.pcentre) AND (c.commodity = d.commodity) AND (c.commodtype = d.commodtype) AND (a.origin = d.origin) AND (a.quality = d.quality) AND (a.valuedin = d.valuedin))))
     JOIN true_open_cte t ON (((a.contno = t.contno) AND (a.split = t.split))))
     CROSS JOIN public.params)
  WHERE ((a.price_fixing = 'N'::bpchar) AND (t.true_open_fix > (0)::numeric))
UNION ALL
 SELECT c.contract_type,
    a.contno,
    a.split,
    'TOTAL'::text AS status,
    'PFUNFIX'::text AS flag,
    b.original,
    b.quantunit,
    b.unfixed AS openqnt,
    a.price_fixing,
    b.unfixed,
    NULL::numeric AS unitprice,
    a.currency,
    a.priceunit,
    a.pfcontract,
    a.pfposition,
    a.pfdifftype,
    a.pfdiffer,
    a.pfoption,
    a.pfdiffcurr,
    a.pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.shipment,
    a.shipordelv,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.price_fixing AS original_price_fixing,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    a.pfposition AS original_pfposition,
    c.priceterm,
    c.prcstlocn AS prcst_location,
    t.true_open_pfunfix AS true_open,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(t.true_open_pfunfix, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(t.true_open_pfunfix, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS base_openqnt,
    a.estmarket,
    a.payterm,
    a.tracking_unpriced,
    a.certification,
    a.eudr_flag,
        CASE
            WHEN (a.price_fixing = 'Y'::bpchar) THEN public.sp_pricestr_mmyy('Y'::bpchar, a.unitprice, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit)
            ELSE NULL::character varying
        END AS price_fixing_diff_string,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN public.sp_pricestr_mmyy((
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit)
            ELSE public.sp_pricestr_mmyy((
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit)
        END AS valn_string,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlposition
            ELSE a.vlposition
        END AS chosen_vlposition,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlcontract
            ELSE a.vlcontract
        END AS chosen_vlcontract,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldifftype
            ELSE a.vldifftype
        END AS chosen_vldifftype,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffer
            ELSE a.vldiffer
        END AS chosen_vldiffer,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffcurr
            ELSE a.vldiffcurr
        END AS chosen_vldiffcurr,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffunit
            ELSE a.vldiffunit
        END AS chosen_vldiffunit,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlposition
            ELSE a.vlposition
        END AS valn_month,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN (('-1'::integer)::numeric * public.sp_calc_value(t.true_open_pfunfix, a.quantunit, a.price_fixing, NULL::numeric, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit, params.base_currency, params.systemdate))
            ELSE public.sp_calc_value(t.true_open_pfunfix, a.quantunit, a.price_fixing, NULL::numeric, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit, params.base_currency, params.systemdate)
        END AS phys_value,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN (public.sp_calc_value(t.true_open_pfunfix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit, params.base_currency, params.systemdate) * (
            CASE
                WHEN (c.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric)
            ELSE (public.sp_calc_value(t.true_open_pfunfix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit, params.base_currency, params.systemdate) * (
            CASE
                WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
                ELSE 1
            END)::numeric)
        END AS valn_value,
    public.sp_get_total_reserves_in_base(a.contno, a.split) AS costs_per_base_unit,
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END AS unit_to_mt_conversation_factor,
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END AS currency_to_basecurr_conversion_factor,
    ((NULL::numeric *
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END) *
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END) AS unit_price_basecurr_mt,
    ((((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
            ELSE 1
        END)::numeric * public.sp_calc_value(t.true_open_pfunfix, a.quantunit, a.price_fixing, NULL::numeric, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit, params.base_currency, params.systemdate)) / NULLIF(((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN 1
            ELSE '-1'::integer
        END)::numeric * public.sp_convert_qty(t.true_open_pfunfix, b.quantunit, 'MT'::bpchar)), (0)::numeric)) + COALESCE(public.sp_get_total_reserves_in_base(a.contno, a.split), (0)::numeric)) AS final_price_basecurr_mt,
    (
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN (public.sp_calc_value(t.true_open_pfunfix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit, params.base_currency, params.systemdate) * (
            CASE
                WHEN (c.contract_type = 'P'::bpchar) THEN 1
                ELSE '-1'::integer
            END)::numeric)
            ELSE (public.sp_calc_value(t.true_open_pfunfix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit, params.base_currency, params.systemdate) * (
            CASE
                WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
                ELSE 1
            END)::numeric)
        END / NULLIF(((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN 1
            ELSE '-1'::integer
        END)::numeric * public.sp_convert_qty(t.true_open_pfunfix, b.quantunit, 'MT'::bpchar)), (0)::numeric)) AS valuation_price_basecurr_mt
   FROM (((((public.sub_contracts a
     JOIN public.phys_avail_valn_sopex b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
     JOIN public.val_differentials d ON (((c.company = d.company) AND (c.pcentre = d.pcentre) AND (c.commodity = d.commodity) AND (c.commodtype = d.commodtype) AND (a.origin = d.origin) AND (a.quality = d.quality) AND (a.valuedin = d.valuedin))))
     JOIN true_open_cte t ON (((a.contno = t.contno) AND (a.split = t.split))))
     CROSS JOIN public.params)
  WHERE ((a.price_fixing = 'Y'::bpchar) AND (t.true_open_pfunfix > (0)::numeric))
UNION ALL
 SELECT c.contract_type,
    a.contno,
    a.split,
    'TOTAL'::text AS status,
    'PFFIX'::text AS flag,
    b.original,
    b.quantunit,
    b.fixed AS openqnt,
    'N'::text AS price_fixing,
    b.unfixed,
    public.sp_phys_avefixprice(a.contno, a.split) AS unitprice,
    a.currency,
    a.priceunit,
    NULL::bpchar AS pfcontract,
    NULL::bpchar AS pfposition,
    NULL::bpchar AS pfdifftype,
    NULL::numeric AS pfdiffer,
    NULL::bpchar AS pfoption,
    NULL::bpchar AS pfdiffcurr,
    NULL::bpchar AS pfdiffunit,
    c.company,
    c.pcentre,
    c.commodity,
    c.commodtype,
    c.contdate,
    c.client,
    a.valuedin,
    a.valn_type,
    a.valn_price,
    a.valn_curr,
    a.valn_unit,
    a.vlcontract,
    a.vlposition,
    a.vldifftype,
    a.vldiffer,
    a.vldiffcurr,
    a.vldiffunit,
    a.origin,
    a.quality,
    a.shipfrom,
    a.shipto,
    a.ship_desc,
    a.shipment,
    a.shipordelv,
    a.est_fx_rate,
    a.cddifftype,
    a.cddiffer,
    a.price_fixing AS original_price_fixing,
    a.pfdifftype AS original_pfdifftype,
    a.pfdiffer AS original_pfdiffer,
    a.pfposition AS original_pfposition,
    c.priceterm,
    c.prcstlocn AS prcst_location,
    t.true_open_pffix AS true_open,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(t.true_open_pffix, b.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(t.true_open_pffix, b.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS base_openqnt,
    a.estmarket,
    a.payterm,
    a.tracking_unpriced,
    a.certification,
    a.eudr_flag,
        CASE
            WHEN (a.price_fixing = 'Y'::bpchar) THEN public.sp_pricestr_mmyy('Y'::bpchar, a.unitprice, a.currency, a.priceunit, a.pfcontract, a.pfposition, a.pfdifftype, a.pfdiffer, a.pfdiffcurr, a.pfdiffunit)
            ELSE NULL::character varying
        END AS price_fixing_diff_string,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN public.sp_pricestr_mmyy((
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit)
            ELSE public.sp_pricestr_mmyy((
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit)
        END AS valn_string,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlposition
            ELSE a.vlposition
        END AS chosen_vlposition,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlcontract
            ELSE a.vlcontract
        END AS chosen_vlcontract,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldifftype
            ELSE a.vldifftype
        END AS chosen_vldifftype,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffer
            ELSE a.vldiffer
        END AS chosen_vldiffer,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffcurr
            ELSE a.vldiffcurr
        END AS chosen_vldiffcurr,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vldiffunit
            ELSE a.vldiffunit
        END AS chosen_vldiffunit,
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN d.vlposition
            ELSE a.vlposition
        END AS valn_month,
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN (('-1'::integer)::numeric * public.sp_calc_value(t.true_open_pffix, b.quantunit, 'N'::bpchar, public.sp_phys_avefixprice(a.contno, a.split), a.currency, a.priceunit, NULL::bpchar, NULL::bpchar, NULL::bpchar, NULL::numeric, NULL::bpchar, NULL::bpchar, params.base_currency, params.systemdate))
            ELSE public.sp_calc_value(t.true_open_pffix, b.quantunit, 'N'::bpchar, public.sp_phys_avefixprice(a.contno, a.split), a.currency, a.priceunit, NULL::bpchar, NULL::bpchar, NULL::bpchar, NULL::numeric, NULL::bpchar, NULL::bpchar, params.base_currency, params.systemdate)
        END AS phys_value,
    (
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN public.sp_calc_value(t.true_open_pffix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit, params.base_currency, params.systemdate)
            ELSE public.sp_calc_value(t.true_open_pffix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit, params.base_currency, params.systemdate)
        END * (
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
            ELSE 1
        END)::numeric) AS valn_value,
    public.sp_get_total_reserves_in_base(a.contno, a.split) AS costs_per_base_unit,
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END AS unit_to_mt_conversation_factor,
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END AS currency_to_basecurr_conversion_factor,
    ((public.sp_phys_avefixprice(a.contno, a.split) *
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END) *
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END) AS unit_price_basecurr_mt,
    (COALESCE(NULLIF(((public.sp_phys_avefixprice(a.contno, a.split) *
        CASE
            WHEN (params.base_currency = 'GBP'::bpchar) THEN public.sp_convert_qty((1)::numeric, a.quantunit, params.base_unit)
            ELSE (1.0 / public.sp_convert_qty((1)::numeric, a.priceunit, params.base_unit))
        END) *
        CASE
            WHEN (public.sp_curr_getunderlying(a.currency) = params.base_currency) THEN public.sp_datedfxrate(a.currency, params.base_currency, CURRENT_DATE, CURRENT_DATE)
            ELSE public.sp_get_outright_or_averaged_fixes_fx_rate(a.contno, a.split)
        END), NULL::numeric), (((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
            ELSE 1
        END)::numeric * public.sp_calc_value(t.true_open_pffix, b.quantunit, 'N'::bpchar, public.sp_phys_avefixprice(a.contno, a.split), a.currency, a.priceunit, NULL::bpchar, NULL::bpchar, NULL::bpchar, NULL::numeric, NULL::bpchar, NULL::bpchar, params.base_currency, params.systemdate)) / NULLIF(((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN 1
            ELSE '-1'::integer
        END)::numeric * public.sp_convert_qty(t.true_open_pffix, b.quantunit, 'MT'::bpchar)), (0)::numeric))) + COALESCE(public.sp_get_total_reserves_in_base(a.contno, a.split), (0)::numeric)) AS final_price_basecurr_mt,
    ((
        CASE
            WHEN (a.valn_type = 'P'::bpchar) THEN public.sp_calc_value(t.true_open_pffix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, d.valn_price, d.valn_curr, d.valn_unit, d.vlcontract, d.vlposition, d.vldifftype, d.vldiffer, d.vldiffcurr, d.vldiffunit, params.base_currency, params.systemdate)
            ELSE public.sp_calc_value(t.true_open_pffix, a.quantunit, (
            CASE
                WHEN (a.valn_type = 'F'::bpchar) THEN 'N'::text
                ELSE 'Y'::text
            END)::bpchar, a.valn_price, a.valn_curr, a.valn_unit, a.vlcontract, a.vlposition, a.vldifftype, a.vldiffer, a.vldiffcurr, a.vldiffunit, params.base_currency, params.systemdate)
        END * (
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN '-1'::integer
            ELSE 1
        END)::numeric) / NULLIF(((
        CASE
            WHEN (c.contract_type = 'P'::bpchar) THEN 1
            ELSE '-1'::integer
        END)::numeric * public.sp_convert_qty(t.true_open_pffix, b.quantunit, 'MT'::bpchar)), (0)::numeric)) AS valuation_price_basecurr_mt
   FROM (((((public.sub_contracts a
     JOIN public.phys_avail_valn_sopex b ON (((a.contno = b.contno) AND (a.split = b.split))))
     JOIN public.master_contracts c ON ((c.contno = a.contno)))
     JOIN public.val_differentials d ON (((c.company = d.company) AND (c.pcentre = d.pcentre) AND (c.commodity = d.commodity) AND (c.commodtype = d.commodtype) AND (a.origin = d.origin) AND (a.quality = d.quality) AND (a.valuedin = d.valuedin))))
     JOIN true_open_cte t ON (((a.contno = t.contno) AND (a.split = t.split))))
     CROSS JOIN public.params)
  WHERE ((a.price_fixing = 'Y'::bpchar) AND (t.true_open_pffix > (0)::numeric));




CREATE OR REPLACE VIEW public.phys_splits_fxhedges AS
 SELECT c.contno,
    c.split,
    public.sp_curr_cvtunderlying(c.contvalue, c.currency) AS contvalue,
    public.sp_curr_getunderlying(c.currency) AS currency,
    a.contdate,
    a.seqno,
    a.contno AS termcontno,
    a.commodity,
    a.futconts,
    a.prompt,
    a.get_prompt,
    a.tradetype,
    a.tprice,
    a.lots,
    a.hedgeable,
    a.mktcurr,
    a.othercurr,
    a.dealratetype,
    b.quantity AS hedgedqty
   FROM ((public.phys_org_contval c
     LEFT JOIN public.forex_hedges b ON (((c.contno = b.contno) AND (c.split = b.split))))
     LEFT JOIN public.term_view a ON (((b.termdate = a.contdate) AND (b.termseqno = a.seqno))))
  WHERE ((a.hedge = 'Y'::bpchar) AND (a.tradetype = 'X'::bpchar));




CREATE OR REPLACE VIEW public.phys_splits_termhedges AS
 SELECT c.contno,
    c.split,
    c.baseorgqty,
    d.base_unit,
    a.contno AS termcontno,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tradetype,
    a.series,
    a.tprice,
    a.lots,
    a.hedgeable,
    a.mktcurr,
    b.quantity AS hedgedqty,
    b.quantunit,
    public.sp_convert_qty(b.quantity, b.quantunit, d.base_unit) AS hedgedqty_baseunit,
    a.mktunit
   FROM ((public.phys_org_contval c
     LEFT JOIN public.terminal_hedges b ON (((c.contno = b.contno) AND (c.split = b.split))))
     LEFT JOIN public.term_view a ON (((b.termdate = a.contdate) AND (b.termseqno = a.seqno)))),
    public.params d
  WHERE ((a.hedge = 'Y'::bpchar) AND (a.tradetype <> 'X'::bpchar));




CREATE OR REPLACE VIEW public.phys_termhedge_breakdown AS
 SELECT c.contno,
    c.split,
    a.contdate,
    a.seqno,
    a.contno AS termcontno,
    a.commodity,
    a.futconts,
    a.get_prompt,
    a.tradetype,
    a.series,
    a.tprice,
    a.lots,
    a.hedgeable,
    a.mktcurr,
    b.quantity AS hedgedqty,
    b.quantunit,
    public.sp_convert_qty(b.quantity, b.quantunit, a.mktunit) AS hedgedqty_mktunit,
    a.mktunit
   FROM ((public.sub_contracts c
     LEFT JOIN public.terminal_hedges b ON (((c.contno = b.contno) AND (c.split = b.split))))
     LEFT JOIN public.term_view a ON (((b.termdate = a.contdate) AND (b.termseqno = a.seqno))))
  WHERE ((a.hedge = 'Y'::bpchar) AND (a.tradetype <> 'X'::bpchar));




CREATE OR REPLACE VIEW public.phys_valn_view2 AS
 WITH base AS (
         SELECT b.company,
            b.pcentre,
            b.commodity,
            b.commodtype,
            a.origin,
            a.quality,
            a.valuedin,
            public.sp_prompt_month(a.valuedin) AS valuedin_str,
            a.contno,
            a.split,
            b.contract_type,
            b.contdate,
            b.client,
            d.openqnt,
            d.quantunit,
            d.original AS origqnt,
            d.unitprice,
            d.status,
            d.allocated,
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(d.openqnt, d.quantunit, params.base_unit))
                END AS base_openqnt,
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(d.original, d.quantunit, params.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(d.original, d.quantunit, params.base_unit))
                END AS base_origqnt,
            params.base_unit,
            d.price_fixing,
            d.currency,
            d.priceunit,
            d.pfcontract,
            d.pfposition,
            d.pfdifftype,
            d.pfdiffer,
            d.pfdiffcurr,
            d.pfdiffunit,
            public.sp_pricestr(d.price_fixing, d.unitprice, d.currency, d.priceunit, d.pfcontract, d.pfposition, d.pfdifftype, d.pfdiffer, d.pfdiffcurr, d.pfdiffunit) AS price_string,
            a.valn_type AS ct_valn_type,
            a.valn_price AS ct_valn_price,
            a.valn_curr AS ct_valn_curr,
            a.valn_unit AS ct_valn_unit,
            a.vlcontract AS ct_vlcontract,
            a.vlposition AS ct_vlposition,
            a.vldifftype AS ct_vldifftype,
            a.vldiffer AS ct_vldiffer,
            a.vldiffcurr AS ct_vldiffcurr,
            a.vldiffunit AS ct_vldiffunit,
            c_1.valn_type AS ps_valn_type,
            c_1.valn_price AS ps_valn_price,
            c_1.valn_curr AS ps_valn_curr,
            c_1.valn_unit AS ps_valn_unit,
            c_1.vlcontract AS ps_vlcontract,
            c_1.vlposition AS ps_vlposition,
            c_1.vldifftype AS ps_vldifftype,
            c_1.vldiffer AS ps_vldiffer,
            c_1.vldiffcurr AS ps_vldiffcurr,
            c_1.vldiffunit AS ps_vldiffunit,
            c_1.valn_type AS c_valn_type,
            c_1.valn_price AS c_valn_price,
            c_1.valn_curr AS c_valn_curr,
            c_1.valn_unit AS c_valn_unit,
            c_1.vlcontract AS c_vlcontract,
            c_1.vlposition AS c_vlposition,
            c_1.vldifftype AS c_vldifftype,
            c_1.vldiffer AS c_vldiffer,
            c_1.vldiffcurr AS c_vldiffcurr,
            c_1.vldiffunit AS c_vldiffunit,
            params.base_currency,
            params.systemdate
           FROM ((((public.sub_contracts a
             JOIN public.master_contracts b ON ((a.contno = b.contno)))
             JOIN public.val_differentials c_1 ON (((b.company = c_1.company) AND (b.pcentre = c_1.pcentre) AND (b.commodity = c_1.commodity) AND (b.commodtype = c_1.commodtype) AND (a.origin = c_1.origin) AND (a.quality = c_1.quality) AND (a.valuedin = c_1.valuedin))))
             JOIN public.phys_pricing2 d ON (((a.contno = d.contno) AND (a.split = d.split))))
             CROSS JOIN public.params)
        ), computed AS (
         SELECT b.company,
            b.pcentre,
            b.commodity,
            b.commodtype,
            b.origin,
            b.quality,
            b.valuedin,
            b.valuedin_str,
            b.contno,
            b.split,
            b.contract_type,
            b.contdate,
            b.client,
            b.openqnt,
            b.quantunit,
            b.origqnt,
            b.unitprice,
            b.status,
            b.allocated,
            b.base_openqnt,
            b.base_origqnt,
            b.base_unit,
            b.price_fixing,
            b.currency,
            b.priceunit,
            b.pfcontract,
            b.pfposition,
            b.pfdifftype,
            b.pfdiffer,
            b.pfdiffcurr,
            b.pfdiffunit,
            b.price_string,
            b.ct_valn_type,
            b.ct_valn_price,
            b.ct_valn_curr,
            b.ct_valn_unit,
            b.ct_vlcontract,
            b.ct_vlposition,
            b.ct_vldifftype,
            b.ct_vldiffer,
            b.ct_vldiffcurr,
            b.ct_vldiffunit,
            b.ps_valn_type,
            b.ps_valn_price,
            b.ps_valn_curr,
            b.ps_valn_unit,
            b.ps_vlcontract,
            b.ps_vlposition,
            b.ps_vldifftype,
            b.ps_vldiffer,
            b.ps_vldiffcurr,
            b.ps_vldiffunit,
            b.c_valn_type,
            b.c_valn_price,
            b.c_valn_curr,
            b.c_valn_unit,
            b.c_vlcontract,
            b.c_vlposition,
            b.c_vldifftype,
            b.c_vldiffer,
            b.c_vldiffcurr,
            b.c_vldiffunit,
            b.base_currency,
            b.systemdate,
                CASE
                    WHEN (b.ct_valn_type = 'P'::bpchar) THEN public.sp_pricestr((
                    CASE
                        WHEN (b.c_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.c_valn_price, b.c_valn_curr, b.c_valn_unit, b.c_vlcontract, b.c_vlposition, b.c_vldifftype, b.c_vldiffer, b.c_vldiffcurr, b.c_vldiffunit)
                    ELSE public.sp_pricestr((
                    CASE
                        WHEN (b.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.ct_valn_price, b.ct_valn_curr, b.ct_valn_unit, b.ct_vlcontract, b.ct_vlposition, b.ct_vldifftype, b.ct_vldiffer, b.ct_vldiffcurr, b.ct_vldiffunit)
                END AS valn_string,
            (public.sp_calc_value(b.openqnt, b.quantunit, b.price_fixing, b.unitprice, b.currency, b.priceunit, b.pfcontract, b.pfposition, b.pfdifftype, b.pfdiffer, b.pfdiffcurr, b.pfdiffunit, b.base_currency, b.systemdate) * (
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END)::numeric) AS phys_value,
            (
                CASE
                    WHEN (b.ct_valn_type = 'P'::bpchar) THEN public.sp_calc_value(b.openqnt, b.quantunit, (
                    CASE
                        WHEN (b.c_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.c_valn_price, b.c_valn_curr, b.c_valn_unit, b.c_vlcontract, b.c_vlposition, b.c_vldifftype, b.c_vldiffer, b.c_vldiffcurr, b.c_vldiffunit, b.base_currency, b.systemdate)
                    ELSE public.sp_calc_value(b.openqnt, b.quantunit, (
                    CASE
                        WHEN (b.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.ct_valn_price, b.ct_valn_curr, b.ct_valn_unit, b.ct_vlcontract, b.ct_vlposition, b.ct_vldifftype, b.ct_vldiffer, b.ct_vldiffcurr, b.ct_vldiffunit, b.base_currency, b.systemdate)
                END * (
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END)::numeric) AS valn_value,
            public.sp_phys_valn_term(b.contno, b.split, b.openqnt, b.origqnt, b.base_currency, b.systemdate) AS term_pandl,
            public.sp_phys_valn_fx(b.contno, b.split, b.openqnt, b.origqnt, b.base_currency, b.systemdate) AS fx_pandl,
            (public.sp_phys_valn_resvs(b.contno, b.split,
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.openqnt, b.quantunit, b.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(b.openqnt, b.quantunit, b.base_unit))
                END, b.base_unit,
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(b.origqnt, b.quantunit, b.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(b.origqnt, b.quantunit, b.base_unit))
                END, (public.sp_calc_value(b.openqnt, b.quantunit, b.price_fixing, b.unitprice, b.currency, b.priceunit, b.pfcontract, b.pfposition, b.pfdifftype, b.pfdiffer, b.pfdiffcurr, b.pfdiffunit, b.base_currency, b.systemdate) * (
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END)::numeric), b.base_currency, b.systemdate) * ('-1'::integer)::numeric) AS resvs_pandl
           FROM base b
        )
 SELECT company,
    pcentre,
    commodity,
    commodtype,
    origin,
    quality,
    valuedin,
    valuedin_str,
    contno,
    split,
    contract_type,
    contdate,
    client,
    openqnt,
    quantunit,
    origqnt,
    unitprice,
    status,
    allocated,
    base_openqnt,
    base_origqnt,
    base_unit AS sysbaseunit,
    price_fixing,
    currency,
    priceunit,
    pfcontract,
    pfposition,
    pfdifftype,
    pfdiffer,
    pfdiffcurr,
    pfdiffunit,
    price_string,
    ct_valn_type,
    ct_valn_price,
    ct_valn_curr,
    ct_valn_unit,
    ct_vlcontract,
    ct_vlposition,
    ct_vldifftype,
    ct_vldiffer,
    ct_vldiffcurr,
    ct_vldiffunit,
    ps_valn_type,
    ps_valn_price,
    ps_valn_curr,
    ps_valn_unit,
    ps_vlcontract,
    ps_vlposition,
    ps_vldifftype,
    ps_vldiffer,
    ps_vldiffcurr,
    ps_vldiffunit,
    valn_string,
    base_currency AS sysbasecurr,
    phys_value,
    valn_value,
    (valn_value - phys_value) AS phys_pandl,
    term_pandl,
    fx_pandl,
    resvs_pandl,
    ((((valn_value - phys_value) + term_pandl) + fx_pandl) + resvs_pandl) AS net_pandl
   FROM computed c;




CREATE OR REPLACE VIEW public.phys_valn_view3 AS
 WITH base AS (
         SELECT b.company,
            b.pcentre,
            b.commodity,
            b.commodtype,
            a.origin,
            a.quality,
            a.valuedin,
            public.sp_prompt_month(a.valuedin) AS valuedin_str,
            d_1.allocation_reference,
            a.contno,
            a.split,
            b.contract_type,
            b.contdate,
            b.client,
            d_1.openqnt,
            a.quantunit,
            a.orgunquant AS origqnt,
            d_1.unitprice,
            d_1.status,
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(d_1.openqnt, a.quantunit, params.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(d_1.openqnt, a.quantunit, params.base_unit))
                END AS base_openqnt,
                CASE
                    WHEN (b.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(a.orgunquant, a.quantunit, params.base_unit)
                    ELSE (('-1'::integer)::numeric * public.sp_convert_qty(a.orgunquant, a.quantunit, params.base_unit))
                END AS base_origqnt,
            params.base_unit,
            d_1.price_fixing,
            d_1.currency,
            d_1.priceunit,
            d_1.pfcontract,
            d_1.pfposition,
            d_1.pfdifftype,
            d_1.pfdiffer,
            d_1.pfdiffcurr,
            d_1.pfdiffunit,
            public.sp_pricestr(d_1.price_fixing, d_1.unitprice, d_1.currency, d_1.priceunit, d_1.pfcontract, d_1.pfposition, d_1.pfdifftype, d_1.pfdiffer, d_1.pfdiffcurr, d_1.pfdiffunit) AS price_string,
            a.valn_type AS ct_valn_type,
            a.valn_price AS ct_valn_price,
            a.valn_curr AS ct_valn_curr,
            a.valn_unit AS ct_valn_unit,
            a.vlcontract AS ct_vlcontract,
            a.vlposition AS ct_vlposition,
            a.vldifftype AS ct_vldifftype,
            a.vldiffer AS ct_vldiffer,
            a.vldiffcurr AS ct_vldiffcurr,
            a.vldiffunit AS ct_vldiffunit,
            c.valn_type AS ps_valn_type,
            c.valn_price AS ps_valn_price,
            c.valn_curr AS ps_valn_curr,
            c.valn_unit AS ps_valn_unit,
            c.vlcontract AS ps_vlcontract,
            c.vlposition AS ps_vlposition,
            c.vldifftype AS ps_vldifftype,
            c.vldiffer AS ps_vldiffer,
            c.vldiffcurr AS ps_vldiffcurr,
            c.vldiffunit AS ps_vldiffunit,
            c.valn_type AS c_valn_type,
            c.valn_price AS c_valn_price,
            c.valn_curr AS c_valn_curr,
            c.valn_unit AS c_valn_unit,
            c.vlcontract AS c_vlcontract,
            c.vlposition AS c_vlposition,
            c.vldifftype AS c_vldifftype,
            c.vldiffer AS c_vldiffer,
            c.vldiffcurr AS c_vldiffcurr,
            c.vldiffunit AS c_vldiffunit,
            params.base_currency,
            params.systemdate
           FROM ((((public.sub_contracts a
             JOIN public.master_contracts b ON ((a.contno = b.contno)))
             JOIN public.val_differentials c ON (((b.company = c.company) AND (b.pcentre = c.pcentre) AND (b.commodity = c.commodity) AND (b.commodtype = c.commodtype) AND (a.origin = c.origin) AND (a.quality = c.quality) AND (a.valuedin = c.valuedin))))
             JOIN public.phys_pricing3 d_1 ON (((a.contno = d_1.contno) AND (a.split = d_1.split))))
             CROSS JOIN public.params)
        ), computed AS (
         SELECT b.company,
            b.pcentre,
            b.commodity,
            b.commodtype,
            b.origin,
            b.quality,
            b.valuedin,
            b.valuedin_str,
            b.allocation_reference,
            b.contno,
            b.split,
            b.contract_type,
            b.contdate,
            b.client,
            b.openqnt,
            b.quantunit,
            b.origqnt,
            b.unitprice,
            b.status,
            b.base_openqnt,
            b.base_origqnt,
            b.base_unit,
            b.price_fixing,
            b.currency,
            b.priceunit,
            b.pfcontract,
            b.pfposition,
            b.pfdifftype,
            b.pfdiffer,
            b.pfdiffcurr,
            b.pfdiffunit,
            b.price_string,
            b.ct_valn_type,
            b.ct_valn_price,
            b.ct_valn_curr,
            b.ct_valn_unit,
            b.ct_vlcontract,
            b.ct_vlposition,
            b.ct_vldifftype,
            b.ct_vldiffer,
            b.ct_vldiffcurr,
            b.ct_vldiffunit,
            b.ps_valn_type,
            b.ps_valn_price,
            b.ps_valn_curr,
            b.ps_valn_unit,
            b.ps_vlcontract,
            b.ps_vlposition,
            b.ps_vldifftype,
            b.ps_vldiffer,
            b.ps_vldiffcurr,
            b.ps_vldiffunit,
            b.c_valn_type,
            b.c_valn_price,
            b.c_valn_curr,
            b.c_valn_unit,
            b.c_vlcontract,
            b.c_vlposition,
            b.c_vldifftype,
            b.c_vldiffer,
            b.c_vldiffcurr,
            b.c_vldiffunit,
            b.base_currency,
            b.systemdate,
                CASE
                    WHEN (b.ct_valn_type = 'P'::bpchar) THEN public.sp_pricestr((
                    CASE
                        WHEN (b.c_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.c_valn_price, b.c_valn_curr, b.c_valn_unit, b.c_vlcontract, b.c_vlposition, b.c_vldifftype, b.c_vldiffer, b.c_vldiffcurr, b.c_vldiffunit)
                    ELSE public.sp_pricestr((
                    CASE
                        WHEN (b.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                        ELSE 'Y'::text
                    END)::bpchar, b.ct_valn_price, b.ct_valn_curr, b.ct_valn_unit, b.ct_vlcontract, b.ct_vlposition, b.ct_vldifftype, b.ct_vldiffer, b.ct_vldiffcurr, b.ct_vldiffunit)
                END AS valn_string,
                CASE
                    WHEN (b.status = 'FORWARD'::text) THEN (public.sp_calc_value(b.openqnt, b.quantunit, b.price_fixing, b.unitprice, b.currency, b.priceunit, b.pfcontract, b.pfposition, b.pfdifftype, b.pfdiffer, b.pfdiffcurr, b.pfdiffunit, b.base_currency, b.systemdate) * (
                    CASE
                        WHEN (b.contract_type = 'P'::bpchar) THEN '-1'::integer
                        ELSE 1
                    END)::numeric)
                    ELSE 0.0
                END AS phys_value,
                CASE
                    WHEN (b.status = 'FORWARD'::text) THEN (
                    CASE
                        WHEN (b.ct_valn_type = 'P'::bpchar) THEN public.sp_calc_value(b.openqnt, b.quantunit, (
                        CASE
                            WHEN (b.c_valn_type = 'F'::bpchar) THEN 'N'::text
                            ELSE 'Y'::text
                        END)::bpchar, b.c_valn_price, b.c_valn_curr, b.c_valn_unit, b.c_vlcontract, b.c_vlposition, b.c_vldifftype, b.c_vldiffer, b.c_vldiffcurr, b.c_vldiffunit, b.base_currency, b.systemdate)
                        ELSE public.sp_calc_value(b.openqnt, b.quantunit, (
                        CASE
                            WHEN (b.ct_valn_type = 'F'::bpchar) THEN 'N'::text
                            ELSE 'Y'::text
                        END)::bpchar, b.ct_valn_price, b.ct_valn_curr, b.ct_valn_unit, b.ct_vlcontract, b.ct_vlposition, b.ct_vldifftype, b.ct_vldiffer, b.ct_vldiffcurr, b.ct_vldiffunit, b.base_currency, b.systemdate)
                    END * (
                    CASE
                        WHEN (b.contract_type = 'P'::bpchar) THEN '-1'::integer
                        ELSE 1
                    END)::numeric)
                    ELSE 0.0
                END AS valn_value,
            NULL::numeric AS resvs_pandl
           FROM base b
        ), derived AS (
         SELECT c.company,
            c.pcentre,
            c.commodity,
            c.commodtype,
            c.origin,
            c.quality,
            c.valuedin,
            c.valuedin_str,
            c.allocation_reference,
            c.contno,
            c.split,
            c.contract_type,
            c.contdate,
            c.client,
            c.openqnt,
            c.quantunit,
            c.origqnt,
            c.unitprice,
            c.status,
            c.base_openqnt,
            c.base_origqnt,
            c.base_unit,
            c.price_fixing,
            c.currency,
            c.priceunit,
            c.pfcontract,
            c.pfposition,
            c.pfdifftype,
            c.pfdiffer,
            c.pfdiffcurr,
            c.pfdiffunit,
            c.price_string,
            c.ct_valn_type,
            c.ct_valn_price,
            c.ct_valn_curr,
            c.ct_valn_unit,
            c.ct_vlcontract,
            c.ct_vlposition,
            c.ct_vldifftype,
            c.ct_vldiffer,
            c.ct_vldiffcurr,
            c.ct_vldiffunit,
            c.ps_valn_type,
            c.ps_valn_price,
            c.ps_valn_curr,
            c.ps_valn_unit,
            c.ps_vlcontract,
            c.ps_vlposition,
            c.ps_vldifftype,
            c.ps_vldiffer,
            c.ps_vldiffcurr,
            c.ps_vldiffunit,
            c.c_valn_type,
            c.c_valn_price,
            c.c_valn_curr,
            c.c_valn_unit,
            c.c_vlcontract,
            c.c_vlposition,
            c.c_vldifftype,
            c.c_vldiffer,
            c.c_vldiffcurr,
            c.c_vldiffunit,
            c.base_currency,
            c.systemdate,
            c.valn_string,
            c.phys_value,
            c.valn_value,
            c.resvs_pandl,
                CASE
                    WHEN (c.status = 'FORWARD'::text) THEN (public.sp_phys_valn_resvs(c.contno, c.split, c.base_openqnt, c.base_unit, c.base_origqnt, c.phys_value, c.base_currency, c.systemdate) * ('-1'::integer)::numeric)
                    ELSE 0.0
                END AS resvs_pandl_final
           FROM computed c
        )
 SELECT company,
    pcentre,
    commodity,
    commodtype,
    origin,
    quality,
    valuedin,
    valuedin_str,
    allocation_reference,
    contno,
    split,
    contract_type,
    contdate,
    client,
    openqnt,
    quantunit,
    origqnt,
    unitprice,
    status,
    base_openqnt,
    base_origqnt,
    base_unit AS sysbaseunit,
    price_fixing,
    currency,
    priceunit,
    pfcontract,
    pfposition,
    pfdifftype,
    pfdiffer,
    pfdiffcurr,
    pfdiffunit,
    price_string,
    ct_valn_type,
    ct_valn_price,
    ct_valn_curr,
    ct_valn_unit,
    ct_vlcontract,
    ct_vlposition,
    ct_vldifftype,
    ct_vldiffer,
    ct_vldiffcurr,
    ct_vldiffunit,
    ps_valn_type,
    ps_valn_price,
    ps_valn_curr,
    ps_valn_unit,
    ps_vlcontract,
    ps_vlposition,
    ps_vldifftype,
    ps_vldiffer,
    ps_vldiffcurr,
    ps_vldiffunit,
    valn_string,
    base_currency AS sysbasecurr,
    phys_value,
    valn_value,
    (valn_value - phys_value) AS phys_pandl,
    resvs_pandl_final AS resvs_pandl,
    ((valn_value - phys_value) + resvs_pandl_final) AS net_pandl
   FROM derived d;




CREATE OR REPLACE VIEW public.physcont_view AS
 WITH base AS (
         SELECT params.systemdate,
            company.name AS our_name,
            company.longname AS our_longname,
            COALESCE(company.addr1, ''::character varying) AS our_addr1,
            COALESCE(company.addr2, ''::character varying) AS our_addr2,
            COALESCE(company.addr3, ''::character varying) AS our_addr3,
            COALESCE(company.addr4, ''::character varying) AS our_addr4,
            COALESCE(company.addr5, ''::character varying) AS our_addr5,
            COALESCE(company.addr6, ''::character varying) AS our_addr6,
            COALESCE(company.regno, ''::character varying) AS our_regno,
            COALESCE(company.vatno, ''::character varying) AS our_vatno,
            master_contracts.contno,
            master_contracts.contdate,
            master_contracts.company,
            master_contracts.pcentre,
            sub_contracts.split,
            master_contracts.contract_type AS conttype,
            rtrim(substr('BOUGHT FROM YOU     SOLD TO YOU         '::text, ((strpos('PS'::text, (master_contracts.contract_type)::text) * 20) - 19), 20)) AS cp_buysell_desc,
            sub_contracts.client,
            client.name AS client_name,
            client.longname AS client_longname,
            COALESCE(client.addr1, ''::character varying) AS client_addr1,
            COALESCE(client.addr2, ''::character varying) AS client_addr2,
            COALESCE(client.addr3, ''::character varying) AS client_addr3,
            COALESCE(client.addr4, ''::character varying) AS client_addr4,
            COALESCE(client.addr5, ''::character varying) AS client_addr5,
            COALESCE(client.addr6, ''::character varying) AS client_addr6,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, (client.name)::character varying, (company.name)::character varying) AS cp_buyer_name,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, client.longname, company.longname) AS cp_buyer_longname,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, COALESCE(client.addr1, ''::character varying), COALESCE(company.addr1, ''::character varying)) AS cp_buyer_addr1,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, COALESCE(client.addr2, ''::character varying), COALESCE(company.addr2, ''::character varying)) AS cp_buyer_addr2,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, COALESCE(client.addr3, ''::character varying), COALESCE(company.addr3, ''::character varying)) AS cp_buyer_addr3,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, COALESCE(client.addr4, ''::character varying), COALESCE(company.addr4, ''::character varying)) AS cp_buyer_addr4,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, COALESCE(client.addr5, ''::character varying), COALESCE(company.addr5, ''::character varying)) AS cp_buyer_addr5,
            public.sp_side_det(master_contracts.contract_type, 'P'::bpchar, COALESCE(client.addr6, ''::character varying), COALESCE(company.addr6, ''::character varying)) AS cp_buyer_addr6,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, (client.name)::character varying, (company.name)::character varying) AS cp_seller_name,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, client.longname, company.longname) AS cp_seller_longname,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, COALESCE(client.addr1, ''::character varying), COALESCE(company.addr1, ''::character varying)) AS cp_seller_addr1,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, COALESCE(client.addr2, ''::character varying), COALESCE(company.addr2, ''::character varying)) AS cp_seller_addr2,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, COALESCE(client.addr3, ''::character varying), COALESCE(company.addr3, ''::character varying)) AS cp_seller_addr3,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, COALESCE(client.addr4, ''::character varying), COALESCE(company.addr4, ''::character varying)) AS cp_seller_addr4,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, COALESCE(client.addr5, ''::character varying), COALESCE(company.addr5, ''::character varying)) AS cp_seller_addr5,
            public.sp_side_det(master_contracts.contract_type, 'S'::bpchar, COALESCE(client.addr6, ''::character varying), COALESCE(company.addr6, ''::character varying)) AS cp_seller_addr6,
            master_contracts.commodity,
            commodity.name AS commodity_name,
            commodity.longname AS commodity_longname,
            master_contracts.commodtype,
            commodity_type.name AS commodtype_name,
            commodity_type.longname AS commodtype_longname,
            sub_contracts.origin,
            origin.name AS origin_name,
            origin.longname AS origin_longname,
            sub_contracts.quality,
            quality.name AS quality_name,
            quality.longname AS quality_longname,
            sub_contracts.packing,
            packing.name AS packing_name,
            packing.longname AS packing_longname,
            sub_contracts.payterm,
            payment_term.name AS payterm_name,
            payment_term.longname AS payterm_longname,
            sub_contracts.notes AS split_notes,
            master_contracts.priceterm,
            price_term.name AS price_term_name,
            price_term.longname AS price_term_longname,
            master_contracts.prcstlocn,
            prcstlocn.name AS prcstlocn_name,
            prcstlocn.longname AS prcstlocn_longname,
            master_contracts.port,
            portlocn.name AS port_name,
            portlocn.longname AS port_longname,
            master_contracts.dest,
            destlocn.name AS dest_name,
            destlocn.longname AS dest_longname,
            master_contracts.notes,
            master_contracts.crop,
            master_contracts.season,
            master_contracts.clientref,
            master_contracts.insurance,
            insurance.name AS insurance_name,
            insurance.longname AS insurance_longname,
            master_contracts.arbitrationlocn,
            arbitlocn.name AS arbit_name,
            arbitlocn.longname AS arbit_longname,
            master_contracts.freight,
            freight.name AS freight_name,
            freight.longname AS freight_longname,
            master_contracts.weights,
            weight.name AS weights_name,
            weight.longname AS weight_longname,
            master_contracts.tolerance,
            master_contracts.clause1,
            clause1.name AS clause1_name,
            clause1.longname AS clause1_longname,
            master_contracts.clause2,
            clause2.name AS clause2_name,
            clause2.longname AS clause2_longname,
            master_contracts.clause3,
            clause3.name AS clause3_name,
            clause3.longname AS clause3_longname,
            master_contracts.specialclause,
            clause4.name AS specialclause_name,
            clause4.longname AS specialclause_longname,
            master_contracts.clause4,
            clause5.name AS clause5_name,
            clause5.longname AS clause5_longname,
            master_contracts.clause5,
            clause6.name AS clause6_name,
            clause6.longname AS clause6_longname,
            master_contracts.samplereqd,
            master_contracts.amenddate,
            master_contracts.formtype,
            form.longname AS formtype_longname,
            form.exchange,
            form.conditions,
            master_contracts.paytlocn,
            master_contracts.lastsplit,
            sub_contracts.splitdate,
                CASE
                    WHEN (master_contracts.contract_type = 'P'::bpchar) THEN 1
                    ELSE '-1'::integer
                END AS cp_qtysign,
            sub_contracts.orgunquant,
            public.sp_ntos(sub_contracts.orgunquant, 'EN'::bpchar) AS cp_origqty_amount_in_words,
            public.sp_convert_qty(sub_contracts.orgunquant, sub_contracts.quantunit, 'MT'::bpchar) AS contract_split_tonnage,
            sub_contracts.unitprice,
            sub_contracts.currency,
            currency.name AS currency_name,
            currency.longname AS currency_longname,
            sub_contracts.priceunit,
            priceunit.name AS priceunit_name,
            priceunit.longname AS priceunit_longname,
            sub_contracts.shipment,
            public.sp_shipment_desc(sub_contracts.shipment, sub_contracts.shipordelv) AS cp_shipment_desc,
            sub_contracts.price_fixing,
            sub_contracts.pfcontract,
            pf_futconts.name AS pfcontract_name,
            pf_futconts.longname AS pfcontract_longname,
            pf_futconts.currency AS pftermcurr,
            pf_futconts.unit AS pftermunit,
            sub_contracts.pfposition,
            sub_contracts.pfdifftype,
            sub_contracts.pfdiffer,
            sub_contracts.pfoption,
            sub_contracts.pfdiffcurr,
            pfcurrency.name AS pfdiffcurr_name,
            pfcurrency.longname AS pfdiffcurr_longname,
            sub_contracts.pfdiffunit,
            pfdiffunit.name AS pfdiffunit_name,
            pfdiffunit.longname AS pfdiffunit_longname,
            sub_contracts.fixbydate,
            rtrim((public.sp_whosoption_short(sub_contracts.pfoption))::text) AS cp_pfoption_desc,
            rtrim((public.sp_pfdifftype(sub_contracts.pfdifftype))::text) AS cp_pfdifftype_desc,
            COALESCE(public.sp_prompt_month(sub_contracts.pfposition), ''::bpchar) AS cp_pfposition_str,
            public.sp_pricestr(sub_contracts.price_fixing, sub_contracts.unitprice, sub_contracts.currency, sub_contracts.priceunit, sub_contracts.pfcontract, sub_contracts.pfposition, sub_contracts.pfdifftype, sub_contracts.pfdiffer, sub_contracts.pfdiffcurr, sub_contracts.pfdiffunit) AS price_string,
            sub_contracts.othernotes,
            sub_contracts.valuedin,
            public.sp_prompt_month(sub_contracts.valuedin) AS cp_validin_str,
            sub_contracts.allocref,
            sub_contracts.shipordelv,
            public.sp_shipdelvarrv(sub_contracts.shipordelv) AS cp_shipordelv_desc,
            sub_contracts.shipoption,
            public.sp_whosoption(sub_contracts.shipoption) AS cp_shipoption_desc,
            sub_contracts.shipfrom,
            sub_contracts.shipto,
            sub_contracts.differential,
            sub_contracts.lastfix,
            phys_avail.moved,
            phys_avail.allocated,
            phys_avail.unallocated,
            phys_avail.invoiced,
            phys_avail.uninvoiced,
            phys_avail.invposted,
            phys_avail.invunposted,
            phys_avail.fixed,
            phys_avail.unfixed,
            phys_avail.fixedlots,
            phys_avail.unfixedlots,
            phys_avail.fixed_base,
            phys_avail.unfixed_base,
            phys_avail.stock,
            (phys_avail.openqnt + phys_avail.stock) AS contract_open_quantity,
            sub_contracts.unquantity,
            sub_contracts.quantunit,
            quantunit.name AS quantunit_name,
            quantunit.longname AS quantunit_longname,
            quantunit.longname_plural AS quantunit_longname_plural,
            params.base_unit,
            params.base_currency,
            sub_contracts.completed_on,
            sub_contracts.eudr_flag,
            client.country AS client_country,
            origin.longname AS origin_longname_raw,
            commodity_type.longname AS commodtype_longname_raw,
            commodity.longname AS commodity_longname_raw,
            prcstlocn.longname AS prcstlocn_longname_raw
           FROM ((((((((((((((((((((((((((((((((public.params
             CROSS JOIN public.master_contracts)
             JOIN public.sub_contracts ON ((master_contracts.contno = sub_contracts.contno)))
             JOIN public.phys_avail ON (((sub_contracts.contno = phys_avail.contno) AND (sub_contracts.split = phys_avail.split))))
             LEFT JOIN public.company ON ((master_contracts.company = company.code)))
             LEFT JOIN public.client ON ((sub_contracts.client = client.code)))
             LEFT JOIN public.form ON ((master_contracts.formtype = form.code)))
             LEFT JOIN public.commodity ON ((master_contracts.commodity = commodity.code)))
             LEFT JOIN public.commodity_type ON ((master_contracts.commodtype = commodity_type.code)))
             LEFT JOIN public.origin ON ((sub_contracts.origin = origin.code)))
             LEFT JOIN public.quality ON ((sub_contracts.quality = quality.code)))
             LEFT JOIN public.packing ON ((sub_contracts.packing = packing.code)))
             LEFT JOIN public.location prcstlocn ON ((master_contracts.prcstlocn = prcstlocn.code)))
             LEFT JOIN public.location portlocn ON ((master_contracts.port = portlocn.code)))
             LEFT JOIN public.location destlocn ON ((master_contracts.dest = destlocn.code)))
             LEFT JOIN public.location arbitlocn ON ((master_contracts.arbitrationlocn = arbitlocn.code)))
             LEFT JOIN public.freight ON ((master_contracts.freight = freight.code)))
             LEFT JOIN public.insurance ON ((master_contracts.insurance = insurance.code)))
             LEFT JOIN public.price_term ON ((master_contracts.priceterm = price_term.code)))
             LEFT JOIN public.payment_term ON ((sub_contracts.payterm = payment_term.code)))
             LEFT JOIN public.weight ON ((master_contracts.weights = weight.code)))
             LEFT JOIN public.clause clause1 ON ((master_contracts.clause1 = clause1.code)))
             LEFT JOIN public.clause clause2 ON ((master_contracts.clause2 = clause2.code)))
             LEFT JOIN public.clause clause3 ON ((master_contracts.clause3 = clause3.code)))
             LEFT JOIN public.clause clause4 ON ((master_contracts.specialclause = clause4.code)))
             LEFT JOIN public.clause clause5 ON ((master_contracts.clause4 = clause5.code)))
             LEFT JOIN public.clause clause6 ON ((master_contracts.clause5 = clause6.code)))
             LEFT JOIN public.unit quantunit ON ((sub_contracts.quantunit = quantunit.code)))
             LEFT JOIN public.unit priceunit ON ((sub_contracts.priceunit = priceunit.code)))
             LEFT JOIN public.unit pfdiffunit ON ((sub_contracts.pfdiffunit = pfdiffunit.code)))
             LEFT JOIN public.currency ON ((sub_contracts.currency = currency.code)))
             LEFT JOIN public.currency pfcurrency ON ((sub_contracts.pfdiffcurr = pfcurrency.code)))
             LEFT JOIN public.futures_contract pf_futconts ON ((sub_contracts.pfcontract = pf_futconts.code)))
        ), computed AS (
         SELECT b.systemdate,
            b.our_name,
            b.our_longname,
            b.our_addr1,
            b.our_addr2,
            b.our_addr3,
            b.our_addr4,
            b.our_addr5,
            b.our_addr6,
            b.our_regno,
            b.our_vatno,
            b.contno,
            b.contdate,
            b.company,
            b.pcentre,
            b.split,
            b.conttype,
            b.cp_buysell_desc,
            b.client,
            b.client_name,
            b.client_longname,
            b.client_addr1,
            b.client_addr2,
            b.client_addr3,
            b.client_addr4,
            b.client_addr5,
            b.client_addr6,
            b.cp_buyer_name,
            b.cp_buyer_longname,
            b.cp_buyer_addr1,
            b.cp_buyer_addr2,
            b.cp_buyer_addr3,
            b.cp_buyer_addr4,
            b.cp_buyer_addr5,
            b.cp_buyer_addr6,
            b.cp_seller_name,
            b.cp_seller_longname,
            b.cp_seller_addr1,
            b.cp_seller_addr2,
            b.cp_seller_addr3,
            b.cp_seller_addr4,
            b.cp_seller_addr5,
            b.cp_seller_addr6,
            b.commodity,
            b.commodity_name,
            b.commodity_longname,
            b.commodtype,
            b.commodtype_name,
            b.commodtype_longname,
            b.origin,
            b.origin_name,
            b.origin_longname,
            b.quality,
            b.quality_name,
            b.quality_longname,
            b.packing,
            b.packing_name,
            b.packing_longname,
            b.payterm,
            b.payterm_name,
            b.payterm_longname,
            b.split_notes,
            b.priceterm,
            b.price_term_name,
            b.price_term_longname,
            b.prcstlocn,
            b.prcstlocn_name,
            b.prcstlocn_longname,
            b.port,
            b.port_name,
            b.port_longname,
            b.dest,
            b.dest_name,
            b.dest_longname,
            b.notes,
            b.crop,
            b.season,
            b.clientref,
            b.insurance,
            b.insurance_name,
            b.insurance_longname,
            b.arbitrationlocn,
            b.arbit_name,
            b.arbit_longname,
            b.freight,
            b.freight_name,
            b.freight_longname,
            b.weights,
            b.weights_name,
            b.weight_longname,
            b.tolerance,
            b.clause1,
            b.clause1_name,
            b.clause1_longname,
            b.clause2,
            b.clause2_name,
            b.clause2_longname,
            b.clause3,
            b.clause3_name,
            b.clause3_longname,
            b.specialclause,
            b.specialclause_name,
            b.specialclause_longname,
            b.clause4,
            b.clause5_name,
            b.clause5_longname,
            b.clause5,
            b.clause6_name,
            b.clause6_longname,
            b.samplereqd,
            b.amenddate,
            b.formtype,
            b.formtype_longname,
            b.exchange,
            b.conditions,
            b.paytlocn,
            b.lastsplit,
            b.splitdate,
            b.cp_qtysign,
            b.orgunquant,
            b.cp_origqty_amount_in_words,
            b.contract_split_tonnage,
            b.unitprice,
            b.currency,
            b.currency_name,
            b.currency_longname,
            b.priceunit,
            b.priceunit_name,
            b.priceunit_longname,
            b.shipment,
            b.cp_shipment_desc,
            b.price_fixing,
            b.pfcontract,
            b.pfcontract_name,
            b.pfcontract_longname,
            b.pftermcurr,
            b.pftermunit,
            b.pfposition,
            b.pfdifftype,
            b.pfdiffer,
            b.pfoption,
            b.pfdiffcurr,
            b.pfdiffcurr_name,
            b.pfdiffcurr_longname,
            b.pfdiffunit,
            b.pfdiffunit_name,
            b.pfdiffunit_longname,
            b.fixbydate,
            b.cp_pfoption_desc,
            b.cp_pfdifftype_desc,
            b.cp_pfposition_str,
            b.price_string,
            b.othernotes,
            b.valuedin,
            b.cp_validin_str,
            b.allocref,
            b.shipordelv,
            b.cp_shipordelv_desc,
            b.shipoption,
            b.cp_shipoption_desc,
            b.shipfrom,
            b.shipto,
            b.differential,
            b.lastfix,
            b.moved,
            b.allocated,
            b.unallocated,
            b.invoiced,
            b.uninvoiced,
            b.invposted,
            b.invunposted,
            b.fixed,
            b.unfixed,
            b.fixedlots,
            b.unfixedlots,
            b.fixed_base,
            b.unfixed_base,
            b.stock,
            b.contract_open_quantity,
            b.unquantity,
            b.quantunit,
            b.quantunit_name,
            b.quantunit_longname,
            b.quantunit_longname_plural,
            b.base_unit,
            b.base_currency,
            b.completed_on,
            b.eudr_flag,
            b.client_country,
            b.origin_longname_raw,
            b.commodtype_longname_raw,
            b.commodity_longname_raw,
            b.prcstlocn_longname_raw,
            b.pfcurrency_longname,
            b.pf_futconts_longname,
            b.pfdiffunit_longname_raw,
            b.price_term_longname_raw,
            (((((((((b.origin_longname_raw)::text || ' '::text) || (COALESCE(b.crop, ''::character varying))::text) ||
                CASE
                    WHEN (b.crop IS NOT NULL) THEN ' '::text
                    ELSE ''::text
                END) || (COALESCE(b.season, ''::character varying))::text) ||
                CASE
                    WHEN (b.season IS NOT NULL) THEN ' '::text
                    ELSE ''::text
                END) || (b.commodtype_longname_raw)::text) || ' '::text) || (b.commodity_longname_raw)::text) AS cp_description,
            ((((((((('('::text || (b.pfoption)::text) || ') '::text) || (b.pfcontract)::text) || ' / '::text) || (COALESCE(public.sp_prompt_month(b.pfposition), ''::bpchar))::text) || ' '::text) || (b.pfdifftype)::text) || ' '::text) || (b.pfdiffer)::text) AS cp_pfix_diff,
            ((((((((((((((rtrim((b.pfcurrency_longname)::text) || ' '::text) || ((b.pfdiffer)::numeric(16,2))::text) || ' '::text) || rtrim((public.sp_pfdifftype(b.pfdifftype))::text)) || ' '::text) || (public.sp_long_month((COALESCE(public.sp_prompt_month(b.pfposition), ''::bpchar))::character varying))::text) || ' '::text) || rtrim((b.pf_futconts_longname)::text)) || ' per '::text) || rtrim((b.pfdiffunit_longname_raw)::text)) || ' '::text) || rtrim((b.price_term_longname_raw)::text)) || ' '::text) || (b.prcstlocn_longname_raw)::text) AS cp_pfix_price_desc
           FROM ( SELECT b_1.systemdate,
                    b_1.our_name,
                    b_1.our_longname,
                    b_1.our_addr1,
                    b_1.our_addr2,
                    b_1.our_addr3,
                    b_1.our_addr4,
                    b_1.our_addr5,
                    b_1.our_addr6,
                    b_1.our_regno,
                    b_1.our_vatno,
                    b_1.contno,
                    b_1.contdate,
                    b_1.company,
                    b_1.pcentre,
                    b_1.split,
                    b_1.conttype,
                    b_1.cp_buysell_desc,
                    b_1.client,
                    b_1.client_name,
                    b_1.client_longname,
                    b_1.client_addr1,
                    b_1.client_addr2,
                    b_1.client_addr3,
                    b_1.client_addr4,
                    b_1.client_addr5,
                    b_1.client_addr6,
                    b_1.cp_buyer_name,
                    b_1.cp_buyer_longname,
                    b_1.cp_buyer_addr1,
                    b_1.cp_buyer_addr2,
                    b_1.cp_buyer_addr3,
                    b_1.cp_buyer_addr4,
                    b_1.cp_buyer_addr5,
                    b_1.cp_buyer_addr6,
                    b_1.cp_seller_name,
                    b_1.cp_seller_longname,
                    b_1.cp_seller_addr1,
                    b_1.cp_seller_addr2,
                    b_1.cp_seller_addr3,
                    b_1.cp_seller_addr4,
                    b_1.cp_seller_addr5,
                    b_1.cp_seller_addr6,
                    b_1.commodity,
                    b_1.commodity_name,
                    b_1.commodity_longname,
                    b_1.commodtype,
                    b_1.commodtype_name,
                    b_1.commodtype_longname,
                    b_1.origin,
                    b_1.origin_name,
                    b_1.origin_longname,
                    b_1.quality,
                    b_1.quality_name,
                    b_1.quality_longname,
                    b_1.packing,
                    b_1.packing_name,
                    b_1.packing_longname,
                    b_1.payterm,
                    b_1.payterm_name,
                    b_1.payterm_longname,
                    b_1.split_notes,
                    b_1.priceterm,
                    b_1.price_term_name,
                    b_1.price_term_longname,
                    b_1.prcstlocn,
                    b_1.prcstlocn_name,
                    b_1.prcstlocn_longname,
                    b_1.port,
                    b_1.port_name,
                    b_1.port_longname,
                    b_1.dest,
                    b_1.dest_name,
                    b_1.dest_longname,
                    b_1.notes,
                    b_1.crop,
                    b_1.season,
                    b_1.clientref,
                    b_1.insurance,
                    b_1.insurance_name,
                    b_1.insurance_longname,
                    b_1.arbitrationlocn,
                    b_1.arbit_name,
                    b_1.arbit_longname,
                    b_1.freight,
                    b_1.freight_name,
                    b_1.freight_longname,
                    b_1.weights,
                    b_1.weights_name,
                    b_1.weight_longname,
                    b_1.tolerance,
                    b_1.clause1,
                    b_1.clause1_name,
                    b_1.clause1_longname,
                    b_1.clause2,
                    b_1.clause2_name,
                    b_1.clause2_longname,
                    b_1.clause3,
                    b_1.clause3_name,
                    b_1.clause3_longname,
                    b_1.specialclause,
                    b_1.specialclause_name,
                    b_1.specialclause_longname,
                    b_1.clause4,
                    b_1.clause5_name,
                    b_1.clause5_longname,
                    b_1.clause5,
                    b_1.clause6_name,
                    b_1.clause6_longname,
                    b_1.samplereqd,
                    b_1.amenddate,
                    b_1.formtype,
                    b_1.formtype_longname,
                    b_1.exchange,
                    b_1.conditions,
                    b_1.paytlocn,
                    b_1.lastsplit,
                    b_1.splitdate,
                    b_1.cp_qtysign,
                    b_1.orgunquant,
                    b_1.cp_origqty_amount_in_words,
                    b_1.contract_split_tonnage,
                    b_1.unitprice,
                    b_1.currency,
                    b_1.currency_name,
                    b_1.currency_longname,
                    b_1.priceunit,
                    b_1.priceunit_name,
                    b_1.priceunit_longname,
                    b_1.shipment,
                    b_1.cp_shipment_desc,
                    b_1.price_fixing,
                    b_1.pfcontract,
                    b_1.pfcontract_name,
                    b_1.pfcontract_longname,
                    b_1.pftermcurr,
                    b_1.pftermunit,
                    b_1.pfposition,
                    b_1.pfdifftype,
                    b_1.pfdiffer,
                    b_1.pfoption,
                    b_1.pfdiffcurr,
                    b_1.pfdiffcurr_name,
                    b_1.pfdiffcurr_longname,
                    b_1.pfdiffunit,
                    b_1.pfdiffunit_name,
                    b_1.pfdiffunit_longname,
                    b_1.fixbydate,
                    b_1.cp_pfoption_desc,
                    b_1.cp_pfdifftype_desc,
                    b_1.cp_pfposition_str,
                    b_1.price_string,
                    b_1.othernotes,
                    b_1.valuedin,
                    b_1.cp_validin_str,
                    b_1.allocref,
                    b_1.shipordelv,
                    b_1.cp_shipordelv_desc,
                    b_1.shipoption,
                    b_1.cp_shipoption_desc,
                    b_1.shipfrom,
                    b_1.shipto,
                    b_1.differential,
                    b_1.lastfix,
                    b_1.moved,
                    b_1.allocated,
                    b_1.unallocated,
                    b_1.invoiced,
                    b_1.uninvoiced,
                    b_1.invposted,
                    b_1.invunposted,
                    b_1.fixed,
                    b_1.unfixed,
                    b_1.fixedlots,
                    b_1.unfixedlots,
                    b_1.fixed_base,
                    b_1.unfixed_base,
                    b_1.stock,
                    b_1.contract_open_quantity,
                    b_1.unquantity,
                    b_1.quantunit,
                    b_1.quantunit_name,
                    b_1.quantunit_longname,
                    b_1.quantunit_longname_plural,
                    b_1.base_unit,
                    b_1.base_currency,
                    b_1.completed_on,
                    b_1.eudr_flag,
                    b_1.client_country,
                    b_1.origin_longname_raw,
                    b_1.commodtype_longname_raw,
                    b_1.commodity_longname_raw,
                    b_1.prcstlocn_longname_raw,
                    b_1.pfdiffcurr_longname AS pfcurrency_longname,
                    b_1.pfcontract_longname AS pf_futconts_longname,
                    b_1.pfdiffunit_longname AS pfdiffunit_longname_raw,
                    b_1.price_term_longname AS price_term_longname_raw
                   FROM base b_1) b
        )
 SELECT systemdate,
    our_name,
    our_longname,
    our_addr1,
    our_addr2,
    our_addr3,
    our_addr4,
    our_addr5,
    our_addr6,
    our_regno,
    our_vatno,
    contno,
    contdate,
    company,
    pcentre,
    split,
    conttype,
    cp_buysell_desc,
    client,
    client_name,
    client_longname,
    client_addr1,
    client_addr2,
    client_addr3,
    client_addr4,
    client_addr5,
    client_addr6,
    cp_buyer_name,
    cp_buyer_longname,
    cp_buyer_addr1,
    cp_buyer_addr2,
    cp_buyer_addr3,
    cp_buyer_addr4,
    cp_buyer_addr5,
    cp_buyer_addr6,
    cp_seller_name,
    cp_seller_longname,
    cp_seller_addr1,
    cp_seller_addr2,
    cp_seller_addr3,
    cp_seller_addr4,
    cp_seller_addr5,
    cp_seller_addr6,
    commodity,
    commodity_name,
    commodity_longname,
    commodtype,
    commodtype_name,
    commodtype_longname,
    origin,
    origin_name,
    origin_longname,
    quality,
    quality_name,
    quality_longname,
    packing,
    packing_name,
    packing_longname,
    payterm,
    payterm_name,
    payterm_longname,
    split_notes,
    cp_description,
    priceterm,
    price_term_name,
    price_term_longname,
    prcstlocn,
    prcstlocn_name,
    prcstlocn_longname,
    port,
    port_name,
    port_longname,
    dest,
    dest_name,
    dest_longname,
    notes,
    crop,
    season,
    clientref,
    insurance,
    insurance_name,
    insurance_longname,
    arbitrationlocn,
    arbit_name,
    arbit_longname,
    freight,
    freight_name,
    freight_longname,
    weights,
    weights_name,
    weight_longname,
    tolerance,
    clause1,
    clause1_name,
    clause1_longname,
    clause2,
    clause2_name,
    clause2_longname,
    clause3,
    clause3_name,
    clause3_longname,
    specialclause,
    specialclause_name,
    specialclause_longname,
    clause4,
    clause5_name,
    clause5_longname,
    clause5,
    clause6_name,
    clause6_longname,
    samplereqd,
    amenddate,
    formtype,
    formtype_longname,
    exchange,
    conditions,
    paytlocn,
    lastsplit,
    splitdate,
    cp_qtysign,
    orgunquant,
    cp_origqty_amount_in_words,
    (orgunquant * (cp_qtysign)::numeric) AS cp_signed_orgunquant,
    contract_split_tonnage,
    unitprice,
    currency,
    currency_name,
    currency_longname,
    priceunit,
    priceunit_name,
    priceunit_longname,
    shipment,
    cp_shipment_desc,
    price_fixing,
    pfcontract,
    pfcontract_name,
    pfcontract_longname,
    pftermcurr,
    pftermunit,
    pfposition,
    pfdifftype,
    pfdiffer,
    pfoption,
    pfdiffcurr,
    pfdiffcurr_name,
    pfdiffcurr_longname,
    pfdiffunit,
    pfdiffunit_name,
    pfdiffunit_longname,
    fixbydate,
    cp_pfoption_desc,
    cp_pfdifftype_desc,
    cp_pfposition_str,
    price_string,
    ((((((((('('::text || (pfoption)::text) || ') '::text) || (pfcontract)::text) || ' / '::text) || (cp_pfposition_str)::text) || ' '::text) || (pfdifftype)::text) || ' '::text) || (pfdiffer)::text) AS cp_pfix_diff,
        CASE
            WHEN (price_fixing = 'Y'::bpchar) THEN ((((((((('('::text || (pfoption)::text) || ') '::text) || (pfcontract)::text) || ' / '::text) || (cp_pfposition_str)::text) || ' '::text) || (pfdifftype)::text) || ' '::text) || (pfdiffer)::text)
            ELSE (unitprice)::text
        END AS cp_price_str,
    cp_pfix_price_desc,
        CASE
            WHEN (price_fixing = 'Y'::bpchar) THEN ((((((((((((((((('Price to be fixed '::text || (public.sp_whosoption(pfoption))::text) || ' at '::text) || rtrim((pfdiffcurr_name)::text)) || ((pfdiffer)::numeric(16,2))::text) || ' ('::text) || (public.sp_ntos(pfdiffer, 'EN'::bpchar))::text) || ' '::text) || (pfdiffcurr_longname)::text) || ') '::text) || ' per '::text) || (pfdiffunit_longname)::text) || ' '::text) || cp_pfdifftype_desc) || ' '::text) || (public.sp_long_month((cp_pfposition_str)::character varying))::text) || ' delivery position of the '::text) || (pfcontract_longname)::text)
            ELSE ((((((((unitprice)::numeric(16,2))::text || ' ('::text) || (public.sp_ntos(unitprice, 'EN'::bpchar))::text) || ') '::text) || rtrim((currency_longname)::text)) || ' per '::text) || rtrim((priceunit_longname)::text))
        END AS cp_fullpricestr,
    othernotes,
    valuedin,
    cp_validin_str,
    allocref,
    shipordelv,
    cp_shipordelv_desc,
    shipoption,
    cp_shipoption_desc,
    shipfrom,
    shipto,
    differential,
    lastfix,
    moved,
    allocated,
    unallocated,
    invoiced,
    uninvoiced,
    invposted,
    invunposted,
    fixed,
    unfixed,
    fixedlots,
    unfixedlots,
    fixed_base,
    unfixed_base,
    stock,
    contract_open_quantity,
        CASE
            WHEN (contract_open_quantity = (0)::numeric) THEN 'Y'::text
            ELSE 'N'::text
        END AS contract_completed,
    public.sp_convert_qty(stock, quantunit, base_unit) AS cp_base_stock,
    public.sp_convert_qty(allocated, quantunit, base_unit) AS cp_base_allocated,
    public.sp_convert_qty(unallocated, quantunit, base_unit) AS cp_base_unallocated,
    (unquantity + stock) AS unquantity,
    quantunit,
    quantunit_name,
    quantunit_longname,
    quantunit_longname_plural,
    public.sp_ntos(orgunquant, 'EN'::bpchar) AS cp_amount_in_words,
    ((((unquantity + stock))::text || ' '::text) || (quantunit_longname)::text) AS cp_unquantity_desc,
    base_unit AS sysbaseunit,
    public.sp_convert_qty((unquantity + stock), quantunit, base_unit) AS cp_base_open,
    ((unquantity + stock) * (cp_qtysign)::numeric) AS cp_signed_unquantity,
    (public.sp_convert_qty((unquantity + stock), quantunit, base_unit) * (cp_qtysign)::numeric) AS cp_signed_base_open,
    completed_on,
    eudr_flag,
    client_country
   FROM computed c;




CREATE OR REPLACE VIEW public.physical_long_short_position_view AS
 SELECT phys_avail.contract_type,
    phys_avail.contno AS contract_number,
    phys_avail.split AS contract_split,
    master_contracts.commodtype AS commodity_type,
    master_contracts.origin,
    master_contracts.quality,
    quality.longname AS quality_longname,
    public.sp_prompt_month(sub_contracts.vlposition) AS valuation_month,
    sub_contracts.client,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN 'Price-fixing'::text
            ELSE 'Outright Price'::text
        END AS price_fixing,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_pricestr(sub_contracts.price_fixing, sub_contracts.unitprice, sub_contracts.currency, sub_contracts.priceunit, sub_contracts.pfcontract, sub_contracts.pfposition, sub_contracts.pfdifftype, sub_contracts.pfdiffer, sub_contracts.pfdiffcurr, sub_contracts.pfdiffunit)
            ELSE ''::character varying
        END AS price_fixing_price,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN ((((TRIM(BOTH FROM to_char(public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split), 'FM999999999999.9999'::text)) || ' '::text) || (sub_contracts.currency)::text) || '/'::text) || (sub_contracts.priceunit)::text)
            ELSE (((((sub_contracts.unitprice)::text || ' '::text) || (sub_contracts.currency)::text) || '/'::text) || (sub_contracts.priceunit)::text)
        END AS price_or_average_fixed,
        CASE
            WHEN (sub_contracts.price_fixing = 'N'::bpchar) THEN ''::bpchar
            ELSE public.sp_prompt_month(sub_contracts.pfposition)
        END AS price_fixing_month,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN phys_avail.original
            ELSE (phys_avail.original * ('-1'::integer)::numeric)
        END AS original_quantity,
    sub_contracts.quantunit AS unit,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(phys_avail.original, sub_contracts.quantunit, params.base_unit)
            ELSE (public.sp_convert_qty(phys_avail.original, sub_contracts.quantunit, params.base_unit) * ('-1'::integer)::numeric)
        END AS original_tonnage,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN phys_avail.fixed
            ELSE (phys_avail.fixed * ('-1'::integer)::numeric)
        END AS fixed,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(phys_avail.fixed, sub_contracts.quantunit, params.base_unit)
            ELSE (public.sp_convert_qty(phys_avail.fixed, sub_contracts.quantunit, params.base_unit) * ('-1'::integer)::numeric)
        END AS fixed_tonnage,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN phys_avail.unfixed
            ELSE (phys_avail.unfixed * ('-1'::integer)::numeric)
        END AS unfixed,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(phys_avail.unfixed, sub_contracts.quantunit, params.base_unit)
            ELSE (public.sp_convert_qty(phys_avail.unfixed, sub_contracts.quantunit, params.base_unit) * ('-1'::integer)::numeric)
        END AS unfixed_tonnage,
        CASE
            WHEN (sub_contracts.price_fixing = 'N'::bpchar) THEN (0)::numeric
            ELSE
            CASE
                WHEN (phys_avail.contract_type = 'P'::bpchar) THEN COALESCE((phys_avail.unfixedlots * ('-1'::integer)::numeric), (0)::numeric)
                ELSE COALESCE(phys_avail.unfixedlots, (0)::numeric)
            END
        END AS unfixed_lots,
        CASE
            WHEN (sub_contracts.price_fixing = 'N'::bpchar) THEN (0)::numeric
            ELSE
            CASE
                WHEN (master_contracts.commodtype = 'ROB'::bpchar) THEN round(((
                CASE
                    WHEN (phys_avail.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(phys_avail.unfixed, sub_contracts.quantunit, params.base_unit)
                    ELSE (public.sp_convert_qty(phys_avail.unfixed, sub_contracts.quantunit, params.base_unit) * ('-1'::integer)::numeric)
                END / (10)::numeric) * ('-1'::integer)::numeric), 0)
                ELSE round(((
                CASE
                    WHEN (phys_avail.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(phys_avail.unfixed, sub_contracts.quantunit, params.base_unit)
                    ELSE (public.sp_convert_qty(phys_avail.unfixed, sub_contracts.quantunit, params.base_unit) * ('-1'::integer)::numeric)
                END / 17.0098875) * ('-1'::integer)::numeric), 0)
            END
        END AS calculated_estimated_unfixed_lots,
    master_contracts.priceterm AS price_terms,
    master_contracts.prcstlocn AS price_location,
    sub_contracts.shipfrom AS ship_from_date,
    sub_contracts.shipto AS ship_to_date,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN (phys_avail.openqnt + phys_avail.stock)
            ELSE (phys_avail.openqnt * ('-1'::integer)::numeric)
        END AS open_quantity,
    public.sp_convert_qty(
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN (phys_avail.openqnt + phys_avail.stock)
            ELSE (phys_avail.openqnt * ('-1'::integer)::numeric)
        END, sub_contracts.quantunit, params.base_unit) AS open_tonnage,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN sub_contracts.unquantity
            ELSE (sub_contracts.unquantity * ('-1'::integer)::numeric)
        END AS forward_quantity,
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(sub_contracts.unquantity, sub_contracts.quantunit, params.base_unit)
            ELSE (public.sp_convert_qty(sub_contracts.unquantity, sub_contracts.quantunit, params.base_unit) * ('-1'::integer)::numeric)
        END AS forward_tonnage,
    phys_avail.stock AS stock_quantity,
    public.sp_convert_qty(phys_avail.stock, sub_contracts.quantunit, params.base_unit) AS stock_tonnage,
    '      '::text AS right_margin
   FROM ((((public.phys_avail
     JOIN public.sub_contracts ON (((phys_avail.contno = sub_contracts.contno) AND (phys_avail.split = sub_contracts.split))))
     JOIN public.master_contracts ON ((master_contracts.contno = sub_contracts.contno)))
     JOIN public.quality ON ((master_contracts.quality = quality.code)))
     CROSS JOIN public.params)
  WHERE (abs(
        CASE
            WHEN (phys_avail.contract_type = 'P'::bpchar) THEN (phys_avail.openqnt + phys_avail.stock)
            ELSE (phys_avail.openqnt * ('-1'::integer)::numeric)
        END) > (0)::numeric)
UNION ALL
 SELECT master_contracts.contract_type,
    master_contracts.contno AS contract_number,
    sub_contracts.split AS contract_split,
    master_contracts.commodtype AS commodity_type,
    master_contracts.origin,
    master_contracts.quality,
    quality.longname AS quality_longname,
    public.sp_prompt_month(sub_contracts.vlposition) AS valuation_month,
    master_contracts.client,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN 'Price-fixing'::text
            ELSE 'Outright Price'::text
        END AS price_fixing,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN public.sp_pricestr(sub_contracts.price_fixing, sub_contracts.unitprice, sub_contracts.currency, sub_contracts.priceunit, sub_contracts.pfcontract, sub_contracts.pfposition, sub_contracts.pfdifftype, sub_contracts.pfdiffer, sub_contracts.pfdiffcurr, sub_contracts.pfdiffunit)
            ELSE ''::character varying
        END AS price_fixing_price,
        CASE
            WHEN (sub_contracts.price_fixing = 'Y'::bpchar) THEN ((((TRIM(BOTH FROM to_char(public.sp_phys_avefixprice(sub_contracts.contno, sub_contracts.split), 'FM999999999999.9999'::text)) || ' '::text) || (sub_contracts.currency)::text) || '/'::text) || (sub_contracts.priceunit)::text)
            ELSE (((((sub_contracts.unitprice)::text || ' '::text) || (sub_contracts.currency)::text) || '/'::text) || (sub_contracts.priceunit)::text)
        END AS price_or_average_fixed,
        CASE
            WHEN (sub_contracts.price_fixing = 'N'::bpchar) THEN ''::bpchar
            ELSE public.sp_prompt_month(sub_contracts.pfposition)
        END AS price_fixing_month,
    0 AS original_quantity,
    sub_contracts.quantunit AS unit,
    0 AS original_tonnage,
    0 AS fixed,
    0 AS fixed_tonnage,
    0 AS unfixed,
    0 AS unfixed_tonnage,
    0 AS unfixed_lots,
    0 AS calculated_estimated_unfixed_lots,
    master_contracts.priceterm AS price_terms,
    master_contracts.prcstlocn AS price_location,
    sub_contracts.shipfrom AS ship_from_date,
    sub_contracts.shipto AS ship_to_date,
    0 AS open_quantity,
    0 AS open_tonnage,
    0 AS forward_quantity,
    0 AS forward_tonnage,
    0 AS stock_quantity,
    0 AS stock_tonnage,
    '      '::text AS right_margin
   FROM ((((public.master_contracts
     JOIN public.sub_contracts ON ((master_contracts.contno = sub_contracts.contno)))
     JOIN public.phys_avail ON (((sub_contracts.contno = phys_avail.contno) AND (sub_contracts.split = phys_avail.split))))
     JOIN public.quality ON ((master_contracts.quality = quality.code)))
     CROSS JOIN public.params)
  WHERE ((phys_avail.openqnt + phys_avail.stock) = (0)::numeric);




CREATE OR REPLACE VIEW public.physical_trading_browser_underlying_level1_view AS
 SELECT sub_contracts.contno,
    sub_contracts.split,
    master_contracts.contract_type AS conttype,
    allocated_contracts.quantity AS alloc_quantity,
    public.sp_convert_qty(allocated_contracts.quantity, sub_contracts.quantunit, 'MT'::bpchar) AS base_alloc_quantity,
    public.sp_allocation_check_if_fully_fixed(allocated_contracts.allocation_reference) AS is_allocation_fully_fixed
   FROM public.allocation,
    public.allocated_contracts,
    public.sub_contracts,
    public.master_contracts
  WHERE ((allocated_contracts.allocation_reference = allocation.allocation_reference) AND (allocated_contracts.contno = sub_contracts.contno) AND (allocated_contracts.split = sub_contracts.split) AND (sub_contracts.contno = master_contracts.contno) AND (allocation.allocation_completed = 'N'::bpchar) AND (public.sp_allocation_check_if_fully_fixed(allocated_contracts.allocation_reference) = 'Y'::bpchar) AND (public.sp_allocation_check_if_only_stock(allocated_contracts.allocation_reference) = 'N'::bpchar) AND (public.sp_convert_qty(allocated_contracts.quantity, sub_contracts.quantunit, 'MT'::bpchar) <> (0)::numeric));




CREATE OR REPLACE VIEW public.physical_trading_browser_underlying_level2_view AS
 SELECT phys_valn_view_valn_sopex.company,
    phys_valn_view_valn_sopex.pcentre,
    phys_valn_view_valn_sopex.commodity,
    phys_valn_view_valn_sopex.commodtype,
    commodity_type.longname AS commodtype_longname,
    phys_valn_view_valn_sopex.origin,
    phys_valn_view_valn_sopex.quality,
    commodity_type.longname AS comm_description,
    phys_valn_view_valn_sopex.contno,
    phys_valn_view_valn_sopex.split,
    phys_valn_view_valn_sopex.contract_type AS conttype,
    phys_valn_view_valn_sopex.contdate,
    'Alloc & Fixed'::text AS allocated_fixed_flag,
    'Unallocated OR Alloc but Unfixed'::text AS unallocated_fixed_flag,
    phys_valn_view_valn_sopex.client,
    client.country AS client_country,
    phys_valn_view_valn_sopex.certification,
    sub_contracts.eudr_flag,
    sub_contracts.eudr_date_harvest,
    phys_valn_view_valn_sopex.shipfrom,
    phys_valn_view_valn_sopex.shipto,
        CASE
            WHEN (phys_valn_view_valn_sopex.shipordelv = 'S'::bpchar) THEN ((to_char((phys_valn_view_valn_sopex.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((phys_valn_view_valn_sopex.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS ship_period,
        CASE
            WHEN (phys_valn_view_valn_sopex.shipordelv = 'D'::bpchar) THEN ((to_char((phys_valn_view_valn_sopex.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((phys_valn_view_valn_sopex.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS delivery_period,
    phys_valn_view_valn_sopex.shipordelv,
    COALESCE(public.sp_prompt_month(sub_contracts.pfposition), ''::bpchar) AS cp_pfposition_str,
    phys_valn_view_valn_sopex.priceterm,
    phys_valn_view_valn_sopex.prcst_location,
    phys_valn_view_valn_sopex.payterm AS payment_term,
    phys_valn_view_valn_sopex.chosen_vlcontract AS vlcontract,
    phys_valn_view_valn_sopex.chosen_vlposition AS valuedin,
    public.sp_prompt_month(phys_valn_view_valn_sopex.chosen_vlposition) AS cp_valuedin_str,
    ((((((phys_valn_view_valn_sopex.chosen_vldifftype)::text || ((phys_valn_view_valn_sopex.chosen_vldiffer)::numeric(10,2))::text) || ' '::text) || (phys_valn_view_valn_sopex.chosen_vldiffcurr)::text) || '/'::text) || (phys_valn_view_valn_sopex.chosen_vldiffunit)::text) AS valn_string,
    phys_valn_view_valn_sopex.valn_month,
    params.systemdate,
    phys_valn_view_valn_sopex.true_open AS open_quantity,
    public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar) AS base_openqnt,
    0 AS base_allocated,
    0 AS allocated_unfixed_tonnage,
        CASE
            WHEN (phys_valn_view_valn_sopex.contract_type = 'P'::bpchar) THEN (abs(public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar)) - (abs(0))::numeric)
            ELSE ((abs(public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar)) - (abs(0))::numeric) * ('-1'::integer)::numeric)
        END AS base_unallocated,
    public.sp_list_allocated_contracts_details_fixed(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS allocated_to_contracts_details,
    public.sp_list_allocated_contracts_details_unfixed(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS unallocated_to_contracts_details,
        CASE
            WHEN (phys_valn_view_valn_sopex.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(public.sp_list_allocated_contracts_details_unfixed_invq(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'Q'::bpchar), phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(public.sp_list_allocated_contracts_details_unfixed_invq(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'Q'::bpchar), phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS base_invoiced,
    ''::text AS invoiced_status,
    public.sp_convert_qty(phys_valn_view_valn_sopex.true_open, phys_valn_view_valn_sopex.quantunit, 'MT'::bpchar) AS unquantity_tonnage,
    public.sp_contract_shipment_statuses(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS shipment_statuses,
    public.sp_contract_shipment_etd_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'S'::bpchar) AS shipment_etd,
    public.sp_contract_shipment_etd_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'L'::bpchar) AS shipment_etd_list,
    public.sp_contract_shipment_eta_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'S'::bpchar) AS shipment_eta,
    public.sp_contract_shipment_eta_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, 'L'::bpchar) AS shipment_eta_list,
    ( SELECT string_agg(DISTINCT (stocks.warehouse)::text, ', '::text) AS string_agg
           FROM public.stocks
          WHERE ((stocks.contno = phys_valn_view_valn_sopex.contno) AND (stocks.split = phys_valn_view_valn_sopex.split))) AS stock_warehouses,
    public.sp_list_allocated_contracts_unpaid_sales_invoices_unfixed(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split) AS unsettled_provisional_invoices,
    public.sp_contract_shipment_eudr_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'TEXT'::bpchar) AS contract_shipment_eudr_info,
    public.sp_contract_shipment_eudr_info(phys_valn_view_valn_sopex.contno, phys_valn_view_valn_sopex.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'STATUS'::bpchar) AS contract_shipment_eudr_status,
    phys_valn_view_valn_sopex.quantunit,
    'OPEN'::text AS row_marker
   FROM (((((public.phys_valn_view_valn_sopex
     JOIN public.sub_contracts ON (((phys_valn_view_valn_sopex.contno = sub_contracts.contno) AND (phys_valn_view_valn_sopex.split = sub_contracts.split))))
     JOIN public.commodity_type ON ((phys_valn_view_valn_sopex.commodtype = commodity_type.code)))
     JOIN public.quality ON ((phys_valn_view_valn_sopex.quality = quality.code)))
     JOIN public.client ON ((phys_valn_view_valn_sopex.client = client.code)))
     CROSS JOIN public.params)
  WHERE (phys_valn_view_valn_sopex.true_open > (0)::numeric)
UNION ALL
 SELECT master_contracts.company,
    master_contracts.pcentre,
    master_contracts.commodity,
    master_contracts.commodtype,
    commodity_type.longname AS commodtype_longname,
    master_contracts.origin,
    master_contracts.quality,
    commodity_type.longname AS comm_description,
    sub_contracts.contno,
    sub_contracts.split,
    master_contracts.contract_type AS conttype,
    master_contracts.contdate,
    'Alloc & Fixed'::text AS allocated_fixed_flag,
    'Unallocated OR Alloc but Unfixed'::text AS unallocated_fixed_flag,
    master_contracts.client,
    client.country AS client_country,
    sub_contracts.certification,
    sub_contracts.eudr_flag,
    sub_contracts.eudr_date_harvest,
    sub_contracts.shipfrom,
    sub_contracts.shipto,
        CASE
            WHEN (sub_contracts.shipordelv = 'S'::bpchar) THEN ((to_char((sub_contracts.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((sub_contracts.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS ship_period,
        CASE
            WHEN (sub_contracts.shipordelv = 'D'::bpchar) THEN ((to_char((sub_contracts.shipfrom)::timestamp with time zone, 'DD/MM/YYYY'::text) || '-'::text) || to_char((sub_contracts.shipto)::timestamp with time zone, 'DD/MM/YYYY'::text))
            ELSE '-'::text
        END AS delivery_period,
    sub_contracts.shipordelv,
    COALESCE(public.sp_prompt_month(sub_contracts.pfposition), ''::bpchar) AS cp_pfposition_str,
    master_contracts.priceterm,
    master_contracts.prcstlocn AS prcst_location,
    master_contracts.payterm AS payment_term,
    sub_contracts.vlcontract,
    sub_contracts.vlposition AS valuedin,
    public.sp_prompt_month(sub_contracts.vlposition) AS cp_valuedin_str,
        CASE
            WHEN (sub_contracts.valn_type = 'F'::bpchar) THEN ((((((sub_contracts.valn_price)::numeric(10,2))::text || ' '::text) || (sub_contracts.valn_curr)::text) || '/'::text) || (sub_contracts.valn_unit)::text)
            ELSE ((((((sub_contracts.vldifftype)::text || ((sub_contracts.vldiffer)::numeric(10,2))::text) || ' '::text) || (sub_contracts.vldiffcurr)::text) || '/'::text) || (sub_contracts.vldiffunit)::text)
        END AS valn_string,
    sub_contracts.vlposition AS valn_month,
    params.systemdate,
        CASE
            WHEN (master_contracts.contract_type = 'S'::bpchar) THEN (sum(physical_trading_browser_underlying_level1_view.alloc_quantity) * ('-1'::integer)::numeric)
            ELSE sum(physical_trading_browser_underlying_level1_view.alloc_quantity)
        END AS open_quantity,
    sum(physical_trading_browser_underlying_level1_view.base_alloc_quantity) AS base_openqnt,
    sum(physical_trading_browser_underlying_level1_view.base_alloc_quantity) AS base_allocated,
    0 AS allocated_unfixed_tonnage,
    0 AS base_unallocated,
    public.sp_list_allocated_contracts_details_fixed(sub_contracts.contno, sub_contracts.split) AS allocated_to_contracts_details,
    public.sp_list_allocated_contracts_details_unfixed(sub_contracts.contno, sub_contracts.split) AS unallocated_to_contracts_details,
        CASE
            WHEN (master_contracts.contract_type = 'P'::bpchar) THEN public.sp_convert_qty(public.sp_list_allocated_contracts_details_fixed_invq(sub_contracts.contno, sub_contracts.split, 'Q'::bpchar), sub_contracts.quantunit, 'MT'::bpchar)
            ELSE (public.sp_convert_qty(public.sp_list_allocated_contracts_details_fixed_invq(sub_contracts.contno, sub_contracts.split, 'Q'::bpchar), sub_contracts.quantunit, 'MT'::bpchar) * ('-1'::integer)::numeric)
        END AS base_invoiced,
    ''::text AS invoiced_status,
    0 AS unquantity_tonnage,
    public.sp_contract_shipment_statuses(sub_contracts.contno, sub_contracts.split) AS shipment_statuses,
    public.sp_contract_shipment_etd_info(sub_contracts.contno, sub_contracts.split, 'S'::bpchar) AS shipment_etd,
    public.sp_contract_shipment_etd_info(sub_contracts.contno, sub_contracts.split, 'L'::bpchar) AS shipment_etd_list,
    public.sp_contract_shipment_eta_info(sub_contracts.contno, sub_contracts.split, 'S'::bpchar) AS shipment_eta,
    public.sp_contract_shipment_eta_info(sub_contracts.contno, sub_contracts.split, 'L'::bpchar) AS shipment_eta_list,
    ( SELECT string_agg(DISTINCT (stocks.warehouse)::text, ', '::text) AS string_agg
           FROM public.stocks
          WHERE ((stocks.contno = sub_contracts.contno) AND (stocks.split = sub_contracts.split))) AS stock_warehouses,
    public.sp_list_allocated_contracts_unpaid_sales_invoices_fixed(sub_contracts.contno, sub_contracts.split) AS unsettled_provisional_invoices,
    public.sp_contract_shipment_eudr_info(sub_contracts.contno, sub_contracts.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'TEXT'::bpchar) AS contract_shipment_eudr_info,
    public.sp_contract_shipment_eudr_info(sub_contracts.contno, sub_contracts.split, sub_contracts.eudr_flag, (sub_contracts.eudr_date_harvest)::bpchar, 'STATUS'::bpchar) AS contract_shipment_eudr_status,
    sub_contracts.quantunit,
    'ALLOC'::text AS row_marker
   FROM (((((public.physical_trading_browser_underlying_level1_view
     JOIN public.sub_contracts ON (((sub_contracts.contno = physical_trading_browser_underlying_level1_view.contno) AND (sub_contracts.split = physical_trading_browser_underlying_level1_view.split))))
     JOIN public.master_contracts ON ((sub_contracts.contno = master_contracts.contno)))
     JOIN public.commodity_type ON ((master_contracts.commodtype = commodity_type.code)))
     JOIN public.client ON ((sub_contracts.client = client.code)))
     CROSS JOIN public.params)
  GROUP BY master_contracts.company, master_contracts.pcentre, master_contracts.commodity, master_contracts.commodtype, commodity_type.longname, master_contracts.origin, master_contracts.quality, sub_contracts.contno, sub_contracts.split, master_contracts.contract_type, master_contracts.contdate, master_contracts.client, client.country, sub_contracts.certification, sub_contracts.eudr_flag, sub_contracts.eudr_date_harvest, sub_contracts.quantunit, sub_contracts.shipfrom, sub_contracts.shipto, sub_contracts.shipordelv, master_contracts.priceterm, master_contracts.prcstlocn, master_contracts.payterm, sub_contracts.vlcontract, sub_contracts.vlposition, sub_contracts.valn_type, sub_contracts.valn_price, sub_contracts.valn_curr, sub_contracts.valn_unit, sub_contracts.vldifftype, sub_contracts.vldiffer, sub_contracts.vldiffcurr, sub_contracts.vldiffunit, sub_contracts.pfposition, params.systemdate;




CREATE OR REPLACE VIEW public.powerbi_caja_forex_deals AS
 SELECT public.sp_termcontno(terminal.contdate, terminal.seqno) AS fx_trade_contract_number,
    terminal.contdate AS fx_trade_date,
    terminal.seqno AS fx_trade_seqno,
    terminal.broker AS bank,
    sub_contracts.contno AS contract_number,
    sub_contracts.split,
    terminal.futconts AS fx_market,
    (terminal.prompt)::date AS expiry_date,
        CASE
            WHEN (terminal.plots IS NOT NULL) THEN futures_contract.currency
            ELSE futures_contract.othercurr
        END AS buy_currency,
        CASE
            WHEN (terminal.plots IS NOT NULL) THEN terminal.plots
            ELSE
            CASE
                WHEN (terminal.dealratetype = 'M'::bpchar) THEN (terminal.slots * terminal.tprice)
                ELSE (terminal.slots / terminal.tprice)
            END
        END AS buy_amount,
    terminal.tprice AS deal_rate,
        CASE
            WHEN (terminal.slots IS NOT NULL) THEN futures_contract.currency
            ELSE futures_contract.othercurr
        END AS sell_currency,
        CASE
            WHEN (terminal.plots IS NOT NULL) THEN
            CASE
                WHEN (terminal.dealratetype = 'M'::bpchar) THEN (terminal.plots * terminal.tprice)
                ELSE (terminal.plots / terminal.tprice)
            END
            ELSE terminal.slots
        END AS sell_amount,
    to_char(((terminal.prompt)::date)::timestamp with time zone, 'YYYY-MM'::text) AS fx_maturity_year_month
   FROM (((public.terminal
     LEFT JOIN public.forex_hedges ON (((terminal.contdate = forex_hedges.termdate) AND (terminal.seqno = forex_hedges.termseqno))))
     LEFT JOIN public.sub_contracts ON (((forex_hedges.contno = sub_contracts.contno) AND (forex_hedges.split = sub_contracts.split))))
     LEFT JOIN public.master_contracts ON ((sub_contracts.contno = master_contracts.contno))),
    public.futures_contract,
    public.params
  WHERE ((terminal.futconts = futures_contract.code) AND (terminal.mktype = 'X'::bpchar));




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




CREATE OR REPLACE VIEW public.powerbi_invoiced_contracts AS
 SELECT invoice.invoice_type,
    invoice.invoice_number,
    stocks.original_allocation_reference AS invoice_allocation_reference,
    invoice.client AS invoice_client,
    client.country AS client_country,
    invoice.commodity_type AS invoice_commodity_type,
    invoice.origin AS invoice_origin,
    invoice.quality AS invoice_quality,
    invoice.invoice_date AS invoice_document_date,
    invoice.posted_date AS invoice_posted_date,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.house_rate AS invoice_house_rate,
    invoice.payment_terms AS invoice_payment_terms,
    sub_contracts.contno AS contract_number,
    sub_contracts.split,
    master_contracts.contdate AS contract_date,
    master_contracts.priceterm AS price_terms,
    master_contracts.prcstlocn AS price_terms_location,
    sub_contracts.shipordelv AS shipment_or_delivery,
    sub_contracts.shipment AS shipment_period,
    sub_contracts.shipfrom AS shipment_from,
    sub_contracts.shipto AS shipment_to,
    sub_contracts.orgunquant AS contract_original_quantity,
    sub_contracts.quantunit AS quantity_unit,
    public.sp_convert_qty(sub_contracts.orgunquant, sub_contracts.quantunit, params.base_unit) AS contract_original_tonnage,
    ( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))) AS invoice_positional_quantity,
    public.sp_convert_qty(( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))), sub_contracts.quantunit, params.base_unit) AS invoice_positional_tonnage,
    ( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))) AS invoice_invoiced_quantity,
    public.sp_convert_qty(( SELECT sum(invoice_details_2.positional_quantity) AS sum
           FROM public.invoice_details_2
          WHERE ((invoice_details_2.invoice_number = invoice.invoice_number) AND (invoice_details_2.invoice_type = invoice.invoice_type) AND (invoice_details_2.client = invoice.client))), sub_contracts.quantunit, params.base_unit) AS invoice_invoiced_tonnage,
    (((((stocks.contno)::text || '-'::text) || (stocks.split)::text) || '-'::text) || concat(stocks.stock_id)) AS stock_reference,
    invoice_stocks.stock_quantity,
    stocks.quantity_unit AS stock_quantity_unit,
    public.sp_convert_qty(invoice_stocks.stock_quantity, stocks.quantity_unit, params.base_unit) AS stock_tonnage,
    stocks.original_invoice_number AS stock_purchase_invoice_number,
    stocks.original_client AS stock_purchase_invoice_client,
    stocks.original_allocation_reference AS stock_purchase_allocation_reference,
    stocks.commodity_type AS stock_commodity_type,
    stocks.origin AS stock_origin,
    stocks.quality AS stock_quality,
    invoice.invoice_date AS stock_purchase_invoice_document_date,
    invoice.posted_date AS stock_purchase_invoice_posted_date
   FROM public.invoice,
    public.invoice_stocks,
    public.master_contracts,
    public.sub_contracts,
    public.client,
    public.stocks,
    public.params
  WHERE ((invoice.invoice_type = invoice_stocks.invoice_type) AND (invoice.invoice_number = invoice_stocks.invoice_number) AND (invoice.client = invoice_stocks.client) AND (invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id) AND (stocks.contno = sub_contracts.contno) AND (stocks.split = sub_contracts.split) AND (invoice_stocks.contno = master_contracts.contno) AND (invoice.client = client.code) AND (invoice.invoice_type = 'P'::bpchar) AND (invoice_stocks.stock_quantity > (0)::numeric) AND (invoice.posted_date IS NOT NULL))
UNION ALL
 SELECT invoice_details_2.invoice_type,
    invoice_details_2.invoice_number,
    invoice_details_2.allocation_reference AS invoice_allocation_reference,
    invoice_details_2.client AS invoice_client,
    client.country AS client_country,
    invoice.commodity_type AS invoice_commodity_type,
    invoice.origin AS invoice_origin,
    invoice.quality AS invoice_quality,
    invoice.invoice_date AS invoice_document_date,
    invoice.posted_date AS invoice_posted_date,
    invoice.invoice_value,
    invoice.invoice_currency,
    invoice.house_rate AS invoice_house_rate,
    invoice.payment_terms AS invoice_payment_terms,
    invoice_details_2.contno AS contract_number,
    invoice_details_2.split,
    master_contracts.contdate AS contract_date,
    master_contracts.priceterm AS price_terms,
    master_contracts.prcstlocn AS price_terms_location,
    sub_contracts.shipordelv AS shipment_or_delivery,
    sub_contracts.shipment AS shipment_period,
    sub_contracts.shipfrom AS shipment_from,
    sub_contracts.shipto AS shipment_to,
    sub_contracts.orgunquant AS contract_original_quantity,
    sub_contracts.quantunit AS quantity_unit,
    public.sp_convert_qty(sub_contracts.orgunquant, sub_contracts.quantunit, params.base_unit) AS contract_original_tonnage,
    invoice_details_2.positional_quantity AS invoice_positional_quantity,
    public.sp_convert_qty(invoice_details_2.positional_quantity, sub_contracts.quantunit, params.base_unit) AS invoice_positional_tonnage,
    invoice_details_2.invoiced_quantity AS invoice_invoiced_quantity,
    public.sp_convert_qty(invoice_details_2.invoiced_quantity, sub_contracts.quantunit, params.base_unit) AS invoice_invoiced_tonnage,
    (((((stocks.contno)::text || '-'::text) || (stocks.split)::text) || '-'::text) || concat(stocks.stock_id)) AS stock_reference,
    invoice_stocks.stock_quantity,
    stocks.quantity_unit AS stock_quantity_unit,
    public.sp_convert_qty(invoice_stocks.stock_quantity, stocks.quantity_unit, params.base_unit) AS stock_tonnage,
    stocks.original_invoice_number AS stock_purchase_invoice_number,
    stocks.original_client AS stock_purchase_invoice_client,
    stocks.original_allocation_reference AS stock_purchase_allocation_reference,
    stocks.commodity_type AS stock_commodity_type,
    stocks.origin AS stock_origin,
    stocks.quality AS stock_quality,
    ( SELECT purch_invoice.invoice_date
           FROM public.invoice purch_invoice
          WHERE ((purch_invoice.invoice_number = stocks.original_invoice_number) AND (purch_invoice.client = stocks.original_client) AND (purch_invoice.invoice_type = 'P'::bpchar))) AS stock_purchase_invoice_document_date,
    ( SELECT purch_invoice.posted_date
           FROM public.invoice purch_invoice
          WHERE ((purch_invoice.invoice_number = stocks.original_invoice_number) AND (purch_invoice.client = stocks.original_client) AND (purch_invoice.invoice_type = 'P'::bpchar))) AS stock_purchase_invoice_posted_date
   FROM public.invoice,
    public.invoice_details_2,
    public.invoice_stocks,
    public.master_contracts,
    public.sub_contracts,
    public.client,
    public.stocks,
    public.params
  WHERE ((invoice.invoice_type = invoice_details_2.invoice_type) AND (invoice.invoice_number = invoice_details_2.invoice_number) AND (invoice.client = invoice_details_2.client) AND (invoice_details_2.invoice_type = invoice_stocks.invoice_type) AND (invoice_details_2.invoice_number = invoice_stocks.invoice_number) AND (invoice_details_2.client = invoice_stocks.client) AND (invoice_stocks.contno = stocks.contno) AND (invoice_stocks.split = stocks.split) AND (invoice_stocks.stock_id = stocks.stock_id) AND (invoice.client = client.code) AND (invoice_details_2.contno = master_contracts.contno) AND (invoice_details_2.contno = sub_contracts.contno) AND (invoice_details_2.split = sub_contracts.split) AND (invoice.invoice_type = 'S'::bpchar))
  ORDER BY 1, 2, 4, 10, 11;




CREATE OR REPLACE VIEW public.term_hedges_valn AS
 SELECT a.contno,
    a.split,
    a.termdate,
    a.termseqno,
    a.quantity,
    a.quantunit,
    b.futconts,
    b.prompt,
    b.tradetype,
    b.series,
    b.tprice AS hedgeprice,
    b.busdate AS closedate,
    public.sp_term_valprice(b.busdate, b.futconts, b.prompt, b.tradetype, b.series) AS closing,
    b.plots,
    b.slots,
    c.lots AS origlots,
    b.lotfactor,
    b.pricefactor,
    b.mktcurr,
    b.mktunit
   FROM ((public.terminal_hedges a
     JOIN public.termclosed_view b ON (((b.contdate = a.termdate) AND (b.seqno = a.termseqno))))
     JOIN public.terminal c ON (((c.contdate = b.contdate) AND (c.seqno = b.seqno))))
  WHERE (b.histaction = 'S'::bpchar)
UNION
 SELECT a.contno,
    a.split,
    a.termdate,
    a.termseqno,
    a.quantity,
    a.quantunit,
    b.futconts,
    b.prompt,
    b.tradetype,
    b.series,
    b.tprice AS hedgeprice,
    params.systemdate AS closedate,
    public.sp_term_valprice(params.systemdate, b.futconts, b.prompt, b.tradetype, b.series) AS closing,
    b.plots,
    b.slots,
    b.lots AS origlots,
    b.lotfactor,
    b.pricefactor,
    b.mktcurr,
    b.mktunit
   FROM ((public.terminal_hedges a
     JOIN public.term_view b ON (((b.contdate = a.termdate) AND (b.seqno = a.termseqno))))
     CROSS JOIN public.params);






