#!/usr/bin/env bash
set -euo pipefail
NS=np-9
PASS=0; FAIL=0

check_curl() {
  local desc=$1 pod=$2 target=$3 expect=$4
  result=$(kubectl -n "$NS" exec "deploy/$pod" -- \
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
  local desc=$1 pod=$2 target=$3 expect=$4
  result=$(kubectl -n "$NS" exec "deploy/$pod" -- \
    wget -q -O- --timeout=4 "$target" > /dev/null 2>&1 && echo "ok" || echo "fail")
  if [ "$result" = "$expect" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $desc (got=$result, want=$expect)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== Task 9 verify ==="
check_curl "web -> api:80   ALLOWED"  web "http://api.np-9.svc.cluster.local:80"    "ok"
check_curl "web -> db:5432  BLOCKED"  web "http://db.np-9.svc.cluster.local:5432"   "fail"
check_wget "api -> db:5432  ALLOWED"  api "http://db.np-9.svc.cluster.local:5432"   "ok"
check_wget "db  -> api:80   BLOCKED"  db  "http://api.np-9.svc.cluster.local:80"    "fail"
check_wget "db  -> web      BLOCKED"  db  "http://web.np-9.svc.cluster.local"       "fail"

echo ""
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "OK: additive policies work" || echo "ERROR"
