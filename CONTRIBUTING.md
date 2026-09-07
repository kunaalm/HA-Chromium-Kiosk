# Contributing

Thanks for considering a contribution. This is a bash script that runs as root on Debian systems and modifies system state (users, systemd services, X/Openbox config) — the bar for testing is correspondingly higher than "it looked right."

## Workflow

1. **Fork/branch** off `main`.
2. **Make your change.**
3. **Test it for real** — see [TESTING.md](TESTING.md) for the full plan. At minimum:
   - `bash -n ha-chromium-kiosk-setup.sh` (syntax)
   - ShellCheck: `docker run --rm -v "$PWD":/mnt -e SHELLCHECK_OPTS="-e SC2154" koalaman/shellcheck:stable /mnt/ha-chromium-kiosk-setup.sh`
   - The integration suite, ideally against a real systemd container (see TESTING.md Level 4), not just a bare Docker container: `bash tests/run-integration-tests.sh`
4. **Open a PR against `main`.** CI (`.github/workflows/lint.yml`) runs ShellCheck and the integration suite automatically — both must pass.
5. Static analysis passing is necessary but not sufficient for anything that changes runtime behavior (prompts, install/uninstall logic, generated scripts) — if your change touches that, say in the PR description what you actually ran it against (a real container, real hardware, etc.), not just what analysis you ran.

## Reporting bugs / requesting features

Use the [issue templates](.github/ISSUE_TEMPLATE/) — a bug report with your OS, Home Assistant version, and the exact command + output you saw is far more actionable than a one-line description.

## Scope notes

- The `docs/` and `README.md` do not need to duplicate the script itself — code stays in the script, docs stay descriptive.
- `TESTING.md` documents what's covered and what isn't (see its "not covered" section) — real Chromium/GUI rendering on physical hardware, for instance, isn't something CI can verify. Be honest in a PR about what you didn't test, not just what you did.
- Releases are cut by pushing a `vX.Y.Z` tag — `.github/workflows/release.yml` then computes the checksum and publishes the GitHub Release automatically. You don't need to (and shouldn't) hand-edit a checksum into a PR.
