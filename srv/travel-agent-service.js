import cds from '@sap/cds'

export default class TravelAgentService extends cds.ApplicationService {
  async init() {
    // The LLM is a CAP service (branch 04), so which model answers is a profile
    // decision, not a code decision. Nothing here imports an AI SDK.
    const llm = await cds.connect.to('LLM')

    this.on('recommendAgency', async req => {
      const { wish } = req.data
      if (!wish) return req.reject(400, 'wish is required')

      // Read through OUR projection, as THIS caller. @restrict and the curated
      // element list both still apply -- the agent cannot widen this.
      const agencies = await this.read('Agencies').columns('ID', 'Name', 'City')

      // AUGMENT -- we decide what goes into the prompt. This is the trust
      // boundary: whatever is on the next line leaves the system.
      const context = agencies
        .map((a, i) => `[${i + 1}] ${a.Name} (${a.City})`)
        .join('\n')

      // GENERATE
      const res = await llm.send('chat', {
        system: 'Recommend one of the numbered travel agencies below for the ' +
                'traveller\'s wish and say why in one sentence. Use ONLY the ' +
                'agencies given. If none fit, say so.',
        user: `Wish: ${wish}\n\nAgencies:\n${context}`
      })

      return { wish, answer: res.content, model: res.model, mocked: res.mocked }
    })

    return super.init()
  }
}
