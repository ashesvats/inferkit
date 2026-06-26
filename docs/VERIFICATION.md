# Verification

Use lightweight package-local checks by default:

```bash
dart analyze
dart test
```

Do not run host-application builds or tests from this repository unless a task
explicitly asks for cross-project verification.

If behavior changes, update [USAGE.md](USAGE.md) and
[CHANGELOG.md](CHANGELOG.md) together when relevant.
