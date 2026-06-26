# Package Boundaries

InferKit owns:

- OpenAI-compatible chat completions and model listing.
- Request and response models.
- Streaming events and collection helpers.
- Reasoning extraction and phase tracking.
- Agent tool orchestration and tool lifecycle events.
- Package examples, package docs, tests, and pub.dev metadata.

Host applications own:

- Persistence and database schemas.
- User settings and secrets storage.
- Domain tools and tool handlers.
- Document search, OCR workflows, embeddings, citations, and UI rendering.
- Any display payload interpretation.

If you are changing behavior that crosses this boundary, check
[VERIFICATION.md](VERIFICATION.md) and [CONTRIBUTING.md](CONTRIBUTING.md).
