# Claude Code in dev containers, a feature at a time

The code for the article "Dev containers for Claude Code, step by step". It runs Claude Code in a
dev container, with one Postgres container that the dev container of every feature (every git
worktree) shares, a database per dev container in it, and a `delegate` skill that lets the Claude
on your laptop hand features to the Claudes inside.

Copy this folder's contents (`.devcontainer/`, `.claude/` and this README if you like) into the
root of your own repository. `feature.sh` finds the repository with `git rev-parse
--show-toplevel`, so it works from a repository root, not from a subfolder like this one.

```sh
docker compose -f .devcontainer/postgres.yaml up -d        # once; Docker keeps it running
npx -y @devcontainers/cli up --workspace-folder .           # or VS Code: Reopen in Container
npx -y @devcontainers/cli exec --workspace-folder . psql -c 'SELECT current_database()'
```

- `.devcontainer/postgres.yaml` is the shared Postgres: a fixed project name
  (`shared-postgres`), so it is the same container whichever worktree starts it,
  `restart: unless-stopped`, and a network with a fixed name, `shared-postgres`.
- `.devcontainer/compose.yaml` is the dev container alone; it joins that network and reaches
  the database as `postgres`. No port is published on the host.
- `postStartCommand` runs `.devcontainer/create-db.sh`, which creates `app_<devcontainerId>`
  when it is missing; `PGDATABASE` names it, so `psql` connects there with no arguments.

Claude Code is in the image. Sign in once, in any feature's dev container: run `claude`, copy
the URL it shows into a browser on the host and paste the code back. The sign-in lives in the
volume `claude-config`, which every feature's dev container mounts, so all of them are signed
in from then on, across rebuilds. Then `claude` in a feature's container works on that
feature's files and database; `claude --dangerously-skip-permissions` runs too, as `vscode`.

To have Claude build features for you, ask the Claude on the host to use the `delegate`
skill (`.claude/skills/delegate/`): it starts each feature as a worktree with its own dev
container, hands the Claude inside it tasks, answers its questions, reviews and commits on the
host, and stops it again.

A second feature by hand:

```sh
git worktree add ../<your-repo>-b -b b
npx -y @devcontainers/cli up --workspace-folder ../<your-repo>-b
```

Give every copy its own folder name: the dev container's Compose project is named after the
folder, so two copies with the same folder name share one dev container.

Stop a feature's dev container with `docker compose -p <folder>_devcontainer down`. Stop the
Postgres with `docker compose -f .devcontainer/postgres.yaml down`; add `-v` to delete every
database.

## What it does not do

- No egress firewall: Claude inside can reach any host. Anthropic's reference dev container
  has one to start from: https://code.claude.com/docs/en/devcontainer
- Every dev container connects as the Postgres superuser, so one feature can read another
  feature's database. Hand each executor only its own feature.
- Every executor is a Claude session of its own, so two cost about twice as much as one.
