#!/bin/bash
# Features as git worktrees, each with a dev container and a Claude executor in it.
# Run from the main checkout on the host.
#   feature.sh new <name>             worktree ../<repo>-<name> on branch <name>, its dev container up
#   feature.sh ask <name> <message>   message the executor: the first starts its session, later ones resume it
#   feature.sh stop <name>            its dev container down, its worktree removed; branch and database kept
#   feature.sh list                   the features and their session ids
set -euo pipefail

main=$(git rev-parse --show-toplevel)
repo=$(basename "$main")
state="$(git rev-parse --git-common-dir)/delegate"
mkdir -p "$state"
dc=(npx -y @devcontainers/cli)

# Runs a command quietly; on failure, prints what it said.
quiet() {
  local log
  log=$("$@" 2>&1) || { echo "$log" >&2; return 1; }
}

# The executor's standing orders; the orchestrator reads the last line of every reply.
read -r -d '' ORDERS <<'ORDERS' || true
You are an executor: an orchestrator Claude on the host hands you tasks for this one feature,
and no human reads your replies. Work in this folder and in the database PGDATABASE names.
Leave version control to the orchestrator: git does not work in this container. Finish every
reply with exactly one last line: `DONE: <what you did, in one line>` once the task is complete,
or `QUESTION: <the decision you need>` when you cannot go on without one. After a QUESTION,
stop; the answer comes as your next message.
ORDERS

name=${2:-}
tree="$(dirname "$main")/$repo-$name"

case ${1:-} in
  new)
    [ -n "$name" ] || { echo "usage: feature.sh new <name>" >&2; exit 2; }
    quiet docker compose -f "$main/.devcontainer/postgres.yaml" up -d --wait
    quiet git -C "$main" worktree add "$tree" -b "$name"
    quiet "${dc[@]}" up --workspace-folder "$tree"
    echo "$name: $tree, database $("${dc[@]}" exec --workspace-folder "$tree" printenv PGDATABASE 2>/dev/null)"
    ;;
  ask)
    [ -n "$name" ] && [ -n "${3:-}" ] || { echo "usage: feature.sh ask <name> <message>" >&2; exit 2; }
    session=()
    [ -f "$state/$name" ] && session=(--resume "$(cat "$state/$name")")
    out=$("${dc[@]}" exec --workspace-folder "$tree" claude -p "$3" ${session[@]+"${session[@]}"} \
      --append-system-prompt "$ORDERS" --dangerously-skip-permissions --output-format json 2>/dev/null)
    echo "$out" | jq -r .session_id > "$state/$name"
    echo "$out" | jq -r .result
    ;;
  stop)
    [ -n "$name" ] || { echo "usage: feature.sh stop <name>" >&2; exit 2; }
    if [ -n "$(git -C "$tree" status --porcelain)" ]; then
      echo "$name: uncommitted changes in $tree; commit them first" >&2; exit 1
    fi
    quiet docker compose -p "$repo-${name}_devcontainer" down
    git -C "$main" worktree remove "$tree"
    rm -f "$state/$name"
    echo "$name: stopped; branch $name and its database kept"
    ;;
  list)
    for f in "$state"/*; do [ -f "$f" ] && echo "$(basename "$f") $(cat "$f")"; done
    git -C "$main" worktree list
    ;;
  *)
    sed -n '2,8p' "$0" >&2; exit 2
    ;;
esac
