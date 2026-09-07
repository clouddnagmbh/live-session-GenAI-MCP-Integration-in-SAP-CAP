import cds from '@sap/cds'

/**
 * Local implementation. Deterministic, offline, no entitlement.
 *
 * It is NOT a language model: it extracts the figures already present in the
 * prompt and renders them as a sentence. That is enough to prove the wiring,
 * the service contract and the downstream code -- and nothing more. Say so.
 */
export default class MockLLM extends cds.Service {
  init() {
    this.on('chat', async req => {
      const { user = '' } = req.data
      const num = (re) => (user.match(re)?.[1] ?? '').trim()
      const desc   = num(/Description:\s*(.*)/)
      const agency = num(/Agency:\s*(.*)/)
      const status = num(/Status:\s*(.*)/)
      const price  = num(/TotalPrice:\s*(.*)/)
      const nights = num(/Nights:\s*(.*)/)

      const content = desc
        ? `${desc} booked through ${agency || 'an agency'}${nights ? ` for ${nights} nights` : ''}` +
          `${price ? `, totalling ${price}` : ''}. Current status: ${status || 'unknown'}.` +
          ` [mock summary — no language model was called]`
        : `[mock summary — no language model was called]`

      return {
        content,
        model: 'mock',
        promptTokens: Math.ceil(user.length / 4),
        completionTokens: Math.ceil(content.length / 4),
        mocked: true
      }
    })
    return super.init()
  }
}
