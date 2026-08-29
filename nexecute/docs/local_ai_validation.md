# Local AI validation

This smoke test validates Nexecute's real OpenAI-compatible transport against
an Ollama server without committing a private endpoint, model, credential, or
conversation.

## Prerequisites

- Ollama is reachable from the machine running the test.
- The configured model is already installed on the Ollama server.
- Ollama's OpenAI-compatible API is available under `/v1`.
- Any firewall or Tailscale policy permits this device to reach the server.

## Home-network run

Replace the example values only in the command invocation:

```sh
flutter test test/live/ollama_live_smoke_test.dart \
  --dart-define=NEXECUTE_OLLAMA_BASE_URL=http://192.0.2.10:11434/v1 \
  --dart-define=NEXECUTE_OLLAMA_MODEL=your-model-id
```

`192.0.2.10` is a documentation-only address and is not expected to work.

## Tailscale run

Prefer the server's valid Tailscale HTTPS/MagicDNS URL when available:

```sh
flutter test test/live/ollama_live_smoke_test.dart \
  --dart-define=NEXECUTE_OLLAMA_BASE_URL=https://your-server.example.ts.net/v1 \
  --dart-define=NEXECUTE_OLLAMA_MODEL=your-model-id
```

The test performs `GET /v1/models` and one short streamed
`POST /v1/chat/completions` request. It does not write a conversation to
Firestore. Running the test without both defines skips it safely.

Do not add real endpoint values, credentials, or personal prompts to this file.

## Validation record

Keep personal addresses and conversation content out of this record. Record
only versions, model identifiers when they are safe to publish, connection
method, and the observed result.

| Date | Path | Ollama/API | Model | Result |
| --- | --- | --- | --- | --- |
| 2026-08-29 | Adapter tests | OpenAI-compatible contract | Synthetic | Pass |
| Pending | Home network | Pending | Pending | Pending |
| Pending | Tailscale | Pending | Pending | Pending |

The adapter contract covers model discovery, streamed text, HTTP failures,
Ollama-style string errors, malformed stream data, cancellation, and a server
that stops producing stream data. Real-server validation is still required
because it also exercises networking, model startup, and the installed Ollama
version.
