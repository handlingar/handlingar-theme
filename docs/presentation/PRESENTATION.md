---
marp: true
paginate: true
theme: default
---

<!--
30–45 min presentation for a NON-TECHNICAL audience about the new
handlingar.se platform setup, followed by / interleaved with a live demo.

How to use this file:
- It reads as a normal document top-to-bottom.
- It is also a Marp deck: `npx @marp-team/marp-cli PRESENTATION.md -o slides.pdf`
  (or present straight from the VS Code Marp extension). Each `---` is a slide.
- Speaker notes are in HTML comments like this one — visible in presenter view,
  invisible on the slides.
- The paired demo script with exact commands and fallbacks is in DEMO.md.

Suggested timing (40 min total):
  min 0–2    Slide 1–2, and START `make bringup` LIVE on stage (see DEMO.md, act 0)
  min 2–12   Slides: what handlingar.se is, the problem we had
  min 12–22  Slides: what we built, the five capabilities
  min 22–35  DEMO (the cluster you started at min 0 is now live)
  min 35–40  What this unlocks next + questions
-->

# handlingar.se
## A platform you can rebuild from scratch in 17 minutes

<!--
Opening move (demo act 0): show `make resources` — an EMPTY table. "This is
our cloud account: nothing." Then run `make bringup`: "That command is now
building an entire copy of our platform from nothing: servers, database,
website, certificates, everything. It will be done before the demo. Let me
explain why that's a big deal." The empty table returns twice: full (act 2)
and empty again (finale) — it's the non-technical thread through the talk.
-->

---

## What is handlingar.se?

- A public website where **anyone in Sweden can send a freedom-of-information
  request** (begäran om allmän handling) to a public authority
- Requests **and the authorities' answers are published openly**, so one
  person's question becomes everyone's answer
- Built on **Alaveteli** — proven open-source software running FOI sites in
  30+ countries (e.g. WhatDoTheyKnow in the UK)
- We maintain the **Swedish adaptation**: language, branding, and everything
  needed to run it as a reliable public service

<!--
Keep this short if the audience already knows the site. The key setup for the
rest of the talk: it's a PUBLIC SERVICE — people depend on it — so how it's
operated matters as much as what it does.
-->

---

## The problem: the platform lived on one hand-built server

- The production site ran on **one server, configured by hand over time**
- Nobody could say exactly what was on it — the knowledge lived **in people's
  heads and in the server itself**
- Testing a change safely was hard: there was **no second copy** to try things on
- If the server was lost — or the person who knew it was unavailable —
  recovery would be **slow, stressful guesswork**

**Analogy:** we had a house, but no blueprints. You can live in it,
but you can't build a second one, and repairs depend on whoever remembers
where the pipes are.

<!--
Don't dwell on blame — frame it as the normal way small projects grow, and
the thing every project must eventually fix to become sustainable.
-->

---

## What we changed, in one sentence

> **The entire platform is now written down as code in one repository —
> and one command turns that code into a running copy of handlingar.se,
> from nothing, in about 17 minutes.**

- Servers, database, website, email handling, security certificates, DNS —
  all of it is **described in text files**, reviewed and versioned like any document
- The repository is the **blueprint**; the cloud is just where we choose to
  build from it
- This approach is called *Infrastructure as Code* — the industry standard
  for running services you can trust

<!--
This is the thesis slide. Everything after is evidence.
17 minutes: measured on 2026-06-15, full from-zero rebuild, zero manual steps.
-->

---

## Capability 1 — Rebuild everything with one command

```
make bringup
```

- From **zero to a live, working website** — real address, real encryption
  (the padlock in the browser), Swedish branding, search, email — **no manual steps**
- Measured: **17 minutes**, cold start
- Every step is **self-fixing**: if a prerequisite is missing, the tooling
  installs or repairs it and continues

**Why it matters:** disaster recovery stops being a crisis plan and becomes
a coffee break.

<!--
This is the command you ran at minute 0. Callback: "This is what's running in
the background right now."
-->

---

## Capability 2 — Tear it down just as easily (and stop paying)

```
make cluster-down
```

- Destroys the whole test environment in **seconds** — and **stops the bill**
- The test environment costs about **€0.70 per day while it exists** (billed
  by the hour, ≈ €21/month if left running) — so we simply don't keep it
  when we're not using it
- A built-in **audit proves nothing was left behind**: the teardown fails
  loudly if any paid resource survives, instead of quietly billing us

**Why it matters:** we get a full-scale test environment *on demand*
for a few euros, instead of paying for idle servers year-round.

<!--
The audit (cloud-audit-assert) came out of a real incident: an early teardown
silently left a load balancer billing. Now that's structurally impossible to
miss. Good honest anecdote if asked.
-->

---

## Capability 3 — No commands to memorize, no single point of failure

```
make
```

- Typing just `make` lists **every operation with a plain description** —
  deploy, status, rebuild, teardown, test data, email tools
- **Any contributor on their own computer** gets an identical result:
  no hardcoded paths, no personal setup, no "it only works on my machine"
- The only manual step, ever: paste **one access token** the first time
  (secrets are deliberately *never* stored in the repository)

**Why it matters:** the platform no longer depends on any one person's
memory or laptop.

<!--
This is the continuity/bus-factor slide — for a non-technical audience this
is often the one that lands hardest. The design rule is recorded as a formal
decision (ADR 0005): any colleague reproduces identically.
-->

---

## Capability 4 — A safe place to try everything, even email

The test environment is a **complete, realistic copy** — with training wheels:

- **Fake Swedish authorities** and a test user, seeded with one command
- File a **real FOI request** through the real code path
- All outgoing email is **caught in a safe inbox** — nothing can ever reach
  a real authority by accident
- We can even **play the authority**: send a reply, and watch it arrive and
  publish on the request page — the **full round-trip** of the service

**Why it matters:** we can rehearse the entire user journey — including
mistakes — with zero risk to the public site.

<!--
This is the heart of the demo. The mail loop uses Alaveteli's REAL incoming-
mail machinery (POP3 polling), not a shortcut — so what we test is what
production will do.
-->

---

## Capability 5 — Guardrails that make mistakes hard

- The tooling is **provably blind to production**: it works from an explicit
  registry of *our* test resources — anything not on the list is never touched
- DNS (the internet address book) automation is **locked to the test
  subdomain** — it *cannot* modify the live site's records
- A **quality gate** runs every session: checks for leaked secrets, personal
  data, and drift from our recorded architecture decisions
- Every significant choice is written down as a **decision record** — future
  contributors see not just *what*, but *why*

**Why it matters:** safety comes from the system's design,
not from people being careful.

<!--
If asked "what if the command is run wrong?": the guardrails are structural —
e.g. external-dns has a domain filter + ownership registry; the cloud audit is
allowlist-driven. Being careless is recoverable.
-->

---

## Demo

**One table tells the story — you saw it empty at minute 0:**

1. The environment that was built *during this presentation* — live on the
   internet, with a real security certificate
2. That same table again: **every piece we're running and paying for**
3. Seed test authorities → **file an FOI request** on the site
4. Watch the request's email arrive in the **safe inbox**
5. **Reply as the authority** → the answer appears publicly on the site
6. (Finale) tear it all down — **the table is empty again, the bill stops**

<!--
Switch to DEMO.md acts 1–6 here. Keep the terminal font LARGE.
If the live bringup from minute 0 isn't ready or failed, use the pre-built
fallback cluster — see DEMO.md "Fallbacks".
-->

---

## What this unlocks next

- **A registry for our software images** — cuts rebuild time further and
  removes the last speed bottleneck
- **Production-grade mode** — the same setup, hardened for the real site
- **Automatic deployments** — a reviewed change goes live without manual work
- **A staging environment** — an identical dress rehearsal stage, created
  with the *same* command (that's the point: environments are now cheap)
- **Monitoring dashboards** — see the service's health at a glance

The destination: **the public site itself runs from this blueprint** —
rebuildable, testable, and independent of any single person.

<!--
Map to roadmap: registry = P2-T9, production hardening = P2-T10, overlays =
P2-T11, CI/CD = Phase 4, staging = Phase 5, observability = Phase 6.
Don't promise dates.
-->

---

## The one-slide summary

| Before | Now |
| --- | --- |
| One hand-built server, no blueprint | The whole platform as reviewed code |
| Rebuild = guesswork, days | Rebuild = one command, **17 minutes** |
| Testing risked the live site | Full safe copy, on demand, ~€20/mo only while used |
| Knowledge in heads | Knowledge in the repository, self-documenting |
| Depends on specific people | Any contributor, any machine, identical result |

**Questions?**

<!--
Likely questions & short answers:
- "What did this cost to build?" — developer time plus small test-cluster
  hours; the cluster itself bills hourly, ≈ €0.70/day *only while running*
  (the audit table shows the live per-resource prices).
- "Is the live site on this yet?" — not yet; that migration is the roadmap's
  destination, done deliberately with the same safety rails.
- "What happens if the cloud provider disappears?" — the blueprint is
  provider-thin; the same approach rebuilds elsewhere with modest changes.
- "Who can operate this?" — anyone with the repo + two tokens; `make` lists
  every operation. Designed so a non-technical operator memorizes nothing.
-->
