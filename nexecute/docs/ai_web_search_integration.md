# AI web search integration plan

## Status and objective

Steps 15A through 15C are implemented. The provider-neutral profiles,
repository contract, secure credential-reference lifecycle, schema 4
`searchWeb` declaration, bounded tool definition, one-request composer
authorization, native Brave Search executor, validated citation markers,
source cards, and bounded citation persistence are in place. The application
exposes search only for a valid, enabled connection and an explicitly
authorized assistant request.

This document defines a provider-neutral way for Nexecute skills and ordinary
assistant conversations to search the public web. The first implementation
should work with both local models and hosted models without allowing an
imported skill to execute code, choose an arbitrary network destination, or
grant itself network access.

Web search is a new external-data capability. A skill may declare that it can
use the capability, but Nexecute owns the tool definition, authorization,
search implementation, limits, result normalization, citation handling, and
diagnostics.

## Options considered

| Approach | Advantages | Costs and limitations | Place in Nexecute |
| --- | --- | --- | --- |
| App-owned search API | Works with local and hosted models through the existing function-tool loop; one normalized result and citation model | Requires a separate search service and possibly another API key | Recommended first implementation |
| Gemini native Google Search | Uses the Gemini project and returns provider-generated citations; no separate search account | Requires a native Gemini API adapter; unavailable through Nexecute's current OpenAI-compatible Gemini path; provider-specific pricing and behavior | Add after the portable tool proves useful |
| Self-hosted SearXNG | User controls the endpoint and can keep Nexecute free of a hosted search credential | Requires operating a service; upstream engines and JSON availability can change | Second app-owned backend |
| Browser automation or arbitrary page fetching | Can inspect sites without a structured search API | Large security, prompt-injection, SSRF, copyright, parsing, performance, and maintenance surface | Defer |

Brave Search is the preferred hosted pilot because it provides a documented
JSON web-search endpoint, an independent index, bounded result controls, and a
simple subscription token. Keep the repository interface replaceable so
Tavily, Exa, or another maintained service can be added without changing skill
files or model adapters. Do not select Google's Custom Search JSON API for a
new integration: it is closed to new customers and scheduled for
discontinuation on January 1, 2027.

SearXNG is the preferred self-hosted option. Nexecute must target a user-owned
instance rather than relying on public instances, which may disable JSON
responses, rate-limit clients, log queries, or disappear.

## Trust and authorization model

Add the stable app-owned capability ID `searchWeb` to skill schema 4. The
effective tool remains the intersection of:

1. an installed app capability and executor;
2. a connection profile with explicitly confirmed function-tool support;
3. an active skill's `searchWeb` declaration, or skill-free chat;
4. a configured and enabled web-search connection; and
5. explicit authorization for the current user request.

A declaration in a skill is never permission. Web search is off by default.
The assistant composer should offer **Allow web search for this request** and
show the selected search provider before sending. Authorization is consumed by
one user turn and is not inferred from earlier conversation text, a default
skill, or a model-generated request.

The authorization permits at most three search calls during the turn. Show
each executed query and its provider in the transient tool activity UI. Do not
persist search queries or raw result snippets in Firestore. A user may choose a
new explicit per-conversation convenience setting later, but it is outside the
first release.

## Provider-neutral search contract

Keep search configuration separate from the language-model connection:

```text
WebSearchConnectionProfile
- id
- name
- providerKind: brave | searxng
- enabled
- trustedBaseUrl or validated user-owned endpoint
- credentialReference (Brave only)
- country and searchLanguage
- safeSearch

AiWebSearchRepository
- testConnection(profile)
- search(profile, request, cancellation)

WebSearchRequest
- query
- resultLimit
- freshness: any | day | week | month | year

WebSearchResult
- sourceId
- title
- url
- snippet
- publishedAt (optional)
- providerName
```

The app validates the final tool arguments immediately before execution:

- query: non-empty, at most 400 characters and 50 words;
- result count: one to five;
- freshness: one fixed enum value;
- at most three calls per user turn;
- at most 12,000 UTF-8 characters of normalized search results across the
  complete turn; and
- the existing continuation-round, timeout, cancellation, and request-budget
  limits still apply.

Search provider credentials use the existing native secure credential store.
Profiles and Firestore contain only opaque references. Hosted search is
unavailable on Flutter Web until the user-owned gateway exists. The Brave
adapter owns its fixed HTTPS endpoint and authentication header. The SearXNG
adapter accepts a user-entered endpoint under the same URL, private-network,
and Web restrictions used for custom AI endpoints.

## Tool and result flow

Add `searchWeb(query, resultLimit, freshness)` to the app-owned capability
registry and generalize `AiReadToolCoordinator` into an application-tool
coordinator without weakening the existing local read rules.

The executor returns only normalized result objects. Titles and snippets are
untrusted third-party data and are framed as data, never instructions. Remove
HTML, control characters, hidden markup, and provider-only metadata. Do not
follow result URLs in the first release.

Accept only bounded `https` result URLs with a public hostname. Reject embedded
credentials, loopback and private-network targets, non-web schemes, malformed
internationalized hostnames, and provider redirect wrappers that cannot be
resolved to a direct public destination. Strip fragments and known tracking
parameters before displaying or persisting a URL, then deduplicate on the
canonical form.

Results receive request-local IDs such as `web-1`. The continuation prompt
requires the model to cite those IDs with exact markers such as `[[web-1]]`
when it uses a result. Nexecute validates that every cited ID exists, replaces
valid markers with numbered references, removes fabricated markers, renders
the corresponding title and URL as a source card, and opens it in the external
browser. Copying the answer adds the numbered source URLs. This validates
source identity; it does not claim that the source proves the model's sentence.

Extend assistant messages with a bounded list of public citation metadata:

```text
AiCitation
- sourceId
- title
- url
- publishedAt (optional)
```

Persist only citations actually referenced by the final answer. Do not persist
snippets, search-provider payloads, generated search queries, credentials, or
tool continuations. Existing conversations migrate with an empty citation
list.

## Delivery plan

### Phase A: contracts and settings

1. Add the search profile, provider catalog, repository interface, secure
   credential lifecycle, and backward-compatible storage codec.
2. Add AI Settings for Brave and SearXNG with provider disclosure, test action,
   replacement/removal controls, and links to provider billing and key
   management.
3. Add `searchWeb` to skill schema 4 and migrate schema 3 without changing
   existing skill hashes or capability behavior.
4. Add one-turn web-search authorization to the assistant composer. Keep it
   disabled when no search connection exists or the active model has not been
   confirmed to support function tools.

### Phase B: Brave Search pilot

1. Implement the Brave web-search adapter with the fixed official endpoint,
   subscription-token header, localization, freshness, SafeSearch, timeout,
   cancellation, rate-limit handling, and redacted diagnostics.
2. Register and execute the bounded `searchWeb` tool through the generalized
   application-tool coordinator.
3. Normalize at most five results and 12,000 cumulative characters; treat all
   provider text as untrusted.
4. Add transient query/tool status and final source cards with the citation UI
   in Phase C.

For Gemini's OpenAI-compatible endpoint, preserve function-call
`extra_content.google.thought_signature` unchanged in the transient assistant
tool-call continuation. Gemini 3 requires this opaque signature when function
calling continues. Do not expose it to tool executors or persist it with the
conversation. Omit OpenAI strict-function extensions from Gemini requests and
keep exact argument validation in Nexecute's application layer.

### Phase C: citations and persistence

1. Add validated citation markers and `AiCitation` to normalized response and
   conversation models.
2. Persist only cited public title/URL metadata and keep every raw tool result
   transient.
3. Make copied/exported assistant text include readable source links while
   keeping internal source IDs out of user-facing prose.

### Phase D: SearXNG backend

1. Implement the same search contract against a user-owned SearXNG JSON API.
2. Document enabling JSON output and recommend authentication or tailnet-only
   access rather than a public unauthenticated instance.
3. Verify feature degradation when an engine lacks freshness, locale, or
   SafeSearch support.

### Phase E: provider-native search

1. After a native Gemini adapter exists, map Gemini Google Search calls and URL
   annotations into the same normalized citations and UI.
2. Later map OpenAI and Anthropic server-side web search only after their native
   adapters exist and their versioned tool semantics, costs, retention, and
   citations have deterministic coverage.
3. Never enable both app-owned and provider-native search in the same request.
   Show which provider receives the query and which account pays for it.

## Verification and acceptance

Deterministic tests must cover capability migration and hashing, all five
authorization intersections, denial without a network call, argument and call
limits, timeouts, cancellation, rate limits, credential failures, malformed
payloads, UTF-8 Finnish queries, duplicate and unsafe URLs, citation validation,
prompt injection in titles/snippets, request budgeting, persistence exclusion,
and redacted diagnostics.

Run the existing bilingual quality suite with synthetic search fixtures and add
cases for current-information questions, conflicting sources, missing results,
stale dates, unsupported claims, hostile page snippets, and correct source
attribution. Then perform an explicit live run using synthetic queries against
each enabled search backend and at least one local and one hosted model.

Acceptance requires:

- no skill or model can search without current user authorization;
- local and hosted models receive the same normalized app-owned search tool;
- every displayed source maps to an actual returned result;
- denial, failure, or missing configuration preserves ordinary chat;
- raw search results, queries, secrets, and tool transcripts never enter
  Firestore or diagnostics;
- search and model costs are disclosed as separate services; and
- arbitrary URL fetching, browser control, downloads, and network writes remain
  unavailable.

## Official references

- Brave Search API: <https://brave.com/search/api/>
- Brave Web Search reference:
  <https://api-dashboard.search.brave.com/api-reference/web/search/get>
- SearXNG Search API: <https://docs.searxng.org/dev/search_api.html>
- Gemini Grounding with Google Search:
  <https://ai.google.dev/gemini-api/docs/google-search>
- Gemini OpenAI compatibility:
  <https://ai.google.dev/gemini-api/docs/openai>
- Google Custom Search JSON API status:
  <https://developers.google.com/custom-search/v1/overview>
- Anthropic web search tool:
  <https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool>
