# Contributing

Thanks for contributing.

## Workflow

1. Open or create a GitHub issue first (bug or feature), even for small fixes.
2. Create a branch from `main` linked to that issue.
3. Keep changes focused and small (one concern per commit when possible).
4. Validate locally before commit.
5. Commit with a clear message that explains intent.
6. Open a pull request with:
   - what changed
   - why
   - how you tested
7. Add a resolution comment on the issue with commit reference(s), then close it.

### Issue-First Rule (project convention)

For this project, bug fixes should have an issue created before implementation so repo history clearly tracks:

1. symptom/reproduction
2. root cause
3. applied fix
4. verification

## Coding guidelines

1. Keep Arduino code Uno-safe (watch SRAM usage).
2. Prefer fixed-size buffers over dynamic `String` for serial parsing paths.
3. Keep comments practical and tied to behavior.
4. Keep scripts POSIX-friendly where possible and use defensive shell options.

## Testing checklist

1. `bash -n scripts/run_playlist.sh`
2. `./scripts/tests/test_duration_policy.sh`
3. Compile changed sketches with `arduino-cli compile`.
4. If behavior changes on hardware, include before/after notes.

## Documentation

If you change behavior, update:

1. [`README.md`](README.md)
2. Relevant file under [`docs/`](docs/)
3. [`docs/INDEX.md`](docs/INDEX.md) if you add/remove major docs
