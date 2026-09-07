# Test Plan: HA Chromium Kiosk Setup Script

Covers `ha-chromium-kiosk-setup.sh` — install, uninstall, and every user-facing
prompt path. This is a living document: extend it whenever a new option,
prompt, or bug fix lands (see "Regression cases" below for the pattern).

## Why this exists

Prior to 2026-09-07 the only verification was `bash -n` (syntax) and
ShellCheck (static analysis). Both are necessary but not sufficient — a
2026-09-07 real-environment test run found a bug (#34, generated
`check_network()` loop silently never executing) that was syntactically
valid and ShellCheck-clean, because the bug was in a **heredoc-generated
runtime script**, not the installer's own logic. Static analysis cannot
catch bugs in generated output; only actually running the generated
artifact can. Every level below exists for a reason — don't skip straight
to "looks right" without running it.

## Test levels

### 1. Static analysis (fast, run on every commit — automated in CI)
- `bash -n ha-chromium-kiosk-setup.sh` — syntax check.
- `shellcheck -S warning ha-chromium-kiosk-setup.sh` (with `SHELLCHECK_OPTS=-e SC2154`
  — see issue #26 for why that suppression is intentional, not a blind spot).
- Both wired into `.github/workflows/lint.yml`, run on every push/PR to `main`.
- **Known gap:** catches nothing inside heredoc-generated content (the kiosk
  startup script, systemd units, tty1 override) — those are string literals
  to the installer's own shellcheck pass. Level 3 covers that gap.

### 2. Function-level dry runs (fast, manual — no root/apt needed)
Source individual functions in isolation and call them with fixture inputs.
Useful for validating pure logic (validators, prompt flow, string-building)
without needing a real environment. Pattern used during the #21/#22/#24
implementation and the #25 fix:

```bash
bash -c '
source <(sed -n "1,220p" ha-chromium-kiosk-setup.sh)   # pull in just the functions needed
prompt_user() { echo "PROMPT: $2"; declare -g "$1"="Y"; }  # stub interactive prompts
show_summary install
'
```

Cases to dry-run this way whenever touched:
- `validate_ip()` — valid IPv4 (`192.168.20.12`), valid hostname, invalid octet (`999.1.1.1`), garbage string, empty string.
- `validate_port()` — valid (`8123`), boundary (`1`, `65535`), out of range (`0`, `65536`), non-numeric.
- `prompt_user()` — empty input with a default (should use default), empty input with no default (should re-prompt with "required" error), input matching each variable-specific validator branch (`HA_IP`, `HA_PORT`, `HA_DASHBOARD_PATH` vs. the generic alnum-only branch).
- `check_backup_config()` — file doesn't exist (returns 0, no prompts), file exists + decline backup + accept overwrite, file exists + accept backup + decline overwrite (must `return 1`, NOT `exit 0` — this is the #25 regression case, see below).
- Heredoc-generation logic for `install_kiosk()`'s kiosk-script builder — see Level 3, this one specifically needs the generated *output* inspected, not just the generator's own syntax.

### 3. Generated-artifact verification (catches what Level 1/2 can't)
Whenever any code path writes a heredoc into a file that will be executed
later — the kiosk startup script, the systemd unit, the tty1 override — the
**generated file itself** must be syntax-checked and, where it's a shell
script, ideally executed:

```bash
# After a real or simulated install run:
bash -n /usr/local/bin/ha-chromium-kiosk.sh   # generated script must also parse
grep -n '\$attempt\|\$max_attempts\|\$success' /usr/local/bin/ha-chromium-kiosk.sh
# ^ these three should appear as LITERAL $var references in the file,
#   not already-expanded empty strings - this is the exact bug class of #34
```

If a change adds a new heredoc-embedded runtime variable, verify by eye
whether it's meant to resolve at **install time** (leave unescaped,
`$HA_IP`-style) or at **kiosk-boot runtime** (escape it, `\$attempt`-style)
— this distinction is the single most error-prone part of this script.

### 4. Full integration test — real systemd environment (slow, run before every merge to main)

Static checks and dry runs don't prove the script installs anything real.
Use a genuine systemd PID 1, not a bare container:

```bash
# Setup (once per test session)
docker rm -f kiosktest 2>/dev/null
docker run -d --privileged --name kiosktest --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw jrei/systemd-debian:12
sleep 4
docker exec kiosktest systemctl is-system-running   # must print "running"
docker exec kiosktest bash -c "apt-get update -qq && apt-get install -y sudo"
docker cp ha-chromium-kiosk-setup.sh kiosktest:/root/
docker exec kiosktest chmod +x /root/ha-chromium-kiosk-setup.sh
```

**Gotcha:** `jrei/systemd-debian` images have no `sudo` preinstalled, but
the script's `sudo -u $KIOSK_USER` calls need it — install it manually in
the test container BEFORE running the script (this is a real gap in the
script itself too — it never checks for/installs its own `sudo`
dependency; worth a future issue).

#### 4a. Install — happy path
Answer file order matches the CURRENT `install_kiosk()` prompt sequence —
**verify this order against the live script before each test run**, it
has changed as options were added (HTTPS in #21, rotation in #22, zoom in
#24, `show_summary` confirmation in the UI port):
```
<confirm_action: Y>      # only present if show_summary() exists on this branch
<HA_IP>
<HA_PORT>
<HA_DASHBOARD_PATH>
<use_https: Y/N>
<enable_kiosk: Y/n>
<hide_cursor: Y/n>
<rotate_display: y/N>
  <display_output>        # only if rotate_display = Y
  <display_rotation>      # only if rotate_display = Y
<disable_pinch_zoom: y/N>
<zoom_percent>
<reboot_now: Y/n>          # answer N for testing - do NOT let it actually reboot the test container
```

```bash
printf '<answers, one per line, matching the order above>' > answers.txt
docker cp answers.txt kiosktest:/root/
docker exec kiosktest bash -c \
  "timeout 280 /root/ha-chromium-kiosk-setup.sh install < /root/answers.txt > /root/install_log.txt 2>&1; echo EXIT_\$?"
```
**Pass criteria:**
- `EXIT_0`
- `id kiosk` succeeds inside the container
- `/usr/local/bin/ha-chromium-kiosk.sh` exists, is executable, `bash -n` clean
- `/etc/systemd/system/ha-chromium-kiosk.service` exists; `systemctl is-enabled ha-chromium-kiosk.service` reports `enabled`
- `/home/kiosk/.config/openbox/autostart` references the kiosk script
- `/etc/systemd/system/getty@tty1.service.d/override.conf` has the correct `--autologin kiosk` line
- Generated kiosk script's `check_network()` loop verified per Level 3 above
- Every `install_package` line in the log shows a matching `OK Installed <pkg>` (or `FAILED` — investigate if so)

#### 4b. Uninstall — happy path
Run against a container that has a completed install (4a) already applied:
```
<confirm: Y>
<restore_backup: Y/n>        # if a backup exists from a prior test - otherwise not prompted
<remove_packages: Y/n>
<check_remove_user prompt: Y/n>
```
**Pass criteria:**
- `EXIT_0`
- `/usr/local/bin/ha-chromium-kiosk.sh`, the systemd unit, and the tty1
  override are all gone
- `id kiosk` fails ("no such user") if package/user removal was accepted

#### 4c. `help` command
```bash
docker exec kiosktest /root/ha-chromium-kiosk-setup.sh help
```
**Pass criteria:** exits 0, prints usage, does NOT show the warning banner
or block on a `read -n 1 -s` prompt.

#### 4d. No-argument / bad-argument invocation
```bash
docker exec kiosktest /root/ha-chromium-kiosk-setup.sh
docker exec kiosktest /root/ha-chromium-kiosk-setup.sh bogus-command
```
**Pass criteria:** both print usage and exit non-zero (matches `print_usage()`'s `exit 1` when not called with `"help"`).

#### 4e. Non-root invocation
```bash
docker exec -u 1000 kiosktest /root/ha-chromium-kiosk-setup.sh install
```
**Pass criteria:** exits 1 with the "must be run as root" error, before the banner.

### 5. Edge cases and error paths (integration level, run at least before a release tag)

- **Re-install over an existing config** (tests #25's fix): run install twice
  in a row. On the second run, when prompted to overwrite an existing
  config file, answer **N**. Pass criteria: that one step is skipped
  (script prints "Skipping ... configuration will not be modified"), but
  the REST of the install continues and still exits 0 — it must NOT abort
  the whole run (that was the exact #25 regression).
- **Kiosk user already exists**: run install when a `kiosk` user is
  already present (e.g. from a prior test). Pass criteria:
  `check_create_user()` prompts "already exists... use existing?" and
  proceeds correctly on Y, or lets you pick a different username on N.
- **Re-running install while the kiosk service is active** (tests #29's
  atomicity fix): start the systemd service, then re-run install over it.
  Pass criteria: script detects the active service, stops it before
  rewriting `/usr/local/bin/ha-chromium-kiosk.sh`, and restarts it after —
  verify via `systemctl status` before/during/after, and confirm the
  script file was never truncated mid-write (no partial/empty file at any
  point — hard to catch without a deliberate race, but at minimum verify
  the final file is complete and `bash -n` clean).
- **HTTPS selected** (`use_https` = Y): verify the generated kiosk
  script's Chromium URL argument uses `https://`, not `http://`.
- **Display rotation selected**: verify the generated script contains the
  `xrandr --output <X> --rotate <Y>` line with the exact values entered,
  and that an invalid rotation value (e.g. `sideways`) is rejected by the
  prompt's validation loop and re-prompted, not silently accepted.
- **Zoom / pinch-disable selected**: verify the generated Chromium launch
  line includes `--disable-pinch` (if selected) and
  `--force-device-scale-factor=<N>` at the correct decimal (e.g. `125` ->
  `1.25`). Verify a zoom value outside 25-500 or non-numeric is rejected
  and re-prompted.
- **Uninstall declining the restore-backup prompt** and **declining
  package removal** — both should complete without error, just skipping
  that step (same pattern as #25 — verify none of these accidentally
  regress to a hard `exit 0`/abort on decline).

### 6. Security-relevant checks (run whenever touching input handling or file writes)
- Confirm `prompt_user()`'s alnum-restrictive regex still rejects shell
  metacharacters (`;`, `` ` ``, `$(`, `|`) in non-IP/port/path inputs —
  paste one in manually and confirm it's rejected, not passed through.
- Confirm the README's checksum instructions (#30) still match the
  current release tag's actual `sha256sum` — recompute and diff after
  every tagged release.
- Confirm no `sudo apt-get`/`sudo <cmd>` calls exist inside functions that
  already run under a root-required script (redundant sudo was #28's root
  cause elsewhere) — `grep -n 'sudo apt-get\|sudo systemctl\|sudo cat'`
  should return nothing.

## Regression cases (one per fixed bug — never remove, only add)

| Issue | What broke | Test that catches it | Status |
|---|---|---|---|
| #20 | Mid-install `systemctl restart getty@tty1` could auto-login and kill the installer | 4a: install must complete without any spontaneous tty1 login/session kill | Fixed, no regression test automatable in a container (no real tty1) — verify by code inspection: no `systemctl restart getty@tty1` call should exist mid-`install_kiosk()` |
| #25 | Declining an overwrite prompt aborted the ENTIRE install via `exit 0` | 5: re-install-over-existing-config, decline overwrite, verify install still exits 0 | Fixed, testable |
| #26 | ShellCheck SC2154 x17 (declare -g pattern) | 1: `SHELLCHECK_OPTS=-e SC2154` suppression documented, not a real bug | Documented, not a defect |
| #27 | Dead/duplicated `DEFAULT_HA_PORT`/`DEFAULT_HA_DASHBOARD_PATH` | 2: dry-run `install_kiosk()`'s prompt defaults, confirm they read from the constants | Fixed, testable |
| #28 | `adduser` redirect order backwards | 2: `install_package`/`check_create_user` output inspected manually for stray stderr leakage | Fixed, low test value (cosmetic) |
| #29 | No atomicity guard rewriting the live kiosk script | 5: re-install-while-service-active case above | Fixed, testable (partially — full race is hard to force) |
| #30 | No checksum on the README's install one-liner | 6: recompute sha256sum per release, diff against README | Fixed, manual per-release check |
| #21 | No HTTPS support | 5: HTTPS-selected case above | Fixed, testable |
| #22 | No display rotation option | 5: rotation-selected case above | Fixed, testable |
| #24 | No pinch-zoom/zoom-level option | 5: zoom/pinch-selected case above | Fixed, testable |
| #34 | Generated `check_network()` loop silently never ran (heredoc var-expansion timing bug) | 3 + 4a: generated-script inspection, confirm `$attempt` et al. appear literal, then actually run the generated script against an unreachable address and confirm it retries instead of false-reporting success | Fixed, testable — **the case that proved Level 3/4 testing is mandatory, not optional** |

## What's still NOT covered (open gap, tracked as #31)

- ~~No automated harness runs Level 4 (real systemd integration) in CI~~
  **Closed 2026-09-07**: `tests/run-integration-tests.sh` automates the
  4a-4e + #25 regression cases and runs as a second CI job
  (`.github/workflows/lint.yml`, job `integration`) on every push/PR.
  19/19 assertions pass on GitHub-hosted `ubuntu-latest` runners
  (confirmed - not just locally).
- No test actually exercises the kiosk GUI session itself (X server,
  Openbox, Chromium rendering) — Level 4 tests can confirm the systemd
  service is *enabled* and the generated script is *correct*, but not
  that Chromium actually renders a Home Assistant dashboard on a real
  display. This needs either a VM with a virtual framebuffer/VNC, or
  physical hardware — out of scope for a container-based test.
- No test for the `uninstall`'s `restore_backup` path when a real backup
  file exists (needs a prior install + a manually triggered backup
  scenario to set up first — not yet scripted).

## Running the fast subset locally (Level 1 + 2, no root/Docker needed)

```bash
bash -n ha-chromium-kiosk-setup.sh
docker run --rm -v "$PWD":/mnt -e SHELLCHECK_OPTS="-e SC2154" \
  koalaman/shellcheck:stable -S warning /mnt/ha-chromium-kiosk-setup.sh
```

## Running the full suite before a merge to main

1. Level 1 (above).
2. Level 4a/4b/4c/4d/4e against a fresh `jrei/systemd-debian:12` container.
3. Relevant Level 5 edge cases for whatever the change actually touches
   (don't re-run every edge case for a docs-only change; do run all of
   them before a release tag).
4. Update this file's regression table if the change fixes a new bug.
