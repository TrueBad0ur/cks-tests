#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0

check_curl() {
  local desc=$1 ns=$2 pod=$3 target=$4 expect=$5
  result=$(kubectl -n "$ns" exec "deploy/$pod" -- \
    curl -s --max-time 4 "$target" > /dev/null 2>&1 && echo "ok" || echo "fail")
  if [ "$result" = "$expect" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $desc (got=$result, want=$expect)"
    FAIL=$((FAIL+1))
  fi
}

check_wget() {
  local desc=$1 ns=$2 pod=$3 target=$4 expect=$5
  result=$(kubectl -n "$ns" exec "deploy/$pod" -- \
    wget -q -O- --timeout=4 "$target" > /dev/null 2>&1 && echo "ok" || echo "fail")
  if [ "$result" = "$expect" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $desc (got=$result, want=$expect)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== Task 10 verify ==="
check_wget "trusted (role=trusted) -> app:8080  ALLOWED"  np-10-internal trusted          "http://app.np-10-app.svc.cluster.local:8080"          "ok"
check_curl "blocked (role=blocked) -> app:8080  BLOCKED"  np-10-internal blocked-internal "http://app.np-10-app.svc.cluster.local:8080"          "fail"
check_wget "app -> trusted:9090                ALLOWED"   np-10-app      app              "http://trusted.np-10-internal.svc.cluster.local:9090" "ok"

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "OK" || echo "ERROR"
