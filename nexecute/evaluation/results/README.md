# Local AI quality reports

The evaluation runner writes timestamped JSON reports to this directory. The
reports identify the model ID and exact model version/tag/digest, suite version,
production prompts, generation settings, per-case output, token usage when
available, and separate transport, application, and quality outcomes.

Generated reports are ignored by Git by default because endpoint errors or
unexpected model output can contain local environment details. Review and
redact a report before deliberately committing it as a comparison baseline.
