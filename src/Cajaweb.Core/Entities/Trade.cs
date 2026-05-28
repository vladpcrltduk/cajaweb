namespace Cajaweb.Core.Entities;

public class Trade
{
    public int Id { get; set; }
    public string TradeRef { get; set; } = string.Empty;
    public DateTime TradeDate { get; set; }
    public string Direction { get; set; } = string.Empty; // BUY / SELL
    public string Status { get; set; } = "DRAFT"; // DRAFT, CONFIRMED, SETTLED, CANCELLED

    public int CommodityId { get; set; }
    public Commodity Commodity { get; set; } = null!;

    public int CounterpartyId { get; set; }
    public Counterparty Counterparty { get; set; } = null!;

    public decimal Quantity { get; set; }
    public decimal Price { get; set; }
    public string Currency { get; set; } = "USD";

    public DateTime DeliveryFrom { get; set; }
    public DateTime DeliveryTo { get; set; }

    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
