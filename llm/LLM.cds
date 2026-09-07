/**
 * A generative LLM, modelled as a plain CAP service.
 *
 * This is the Calesi pattern, and it is exactly how @cap-js/ai models its own
 * `AICore` service:
 *   @protocol: 'none'  -> internal only, never exposed over HTTP
 *   @impl: '...'       -> implementation bound in the MODEL, not in code
 *
 * Swapping the real SAP Generative AI Hub for a local mock is then a matter of
 * loading a different model (see LLM-mock.cds), selected by profile in
 * package.json. The rest of the application never imports an AI SDK.
 */
@impl: './orchestration.js'
@protocol: 'none'
service LLM {
  action chat(system : String, user : String) returns {
    content          : String;
    model            : String;
    promptTokens     : Integer;
    completionTokens : Integer;
    mocked           : Boolean;
  };
}
