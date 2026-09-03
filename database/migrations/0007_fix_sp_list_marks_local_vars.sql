DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM schema_migrations WHERE script_name = '0007_fix_sp_list_marks_local_vars') THEN
    RAISE NOTICE 'Migration 0007 already applied, skipping.';
    RETURN;
  END IF;

  CREATE OR REPLACE FUNCTION public.sp_list_marks(as_contno character, as_split character)
   RETURNS character
   LANGUAGE plpgsql
  AS $func$DECLARE
    ls_all_marks char(256);
    ls_marks char(256);
    ls_shipment_id char(10);
    ls_purch_contno char(10);
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

  INSERT INTO schema_migrations (script_name) VALUES ('0007_fix_sp_list_marks_local_vars');
  RAISE NOTICE 'Migration 0007 applied successfully.';
END;
$$;
