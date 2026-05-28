using Cajaweb.Core.Entities;
using Cajaweb.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Cajaweb.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TradesController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var trades = await db.Trades
            .Include(t => t.Commodity)
            .Include(t => t.Counterparty)
            .OrderByDescending(t => t.TradeDate)
            .ToListAsync();
        return Ok(trades);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var trade = await db.Trades
            .Include(t => t.Commodity)
            .Include(t => t.Counterparty)
            .FirstOrDefaultAsync(t => t.Id == id);
        return trade is null ? NotFound() : Ok(trade);
    }

    [HttpPost]
    public async Task<IActionResult> Create(Trade trade)
    {
        db.Trades.Add(trade);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = trade.Id }, trade);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, Trade trade)
    {
        if (id != trade.Id) return BadRequest();
        db.Entry(trade).State = EntityState.Modified;
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var trade = await db.Trades.FindAsync(id);
        if (trade is null) return NotFound();
        db.Trades.Remove(trade);
        await db.SaveChangesAsync();
        return NoContent();
    }
}
