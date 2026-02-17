# Diagrams

This folder contains high-level architecture diagrams and their SVG outputs.

## Files

1. `online_playlist_architecture.mmd` / `.svg`
2. `serial_protocol_sequence.mmd` / `.svg`
3. `playlist_runtime_state.mmd` / `.svg`
4. `offline_master_architecture_future.mmd` / `.svg`
5. `codeflows/*.svg` per-code-file flow diagrams

## Regenerate SVGs

Use your local Mermaid CLI workflow to render each `.mmd` into `.svg`.
This repo keeps the rendered SVG files as the shareable artifact.

Notes:

1. Rendering uses `npx @mermaid-js/mermaid-cli`.
2. `puppeteer-config.json` includes `--no-sandbox` args for environments where Chromium sandboxing is restricted.
3. Per-file Mermaid sources are documented in `../codeflows/*.md`.
