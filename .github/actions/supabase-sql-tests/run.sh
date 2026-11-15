#!/usr/bin/env bash
# Applies the migrations, then runs every <supabase-dir>/tests/*.test.sql, on an EMPTY Postgres database.
#   run.sh "postgresql://user:pass@host:5432/db"
# Environment:
#   STUB=1             load local_stub.sql first (plain Postgres without the Supabase roles / auth schema)
#   SUPABASE_DIR       folder holding `migrations/` and `tests/` (default: supabase)
#   RESULT_MARKER      text a test must print to count as passed (default: "RESULT OK")
# A test is a SQL file that leaves nothing in the base and reports through the marker. Two styles are accepted:
#   - `begin; ... raise notice 'RESULT OK'; ... rollback;`
#   - a block that ends with `raise exception 'RESULT OK : ...'` on purpose (this style also works when the
#     whole file is sent as ONE request to a remote base, see supabase-sql-check-remote.yml).
# What counts is the marker in the output, not the exit status: a failing test prints "RESULT FAILED" (or a real
# SQL error) instead.
set -euo pipefail
url="${1:?usage: run.sh <database-url>}"
here="$(cd "$(dirname "$0")" && pwd)"
dir="${SUPABASE_DIR:-supabase}"
marker="${RESULT_MARKER:-RESULT OK}"
psql_() { psql "$url" -v ON_ERROR_STOP=1 -q "$@"; }

[ "${STUB:-0}" = 1 ] && psql_ -f "$here/local_stub.sql"
for f in "$dir"/migrations/*.sql; do
  echo "== migration $(basename "$f")"
  psql_ -f "$f"
done
for f in "$dir"/tests/*.test.sql; do
  echo "== test $(basename "$f")"
  out=$(psql_ -f "$f" 2>&1 || true)
  echo "$out" | grep -q "$marker" || { echo "$out"; echo "FAILED: $(basename "$f") did not print \"$marker\""; exit 1; }
done
echo "All SQL tests passed."
