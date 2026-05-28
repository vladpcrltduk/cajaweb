using Cajaweb.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Cajaweb.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReferenceDataController(AppDbContext db) : ControllerBase
{
    [HttpGet("commodities")]
    public async Task<IActionResult> GetCommodities() =>
        Ok(await db.Commodities.Where(c => true).ToListAsync());

    [HttpGet("counterparties")]
    public async Task<IActionResult> GetCounterparties() =>
        Ok(await db.Counterparties.Where(c => c.IsActive).ToListAsync());
}
