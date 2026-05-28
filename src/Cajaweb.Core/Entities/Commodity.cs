namespace Cajaweb.Core.Entities;

public class Commodity
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string Unit { get; set; } = string.Empty; // MT, BBL, MWh, etc.
    public string? Description { get; set; }
}
