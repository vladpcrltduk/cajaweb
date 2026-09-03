# Cajaweb

Commodity trading web platform — trade blotter, invoicing, logistics, risk management and reporting.

## Stack

| Layer | Technology |
|---|---|
| Frontend | React 19 + TypeScript + Vite + AG Grid |
| Backend | .NET 8 Web API (C#) |
| ORM | Entity Framework Core 8 |
| Database | PostgreSQL (MSSQL-ready via config switch) |

## Project Structure

```
src/
  Cajaweb.Api/            # Web API — controllers, startup
  Cajaweb.Core/           # Domain entities and interfaces
  Cajaweb.Infrastructure/ # EF Core DbContext and data access
frontend/                 # React + TypeScript frontend
```

## Getting Started

### Backend

1. Update the connection string in `src/Cajaweb.Api/appsettings.Development.json`
2. Run migrations: `dotnet ef database update --project src/Cajaweb.Infrastructure --startup-project src/Cajaweb.Api`
3. Start the API: `dotnet run --project src/Cajaweb.Api`

### Frontend

```
cd frontend
npm install
npm run dev
```

The frontend runs on `http://localhost:5173` and expects the API on `http://localhost:5000`.

## Switching to MSSQL

In `appsettings.json`, set:

```json
"DatabaseProvider": "sqlserver",
"ConnectionStrings": {
  "Default": "Server=...;Database=cajaweb;..."
}
```
