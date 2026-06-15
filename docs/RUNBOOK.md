# Runbook — Operational procedures

Living document. Each procedure is a short, numbered, copy-pasteable checklist. If a step lives
only in someone's head, it isn't finished — write it here.

Procedures marked **(TBD)** are placeholders; they are filled as the relevant roadmap phase lands.

---

## R1 — Local development: first-time setup  (TBD, Phase 1)

**When:** new developer, fresh clone.
**Prereqs:** Docker + docker-compose, `make`.

1. `git clone git@github.com:handlingar/handlingar-theme.git && cd handlingar-theme`
2. (TBD) `make dev`
3. (TBD) Open http://localhost:3000 — Alaveteli should load.
4. (TBD) Open http://localhost:5000 — smtp4dev should show captured outbound mail.

---

## R2 — Local development: reset to clean state  (TBD, Phase 1)

**When:** stuck dev DB, want a fresh start.

1. (TBD) `make dev-reset`
2. Confirm the `setupstate` volume and `pgdata` are gone.
3. Re-run R1 step 2.

---

## R3 — Deploy theme change to prod  (CURRENT — legacy flow)

**When:** a theme change is merged into `main`.
**How it works today:** `.github/workflows/deploy.yaml` runs on push to `main`, SSH's to the prod
server, updates `THEME_BRANCH` in `config/general.yml`, runs `bundle exec rake themes:install
RAILS_ENV=production`.

**Limitations (to fix in Phase 4):**
- No staging step.
- No rollback.
- No smoke test.
- Relies on SSH keys + repo vars `SSH_USER`, `SSH_HOST`, `SSH_ALAVETELI_INSTALL_PATH`.

If this fails, check GH Actions logs first. If the server is wedged, see R8.

---

## R4 — Deploy via full pipeline (tst → prod)  (TBD, Phase 4)

---

## R5 — Rollback to previous release  (TBD, Phase 4)

---

## R6 — Upgrade Alaveteli to a new upstream tag  (TBD, Phase 7)

---

## R7 — Rotate a secret  (TBD, Phase 3)

---

## R8 — Production incident: triage the box  (TBD, Phase 0 will seed this)

**When:** site is down or degraded.
**Principle:** observe before touching. Never restart services reflexively.

1. Check https://handlingar.se — HTTPS ok?
2. (TBD, Phase 6) Open Grafana → "Overview" dashboard → identify red panels.
3. SSH to prod as `alaveteli` user (never root unless you know why).
4. `sudo systemctl status apache2 sidekiq postgresql postfix dovecot redis memcached`
5. Tail the relevant log. For the app: `/var/log/apache2/error.log`, sidekiq log path (TBD).
6. If you change anything, record it in the next session's ROADMAP handoff and open a task to
   capture the root cause.

---

## R9 — Refresh tst from anonymised prod snapshot  (TBD, Phase 5)

---

## R10 — Backup verification drill  (TBD, Phase 2/5)

**When:** quarterly.
**Principle:** an untested backup is not a backup.

1. (TBD) Pull latest encrypted backup from Hetzner Object Storage.
2. (TBD) Restore into a throwaway Hetzner box provisioned from `tst` IaC.
3. (TBD) Run smoke test.
4. Record drill date + result in `docs/INVENTORY.md` → "Backup drills".

---

## R10 — Dev cluster: mock mail, mock data, search index  (LIVE, since 2026-06-11)

The dev cluster (https://dev.nonprod.handlingar.se) has a fully mocked email loop and
seedable test data. Everything is a `make` target; all of it is reproduced by `make bringup`
(manifests in `infra/k8s/base/`, scripts in `scripts/mock-data/`).

| What | Command | Notes |
| --- | --- | --- |
| See all caught email (web UI) | `make mail-ui` → http://localhost:8025 | Mailpit catches **all** outgoing app mail (SMTP `mailpit:1025` via `SMTP_URL` in the ConfigMap). Port-forward; Ctrl-C to stop. |
| Feed replies INTO Alaveteli | `make mail-ingest` | Pulls every message from Mailpit's API and pipes it into `script/mailin`. Replies to a request's exact incoming address attach to that request; everything else lands in the admin holding pen. |
| Seed mock authorities + test user | `make mock-data` | Idempotent. 5 fake Swedish authorities (request emails route to Mailpit) + `testuser@…` account. |
| File a mock FOI request | `make mock-request` | Real controller code path → request appears on the site, outgoing email lands in Mailpit. |
| Simulate an authority reply | `make mock-reply [REQ=<id>]` | Delivers an authority answer **into Mailpit over SMTP** (To = the request's `incoming_email`). Defaults to the most recent request. |
| Sync replies via **POP3** | `make mail-poll` | The real incoming path: Alaveteli's native `AlaveteliMailPoller` fetches from Mailpit's POP3 (`:1110`), routes each message via `RequestMailer.receive(_, :poller)`, and deletes it. One pass drains the mailbox. |

**Full POP3 reply loop:** `make mock-request` → `make mock-reply` → `make mail-poll` → the reply
appears on the request page (a `response` event). **Gotcha:** poller-sourced mail is gated behind
Alaveteli's `accept_mail_from_anywhere` feature (`InfoRequest#receive_mail_from_source?`); without
it the poller silently drops everything. `make mock-data` enables it, so a fresh `bringup` works
out of the box. (`make mail-ingest`, source `:mailin`, is unaffected.) Dev caveat: Mailpit is both
the outgoing catcher and the POP3 source, so a poll also sweeps the original outgoing email to the
admin holding pen — harmless, and invisible on the request page.

Search/list pages need the **Xapian index**: built automatically at web-pod boot when missing,
then incrementally updated every 60s by a background loop in the web container (new
authorities/requests become searchable within ~1 min). The index is ephemeral (rebuilt per
pod) — fine at dev data volumes; revisit with a PVC if data grows.

Troubleshooting: `kubectl -n handlingar logs deploy/alaveteli-web | grep '\[boot\]'` shows the
boot chain (migrate → theme → xapian); Mailpit API: `curl localhost:8025/api/v1/messages`
(while `make mail-ui` runs).

## R11 — Tear down / rebuild the dev cluster  (LIVE, since 2026-06-15)

The dev cluster is disposable and **billing-bearing** (~€20/mo nodes + ~€5.4/mo LB). Tear it
down when idle; rebuild from zero in one command.

| Action | Command | Notes |
| --- | --- | --- |
| List everything this stack deploys | `make resources` (alias `make cloud-audit`) | Standardized TYPE/NAME/ID/DETAIL table, **registry-driven** (`infra/resources.tsv`). Read-only. Foreign resources (incl. the prod server) are never listed. |
| Tear down (stops billing) | `make cluster-down` | Deletes the cluster, then **self-heals**: loops `volumes-clean` + `orphans-clean` and re-runs the audit until it confirms **zero** resources remain (handles async volume-detach / LB+DNS deletion). Fails loudly if anything still bills — a teardown can never finish "clean" with a resource alive. |
| Bring back up from zero | `make bringup` | Full cluster + image build/import + app + ingress. ~15–17 min cold (proven 2026-06-15). Idempotent. |
| Re-seed dev data + mail loop | `make mock-data` then the R10 loop | Fresh DB after a rebuild. `mock-data` also re-enables the `accept_mail_from_anywhere` feature so POP3 sync works. |

**Why teardown leaves orphans without this**: `hetzner-k3s delete` only removes what it created.
The cloud-controller-manager's Load Balancer and external-dns's Cloudflare records are created
from *inside* the cluster and outlive it. `orphans-clean` (folded into `cluster-down`) reaps them;
`cloud-audit --assert-empty` is the hard gate that proves it. To manage a new resource type, add a
line to `infra/resources.tsv`.

## Smoke test checklist

Used by several runbooks above. Minimum bar for "it works":

- [ ] https://<env>.handlingar.se loads in <3s.
- [ ] Static assets (logo, css) load (no 404s).
- [ ] Swedish locale is applied (page is in Swedish).
- [ ] Log in with a seeded test account.
- [ ] Submit a sample FOI request — redirect, no 500.
- [ ] Sidekiq picks up a job within 10s (verify via dashboard or log).
- [ ] Outbound mail arrives (smtp4dev in local, actual mailbox elsewhere).
- [ ] Incoming mail from a reply lands on a request (prod/tst only; not testable locally without fixtures).
