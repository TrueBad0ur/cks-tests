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

echo "=== Task 11 verify ==="
check_wget "service-a -> service-b    ALLOWED"  np-11-a       service-a "http://service-b.np-11-b.svc.cluster.local"       "ok"
check_wget "service-b -> service-a    ALLOWED"  np-11-b       service-b "http://service-a.np-11-a.svc.cluster.local"       "ok"
check_curl "outsider  -> service-a    BLOCKED"  np-11-outside outsider  "http://service-a.np-11-a.svc.cluster.local"       "fail"
check_curl "outsider  -> service-b    BLOCKED"  np-11-outside outsider  "http://service-b.np-11-b.svc.cluster.local"       "fail"
check_wget "service-a -> outsider     BLOCKED"  np-11-a       service-a "http://outsider.np-11-outside.svc.cluster.local"  "fail"
check_wget "service-b -> outsider     BLOCKED"  np-11-b       service-b "http://outsider.np-11-outside.svc.cluster.local"  "fail"

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "OK: bidirectional isolation works" || echo "ERROR"
