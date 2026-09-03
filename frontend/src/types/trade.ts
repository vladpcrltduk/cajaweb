export interface Commodity {
  id: number;
  name: string;
  code: string;
  unit: string;
}

export interface Counterparty {
  id: number;
  name: string;
  code: string;
  country?: string;
}

export interface Trade {
  id: number;
  tradeRef: string;
  tradeDate: string;
  direction: 'BUY' | 'SELL';
  status: 'DRAFT' | 'CONFIRMED' | 'SETTLED' | 'CANCELLED';
  commodityId: number;
  commodity: Commodity;
  counterpartyId: number;
  counterparty: Counterparty;
  quantity: number;
  price: number;
  currency: string;
  deliveryFrom: string;
  deliveryTo: string;
  notes?: string;
}
