# InferKit Agent Guide

## Goal

InferKit should give library users maximum flexibility and customization in a
way that stays easy to use, efficient, and well documented.

## First Step For Every Task

Before doing anything, read [docs/INDEX.md](docs/INDEX.md) and use it to
navigate to the right project documentation for the task.

At a minimum, agents should usually review:

- `README.md` for package scope and public examples.
- `docs/USAGE.md` for user-facing behavior and API usage.
- `docs/CONTRIBUTING.md` for workflow and release expectations.
- `pubspec.yaml` before changing package metadata, SDK constraints, or
  dependencies.
- `docs/CHANGELOG.md` before changing behavior or release-facing docs.

## Coding And Structure Conventions

- Keep InferKit independent from host-app implementation details. Do not
  import Flutter UI code, app services, persistence layers, or app-specific
  domain entities into this package.
- Prefer small, focused files with one clear responsibility.
- Use Dart-standard `lower_snake_case` file names for Dart source and test
  files.
- Keep public API surface intentional. Export package-facing APIs deliberately
  and avoid leaking internal helpers.
- Mirror tests to the library structure where practical, and keep test file
  names ending in `_test.dart`.
- Keep documentation inside `docs/` with concise, descriptive uppercase file
  names such as `USAGE.md`, `CHANGELOG.md`, and `VERIFICATION.md`.
- Update documentation alongside behavior changes so package users always have
  accurate guidance.

See [docs/CODING_CONVENTIONS.md](docs/CODING_CONVENTIONS.md) for the fuller
project structure guidance.
