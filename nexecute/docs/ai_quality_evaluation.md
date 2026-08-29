# AI quality evaluation

Nexecute has a versioned, synthetic evaluation suite for the two AI workflows
that exist today: general chat and Note → proposed tasks. It is deliberately
small enough to run against a local model during development and stable enough
to reuse when comparing a hosted provider later.

The committed corpus is `evaluation/ai_quality_cases.v1.json`. Its case IDs are
stable within suite version 1. Inputs contain no personal notes, account data,
endpoint addresses, or credentials. English and Finnish cases cover:

- simple responses and task extraction;
- multiple tasks and explicit dates;
- ambiguous requests and missing information;
- instructions embedded inside untrusted notes or quoted text;
- unsupported claims about app data or completed actions;
- informational text that must not become hallucinated tasks; and
- malformed structured proposal responses.

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

The runner sends chat cases with Nexecute's current production chat system
prompt. Note cases use the production note-task prompt builder and parse output
with the production strict proposal parser. It does not write conversations,
tasks, notes, or Firestore data.

## Interpret a report

Each result has one mutually exclusive outcome:

- `passed`: all deterministic checks passed. Read `reviewCriteria` and inspect
  the output before treating a model as production-ready.
- `transportFailure`: the endpoint was unreachable, timed out, returned an HTTP
  failure, or ended the stream before completion.
- `applicationFailure`: the endpoint response was malformed/empty, a tool call
  appeared where text was required, the task proposal failed the production
  parser, or an application parser guardrail regressed.
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
