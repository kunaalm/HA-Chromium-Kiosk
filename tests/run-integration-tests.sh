#!/bin/bash
# Level 4 integration test harness for ha-chromium-kiosk-setup.sh
# Runs the full test matrix from TESTING.md section 4 (and a few of
# section 5's edge cases) against a real systemd container.
#
# Usage: ./run-integration-tests.sh
# Requires: docker, a script named ha-chromium-kiosk-setup.sh in the
# same directory as this file (or pass a path as $1).

set -u
SCRIPT_PATH="${1:-$(dirname "$0")/../ha-chromium-kiosk-setup.sh}"
CONTAINER=kiosktest-ci
PASS=0
FAIL=0
FAILURES=()

log_pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
log_fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); FAILURES+=("$1"); }

fresh_container() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1
    docker run -d --privileged --name "$CONTAINER" --cgroupns=host \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw jrei/systemd-debian:12 >/dev/null
    sleep 4
    local status
    status=$(docker exec "$CONTAINER" systemctl is-system-running 2>/dev/null)
    if [ "$status" != "running" ]; then
        echo "FATAL: container systemd not running (got: $status)"
        exit 1
    fi
    docker exec "$CONTAINER" bash -c "apt-get update -qq >/dev/null 2>&1 && apt-get install -y sudo >/dev/null 2>&1"
    docker cp "$SCRIPT_PATH" "$CONTAINER:/root/ha-chromium-kiosk-setup.sh"
    docker exec "$CONTAINER" chmod +x /root/ha-chromium-kiosk-setup.sh
}

run_install() {
    # $1 = answers (printf-style string, already newline-separated)
    docker exec "$CONTAINER" bash -c \
        "printf '$1' | timeout 280 /root/ha-chromium-kiosk-setup.sh install > /root/install_log.txt 2>&1; echo EXIT_\$?" \
        | tail -1
}

run_uninstall() {
    docker exec "$CONTAINER" bash -c \
        "printf '$1' | timeout 120 /root/ha-chromium-kiosk-setup.sh uninstall > /root/uninstall_log.txt 2>&1; echo EXIT_\$?" \
        | tail -1
}

# --- 4a: install happy path ---------------------------------------------
echo "=== 4a: install happy path ==="
fresh_container
RESULT=$(run_install 'Y\n192.168.1.50\n8123\nlovelace/default_view\nN\nY\nY\nN\nN\n100\nN\n')
[ "$RESULT" = "EXIT_0" ] && log_pass "install exits 0" || log_fail "install exit code: $RESULT"

docker exec "$CONTAINER" id kiosk >/dev/null 2>&1 \
    && log_pass "kiosk user created" || log_fail "kiosk user NOT created"

docker exec "$CONTAINER" test -x /usr/local/bin/ha-chromium-kiosk.sh \
    && log_pass "kiosk script exists and executable" || log_fail "kiosk script missing/not executable"

docker exec "$CONTAINER" bash -n /usr/local/bin/ha-chromium-kiosk.sh \
    && log_pass "generated kiosk script is syntactically valid" || log_fail "generated kiosk script has a syntax error"

ENABLED=$(docker exec "$CONTAINER" systemctl is-enabled ha-chromium-kiosk.service 2>/dev/null)
[ "$ENABLED" = "enabled" ] && log_pass "systemd service enabled" || log_fail "systemd service not enabled (got: $ENABLED)"

docker exec "$CONTAINER" grep -q "ha-chromium-kiosk.sh" /home/kiosk/.config/openbox/autostart 2>/dev/null \
    && log_pass "openbox autostart references kiosk script" || log_fail "openbox autostart missing/wrong"

docker exec "$CONTAINER" grep -q "autologin kiosk" /etc/systemd/system/getty@tty1.service.d/override.conf 2>/dev/null \
    && log_pass "tty1 auto-login override correct" || log_fail "tty1 auto-login override missing/wrong"

# Level 3 check baked into 4a: generated script's check_network loop must
# be LITERAL, not pre-expanded (regression test for issue #34)
docker exec "$CONTAINER" grep -q 'while \[ \$attempt -lt \$max_attempts \]' /usr/local/bin/ha-chromium-kiosk.sh \
    && log_pass "check_network() loop variables are literal (issue #34 regression check)" \
    || log_fail "check_network() loop variables got pre-expanded (issue #34 REGRESSION)"

# Actually run the generated script briefly and confirm it retries
# instead of falsely reporting success against an unreachable address.
NET_OUT=$(docker exec "$CONTAINER" timeout 8 bash /usr/local/bin/ha-chromium-kiosk.sh 2>&1)
echo "$NET_OUT" | grep -q "Attempt 1 of 30" \
    && log_pass "generated script's network check actually retries (issue #34 functional check)" \
    || log_fail "generated script did not show a retry attempt - possible #34 regression"

# --- 4b: uninstall happy path (same container, install already applied) -
echo "=== 4b: uninstall happy path ==="
RESULT=$(run_uninstall 'Y\nY\n')
[ "$RESULT" = "EXIT_0" ] && log_pass "uninstall exits 0" || log_fail "uninstall exit code: $RESULT"

docker exec "$CONTAINER" test ! -e /usr/local/bin/ha-chromium-kiosk.sh \
    && log_pass "kiosk script removed" || log_fail "kiosk script NOT removed"

docker exec "$CONTAINER" test ! -e /etc/systemd/system/ha-chromium-kiosk.service \
    && log_pass "systemd service file removed" || log_fail "systemd service file NOT removed"

docker exec "$CONTAINER" id kiosk >/dev/null 2>&1 \
    && log_fail "kiosk user still exists after uninstall" || log_pass "kiosk user removed"

# --- 4c: help command -----------------------------------------------------
echo "=== 4c: help command ==="
HELP_OUT=$(docker exec "$CONTAINER" /root/ha-chromium-kiosk-setup.sh help 2>&1)
HELP_EXIT=$?
[ $HELP_EXIT -eq 0 ] && log_pass "help exits 0" || log_fail "help exit code: $HELP_EXIT"
echo "$HELP_OUT" | grep -qi "WARNING: USE AT YOUR OWN RISK" \
    && log_fail "help command shows the warning banner (should skip it)" \
    || log_pass "help command skips the warning banner"

# --- 4d: no-argument / bad-argument invocation -----------------------------
echo "=== 4d: argument validation ==="
docker exec "$CONTAINER" /root/ha-chromium-kiosk-setup.sh >/dev/null 2>&1
[ $? -ne 0 ] && log_pass "no-argument invocation exits non-zero" || log_fail "no-argument invocation exited 0 (should fail)"

docker exec "$CONTAINER" /root/ha-chromium-kiosk-setup.sh bogus-command >/dev/null 2>&1
[ $? -ne 0 ] && log_pass "bad-argument invocation exits non-zero" || log_fail "bad-argument invocation exited 0 (should fail)"

# --- 4e: non-root invocation ------------------------------------------------
echo "=== 4e: non-root invocation ==="
docker exec -u 1000 "$CONTAINER" /root/ha-chromium-kiosk-setup.sh install >/dev/null 2>&1
[ $? -ne 0 ] && log_pass "non-root invocation refused" || log_fail "non-root invocation was NOT refused"

# --- 5: edge case - decline overwrite must not abort whole install --------
echo "=== 5: overwrite-decline does not abort install (issue #25 regression) ==="
fresh_container
run_install 'Y\n192.168.1.50\n8123\nlovelace/default_view\nN\nY\nY\nN\nN\n100\nN\n' >/dev/null
# Re-run install over the existing config, decline the tty1 auto-login
# overwrite specifically, confirm the rest of the install still completes.
RESULT=$(run_install 'Y\nY\n192.168.1.60\n8123\nlovelace/default_view\nN\nY\nY\nN\nN\n100\nN\n')
[ "$RESULT" = "EXIT_0" ] && log_pass "re-install with a declined overwrite still exits 0 (#25 not regressed)" \
    || log_fail "re-install aborted on a declined overwrite (#25 REGRESSION): $RESULT"

# --- cleanup -----------------------------------------------------------
docker rm -f "$CONTAINER" >/dev/null 2>&1

# --- summary -------------------------------------------------------------
echo ""
echo "=================================="
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi
exit 0
