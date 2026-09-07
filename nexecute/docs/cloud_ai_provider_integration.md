# Cloud AI provider integration plan

## Status and objective

This document records the design for adding user-funded cloud language models
to Nexecute alongside local OpenAI-compatible endpoints. It was researched on
2026-09-06 against the providers' official API documentation.

The first release remains bring-your-own-key (BYOK). Nexecute does not supply a
shared provider account, proxy requests through the Firebase project, or pay
for inference. Local models remain supported and core Calendar, Tasks, Notes,
and search workflows remain independent from every AI provider.

"OpenAI API" is used instead of "ChatGPT" in the interface and documentation.
Nexecute integrates developer APIs; it does not connect to a user's ChatGPT,
Gemini application, or Claude application conversation history or subscription.

## Existing foundation

The following boundaries are already suitable for cloud providers:

- `AiConnectionProfile` keeps endpoint and model metadata local.
- `AiCredentialStore` stores only the secret in Android secure storage or the
  macOS Keychain; profiles contain an opaque reference.
- `AiAssistantRepository` exposes provider-neutral connection testing, model
  discovery, and normalized response streams.
- response handling already normalizes text, reasoning, usage, tool calls,
  completion, cancellation, and failures.
- request budgets, bounded application context, read-tool authorization,
  confirmed write proposals, and the no-automatic-retry policy apply before a
  provider adapter is called.
- the synthetic quality suite can compare providers without using personal
  application data.

The current `OpenAiCompatibleAssistantRepository` implements only Chat
Completions. The `openAiResponses` and `anthropicMessages` protocol values are
reserved but deliberately return unsupported.

## Provider and protocol model

Add an app-owned provider identity separately from the wire protocol:

```text
AiProviderKind
- customOpenAiCompatible
- googleGemini
- openAI
- anthropic
```

Existing profiles migrate to `customOpenAiCompatible`. Provider presets own
their trusted HTTPS base URL, protocol, authentication presentation, required
headers, documentation link, and conservative capability defaults. The user
selects a model discovered from the provider or enters a model ID manually.
Nexecute should not persist a moving "latest" model as an application-wide
default.

The profile editor keeps custom endpoint controls for local and private
servers. For a hosted preset it displays the provider URL as locked, labels the
secret as an API credential, and does not let a credential be sent to a custom
hostname without changing the profile back to a custom provider and accepting
a focused warning.

Add a routing repository that selects an adapter from the profile:

```text
AiAssistantRepository
  -> OpenAI-compatible Chat Completions adapter (Ollama and Gemini pilot)
  -> OpenAI Responses adapter
  -> Anthropic Messages adapter
```

Prompt composition, application context, tools, response events, persistence,
and presentation remain shared. Provider-specific JSON, headers, endpoints,
SSE events, stop reasons, token usage, and safe error extraction stay inside
the adapters.

## Credential and privacy boundary

Direct cloud credentials remain available only in native personal builds.
Flutter Web continues requiring a user-owned gateway. A native application
cannot make an API key impossible to extract from a compromised device, even
when the key is stored in secure storage. The profile editor must explain this
trade-off and provide replacement and removal actions.

Creating a hosted profile requires an explicit **Enable cloud API requests**
choice that explains charges may apply. Before enabling it, show:

- the provider and fixed destination host;
- that prompts, active skill instructions, selected attachments, tool results,
  and proposal source text may be transmitted for the current workflow;
- that conversation persistence in Firestore is separate from provider data
  handling;
- the configured output and context limits; and
- a link to the provider's billing, key-management, and data-use controls.

Nexecute keeps hosted inference disabled by default, never retries generation
automatically, and never sends a request merely to inspect billing. Provider
console budgets, prepaid balances, quotas, alerts, and key restrictions remain
the authoritative spending controls. Nexecute may show normalized token usage
returned by a completed request, but it must not claim an exact monetary cost
from stale built-in price data.

Credentials, authorization headers, provider response bodies, personal
content, and custom endpoints remain excluded from diagnostics. Safe request
IDs may be retained in memory for support when a provider supplies them, but
must not enter synchronized conversations.

## Delivery order

### Phase A: shared hosted-provider foundation

**Status:** Complete. The shared provider identity, trusted presets, explicit
cloud activation, native credential lifecycle, adapter routing, Web rejection,
and environment-only quality-runner credential path are implemented.

1. Add `AiProviderKind` with backward-compatible profile decoding.
2. Add the provider descriptor registry and fixed trusted endpoint presets.
3. Add explicit hosted-inference activation and transmission/cost disclosure.
4. Rename the credential field generically while preserving opaque-reference
   storage, replacement, duplication, and deletion behavior.
5. Add the routing repository without changing existing Ollama behavior.
6. Extend the quality runner to read an opt-in credential from an environment
   variable without writing it to reports, command output, or files.
7. Cover profile migration, endpoint locking, web rejection, credential
   lifecycle, adapter routing, disclosure, and redaction with deterministic
   tests.

### Phase B: Gemini compatibility pilot

**Status:** Implementation complete and ready for opt-in live acceptance. The
trusted OpenAI-compatible endpoint, bearer authentication, Nexecute client
header, wire behavior, cancellation, tools, structured workflows, diagnostics,
redaction, and quality-runner provider selection have deterministic coverage.
Model-specific tools and structured-output capability remain unconfirmed until
a live versioned quality run passes.

Use Gemini's official OpenAI-compatible endpoint with the existing Chat
Completions adapter. Its documented REST shape already uses bearer
authentication, streaming, `reasoning_effort`, and OpenAI-format function
calling. Add Google's required client-identification header and provider preset.

Keep tools and structured output unconfirmed until wire tests and a live model
run pass. Do not add Gemini-specific File, Search, Live, image-generation, or
other server tools in this phase.

Verify connection testing, model discovery, ordinary streaming chat, Stop,
read-tool continuation, Note-to-Task, Note-to-Event, Finnish output, timeouts,
rate limits, invalid credentials, and malformed streams. Run the existing
quality suite with a named model and recorded model version. The live run is
explicit and optional; automated development never uses a real key by default.

This is the preferred first hosted slice because it tests the complete BYOK
product boundary with minimal new protocol code. It does not make Gemini the
permanent default or prevent adding native Gemini support later.

### Phase C: OpenAI Responses adapter

Implement `POST /v1/responses` and its SSE event vocabulary behind
`AiAssistantRepository`. Map shared instructions, messages, function tools,
tool continuations, reasoning controls, output limits, usage, stop reasons,
request IDs, and errors into existing Nexecute types. Continue using bearer
authentication and the trusted OpenAI endpoint.

Use deterministic fixtures before any live request. Then run the same bounded
quality suite and failure matrix used for Gemini. Do not add OpenAI-hosted file
search, web search, computer use, remote MCP, background jobs, or provider-side
conversation state in this phase.

### Phase D: Anthropic Messages adapter

Implement `POST /v1/messages`, the required API-version header, Messages SSE
content blocks, system instructions, tool definitions, `tool_use` and
`tool_result` continuations, token usage, stop reasons, request IDs, and safe
errors. Authentication is resolved by the adapter; the profile still stores
only an opaque credential reference.

Model discovery is optional if the current account or endpoint does not expose
a stable compatible list. Manual model entry remains supported. App Attest can
be evaluated later for a distributed macOS build, but it is outside the first
personal BYOK slice and does not solve Android or Web authentication.

Run the shared quality suite and failure matrix before marking tools or
structured proposal quality as supported for a model.

### Phase E: comparison and rollout

Compare at least one cost-conscious model from every implemented provider with
the same quality-suite version, prompt settings, context limit, output limit,
and repetitions. Record quality, application, and transport failures plus
latency and returned token usage. Do not choose a recommended provider from
marketing claims or one successful chat.

Release providers independently. A failure or breaking API change in one
adapter must not prevent local models or another provider from starting.

## Provider-specific findings

### Gemini

Google documents an OpenAI-compatible base URL and REST forms for bearer
authentication, streaming Chat Completions, reasoning effort, and function
calling. Google recommends its native API for full Gemini features, so the
compatibility path is deliberately limited to Nexecute's existing text and
app-owned tool workflows. Google is transitioning Gemini API keys to
service-account-bound authorization keys; Nexecute treats either as an opaque
credential and does not attempt to manage the associated Cloud project.

Official references:

- <https://ai.google.dev/gemini-api/docs/openai>
- <https://ai.google.dev/gemini-api/docs/partner-integration>
- <https://ai.google.dev/gemini-api/docs/api-key>
- <https://ai.google.dev/gemini-api/docs/pricing>

### OpenAI

OpenAI's current API uses bearer credentials and offers streaming, functions,
structured outputs, and usage information through the Responses API. Official
guidance treats API keys as secrets that should not be exposed in client
applications. Direct Keychain/secure-storage BYOK is therefore a documented
personal-build trade-off; a distributed or Web client should prefer a
user-owned server boundary.

Official references:

- <https://developers.openai.com/api/reference/overview>
- <https://developers.openai.com/api/docs/models>
- <https://platform.openai.com/docs/api-reference/responses/create>

### Anthropic

Anthropic's Messages API is stateless across requests and supports SSE
streaming and tools. Requests require an API-version header in addition to
authentication. Current Anthropic authentication documentation also describes
App Attest for direct iOS and macOS clients; this may become useful if Nexecute
is distributed beyond personal builds.

Official references:

- <https://platform.claude.com/docs/en/api/overview>
- <https://platform.claude.com/docs/en/api/http/messages/create>
- <https://platform.claude.com/docs/en/build-with-claude/streaming>
- <https://platform.claude.com/docs/en/manage-claude/authentication>
- <https://platform.claude.com/docs/en/about-claude/pricing>

## Completion criteria

- Existing local profiles migrate and behave exactly as before.
- Every hosted request requires a native secure credential and explicit paid
  cloud activation.
- Provider presets cannot silently send a credential to another hostname.
- Web cannot save or use a direct hosted credential.
- The interface shows the active provider and model before sending selected
  application context or a structured proposal source.
- Streaming, cancellation, timeouts, rate limits, authentication failures,
  usage, tool calls, and malformed responses normalize consistently.
- A provider failure cannot block Nexecute startup or non-AI workflows.
- No secret, provider payload, personal context, or custom endpoint enters
  logs, diagnostics, Firestore, or committed evaluation results.
- Each enabled provider passes deterministic adapter tests and a recorded,
  explicitly initiated live quality run before broader rollout.
