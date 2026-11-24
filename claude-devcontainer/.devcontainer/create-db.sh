#!/bin/bash
# Runs inside the dev container at every start: creates its own database when it is missing.
set -euo pipefail
exists=$(psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE'")
if [ "$exists" = 1 ]; then
  echo "create-db: $PGDATABASE exists"
else
  createdb "$PGDATABASE"
  echo "create-db: created $PGDATABASE"
fi
