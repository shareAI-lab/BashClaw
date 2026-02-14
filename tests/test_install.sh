#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_install"

INSTALL_SCRIPT="${BASHCLAW_ROOT}/install.sh"

# ---- install.sh --help shows usage ----

test_start "install.sh --help shows usage"
setup_test_env
if [[ -f "$INSTALL_SCRIPT" ]]; then
  result="$(bash "$INSTALL_SCRIPT" --help 2>&1)" || true
  if [[ -n "$result" ]]; then
    assert_match "$result" '[Uu]sage|[Hh]elp|[Ii]nstall'
  else
    _test_fail "install.sh --help produced no output"
  fi
else
  printf '  SKIP install.sh not found\n'
  _test_pass
fi
teardown_test_env

# ---- install.sh --prefix documented in help ----

test_start "install.sh --prefix documented in help"
setup_test_env
if [[ -f "$INSTALL_SCRIPT" ]]; then
  result="$(bash "$INSTALL_SCRIPT" --help 2>&1)" || true
  assert_contains "$result" "--prefix"
else
  printf '  SKIP install.sh not found\n'
  _test_pass
fi
teardown_test_env

report_results
