# handlingar-theme

This repository hosts:

1. The **Swedish theme overlay** for [Alaveteli](https://github.com/mysociety/alaveteli) that
   powers [handlingar.se](https://handlingar.se).
2. The **infrastructure-as-code, deployment pipelines, and operational documentation** for the
   platform itself (in active development — see [docs/ROADMAP.md](docs/ROADMAP.md)).

## First-time setup (any contributor)

```bash
git clone git@github.com:handlingar/handlingar-theme.git
cd handlingar-theme
git config core.hooksPath .githooks   # install pre-push quality gate
bash scripts/quality-gate.sh          # one-shot: verify repo is clean
```

The pre-push gate and the required CI check enforce architectural invariants, privacy, and
secret hygiene. See [docs/WAYS-OF-WORKING.md](docs/WAYS-OF-WORKING.md#quality-gate-automated-drift-detection).

## Quickstart (humans)

| You want to… | Start here |
| --- | --- |
| Understand the current plan & what's being worked on | [docs/ROADMAP.md](docs/ROADMAP.md) |
| Understand the target architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Know how we collaborate (human + Claude Code) | [docs/WAYS-OF-WORKING.md](docs/WAYS-OF-WORKING.md) |
| Run a procedure (deploy, rollback, reset dev) | [docs/RUNBOOK.md](docs/RUNBOOK.md) |
| Understand how production is currently put together | [docs/INVENTORY.md](docs/INVENTORY.md) _(Phase 0, WIP)_ |
| See enforced architectural invariants | [docs/invariants.md](docs/invariants.md) |
| Propose a significant technical change | Write an ADR in [docs/decisions/](docs/decisions/) |

## Quickstart (Claude Code)

The file [CLAUDE.md](CLAUDE.md) at the repo root is the entry brief. Claude reads it
automatically at session start. Start there.

## Local development (current state — being replaced in Phase 1)

> The current `docker-compose` flow is quirky. It works but is not the recommended path yet.
> Phase 1 of the roadmap replaces it with `make dev`. Until then:

```bash
# Prereqs — see local.development.prerequisites.txt
git clone --depth=1 https://github.com/mysociety/alaveteli.git ./alaveteli
git -C ./alaveteli submodule update --init --recursive

docker compose up --build
# Expect ~10–15 min on first run (gem install + DB seed + xapian build)
# App: http://localhost:3000
```

To reset:

```bash
docker compose down
docker volume rm $(docker volume ls -q) -f
sudo rm -rf ./themes
```

Known issues captured in the roadmap. If you hit something new, open an issue or add it to the
roadmap backlog.

## Deployment (current state — being replaced in Phase 4)

A merge to `main` triggers [`.github/workflows/deploy.yaml`](.github/workflows/deploy.yaml),
which SSHes to the production Hetzner server and runs `bundle exec rake themes:install`.
There is currently no staging step and no rollback mechanism; see `docs/ROADMAP.md` → Phase 4.

## Repository layout

See [CLAUDE.md § Repo layout](CLAUDE.md#repo-layout-current).

## Upstream theme lineage

This theme was originally forked from mySociety's
[`alavetelitheme`](https://github.com/mysociety/alavetelitheme) and has been maintained as the
Swedish/Handlingar.se variant since. Upstream Alaveteli itself is **not** forked — we pin a
version and deploy it unchanged.

## License

MIT. See [MIT-LICENSE](MIT-LICENSE).
