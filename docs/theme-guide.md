# Handlingar theme guide

This repository is an **Alaveteli overlay**, not a standalone app. Views in
`lib/views/`, Sass in `app/assets/stylesheets/`, and patches in `lib/` are
loaded into a running Alaveteli instance. Do not copy core controllers or
rewrite Stripe.js.

Design source: Tamm Studios *Design System Booklet* (Douglas Tamm & Riley
Eckerlo). Tokens live in `app/assets/stylesheets/responsive/_settings.scss`.
Local Docker setup is in the [README](../README.md).

Work on **`new-design-system`**. Do not merge to `main` without a supervisor
decision.

## Tokens

| Token | Value | Use |
| --- | --- | --- |
| White background | `#FBFBFB` | Page background |
| Brand Primary | `#333333` | Dark buttons, dark sections, body text |
| Brand Secondary | `#EB9C6A` | Nav bar, USP icons, primary button on a dark surface |
| Brand Accent | `#E6722A` | Dividing stroke, illustrations, focus accent |
| Text gray | `#555555` | Secondary text (contrast 4.5:1 on the page background) |
| Illustration gradient | `#20384E` → `#000000` | Large illustration panels only |

Grid: 12 columns, 50px page margin, 20px gutter. Mobile nav breakpoint:
`$main_menu-mobile_menu_cutoff` (`58em`).

Do not introduce Google Fonts, Adobe Fonts / Typekit, or Material Symbols.

## Buttons

| Role | Light background | Dark background (`#333` / hero / footer) |
| --- | --- | --- |
| Primary | Dark `#333` fill, white text | Brand Secondary `#EB9C6A` fill, dark text |
| Secondary | Dark outline | White outline |
| Tertiary | Underlined text | Brand Secondary text |

Never put an orange fill on a light background — that combination fails
contrast. Map Alaveteli’s `.link_button_green` / `input[type=submit]` through
the mixins in `custom.scss` (`%ds-primary`, `%ds-secondary`, `%ds-tertiary`).

## Typography

The booklet specifies Source Sans Pro. The theme uses **Source Sans 3**
(Regular 400, Semibold 600, Bold 700).

| | |
| --- | --- |
| Files | `app/assets/fonts/SourceSans3-{Regular,Semibold,Bold}.woff2` |
| Licence | SIL Open Font License 1.1 — `app/assets/fonts/OFL.md` |
| Source | [adobe-fonts/source-sans](https://github.com/adobe-fonts/source-sans) |
| Loading | `@font-face` in theme Sass, `font-display: swap` |
| Fallback | `"Helvetica Neue", Helvetica, Arial, sans-serif` |

Self-host the files in the theme. No `fonts.googleapis.com`,
`fonts.gstatic.com`, or `use.typekit.net`. Type scale (desktop): H1 48 / H2 36
/ H3 32 / H4 24 / H5 19 / subtitle 18 / body 16 / small 12.

WOFF2 files and the OFL text land with the self-host-fonts work
([PR #24](https://github.com/handlingar/handlingar-theme/pull/24)).

## Icons

UI icons are **local outline SVGs**, coloured with CSS `currentColor`. Primary
set: Iconoir (MIT). Social marks: Simple Icons (CC0).

See [icons.md](icons.md) for file, source, licence and usage.

Do not load an icon webfont. Do not mix filled and outline UI icons. Decorative
icons take `aria-hidden="true"` when the nearby text already explains them.

## Illustrations

Large scenes (how-it-works, create-account, authorities intro) use [unDraw](https://undraw.co)
SVGs recolored to Brand Accent `#E6722A`. Those are illustrations, not UI
icons. Keep them decorative (`aria-hidden` on the wrapper).

USP row marks stay as small icons, not unDraw scenes.

## Stripe (Handlingar Pro)

Alaveteli Pro uses Stripe.js v3. The theme **may restyle** the checkout. It
**must not**:

- change Stripe.js version
- remove or rename `#card-element`
- remove `js-stripe-subscription-form` / `js-stripe-update-form`
- change `AlaveteliPro.stripe_*` hooks

Style `form.stripe-form` and `#card-element` only. Test cards (when Stripe
keys and `:pro_pricing` are on): `4242…` succeeds; `4000 0000 0000 0002` shows
an error in `#card-errors`. Without keys, local `/pro/plans` returns 500 —
that is configuration, not a theme bug.

## Captcha

Google **reCAPTCHA v2** remains the default on every existing `recaptcha_tags`
/ `verify_recaptcha` call site.

Friendly Captcha is optional behind env vars (no secrets in git):

| Variable | Purpose |
| --- | --- |
| `CAPTCHA_PROVIDER=friendly_captcha` | Use Friendly instead of Google |
| `FRIENDLY_CAPTCHA_SITE_KEY` | Widget site key |
| `FRIENDLY_CAPTCHA_SECRET` | Server verify secret |
| `FRIENDLY_CAPTCHA_EU=1` | EU verify endpoint |

Production default during this work: Google, until Friendly is green on
staging.

## Translations

Theme strings live in `locale-theme/sv/app.po` and `locale-theme/en/app.po`.
They override Alaveteli core gettext. After changing `.po` files, restart the
app container — development does not always reload them.

Keep Swedish and English in parity on overlays you touch. Help legal pages
(privacy) are not marketing copy; leave GDPR text unless legal asks.

## How overlays work

| Path | Role |
| --- | --- |
| `lib/views/` | ERB overlays (`app/views/…` in Alaveteli) |
| `lib/config/custom-routes.rb` | Extra routes (`help/terms`, and GET `/profile/sign_up` once merged) |
| `lib/controller_patches.rb` | Small `class_eval` patches (e.g. `HelpController#terms`) |
| `lib/alavetelitheme.rb` | View path, assets, gettext |
| `app/assets/stylesheets/responsive/` | `_settings.scss` tokens + `custom.scss` |
| `locale-theme/` | Theme gettext |

To change a core template, copy it into `lib/views/<same/path>.html.erb` and
edit the copy. Keep the overlay as small as you can.

`$alaveteli_route_extensions` must stay a **filename** (`custom-routes.rb`),
not an absolute path. An absolute path makes Alaveteli fail to load routes.

GET `/profile/sign_up` is not in Alaveteli core (POST only). The auth-pages
work adds it in the theme. After that lands, the running Alaveteli app may
also need the generated routes file under the app `config/` directory — do
not commit Alaveteli `config/general.yml`, generated theme-routes, or `.env`.

## Definition of done (every PR)

- Runs locally against Alaveteli Docker
- Desktop and mobile
- Swedish and English
- No new accessibility regressions; visible focus on new controls
- Stripe / captcha untouched, or covered by a test note
- No Google Fonts or Adobe Fonts requests
- One concern per PR

## Local notes

- Compose from the **alaveteli** directory. Mount this repo over the theme
  path (see README). First Sass compile after an app restart can take minutes
  — do not hammer `localhost:3000` while it compiles.
- Seed public bodies are often English-locale only, so Swedish `/body` can
  show zero authorities. That is Alaveteli locale filtering, not a theme bug.
- Theme gettext changes need an app restart.

## Handover

Open Knowledge Sweden / Handlingar.se. Supervisor: Mattias Axell
(`mattias@okfn.se`).

Ops / staging (not in this repo):

- Stripe test-mode keys
- reCAPTCHA v2 keys
- Friendly Captcha Free keys when that path should go live
- Merge path: `new-design-system` → `dev` versus a collected release

Related pull requests against `new-design-system` (do not merge to `main`
without a supervisor decision): [#22](https://github.com/handlingar/handlingar-theme/pull/22)–[#35](https://github.com/handlingar/handlingar-theme/pull/35).
