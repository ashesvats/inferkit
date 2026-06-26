# Contributing to InferKit

InferKit is a pure-Dart package for OpenAI-compatible inference servers. This
guide covers the normal workflow for changing the package, adding features,
and preparing releases.

## Repository Shape

- `main` is the primary long-lived branch.
- Release versions are recorded with git tags such as `v0.1.0`.
- [CHANGELOG.md](CHANGELOG.md) is the user-facing history of releases.
- [USAGE.md](USAGE.md) is the end-user guide and should stay aligned with the
  public API.
- `AGENTS.md` contains working instructions for Codex agents.

## Before Making Changes

- Read [../README.md](../README.md) to understand the package scope.
- Read [USAGE.md](USAGE.md) to see current public usage examples.
- Read [CHANGELOG.md](CHANGELOG.md) before changing behavior or release-facing
  docs.
- Read `pubspec.yaml` before changing dependencies or version metadata.

## Development Workflow

1. Make the smallest change that solves the problem.
2. Keep package boundaries intact. InferKit stays independent from host app
   code and Flutter UI concerns.
3. Update tests when behavior changes.
4. Update [USAGE.md](USAGE.md) when the public API or user-facing behavior
   changes.
5. Update [CHANGELOG.md](CHANGELOG.md) when a change is relevant to release
   notes.
6. Run `dart analyze` and `dart test` before shipping code changes.

## Release Workflow

For a normal release:

1. Confirm `main` is green.
2. Update `pubspec.yaml` with the new version.
3. Update [CHANGELOG.md](CHANGELOG.md) with the release entry.
4. Ensure [USAGE.md](USAGE.md) reflects any user-visible changes.
5. Run `dart analyze` and `dart test`.
6. Commit the release change.
7. Tag the release, for example `v0.1.1`.
8. Publish the package to pub.dev.

Patch releases should stay backward compatible. Minor releases can add new
behavior without breaking existing callers. Major releases are reserved for
breaking API changes.

## Documentation Rules

- Keep [USAGE.md](USAGE.md) as the single source of truth for package usage.
- Keep [../README.md](../README.md) shorter than [USAGE.md](USAGE.md); it is
  the entry point, not the full reference.
- Keep [CHANGELOG.md](CHANGELOG.md) focused on release notes, not implementation
  details.
- When changing public behavior, update [USAGE.md](USAGE.md) and
  [CHANGELOG.md](CHANGELOG.md) together.

## Tests

Prefer lightweight package-local checks:

```bash
dart analyze
dart test
```

Add or adjust tests when the request/response contract, serialization, stream
behavior, or public descriptors change.

## Pull Requests

- Explain the user-visible effect of the change.
- Mention any API additions, behavior changes, or release notes updates.
- Call out any compatibility risk explicitly.
