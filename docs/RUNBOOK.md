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
