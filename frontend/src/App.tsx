import 'ag-grid-community/styles/ag-theme-alpine.css';
import TradeBlotter from './components/TradeBlotter';
import './App.css';

export default function App() {
  return (
    <div style={{ height: '100vh', display: 'flex', flexDirection: 'column', padding: 16 }}>
      <h1 style={{ margin: '0 0 16px', fontSize: 22, fontWeight: 700 }}>Cajaweb</h1>
      <div style={{ flex: 1 }}>
        <TradeBlotter />
      </div>
    </div>
  );
}
