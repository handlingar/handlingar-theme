# Handover — Handlingar theme (LIA 2026)

Supervisor: Mattias Axell (`mattias@okfn.se`).
Intern: Mustafa Salahuddin.

This theme is an **Alaveteli overlay**. Run it inside the Alaveteli Docker app
(see the [README](../README.md)). Work lands as pull requests against
**`new-design-system`**. Do not merge to `main` without a supervisor decision.

Design tokens, Stripe/captcha contracts, fonts and icons: [theme-guide.md](theme-guide.md)
(PR #36). Icon licences: [icons.md](icons.md) (PR #25 / #36).

## Demo 4 (week 12)

Show Free + Pro, accessibility, and docs. Use **Swedish first**, then switch
to English on the same screen.

Local app: `http://localhost:3000` (compose from the Alaveteli directory).
First Sass compile after restart can take several minutes.

### Free

1. **Startpage** `/` and `/en` — hero, how-it-works, Pro band. Booklet colours;
   no orange fill on a light background.
2. **Blog teasers** (needs `BLOG_FEED` in Alaveteli `config/general.yml`) —
   plain-text excerpts, no WordPress HTML or “appeared first on”.
3. **Authorities** `/body` — search band, alphabet, category accordion.
   Swedish seed data may show **0 bodies**; that is locale filtering. Use
   English to show rows, Swedish to show copy.
4. **Make a request** `/select_authority` then `/new/…` — design-system form.
5. **Auth** `/profile/sign_in` vs `/profile/sign_up` — separate pages.
   Swedish signup has the terms checkbox. reCAPTCHA v2 still on create-account.
6. **Help** `/help/about` — Swedish copy; English no longer says
   “over 0 registered users”. Sidebar chrome, no WhatDoTheyKnow leftovers.
7. **Mobile** — 390px: translated hamburger, 44px targets.

### Pro

8. **Pricing** `/pro` — Handlingar Pro copy (not WhatDoTheyKnow Professional).
9. **Checkout chrome** — style `form.stripe-form` / `#card-element` only.
   `#card-element` and `js-stripe-subscription-form` must still exist.
   Without Stripe keys, `/pro/plans` 500s — configuration, not a theme bug.
10. **Pro dashboard** (seed user `bob@localhost` / `jonespassword` with
    `add_role(:pro)` and `ENABLE_ALAVETELI_PRO: true` in `general.yml` —
    do not commit that file).

### Accessibility and docs

11. Skip link, visible focus, one `h1` on core journeys.
12. Optional: `npm run axe-smoke` from the theme (live) or the CI fixture job.
13. This file + `docs/theme-guide.md` + `docs/icons.md`.

## Pull requests (base `new-design-system`)

| PR | Concern |
| --- | --- |
| [#22](https://github.com/handlingar/handlingar-theme/pull/22) | Swedish signup terms checkbox |
| [#23](https://github.com/handlingar/handlingar-theme/pull/23) | GET `/profile/sign_up` |
| [#24](https://github.com/handlingar/handlingar-theme/pull/24) | Self-hosted Source Sans 3 |
| [#25](https://github.com/handlingar/handlingar-theme/pull/25) | Iconoir / Simple Icons, no Material Symbols CDN |
| [#26](https://github.com/handlingar/handlingar-theme/pull/26) | Frontpage Swedish copy and section order |
| [#27](https://github.com/handlingar/handlingar-theme/pull/27) | Authorities search (booklet 3.3) |
| [#28](https://github.com/handlingar/handlingar-theme/pull/28) | Make-a-request flow |
| [#29](https://github.com/handlingar/handlingar-theme/pull/29) | Handlingar Pro copy |
| [#30](https://github.com/handlingar/handlingar-theme/pull/30) | Stripe checkout chrome only |
| [#31](https://github.com/handlingar/handlingar-theme/pull/31) | reCAPTCHA v2 default; Friendly Captcha behind env |
| [#32](https://github.com/handlingar/handlingar-theme/pull/32) | Translated CSS hamburger |
| [#33](https://github.com/handlingar/handlingar-theme/pull/33) | Recolored unDraw scenes |
| [#34](https://github.com/handlingar/handlingar-theme/pull/34) | Help chrome; WDTK leftovers |
| [#35](https://github.com/handlingar/handlingar-theme/pull/35) | WCAG 2.1 AA core journeys |
| [#36](https://github.com/handlingar/handlingar-theme/pull/36) | Theme guide + icon licence notes |
| [#37](https://github.com/handlingar/handlingar-theme/pull/37) | Pro dashboard chrome |
| [#38](https://github.com/handlingar/handlingar-theme/pull/38) | `/learn` |
| [#39](https://github.com/handlingar/handlingar-theme/pull/39) | Category accordion on `/body` |
| [#40](https://github.com/handlingar/handlingar-theme/pull/40) | axe-core smoke |
| [#41](https://github.com/handlingar/handlingar-theme/pull/41) | Overlay contract specs |
| [#42](https://github.com/handlingar/handlingar-theme/pull/42) | Blog teaser HTML (#4) |
| [#43](https://github.com/handlingar/handlingar-theme/pull/43) | English About “0 users” (#11) |
| this PR | Demo 4 script + handover |

Branches are **independent** from `origin/new-design-system` (not stacked).
Expect conflicts on `custom.scss` and shared overlays when merging many PRs.
[#26](https://github.com/handlingar/handlingar-theme/pull/26) and
[#42](https://github.com/handlingar/handlingar-theme/pull/42) both touch the
homepage blog partial — if #26 lands first, #42 may already be covered.

Suggested land order: fonts/icons (#24–#25) → auth (#22–#23) → frontpage (#26,
then #42 if still needed) → search/request → Pro/Stripe/captcha → chrome
(help, mobile, a11y, learn, accordion) → tests/docs.

## What still needs Open Knowledge Sweden

These are not theme git changes:

- Stripe **test-mode** keys in Alaveteli config (not in this repo)
- Friendly Captcha account and keys if that path should go live (Google stays
  default until then)
- Merge path: `new-design-system` → `dev` now, or one release after week 12
- Staging deploy of the merged theme

## Left on the board (not closed here)

- Issue [#5](https://github.com/handlingar/handlingar-theme/issues/5) English
  nav — comment says copy is already corrected; leave open unless asked
- Live Stripe / Friendly Captcha as above

## Local notes

- `$alaveteli_route_extensions` must be the filename `custom-routes.rb`, not
  an absolute path. Copy theme `lib/config/custom-routes.rb` into Alaveteli
  `config/custom-routes.rb` for local Docker, then restart.
- Do not commit Alaveteli `config/general.yml`, generated theme-routes, or `.env`.
- Theme `.po` files often need an **app restart**.
- Homepage axe defaults skip `/` (orange how-it-works step number contrast).
