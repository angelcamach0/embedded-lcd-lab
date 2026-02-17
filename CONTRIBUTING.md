# Contributing

Thanks for contributing.

## Workflow

1. Fork the repo.
2. Create a feature branch.
3. Keep changes focused and small.
4. Open a pull request with:
   - what changed
   - why
   - how you tested

## Coding guidelines

1. Keep Arduino code Uno-safe (watch SRAM usage).
2. Prefer fixed-size buffers over dynamic `String` for serial parsing paths.
3. Keep comments practical and tied to behavior.
4. Keep scripts POSIX-friendly where possible and use defensive shell options.

## Testing checklist

1. `bash -n scripts/run_playlist.sh`
2. Compile changed sketches with `arduino-cli compile`.
3. If behavior changes on hardware, include before/after notes.

## Documentation

If you change behavior, update:

1. [`README.md`](README.md)
2. Relevant file under [`docs/`](docs/)
3. [`docs/INDEX.md`](docs/INDEX.md) if you add/remove major docs
