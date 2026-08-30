# AI quality evaluation

Nexecute has a versioned, synthetic evaluation suite for general chat,
explicit attached context, Note → proposed tasks, Note → proposed calendar
events, strict parser behavior, and read-tool guardrails. It is deliberately
small enough to run against a local model during development and stable enough
to reuse when comparing a hosted provider later.

The committed corpus is `evaluation/ai_quality_cases.v1.json`. Its case IDs are
stable within suite version 1. Inputs contain no personal notes, account data,
endpoint addresses, or credentials. English and Finnish cases cover:

- simple responses and task extraction;
- multiple tasks and explicit dates;
- relative, timed, overnight, and all-day calendar event proposals;
- ambiguous requests and missing information;
- instructions embedded inside untrusted notes or quoted text;
- unsupported claims about app data or completed actions;
- questions answered only from explicitly attached, bounded application data;
- informational text that must not become hallucinated tasks;
- malformed structured proposal responses; and
- malformed, excessive, unknown, and unauthorized read-tool calls.

## Validate the suite without a server

From the repository root:

```sh
dart run tool/run_ai_quality_evaluation.dart --dry-run
```

This parses and lists the cases but makes no network requests. The regular test
suite also validates the schema, required coverage, bilingual workflows, parser
fixtures, and failure classification.

## Run a model evaluation

Use an OpenAI-compatible `/v1` base URL and an installed model. The model
version is required: use an immutable digest when the server provides one, or
record the exact tag and server-reported version used for the run.

```sh
dart run tool/run_ai_quality_evaluation.dart \
  --base-url http://192.0.2.10:11434/v1 \
  --model your-model-id \
  --model-version your-model-version
```

`192.0.2.10` is a documentation-only address. The base URL is used for the run
but is intentionally omitted from the report. Useful optional controls are:

```sh
dart run tool/run_ai_quality_evaluation.dart \
  --base-url https://your-server.example.ts.net/v1 \
  --model your-model-id \
  --model-version your-model-version \
  --repetitions 3 \
  --case chat-en-ambiguous-action,tasks-fi-note-injection \
  --output evaluation/results/comparison-run.json
```

The runner sends chat and attached-context cases with Nexecute's current
production chat system prompt. Attached-context fixtures become the same
canonical, bounded, untrusted envelope used by the app. Note-to-task and
note-to-event cases use their production prompt builders and strict proposal
parsers. Event fixtures provide an explicit reference local time and UTC offset,
so relative-date expectations remain deterministic across machines and time
zones. Tool-protocol fixtures are deterministic and local: they run the
production coordinator against rejecting fake application reads, so guardrail
cases never contact the configured endpoint. The runner does not write
conversations, tasks, notes, events, reminders, or Firestore data.

## Interpret a report

Each result has one mutually exclusive outcome:

- `passed`: all deterministic checks passed. Read `reviewCriteria` and inspect
  the output before treating a model as production-ready.
- `transportFailure`: the endpoint was unreachable, timed out, returned an HTTP
  failure, or ended the stream before completion.
- `applicationFailure`: the endpoint response was malformed/empty, a tool call
  appeared where text was required, a task or event proposal failed its
  production parser, or an application parser guardrail regressed.
- `qualityFailure`: transport and application handling succeeded, but the valid
  model output missed an expected concept, included forbidden content, returned
  the wrong task count, failed to ask for missing information, or otherwise
  failed a deterministic quality check.

The split is important: changing prompts or models should address quality
failures, while network, adapter, protocol, and parser work should address
transport or application failures.

Reports record the corpus version, model ID, model version, production prompts,
generation settings, run count, latency, output, diagnostics, and token usage
when supplied by the endpoint. Generated JSON files under `evaluation/results`
are ignored by Git because unexpected model or error text may expose local
details. Review and redact any result before deliberately committing it as a
baseline.

Automatic checks are intentionally conservative and transparent rather than a
claim of complete semantic grading. Compare providers with the same suite
version and repetitions, inspect every failure, and use the recorded manual
review criteria before choosing a model.
