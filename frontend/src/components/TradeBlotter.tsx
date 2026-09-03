import { useEffect, useMemo, useRef, useState } from 'react';
import { AgGridReact } from 'ag-grid-react';
import type { ColDef } from 'ag-grid-community';
import { AllCommunityModule, ModuleRegistry } from 'ag-grid-community';
import api from '../api/client';
import type { Commodity, Counterparty, Trade } from '../types/trade';

ModuleRegistry.registerModules([AllCommunityModule]);

const DIRECTIONS = ['BUY', 'SELL'];
const STATUSES = ['DRAFT', 'CONFIRMED', 'SETTLED', 'CANCELLED'];
const CURRENCIES = ['USD', 'EUR', 'GBP'];

export default function TradeBlotter() {
  const gridRef = useRef<AgGridReact<Trade>>(null);
  const [trades, setTrades] = useState<Trade[]>([]);
  const [commodities, setCommodities] = useState<Commodity[]>([]);
  const [counterparties, setCounterparties] = useState<Counterparty[]>([]);

  useEffect(() => {
    api.get<Trade[]>('/trades').then(r => setTrades(r.data));
    api.get<Commodity[]>('/referencedata/commodities').then(r => setCommodities(r.data));
    api.get<Counterparty[]>('/referencedata/counterparties').then(r => setCounterparties(r.data));
  }, []);

  const colDefs = useMemo<ColDef<Trade>[]>(() => [
    { field: 'tradeRef', headerName: 'Ref', width: 120, pinned: 'left' },
    { field: 'tradeDate', headerName: 'Date', width: 120,
      valueFormatter: p => p.value ? new Date(p.value).toLocaleDateString() : '' },
    { field: 'direction', headerName: 'B/S', width: 80,
      cellStyle: p => ({ color: p.value === 'BUY' ? '#16a34a' : '#dc2626', fontWeight: 600 }),
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: { values: DIRECTIONS }, editable: true },
    { field: 'status', headerName: 'Status', width: 120,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: { values: STATUSES }, editable: true },
    { field: 'commodity.name', headerName: 'Commodity', width: 140,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: { values: commodities.map(c => c.name) }, editable: true },
    { field: 'counterparty.name', headerName: 'Counterparty', width: 160,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: { values: counterparties.map(c => c.name) }, editable: true },
    { field: 'quantity', headerName: 'Qty', width: 110, type: 'numericColumn', editable: true },
    { field: 'price', headerName: 'Price', width: 110, type: 'numericColumn', editable: true,
      valueFormatter: p => p.value != null ? p.value.toFixed(4) : '' },
    { field: 'currency', headerName: 'CCY', width: 80,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: { values: CURRENCIES }, editable: true },
    { field: 'deliveryFrom', headerName: 'Del. From', width: 120,
      valueFormatter: p => p.value ? new Date(p.value).toLocaleDateString() : '' },
    { field: 'deliveryTo', headerName: 'Del. To', width: 120,
      valueFormatter: p => p.value ? new Date(p.value).toLocaleDateString() : '' },
    { field: 'notes', headerName: 'Notes', flex: 1, editable: true },
  ], [commodities, counterparties]);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <h2 style={{ margin: '0 0 8px', fontSize: 18 }}>Trade Blotter</h2>
      <div className="ag-theme-alpine" style={{ flex: 1 }}>
        <AgGridReact
          ref={gridRef}
          rowData={trades}
          columnDefs={colDefs}
          defaultColDef={{ resizable: true, sortable: true, filter: true }}
          rowSelection="single"
        />
      </div>
    </div>
  );
}
