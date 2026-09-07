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

      // recommendAgency prompt shape (branch 11): pick the first agency listed.
      // A real LLM would reason over all of them; this just proves the chain.
      const rec = user.match(/Agencies:\n\[1\]\s*(.+?)\s*\(([^)]+)\)/)
      if (rec) {
        const [, who, city] = rec
        const w = num(/Wish:\s*(.*)/)
        return {
          content: `For "${w}" I would suggest ${who} (${city}). ` +
                   `[mock answer — no language model was called]`,
          model: 'mock',
          promptTokens: Math.ceil(user.length / 4),
          completionTokens: 40,
          mocked: true
        }
      }

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
