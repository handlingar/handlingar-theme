# Inventory — production server

Filled during Phase 0. Each section is a template; replace `<fill>` placeholders with observed
facts. **Do not guess.** Only record what was verified on the live box. Where a value is sensitive
(secrets), note `see secrets/prod.enc.yaml → <key>` instead of writing the value here.

> Last verified: _partial — 2026-06-15, Host section only, via Hetzner Cloud **API discovery**
> (not on-box) during the P2-T8 session. Everything else awaits Phase 0._

---

## A. Host

| Field | Value |
| --- | --- |
| Provider | Hetzner **Cloud** — **same project + API token as the dev cluster** (see § L) |
| Instance type | `<fill>` (~8 GB RAM per server name; confirm exact type on-box) |
| Region / DC | `hel1` (Helsinki) |
| OS | Debian (per server name; confirm `cat /etc/os-release` on-box) |
| Kernel | `<fill>` (`uname -r`) |
| CPU / RAM / Disk | `<fill>` |
| Public IPv4 / IPv6 | `<fill>` (verify the IP↔server assignment on-box before recording) |
| Floating IP? | `<fill>` |
| Hostname | `handlingar-prod-debian-8gb-hel1-1` (Hetzner server name) |
| Timezone | `<fill>` |
| Created (approx) | `<fill>` |

## B. Network / DNS / TLS

| Field | Value |
| --- | --- |
| DNS provider | `<fill>` |
| Records for `handlingar.se` | `<fill>` (A, AAAA, MX, SPF, DKIM, DMARC) |
| TLS source | `<fill>` (Let's Encrypt? certbot? acme.sh?) |
| Cert renewal mechanism | `<fill>` (systemd timer? cron?) |
| Cert expiry | `<fill>` |
| Firewall (Hetzner Cloud) | `<fill>` (ports exposed) |
| Host firewall (ufw/nftables/iptables) | `<fill>` |
| crowdsec scenarios enabled | `<fill>` |

## C. apache2

| Field | Value |
| --- | --- |
| Version | `<fill>` |
| vhost(s) | `<fill>` (paths to `.conf` files) |
| Passenger version | `<fill>` |
| Passenger ruby | `<fill>` (absolute path to rbenv shim) |
| Loaded modules of interest | `<fill>` (ssl, passenger, rewrite, headers) |

## D. Ruby / Rails / Alaveteli

| Field | Value |
| --- | --- |
| rbenv version | `<fill>` |
| Ruby version | `<fill>` (should be 3.2.x for current Alaveteli) |
| Bundler version | `<fill>` |
| Alaveteli install path | `<fill>` (workflow uses `${{ vars.SSH_ALAVETELI_INSTALL_PATH }}`) |
| Alaveteli git SHA / tag | `<fill>` |
| Alaveteli branch currently checked out | `<fill>` |
| THEME_URLS in general.yml | `<fill>` |
| THEME_BRANCH in general.yml | `<fill>` |
| general.yml notable non-default keys | `<fill>` (list diffs vs. `general.yml-example`) |
| Sidekiq systemd unit | `<fill>` (unit file path) |
| Sidekiq concurrency / queues | `<fill>` |

## E. PostgreSQL

| Field | Value |
| --- | --- |
| Version | `<fill>` |
| Data directory | `<fill>` |
| Database(s) | `<fill>` (name, owner, size) |
| Max schema_migrations version | `<fill>` |
| Extensions installed | `<fill>` |
| Auth config (pg_hba) notable entries | `<fill>` |
| Backup mechanism | `<fill>` (pg_dump cron? wal-g? none?) |
| Backup destination | `<fill>` |
| Last verified restore | `<fill>` (date + outcome) |

## F. Mail (postfix + dovecot)

| Field | Value |
| --- | --- |
| postfix version | `<fill>` |
| postfix role(s) | `<fill>` (inbound only? outbound only? both?) |
| virtual alias maps | `<fill>` (paths, record pattern, NOT contents if sensitive) |
| transport maps / pipe to Alaveteli | `<fill>` |
| dovecot version | `<fill>` |
| Maildir location for Alaveteli inbound | `<fill>` |
| MX records pointing here | `<fill>` |
| DKIM signing? | `<fill>` |

## G. Redis / memcached

| Field | Value |
| --- | --- |
| Redis version | `<fill>` |
| Redis maxmemory / policy | `<fill>` |
| memcached version | `<fill>` |
| memcached memory cap | `<fill>` |

## H. Cronjobs for `alaveteli` user

| Schedule | Command | Purpose |
| --- | --- | --- |
| `<fill>` | `<fill>` | `<fill>` |

(Cover xapian rebuilds, alert mails, daily digests, etc.)

## I. systemd units we maintain

| Unit | Purpose | Enabled? |
| --- | --- | --- |
| `<fill>` | `<fill>` | `<fill>` |

## J. Users & SSH access

| User | Role | Key holders |
| --- | --- | --- |
| `root` | — | `<fill>` |
| `alaveteli` | app user | `<fill>` |
| `<fill>` | `<fill>` | `<fill>` |

## K. Packages pinned / held

Anything `apt-mark hold`'d, PPAs, or non-standard repos:

- `<fill>`

## L. Known drift / debt

Running list of things that aren't how we'd build them today, to be addressed through the roadmap.

- **Prod shares one Hetzner Cloud project + API token with the dev cluster** (discovered
  2026-06-15, P2-T8). The dev `HCLOUD_TOKEN` can therefore read/modify/delete prod. Dev tooling
  is hard-scoped to the `handlingar-dev` cluster name + `nonprod` DNS subtree to compensate
  (`scripts/cloud-audit.sh` is driven by `infra/resources.tsv` and never lists prod), but the
  durable fix is to split dev/tst into a separate Hetzner project with its own token before the
  prod migration. See `docs/assumptions.md` (2026-06-15).
- `<fill>`

## M. Runtime patches injected via this theme

Alaveteli's theme mechanism lets the theme load Ruby files into the running Rails process. This
repo's `lib/` contains such patches (not pure view overrides). Record which upstream classes /
modules each patch affects, to inform upgrade-risk assessment.

| Patch file | Upstream target(s) | What it changes | Version-sensitive? |
| --- | --- | --- | --- |
| `lib/model_patches.rb` | `<fill>` | `<fill>` | `<fill>` |
| `lib/controller_patches.rb` | `<fill>` | `<fill>` | `<fill>` |
| `lib/patch_mailer_paths.rb` | `<fill>` | `<fill>` | `<fill>` |
| `lib/customstates.rb` | `<fill>` | `<fill>` | `<fill>` |
| `lib/config/custom-routes.rb` | `<fill>` | `<fill>` | `<fill>` |
| `lib/config/user_spam_scorer.rb` | `<fill>` | `<fill>` | `<fill>` |
| `initializers/debug.rb` | `<fill>` | `<fill>` | `<fill>` |

## N. Backup drills

| Date | Drill type | Outcome | Notes |
| --- | --- | --- | --- |
| `<fill>` | `<fill>` | `<fill>` | `<fill>` |

---

## Collection method (for reproducibility)

Phase 0 tasks fill this document by running a read-only inventory script (designed in P0-T10
with built-in secret masking) against prod. The script must never mutate state. A developer
reviews its output before pasting values here. Do not run any inventory tooling against prod
without per-session explicit approval from the maintainer.
