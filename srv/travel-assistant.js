import cds from '@sap/cds'

const { Travels } = cds.entities('sap.capire.travels')

export default class TravelAssistant extends cds.ApplicationService {
  async init() {
    const llm = await cds.connect.to('LLM')

    this.on('summarize', async req => {
      const { travelID } = req.data
      const t = await SELECT.one.from(Travels, travelID).columns(
        'ID', 'Description', 'BeginDate', 'EndDate', 'TotalPrice', 'Currency_code',
        'Status.name as statusName', 'Agency.Name as agencyName'
      )
      if (!t) return req.reject(404, `No travel with ID ${travelID}`)

      const nights = Math.round(
        (new Date(t.EndDate) - new Date(t.BeginDate)) / 864e5)

      // Only the fields we chose. The prompt is the trust boundary: whatever
      // goes in here leaves the system.
      const prompt = [
        `Description: ${t.Description}`,
        `Agency: ${t.agencyName ?? '-'}`,
        `Status: ${t.statusName ?? '-'}`,
        `TotalPrice: ${t.TotalPrice} ${t.Currency_code}`,
        `Nights: ${nights}`
      ].join('\n')

      const res = await llm.send('chat', {
        system: 'Summarise this travel booking in one short paragraph for a ' +
                'travel agent. Be factual; do not invent details.',
        user: prompt
      })

      return {
        travelID,
        summary: res.content,
        model: res.model,
        mocked: res.mocked,
        promptTokens: res.promptTokens,
        completionTokens: res.completionTokens
      }
    })

    return super.init()
  }
}
