# Changelog

## 0.1.0

Initial public release.

- Added a pure-Dart OpenAI-compatible inference client.
- Added chat completion requests, non-streaming responses, and SSE streaming.
- Added configurable reasoning extraction from structured fields and inline tags.
- Added typed stream events for reasoning, content deltas, tool-call deltas,
  usage, and completion.
- Added phase tracking for chat streams.
- Added model listing through `/v1/models`.
- Added typed exceptions for HTTP, timeout, network, and invalid response
  failures.
- Added an optional Agent layer for recursive tool-call orchestration,
  parallel tool execution, lifecycle events, and final-answer handling.
