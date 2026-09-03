-- Migration 0011: Widen allocation_reference from char(10) to char(20)
-- Affects: 22 tables (char(10) columns), 12 FK constraints, 22 views, 17 functions
-- Note: allocated_containers and allocation_container already have char(20) — not touched

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0011_allocation_reference_widen') THEN
    RAISE NOTICE 'Migration 0011 already applied, skipping.';
    RETURN;
  END IF;

  -- ============================================================
  -- STEP 1: Drop all 22 dependent views
  -- ============================================================
  DROP VIEW IF EXISTS public.alloc_contracts_view CASCADE;
  DROP VIEW IF EXISTS public.allocated_purch_quantity CASCADE;
  DROP VIEW IF EXISTS public.allocated_purch_quantity_extended CASCADE;
  DROP VIEW IF EXISTS public.bal_anal_view CASCADE;
  DROP VIEW IF EXISTS public.crdrnote_view CASCADE;
  DROP VIEW IF EXISTS public.expenses_month_end_reports_view CASCADE;
  DROP VIEW IF EXISTS public.expenses_view CASCADE;
  DROP VIEW IF EXISTS public.floating_stock_view CASCADE;
  DROP VIEW IF EXISTS public.forecast_report_outbooked_p_expenses_view CASCADE;
  DROP VIEW IF EXISTS public.invoice_allocation_detail_view CASCADE;
  DROP VIEW IF EXISTS public.invoice_charges_view CASCADE;
  DROP VIEW IF EXISTS public.invoice_charges_view2 CASCADE;
  DROP VIEW IF EXISTS public.invoice_contracts_view CASCADE;
  DROP VIEW IF EXISTS public.invoice_details_2_copy_of_original_view CASCADE;
  DROP VIEW IF EXISTS public.invoices_stocks_view CASCADE;
  DROP VIEW IF EXISTS public.phys_alloc CASCADE;
  DROP VIEW IF EXISTS public.phys_pricing3 CASCADE;
  DROP VIEW IF EXISTS public.phys_stocks CASCADE;
  DROP VIEW IF EXISTS public.phys_valn_view3 CASCADE;
  DROP VIEW IF EXISTS public.physical_trading_browser_underlying_level1_view CASCADE;
  DROP VIEW IF EXISTS public.powerbi_caja_stocks_by_warehouse CASCADE;
  DROP VIEW IF EXISTS public.powerbi_invoiced_contracts CASCADE;

  -- ============================================================
  -- STEP 2: Drop FK constraints referencing allocation_reference
  -- ============================================================
  ALTER TABLE public.alloc_shipment DROP CONSTRAINT IF EXISTS fk_alloc_shipment_allocation;
  ALTER TABLE public.allocated_contracts DROP CONSTRAINT IF EXISTS fk_alloccont_allocation;
  ALTER TABLE public.expenses_detail DROP CONSTRAINT IF EXISTS fk_expenses_detail_allocated_contracts;
  ALTER TABLE public.expenses_summary DROP CONSTRAINT IF EXISTS fk_expense_invalloc;
  ALTER TABLE public.final_invoice_details_2 DROP CONSTRAINT IF EXISTS fk_fininvdets2_contract;
  ALTER TABLE public.invoice DROP CONSTRAINT IF EXISTS fk_invoice_allocation;
  ALTER TABLE public.invoice_details_2 DROP CONSTRAINT IF EXISTS fk_invdets2_contract;
  ALTER TABLE public.invoice_stocks_tariffs DROP CONSTRAINT IF EXISTS fk_tariffs_allocated_contracts;
  ALTER TABLE public.provisional_invoice_archive DROP CONSTRAINT IF EXISTS fk_invoice_allocation;
  ALTER TABLE public.provisional_invoice_details_2_archive DROP CONSTRAINT IF EXISTS fk_invdets2_contract;
  ALTER TABLE public.stocks DROP CONSTRAINT IF EXISTS fk_stock_physalloc;

  -- ============================================================
  -- STEP 3: Widen allocation_reference in all 22 char(10) tables
  -- ============================================================
  ALTER TABLE public.alloc_shipment ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.allocated_contracts ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.allocation ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.allocation_history ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.document_tracking ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.expenses_detail ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.expenses_summary ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.final_invoice_details_2 ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.historical_report_snapshots_05_alloc_pl ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.invoice ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.invoice_allocation ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.invoice_allocation_history ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.invoice_charges ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.invoice_details_2 ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.invoice_history ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.invoice_stocks_tariffs ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.phys_position_history ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.provisional_invoice_archive ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.provisional_invoice_details_2_archive ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.shipment_history ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.stocks ALTER COLUMN allocation_reference TYPE char(20);
  ALTER TABLE public.stocks_history ALTER COLUMN allocation_reference TYPE char(20);

  -- ============================================================
  -- STEP 4: Re-add FK constraints
  -- ============================================================
  ALTER TABLE public.alloc_shipment
    ADD CONSTRAINT fk_alloc_shipment_allocation
      FOREIGN KEY (allocation_reference) REFERENCES public.allocation(allocation_reference);

  ALTER TABLE public.allocated_contracts
    ADD CONSTRAINT fk_alloccont_allocation
      FOREIGN KEY (allocation_reference) REFERENCES public.allocation(allocation_reference) ON UPDATE CASCADE;

  ALTER TABLE public.expenses_detail
    ADD CONSTRAINT fk_expenses_detail_allocated_contracts
      FOREIGN KEY (allocation_reference, contno, split) REFERENCES public.allocated_contracts(allocation_reference, contno, split);

  ALTER TABLE public.expenses_summary
    ADD CONSTRAINT fk_expense_invalloc
      FOREIGN KEY (allocation_reference) REFERENCES public.invoice_allocation(allocation_reference);

  ALTER TABLE public.final_invoice_details_2
    ADD CONSTRAINT fk_fininvdets2_contract
      FOREIGN KEY (allocation_reference, contno, split) REFERENCES public.allocated_contracts(allocation_reference, contno, split);

  ALTER TABLE public.invoice
    ADD CONSTRAINT fk_invoice_allocation
      FOREIGN KEY (allocation_reference) REFERENCES public.invoice_allocation(allocation_reference);

  ALTER TABLE public.invoice_details_2
    ADD CONSTRAINT fk_invdets2_contract
      FOREIGN KEY (allocation_reference, contno, split) REFERENCES public.allocated_contracts(allocation_reference, contno, split);

  ALTER TABLE public.invoice_stocks_tariffs
    ADD CONSTRAINT fk_tariffs_allocated_contracts
      FOREIGN KEY (sales_contno, sales_split, allocation_reference) REFERENCES public.allocated_contracts(contno, split, allocation_reference);

  ALTER TABLE public.provisional_invoice_archive
    ADD CONSTRAINT fk_invoice_allocation
      FOREIGN KEY (allocation_reference) REFERENCES public.invoice_allocation(allocation_reference);

  ALTER TABLE public.provisional_invoice_details_2_archive
    ADD CONSTRAINT fk_invdets2_contract
      FOREIGN KEY (allocation_reference, contno, split) REFERENCES public.allocated_contracts(allocation_reference, contno, split);

  ALTER TABLE public.stocks
    ADD CONSTRAINT fk_stock_physalloc
      FOREIGN KEY (allocation_reference) REFERENCES public.allocation(allocation_reference);

  -- ============================================================
  -- STEP 5: Update 17 function local variables char(10) → char(20)
  -- ============================================================

  CREATE OR REPLACE FUNCTION public.sp_allocation_calculate_only_normal_alloc_quantity(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ln_total_allocation_quantity NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_is_this_allocation_fully_fixed char(1);
    ls_allocation_reference char(20);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ln_total_allocation_quantity := 0;
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      SELECT sp_allocation_check_if_fully_fixed(ls_allocation_reference) INTO ls_is_this_allocation_fully_fixed;
      IF ls_is_this_stock_allocation = 'N' AND ls_is_this_allocation_fully_fixed = 'Y' THEN
        SELECT COALESCE(allocated_contracts.quantity, 0)
          INTO ln_single_allocation_quantity FROM allocated_contracts
          WHERE allocated_contracts.allocation_reference = ls_allocation_reference
            AND allocated_contracts.contno = as_contno
            AND allocated_contracts.split = as_split;
        ln_total_allocation_quantity := ln_total_allocation_quantity + ln_single_allocation_quantity;
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ln_total_allocation_quantity;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_calculate_only_normal_alloc_stock_quantity(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ln_total_stock_quantity NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_is_this_allocation_fully_fixed char(1);
    ls_allocation_reference char(20);
    ln_single_stock_quantity NUMERIC(16,4);
  BEGIN
    ln_total_stock_quantity := 0;
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      IF ls_is_this_stock_allocation = 'N' THEN
        SELECT COALESCE(sum(stocks.quantity), 0)
          INTO ln_single_stock_quantity
          FROM stocks
          WHERE stocks.allocation_reference = ls_allocation_reference
            AND stocks.contno = as_contno
            AND stocks.split = as_split;
        ln_total_stock_quantity := ln_total_stock_quantity + ln_single_stock_quantity;
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ln_total_stock_quantity;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_calculate_only_normal_unfixed_alloc_quantity(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ln_total_allocation_quantity NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_is_this_allocation_fully_fixed char(1);
    ls_allocation_reference char(20);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ln_total_allocation_quantity := 0;
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      SELECT sp_allocation_check_if_fully_fixed(ls_allocation_reference) INTO ls_is_this_allocation_fully_fixed;
      IF ls_is_this_stock_allocation = 'N' AND ls_is_this_allocation_fully_fixed = 'N' THEN
        SELECT COALESCE(allocated_contracts.quantity, 0)
          INTO ln_single_allocation_quantity
          FROM allocated_contracts
          WHERE allocated_contracts.allocation_reference = ls_allocation_reference
            AND allocated_contracts.contno = as_contno
            AND allocated_contracts.split = as_split;
        ln_total_allocation_quantity := ln_total_allocation_quantity + ln_single_allocation_quantity;
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ln_total_allocation_quantity;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_calculate_only_stock_alloc_quantity(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ln_total_stock_allocation_quantity NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_allocation_reference char(20);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ln_total_stock_allocation_quantity := 0;
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      IF ls_is_this_stock_allocation = 'Y' THEN
        SELECT COALESCE(allocated_contracts.quantity, 0)
          INTO ln_single_allocation_quantity
          FROM allocated_contracts
          WHERE allocated_contracts.allocation_reference = ls_allocation_reference
            AND allocated_contracts.contno = as_contno
            AND allocated_contracts.split = as_split;
        ln_total_stock_allocation_quantity := ln_total_stock_allocation_quantity + ln_single_allocation_quantity;
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ln_total_stock_allocation_quantity;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_calculate_only_stock_alloc_stock_quantity(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ln_total_stock_quantity NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_is_this_allocation_fully_fixed char(1);
    ls_allocation_reference char(20);
    ln_single_stock_quantity NUMERIC(16,4);
  BEGIN
    ln_total_stock_quantity := 0;
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      IF ls_is_this_stock_allocation = 'Y' THEN
        SELECT COALESCE(sum(stocks.quantity), 0)
          INTO ln_single_stock_quantity
          FROM stocks
          WHERE stocks.allocation_reference = ls_allocation_reference
            AND stocks.contno = as_contno
            AND stocks.split = as_split;
        ln_total_stock_quantity := ln_total_stock_quantity + ln_single_stock_quantity;
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ln_total_stock_quantity;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_calculate_total_normal_alloc_quantity(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ln_total_allocation_quantity NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_allocation_reference char(20);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ln_total_allocation_quantity := 0;
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      IF ls_is_this_stock_allocation = 'N' THEN
        SELECT COALESCE(allocated_contracts.quantity, 0)
          INTO ln_single_allocation_quantity
          FROM allocated_contracts
          WHERE allocated_contracts.allocation_reference = ls_allocation_reference
            AND allocated_contracts.contno = as_contno
            AND allocated_contracts.split = as_split;
        ln_total_allocation_quantity := ln_total_allocation_quantity + ln_single_allocation_quantity;
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ln_total_allocation_quantity;
  END;$func$;

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
    ls_allocation_reference char(20);
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

  CREATE OR REPLACE FUNCTION public.sp_allocation_describe_only_stock_alloc_quantity(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ls_return_text char(2048);
    ls_is_this_stock_allocation char(1);
    ls_allocation_reference char(20);
    ls_contract_quantunit char(4);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ls_return_text := E'\n' || 'Allocation details: ' || E'\n\n';
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      IF ls_is_this_stock_allocation = 'Y' THEN
        SELECT COALESCE(allocated_contracts.quantity, 0), sub_contracts.quantunit
          INTO ln_single_allocation_quantity, ls_contract_quantunit
          FROM allocation, allocated_contracts, sub_contracts
          WHERE allocated_contracts.allocation_reference = ls_allocation_reference
            AND allocated_contracts.allocation_reference = allocation.allocation_reference
            AND allocated_contracts.contno = sub_contracts.contno
            AND allocated_contracts.split = sub_contracts.split
            AND allocated_contracts.contno = as_contno
            AND allocated_contracts.split = as_split;
        ls_return_text := ls_return_text || ln_single_allocation_quantity::text || ' ' || ls_contract_quantunit || ' allocated in ' || ls_allocation_reference || E'\n';
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ls_return_text;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_describe_total_normal_alloc_quantity(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ls_return_text char(2048);
    ls_is_this_stock_allocation char(1);
    ls_is_this_allocation_fully_fixed char(1);
    ls_allocation_reference char(20);
    ls_allocation_completed char(1);
    ls_allocation_completed_description char(16);
    ls_contract_quantunit char(4);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ls_return_text := E'\n' || 'Allocation details: ' || E'\n\n';
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      SELECT sp_allocation_check_if_fully_fixed(ls_allocation_reference) INTO ls_is_this_allocation_fully_fixed;
      IF ls_is_this_stock_allocation = 'N' THEN
        SELECT COALESCE(allocated_contracts.quantity, 0), sub_contracts.quantunit, allocation.allocation_completed
          INTO ln_single_allocation_quantity, ls_contract_quantunit, ls_allocation_completed
          FROM allocation, allocated_contracts, sub_contracts
          WHERE allocated_contracts.allocation_reference = ls_allocation_reference
            AND allocated_contracts.allocation_reference = allocation.allocation_reference
            AND allocated_contracts.contno = sub_contracts.contno
            AND allocated_contracts.split = sub_contracts.split
            AND allocated_contracts.contno = as_contno
            AND allocated_contracts.split = as_split;
        IF ls_allocation_completed = 'Y' THEN
          ls_allocation_completed_description := 'Realised';
        ELSE
          ls_allocation_completed_description := 'Not realised';
        END IF;
        IF ls_is_this_allocation_fully_fixed = 'Y' THEN
          ls_return_text := ls_return_text || ln_single_allocation_quantity::text || ' ' || ls_contract_quantunit || ' allocated in ' || ls_allocation_reference || ' (Fully fixed, ' || ls_allocation_completed_description || ')' || E'\n';
        ELSE
          ls_return_text := ls_return_text || ln_single_allocation_quantity::text || ' ' || ls_contract_quantunit || ' allocated in ' || ls_allocation_reference || ' (Partly/fully unfixed, ' || ls_allocation_completed_description || ')' || E'\n';
        END IF;
      END IF;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ls_return_text;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_allocation_sum_up_realised_alloc_quantity(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsallocations CURSOR FOR
      SELECT allocation.allocation_reference
        FROM allocation, allocated_contracts
        WHERE allocation.allocation_reference = allocated_contracts.allocation_reference
          AND allocation.allocation_completed = 'Y'
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
    ln_total_allocation_quantity NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_is_this_allocation_realised char(1);
    ls_allocation_reference char(20);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ln_total_allocation_quantity := 0;
    OPEN contractsallocations;
    FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT COALESCE(allocated_contracts.quantity, 0)
        INTO ln_single_allocation_quantity
        FROM allocated_contracts
        WHERE allocated_contracts.allocation_reference = ls_allocation_reference
          AND allocated_contracts.contno = as_contno
          AND allocated_contracts.split = as_split;
      ln_total_allocation_quantity := ln_total_allocation_quantity + ln_single_allocation_quantity;
      FETCH NEXT FROM contractsallocations INTO ls_allocation_reference;
    END LOOP;
    CLOSE contractsallocations;
    RETURN ln_total_allocation_quantity;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_list_allocated_contracts(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    allocation_list CURSOR FOR
      SELECT allocation_reference
        FROM allocated_contracts
        WHERE contno = as_contno AND split = as_split;
    ls_alloc_ref char(20);
    ls_contno char(128);
    ls_result char(512);
  BEGIN
    ls_result := '';
    OPEN allocation_list;
    FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    WHILE FOUND LOOP
      SELECT string_agg(allocated_contracts.contno || '-' || allocated_contracts.split, ' ')
        INTO ls_contno
        FROM allocated_contracts
        WHERE allocated_contracts.allocation_reference = ls_alloc_ref
          AND allocated_contracts.contno <> as_contno;
      IF ls_result = '' THEN
        ls_result := ls_result || ls_contno;
      ELSE
        ls_result := ls_result || ', ' || ls_contno;
      END IF;
      FETCH NEXT FROM allocation_list INTO ls_alloc_ref;
    END LOOP;
    CLOSE allocation_list;
    RETURN ls_result;
  END;$func$;

  CREATE OR REPLACE FUNCTION public.sp_list_allocated_contracts_details(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    allocation_list CURSOR FOR
      SELECT allocation_reference
        FROM allocated_contracts
        WHERE contno = as_contno AND split = as_split;
    ls_alloc_ref char(20);
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
    ls_alloc_ref char(20);
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
    "ls_alloc_ref" char(20);
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
    ls_alloc_ref char(20);
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
    "ls_alloc_ref" char(20);
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

  CREATE OR REPLACE FUNCTION public.sp_sopex_get_sum_free_unmatched_stock(as_contno character, as_split character)
   RETURNS numeric
   LANGUAGE plpgsql
  AS $func$DECLARE
    contractsstocks CURSOR FOR
      SELECT sp_convert_qty(stocks.quantity, stocks.quantity_unit, 'MT'), stocks.allocation_reference
        FROM stocks
        WHERE stocks.contno = as_contno
          AND stocks.split = as_split
          AND stocks.quantity > 0;
    ln_total_free_unmatched_stock NUMERIC(16,4);
    ls_is_this_stock_allocation char(1);
    ls_allocation_reference char(20);
    ln_single_allocation_quantity NUMERIC(16,4);
  BEGIN
    ln_total_free_unmatched_stock := 0;
    OPEN contractsstocks;
    FETCH NEXT FROM contractsstocks INTO ln_single_allocation_quantity, ls_allocation_reference;
    WHILE FOUND LOOP
      SELECT sp_allocation_check_if_only_stock(ls_allocation_reference) INTO ls_is_this_stock_allocation;
      IF ls_is_this_stock_allocation = 'Y' THEN
        ln_total_free_unmatched_stock := ln_total_free_unmatched_stock + ln_single_allocation_quantity;
      END IF;
      FETCH NEXT FROM contractsstocks INTO ln_single_allocation_quantity, ls_allocation_reference;
    END LOOP;
    CLOSE contractsstocks;
    RETURN ln_total_free_unmatched_stock;
  END;$func$;

  INSERT INTO schema_migrations (script_name) VALUES ('0011_allocation_reference_widen');
  RAISE NOTICE 'Migration 0011 applied successfully.';
END;
$$;


-- ============================================================
-- Recreate 22 dependent views
-- ============================================================

--
-- PostgreSQL database dump
--


-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3


--
-- Name: alloc_contracts_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: allocated_purch_quantity; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: allocated_purch_quantity_extended; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: bal_anal_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: crdrnote_view; Type: VIEW; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.crdrnote_view AS
 SELECT params.systemdate,
    params.coname AS our_name,
    params.colongname AS our_longname,
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
    ( SELECT invoice.allocation_reference
           FROM public.invoice
          WHERE ((creditdebit_note.invoice_type = invoice.invoice_type) AND (creditdebit_note.client = invoice.client) AND (creditdebit_note.invoice_number = invoice.invoice_number))) AS allocation_reference,
    creditdebit_note.invoice_type,
    creditdebit_note.client,
    creditdebit_note.invoice_number,
    creditdebit_note.crdr_number,
    creditdebit_note.crdr_client,
    creditdebit_note.invoice_date,
    creditdebit_note.company,
    creditdebit_note.pcentre,
    creditdebit_note.commodity,
    creditdebit_note.commodtype,
    creditdebit_note.origin,
    creditdebit_note.due_date,
    creditdebit_note.posted_date,
    creditdebit_note.posted_ledref,
    creditdebit_note.total_value,
    creditdebit_note.currency,
    creditdebit_note.payment_instruction,
    payment_instruction.name AS payinstruct_name,
    payment_instruction.longname AS payinstruct_longname,
    creditdebit_note.crdrind,
    creditdebit_note.description,
    creditdebit_note.pay_amount,
    creditdebit_note.pay_date,
    creditdebit_note.pay_ledref,
    crdr_note_details.charges_line,
    crdr_note_details.expenses_type,
    reserves_types.name AS reserve_name,
    reserves_types.longname AS reserve_longname,
    crdr_note_details.crdrindicator,
    crdr_note_details.amount,
    crdr_note_details.currency AS exp_curr,
    crdr_note_details.exchange_rate AS exrate,
        CASE
            WHEN ((crdr_note_details.exchange_rate <> (0)::numeric) AND (crdr_note_details.exchange_rate IS NOT NULL)) THEN (crdr_note_details.exchange_rate * crdr_note_details.amount)
            ELSE crdr_note_details.amount
        END AS cp_crdr_curramt,
    crdr_note_details.nominal_account,
    crdr_note_details.description AS det_description,
    crdr_note_details.amount_indicator,
    crdr_note_details.linevalue,
    crdr_note_details.price_unit
   FROM public.params,
    public.creditdebit_note,
    public.crdr_note_details,
    public.client,
    public.payment_instruction,
    public.reserves_types
  WHERE ((creditdebit_note.invoice_type = crdr_note_details.invoice_type) AND (creditdebit_note.client = crdr_note_details.client) AND (creditdebit_note.invoice_number = crdr_note_details.invoice_number) AND (creditdebit_note.crdr_number = crdr_note_details.crdr_number) AND (crdr_note_details.expenses_type = reserves_types.code) AND (creditdebit_note.client = client.code) AND (creditdebit_note.payment_instruction = payment_instruction.code));


--
-- Name: expenses_month_end_reports_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: expenses_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: floating_stock_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: forecast_report_outbooked_p_expenses_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: invoice_allocation_detail_view; Type: VIEW; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.invoice_allocation_detail_view AS
 SELECT '1'::text AS invtyp,
    a.allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    NULL::bpchar AS crdrnum,
    NULL::text AS crdrclnt,
    a.invoice_currency AS invcurr,
    a.invoice_value AS invamt,
    a.total_tonnage AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM public.invoice a
  WHERE ((a.invoice_type = 'P'::bpchar) OR (a.invoice_type = 'S'::bpchar))
UNION
 SELECT '2'::text AS invtyp,
    ( SELECT b.allocation_reference
           FROM public.invoice b
          WHERE ((b.invoice_type = a.invoice_type) AND (b.client = a.client) AND (b.invoice_number = a.invoice_number))) AS allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    a.final_invoice_number AS crdrnum,
    NULL::text AS crdrclnt,
    a.invoice_currency AS invcurr,
    a.net_due AS invamt,
    NULL::numeric AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM public.final_invoice a
UNION
 SELECT '3'::text AS invtyp,
    a.allocation_reference,
    NULL::bpchar AS invpors,
    a.expense_number AS invnum,
    a.expense_date AS invdate,
    a.client AS invclnt,
    NULL::bpchar AS crdrnum,
    NULL::text AS crdrclnt,
    a.currency AS invcurr,
    a.total_value AS invamt,
    NULL::numeric AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM public.expenses_summary a
UNION
 SELECT '4'::text AS invtyp,
    ( SELECT b.allocation_reference
           FROM public.invoice b
          WHERE ((b.invoice_type = a.invoice_type) AND (b.client = a.client) AND (b.invoice_number = a.invoice_number))) AS allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    a.crdr_number AS crdrnum,
    a.crdr_client AS crdrclnt,
    a.currency AS invcurr,
    a.total_value AS invamt,
    NULL::numeric AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM public.creditdebit_note a
UNION
 SELECT '5'::text AS invtyp,
    a.allocation_reference,
    a.invoice_type AS invpors,
    a.invoice_number AS invnum,
    a.invoice_date AS invdate,
    a.client AS invclnt,
    NULL::bpchar AS crdrnum,
    NULL::text AS crdrclnt,
    a.invoice_currency AS invcurr,
    a.invoice_value AS invamt,
    a.total_tonnage AS invtons,
    a.due_date AS invdue,
    a.posted_date AS invpostdate
   FROM public.invoice a
  WHERE (a.invoice_type = 'W'::bpchar);


--
-- Name: invoice_charges_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: invoice_charges_view2; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: invoice_contracts_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: invoice_details_2_copy_of_original_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: invoices_stocks_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: phys_alloc; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: phys_stocks; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: phys_pricing3; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: phys_valn_view3; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: physical_trading_browser_underlying_level1_view; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: powerbi_caja_stocks_by_warehouse; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: powerbi_invoiced_contracts; Type: VIEW; Schema: public; Owner: -
--

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


--
-- PostgreSQL database dump complete
--



