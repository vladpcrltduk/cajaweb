using Cajaweb.Core.Entities;
using Microsoft.EntityFrameworkCore;

namespace Cajaweb.Infrastructure.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Trade> Trades => Set<Trade>();
    public DbSet<Commodity> Commodities => Set<Commodity>();
    public DbSet<Counterparty> Counterparties => Set<Counterparty>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Trade>(e =>
        {
            e.HasIndex(t => t.TradeRef).IsUnique();
            e.Property(t => t.Price).HasPrecision(18, 6);
            e.Property(t => t.Quantity).HasPrecision(18, 6);
        });

        modelBuilder.Entity<Commodity>()
            .HasIndex(c => c.Code).IsUnique();

        modelBuilder.Entity<Counterparty>()
            .HasIndex(c => c.Code).IsUnique();
    }
}
