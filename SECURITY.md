# Security Policy

## Supported scope

This project is an educational embedded repo. Security reviews are welcome for:

1. [`scripts/run_playlist.sh`](scripts/run_playlist.sh)
2. Serial protocol handling in sketches
3. Dependency and supply-chain concerns

## Reporting a vulnerability

If you find a security issue:

1. Do not post exploit details publicly first.
2. Open a private report to the maintainer with:
   - affected file/path
   - reproduction steps
   - impact assessment
   - suggested fix (optional)

## Threat model notes

1. The host script executes local tooling (`arduino-cli`, `python3`) and opens serial ports.
2. Weather mode performs unauthenticated public API calls.
3. Sketches trust serial input and intentionally constrain it to ASCII + bounded buffers.

## Hardening recommendations for users

1. Run scripts from a trusted machine.
2. Review third-party URLs before enabling network features.
3. Keep Arduino toolchain and OS packages updated.
4. Do not run serial automation as root unless absolutely required.
