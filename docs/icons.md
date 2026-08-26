# Icons

UI icons are local SVG files in `app/assets/images/icons/`. They are inlined
with the `ds_icon` helper so colour comes from CSS `currentColor`.

Do not load Material Symbols or other icon webfonts. Do not mix Iconoir
filled and outline sets — this theme uses the **regular (outline)** set only.

The SVG files and helper land with the open-icons work
([PR #25](https://github.com/handlingar/handlingar-theme/pull/25)). Until that
merges, `new-design-system` still references Material Symbols in a few
templates.

| File | Source | Licence | Used for |
| --- | --- | --- | --- |
| `antenna-signal.svg` | [Iconoir](https://iconoir.com) 7.11.0 regular | MIT | Frontpage / Pro USP (streamline) |
| `mail-open.svg` | Iconoir 7.11.0 regular | MIT | Frontpage / Pro USP (contact details) |
| `lock.svg` | Iconoir 7.11.0 regular | MIT | Frontpage / Pro USP (private requests) |
| `view-grid.svg` | Iconoir 7.11.0 regular | MIT | Pro USP (batch requests) |
| `bell.svg` | Iconoir 7.11.0 regular | MIT | Pro USP (action alerts) |
| `page.svg` | Iconoir 7.11.0 regular | MIT | Pro USP (save drafts) |
| `edit-pencil.svg` | Iconoir 7.11.0 regular | MIT | How it works (make a request) |
| `mail.svg` | Iconoir 7.11.0 regular | MIT | How it works (wait for a response) |
| `globe.svg` | Iconoir 7.11.0 regular | MIT | How it works (published) |
| `user-plus.svg` | Iconoir 7.11.0 regular | MIT | Create-account illustration |
| `book.svg` | Iconoir 7.11.0 regular | MIT | Authorities list illustration |
| `facebook.svg` | [Simple Icons](https://simpleicons.org) 13.21.0 | CC0 1.0 | Footer Facebook link |
| `x.svg` | Simple Icons 13.21.0 | CC0 1.0 | Footer X / Twitter link |

Iconoir licence: https://github.com/iconoir-icons/iconoir/blob/main/LICENSE  
Simple Icons licence: https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md
