#!/usr/bin/env bash
# Applies every migration in supabase/migrations/ to a scratch Postgres
# database, then runs the RLS negative tests in supabase/tests/. Requires a
# local Postgres server the current user can connect to (peer/trust auth is
# fine for local development).
#
# Usage: scripts/db_test.sh [postgres-connection-args...]
# Example: scripts/db_test.sh -h localhost -U postgres

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_NAME="receiptvault_test_$$"
PSQL=(psql -v ON_ERROR_STOP=1 "$@")

cleanup() {
  "${PSQL[@]}" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Creating scratch database $DB_NAME"
"${PSQL[@]}" -d postgres -c "CREATE DATABASE \"$DB_NAME\";"

echo "==> Applying local Postgres stub (auth/storage schemas)"
"${PSQL[@]}" -d "$DB_NAME" -f "$SCRIPT_DIR/local_pg_stub.sql"

echo "==> Applying migrations"
for migration in "$REPO_ROOT"/supabase/migrations/*.sql; do
  echo "    - $(basename "$migration")"
  "${PSQL[@]}" -d "$DB_NAME" -f "$migration"
done

echo "==> Running RLS tests"
for test_file in "$REPO_ROOT"/supabase/tests/*.sql; do
  echo "    - $(basename "$test_file")"
  "${PSQL[@]}" -d "$DB_NAME" -f "$test_file"
done

echo "==> All migrations applied and all tests passed against $DB_NAME"
