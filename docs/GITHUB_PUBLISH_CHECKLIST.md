# GitHub Publish Checklist

Use this when publishing `embedded-lcd-lab` as a standalone repository.

## 1) Initialize local git repo

```bash
cd embedded-lcd-lab
git init
git add .
git commit -m "Initial public release: Arduino LCD lab"
```

## 2) Create remote repository

Create an empty GitHub repo (no README/license generated on GitHub side), then:

```bash
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

## 3) Verify public artifacts

Before sharing:

1. `README.md` renders correctly
2. `LICENSE` is visible in repo root
3. `PRIVACY.md`, `SECURITY.md`, `DISCLAIMER.md` are present
4. `docs/wiring.md` and project screenshots are accurate

## 4) Optional improvements

1. Add wiring photo/diagram to `docs/`.
2. Add CI workflow that runs:
   - `bash -n scripts/run_playlist.sh`
   - `arduino-cli compile` for sketches
3. Add tagged release (`v0.1.0`) once stable.
