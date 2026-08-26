# Imagery

Hero, search and Learn bands use a self-hosted photograph, not a remote CDN.

| File | Source | Licence | Used for |
| --- | --- | --- | --- |
| `app/assets/images/homepage-background.jpg` | [Unsplash](https://unsplash.com/photos/1454165804606-c3d57bc86b40) — Glenn Carstens-Peters | [Unsplash Licence](https://unsplash.com/license) | Desktop hero, `/body` hero, `/learn` hero |
| `app/assets/images/homepage-background-small.jpg` | Same photo, smaller crop | Unsplash Licence | Mobile hero |

Booklet 1.3 asks for open photography (messy desks / people at work), high contrast. The files are checked into the theme so pages do not call unsplash.com at runtime.

Do not hotlink Unsplash or other CDNs from templates.
