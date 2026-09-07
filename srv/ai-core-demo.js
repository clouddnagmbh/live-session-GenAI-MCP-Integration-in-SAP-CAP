import cds from '@sap/cds'

const { Travels } = cds.entities('sap.capire.travels')

export default class AICoreDemo extends cds.ApplicationService {
  async init() {
    const aiCore = await cds.connect.to('AICore')

    /**
     * Hand-crafted RPT-1 call. This works locally against MockAICoreService,
     * because the mock overrides `_predictRowColumns`.
     */
    this.on('predictTravel', async req => {
      const { description, contextRows = 200 } = req.data
      const predictionColumns = ['Agency_ID', 'Currency_code', 'Status_code']

      // Context = real travels. RPT-1 learns in-context; there is no training step.
      const rows = await SELECT.from(Travels)
        .columns('ID', 'Description', 'BeginDate', 'EndDate', 'BookingFee',
                 'TotalPrice', 'Currency_code', 'Status_code', 'Agency_ID', 'Customer_ID')
        .limit(contextRows)

      // The row we want filled in. RPT-1 marks targets with the literal
      // sentinel '[PREDICT]' (AICoreService.js:185) — NOT null.
      const PREDICT = '[PREDICT]'
      rows.push({ ID: -1, Description: description,
                  BeginDate: null, EndDate: null, BookingFee: 0, TotalPrice: null,
                  Customer_ID: null,
                  Agency_ID: PREDICT, Currency_code: PREDICT, Status_code: PREDICT })

      const { predictions } = await aiCore.fetchPredictions({
        entity: 'sap.capire.travels.Travels', predictionColumns, rows
      })

      const first = predictions?.[0] ?? {}
      return {
        predictionColumns,
        contextRowsSent: rows.length,
        predictions: predictionColumns.flatMap(col => (first[col] ?? []).map(p => ({
          column: col,
          value: String(p.prediction ?? p.RecommendedFieldValue ?? ''),
          score: p.score ?? p.RecommendedFieldScoreValue ?? null
        })))
      }
    })

    /**
     * The Calesi part: AI Core admin objects as a plain CAP service you query
     * with CQL. NOTE: MockAICoreService does NOT mock these — it only mocks
     * predictions. Without a real binding this throws.
     */
    this.on('listResourceGroups', async req => {
      const { resourceGroups } = aiCore.entities
      try {
        const groups = await aiCore.run(SELECT.from(resourceGroups))
        return groups.map(g => ({ id: g.resourceGroupId, status: g.status }))
      } catch (e) {
        // MUST be guarded. Unbound, AICoreService._getToken() throws
        // "Cannot read properties of undefined (reading 'url')" and CAP
        // treats it as an uncaught error that TERMINATES the process.
        return req.reject(501,
          `AI Core admin API needs a real service binding. ` +
          `Run: cds bind AICore -2 <instance> && cds watch --profile hybrid. ` +
          `(underlying error: ${e.message})`)
      }
    })

    return super.init()
  }
}
