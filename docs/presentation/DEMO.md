# Demo runbook — presentation weekend

Companion to [PRESENTATION.md](PRESENTATION.md). Exact commands, expected
outcomes, timings, and fallbacks. Audience is non-technical: keep the terminal
font **large**, run one command at a time, and narrate what each one means
*before* pressing enter.

Everything here uses only existing `make` targets — nothing new to install
beyond what `make preflight` already manages.

---

## The demo's dramatic structure

The centrepiece trick: **start the full rebuild live at minute 0 of the
presentation**, do the slides while it builds (~17 min measured), and return
to a freshly built, live-on-the-internet platform for the demo (~minute 22).
The build happening *during* the talk **is** the proof of the talk's thesis.

If you'd rather not risk it, use Fallback A (pre-built cluster) and show the
timestamped log of a rehearsal bringup instead.

---

## Prep — the day before (do all of this)

1. **Full dress rehearsal, timed.** This validates the exact path the audience
   will see and gives you a log/screenshot for Fallback B:

   ```bash
   make cluster-down          # start from true zero (also proves the audit gate)
   time make bringup 2>&1 | tee /tmp/bringup-rehearsal.log
   make mock-data
   make mock-request          # note the request URL it prints
   make mock-reply            # no REQ= → answers the most recent request
   make mail-poll
   ```

   Then verify in a browser: https://dev.nonprod.handlingar.se loads with a
   valid padlock, the request page shows the authority's reply.

2. **Decide: live bringup or pre-built?**
   - Rehearsal ≤ ~20 min and clean → do the live bringup (Act 0).
   - Anything flaky → leave the rehearsal cluster **up** overnight (≈ €0.70/day,
     hourly-billed) and demo on it (Fallback A).

3. **Capture fallback evidence** (do this even if rehearsal is perfect):
   - Screenshot: the site frontpage with the padlock/cert visible.
   - Screenshot: a request page showing the published authority reply.
   - Screenshot: Mailpit inbox with the request + reply emails.
   - Keep `/tmp/bringup-rehearsal.log` (copy it somewhere safe) — the
     timestamps are your "17 minutes" receipt.

4. **Tokens present:** `make preflight` passes (Hetzner + Cloudflare tokens in
   `.local/.env`).

5. **Render the slides:**
   `npx @marp-team/marp-cli docs/presentation/PRESENTATION.md -o /tmp/slides.pdf`
   (or present from the VS Code Marp extension).

## Prep — one hour before

- Venue network check: can you reach https://dev.nonprod.handlingar.se (if
  using Fallback A) and the Hetzner API? Conference/guest wifi sometimes
  blocks odd ports — the demo needs plain HTTPS + SSH (image import).
  **If the venue network is doubtful, use your phone's hotspot.**
- Two terminal windows, font ≥ 18pt: **T1** for the main flow, **T2** for
  port-forwards (`make mail-ui`) which block.
- Browser with two pinned tabs ready: the site, and http://localhost:8025
  (Mailpit — will work once `make mail-ui` runs).
- Close notifications / other windows. `make preflight` once more.

---

## Act 0 — minute 0 of the *presentation* (before slide 2)

**First, prove you're starting from nothing.** In T1, on stage:

```bash
make resources
```

It prints an **empty table — zero resources**. Say: *"This is our cloud
account right now: nothing. No servers, no database, no website. Remember
this table — you'll see it twice more."* (The audience doesn't need to
understand Kubernetes to understand an empty list.)

Then type and narrate:

```bash
make bringup
```

Say: *"That's the whole platform — servers, database, website, certificates —
being built from nothing, right now. We'll come back to it."* Then present the
slides. Glance at T1 occasionally; narrate milestones if natural ("servers are
up", "website is starting").

**Known cosmetic wobble:** the web app restarts ~3× during first boot while
the database is prepared — it self-heals. If someone sees red text, that's
your line: *"and it repairs itself — that's the design."*

---

## Act 1 — "It's live on the internet" (~2 min)

```bash
make status
make ingress-status
```

Narrate: nodes = the servers, pods = the running pieces, plus the billing
reminder (segue to cost honesty). `ingress-status` shows the public address,
certificate state, and DNS.

Then in the browser: **https://dev.nonprod.handlingar.se** — click the padlock,
show the real certificate. *"This website did not exist 20 minutes ago."*

## Act 2 — "We can see everything we're paying for" (~2 min)

```bash
make resources
```

**The same table that was empty at minute 0** now lists every piece of the
platform — servers, load balancer, storage, internet addresses — **with each
one's real monthly price and a total**, fetched live from the provider. Read
a few rows aloud in plain words: *"Three computers, a traffic distributor,
a database disk for fifty-seven cents a month, the internet addresses are
free. That's the whole platform, and there's the total — about twenty-one
euros a month, billed by the hour, so roughly seventy cents a day while
it exists. This list literally is our bill. And when we tear down at the end, this same
audit refuses to say 'done' if even one of these is still alive and
costing money."*

This before/after/empty-again arc of one table is the non-technical
audience's thread through the whole demo.

## Act 3 — Seed a realistic Sweden (~2 min)

```bash
make mock-data
```

Browser: `/body/list/all` on the site — five (fake) Swedish authorities.
Point out search works too (the index is built automatically at boot).

## Act 4 — File a real FOI request (~3 min)

```bash
make mock-request
```

Open the request URL it prints — the request is live on the public site.
Then show where the email went — the safe inbox. In **T2**:

```bash
make mail-ui        # leaves a port-forward running
```

Browser tab 2: http://localhost:8025 — there's the outgoing email to the
authority. *"In this environment no email can ever reach a real authority —
it's all caught here. We test the real machinery with zero risk."*

## Act 5 — The authority replies, and it publishes (~3 min)

```bash
make mock-reply     # the "authority" answers the latest request (REQ=<id> to target one)
make mail-poll      # the platform pulls incoming mail, exactly like production will
```

Refresh the request page: **the authority's answer is now published** on the
public site. *"That's the entire life of an FOI request — question out, answer
in, published for everyone — rehearsed end-to-end on a copy that appeared
during this presentation."*

This is the demo's peak. Pause here.

## Act 6 — Finale: tear it all down (optional, ~2 min)

Only if you don't need the site for Q&A (you have screenshots regardless):

```bash
make cluster-down
```

~30 seconds to destroy, and the teardown ends by printing **the same
resource table from minute 0 — empty again**, the audit refusing to finish
until it truly is. *"Empty list, empty bill. And when we need it again —
one command, 17 minutes. That's the whole point: this isn't a precious
server anymore. It's a recipe."*

---

## Fallbacks

- **A — bringup not finished / venue network flaky:** demo on the pre-built
  rehearsal cluster (that's why you left it up). Show the rehearsal log's
  timestamps for the 17-minute claim: `grep -iE 'ready|done|real' /tmp/bringup-rehearsal.log`.
- **B — cluster problem mid-demo:** switch to the prepared screenshots and
  narrate the flow. Do **not** debug live; say *"I'll show you the rehearsal
  run"* and move on.
- **C — Mailpit port-forward dies:** rerun `make mail-ui` in T2; it's
  idempotent. If the projector fights you, the reply on the public request
  page (Act 5) carries the story on its own — Mailpit is garnish.
- **D — `mock-reply`/`mail-poll` hiccup:** `make mail-ingest` is the
  alternative ingestion path; the reply still publishes.

## Rules of the stage

- Never type a command not in this script (especially near DNS/infra —
  project rule: pre-specified changes only).
- Nothing here touches production; the tooling is structurally blind to it.
  If asked to "show prod" — decline, that's the invariant working.
- If anything unexpected appears in a terminal, read it calmly *once*,
  then use the fallback. The audience remembers composure, not the glitch.
