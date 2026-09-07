import cds from '@sap/cds'

/**
 * Transparency hook: log exactly what @cap-js/ai sends to SAP AI Core.
 *
 * This exists to demonstrate a real discrepancy. The plugin's docs
 * (.docs/recommendations.md, "Prediction context and data handling") say fields
 * excluded by `@UI.RecommendationState: 0` are removed from the context. They
 * are not — the code filters the context columns on timestamps and
 * binary/vector types only (lib/handlers/recommendations.js:38-46) and never
 * consults the annotation.
 */
cds.once('served', async () => {
  const aiCore = await cds.connect.to('AICore')
  aiCore.before('fetchPredictions', req => {
    const { rows, entity, predictionColumns } = req.data
    console.log('\n─── payload to SAP AI Core ' + '─'.repeat(40))
    console.log('entity            :', entity)
    console.log('prediction TARGETS:', predictionColumns)
    console.log('context rows      :', rows.length)
    console.log('columns per row   :', Object.keys(rows[0] ?? {}).sort().join(', '))
    console.log('─'.repeat(66) + '\n')
  })
})

export default cds.server
