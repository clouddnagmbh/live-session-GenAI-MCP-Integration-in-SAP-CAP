import cds from '@sap/cds'

/** Registered from srv/travel-service.js via this.impl(...) — see that file. */
export default function () {
  const { Travels } = this.entities

  this.on('acceptTravelById', async req => {
    const { travel, note } = req.data
    const row = await SELECT.one.from(Travels, travel).columns('ID', 'Status_code')
    if (!row) return req.reject(404, `No travel with ID ${travel}`)
    if (row.Status_code !== 'O')
      return req.reject(409, `Travel ${travel} is not Open (status ${row.Status_code})`)
    await UPDATE(Travels, travel).with({ Status_code: 'A' })
    return { ID: travel, Status: 'A', note: note ?? null }
  })

  this.on('revenueByAgency', async req => {
    const { from, to } = req.data
    const rows = await SELECT.from(Travels)
      .columns('Agency.Name as Agency', 'sum(TotalPrice) as revenue', 'count(*) as travels')
      .where(from && to ? { BeginDate: { '>=': from, '<=': to } } : {})
      .groupBy('Agency.Name')
      .orderBy({ revenue: 'desc' })
    return rows.map(r => ({ Agency: r.Agency, revenue: r.revenue, travels: r.travels }))
  })

  // bound action, for contrast: MCP never sees this
  this.on('rejectTravel', Travels, async req => {
    const id = req.params[0]?.ID ?? req.params[0]
    await UPDATE(Travels, id).with({ Status_code: 'X' })
    return SELECT.one.from(Travels, id)
  })
}
