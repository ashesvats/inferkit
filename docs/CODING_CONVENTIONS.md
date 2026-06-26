# Coding Conventions

Use these conventions to keep InferKit easy to extend, easy to understand, and
easy to document.

## Goal

InferKit should give library users flexibility and customization without making
common use cases hard. Prefer APIs and internals that stay efficient,
predictable, and well documented.

## File Naming

- Use Dart-standard `lower_snake_case` for Dart source files.
- Use `_test.dart` suffixes for tests.
- Keep documentation in `docs/` using concise uppercase names such as
  `USAGE.md`, `CHANGELOG.md`, and `VERIFICATION.md`.

## Structure

- Give each file one primary responsibility.
- Keep public exports intentional and avoid exposing internal helpers by
  default.
- Prefer package-local abstractions over host-app assumptions.
- Keep tests close in shape to the `lib/` structure when practical.

## Boundaries

- InferKit owns protocol client behavior, typed models, streaming, reasoning,
  agent orchestration, tests, and package documentation.
- Host applications own persistence, settings, secrets storage, UI rendering,
  citations, OCR, embeddings, and domain-specific tool implementations.

## Documentation

- Update `docs/USAGE.md` when public API usage or user-visible behavior
  changes.
- Update `docs/CHANGELOG.md` when release-facing behavior changes.
- Keep `README.md` as the lightweight package entry point and `docs/` as the
  deeper documentation set.

## Verification

Prefer package-local checks:

```bash
dart analyze
dart test
```
