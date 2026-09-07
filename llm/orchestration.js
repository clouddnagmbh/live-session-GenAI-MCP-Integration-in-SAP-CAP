import cds from '@sap/cds'
import { OrchestrationClient } from '@sap-ai-sdk/orchestration'

const LOG = cds.log('llm')

/**
 * Real implementation: SAP Generative AI Hub via the Orchestration service.
 *
 * Credentials do NOT come from cds.requires.LLM. The SAP Cloud SDK for AI
 * resolves them itself, from either the AICORE_SERVICE_KEY env var or a VCAP
 * service binding whose label is `aicore` (packages/core/src/context.ts).
 * That is a different mechanism from the one @cap-js/ai uses -- see
 * docs/04-genai-orchestration.md.
 */
export default class OrchestrationLLM extends cds.Service {
  init() {
    const model = cds.env.requires.LLM?.model ?? 'gpt-5'

    this.on('chat', async req => {
      const { system, user } = req.data
      const client = new OrchestrationClient({
        promptTemplating: { model: { name: model } }
      })
      try {
        const res = await client.chatCompletion({
          messages: [
            ...(system ? [{ role: 'system', content: system }] : []),
            { role: 'user', content: user }
          ]
        })
        const usage = res.getTokenUsage() ?? {}
        return {
          content: res.getContent(),
          model,
          promptTokens: usage.prompt_tokens ?? null,
          completionTokens: usage.completion_tokens ?? null,
          mocked: false
        }
      } catch (e) {
        LOG.error('orchestration call failed:', e.message)
        return req.reject(502,
          `SAP Generative AI Hub call failed: ${e.message}. ` +
          `The SDK needs AICORE_SERVICE_KEY or a VCAP binding labelled 'aicore'.`)
      }
    })

    return super.init()
  }
}
