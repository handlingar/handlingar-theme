Handlingar Theme
==============

Create pull request from [alavetelitheme master branch](https://github.com/mysociety/alavetelitheme/tree/master) to our [dev](https://github.com/handlingar/handlingar-theme/tree/dev) branch.

Then do your suggested changes and pushed into [dev](https://github.com/handlingar/handlingar-theme/tree/dev) branch.

Test these changes on the development server.

If everything from [dev](https://github.com/handlingar/handlingar-theme/tree/dev) branch works correctly on development server we then do a Pull Request (PR) to [main](https://github.com/handlingar/handlingar-theme/tree/main) branch.

Then we push [main](https://github.com/handlingar/handlingar-theme/tree/main) branch to production server.

### Deploy updates on development server or production server
Use the following instructions to deploy changes that have been made. See this [link](https://gitlab.com/handlingar/handlingar/-/wikis/Uppdatera-tema) from Handlingar Wiki.

Read more about project work order at: [Handlingar Wiki](https://gitlab.com/handlingar/handlingar/-/wikis/)

Run this project locally
==============

This repository is an **Alaveteli theme**, not a standalone application — it
only contains view/style/Ruby overlays that are loaded *into* a running
[Alaveteli](https://alaveteli.org) instance. To preview it locally you run
Alaveteli's Docker development environment with this theme mounted in.

### Prerequisites
- [Docker Desktop](https://docs.docker.com/get-docker/) (v20+) running
- `git`
- ~25 GB free disk (the Alaveteli image, Postgres and Xapian index are large)

### 1. Lay out the directories
Alaveteli expects an `alaveteli-themes/` directory next to its own checkout.
Clone the core app and place this theme alongside it:

    # in a parent directory of your choice
    git clone https://github.com/mysociety/alaveteli.git
    mkdir -p alaveteli-themes
    git clone git@github.com:sameerabit/handlingar-theme.git alaveteli-themes/handlingar-theme

Resulting layout:

    .
    ├── alaveteli/                     # the core app (Docker dev env lives here)
    └── alaveteli-themes/
        └── handlingar-theme/          # this repository

### 2. Bootstrap Alaveteli and point it at this theme

    cd alaveteli
    ./docker/bootstrap                 # copies example configs, pulls base images

    # create a theme config and make it the active one
    sed 's#https://github.com/mysociety/alavetelitheme.git#https://github.com/sameerabit/handlingar-theme.git#' \
      config/general-alavetelitheme.yml > config/general-handlingar-theme.yml
    ln -sfn config/general-handlingar-theme.yml config/general.yml

The setup script reads the `config/general.yml` symlink, derives the theme name
(`handlingar-theme`) and switches to it automatically.

### 3. Build, migrate, seed and index (first run: 20–40 min)

    ./docker/setup --reset-data

This builds the images, installs gems, runs `script/switch-theme.rb`
(symlinking the theme into `lib/themes/`), migrates the DB, loads sample data
and builds the Xapian search index.

### 4. Start the app

    docker compose up -d app sidekiq

Then open **http://localhost:3000**. Outgoing email is captured by MailHog at
**http://localhost:1080**.

### Live-editing the theme
To have your edits in this repo render immediately in the running container,
add a `docker-compose.override.yml` in the `alaveteli/` directory that bind-mounts
your theme checkout over the in-container theme path:

    services:
      app:
        volumes:
          - /absolute/path/to/alaveteli-themes/handlingar-theme:/alaveteli-themes/handlingar-theme
      sidekiq:
        volumes:
          - /absolute/path/to/alaveteli-themes/handlingar-theme:/alaveteli-themes/handlingar-theme

Restart with `docker compose up -d app sidekiq`. SCSS recompiles on the next
page load in development; if a stylesheet change isn't picked up, force it with:

    docker compose exec app bin/rails assets:clobber

### Useful commands

    docker compose logs -f app          # tail application logs
    docker compose stop                 # stop containers (keeps data)
    docker compose up -d app sidekiq    # start again
    docker compose down                 # remove containers (volumes persist)

### Troubleshooting
- **Docker daemon won't start / "no space left":** the Docker VM disk image can
  fill the host. Reclaim space with `docker system prune -a` (daemon must be
  running) or, as a last resort, reset Docker Desktop's data — this wipes all
  local images/containers/volumes.
- **Theme not applied:** confirm `config/general.yml` is a symlink to
  `config/general-handlingar-theme.yml` and that its `THEME_URLS` ends in
  `handlingar-theme.git`, then re-run `./docker/setup`.

This theme is based on Alavetelitheme example theme. Read more below.

Alavetelitheme
==============

This is a "hello world" type theme package for Alaveteli.

The intention is to support simple overlaying of templates and
resources without the need to touch the core Alaveteli software.

Typical usage should be limited to that described in the [documentation](http://alaveteli.org/docs/customising/themes/):


## To install:

In the Alaveteli `general.yml` configuration file change the default mysociety  theme repository to your theme repository in the [`THEME_URLS`](http://alaveteli.org/docs/customising/config/#theme_urls) setting:

    THEME_URLS:
      - 'git://github.com/YOUR_GITHUB_USERNAME/YOUR_THEME_NAME.git'

You can then switch the theme the application is using:

    bundle exec rake themes:install

## To run tests:

From the Alaveteli Rails root, with this theme at `lib/themes/handlingar-theme`:

        bundle exec rspec lib/themes/handlingar-theme/spec

In Docker:

        docker compose exec -e RAILS_ENV=test app bundle exec rspec lib/themes/handlingar-theme/spec

The suite loads the theme via `ALAVETELI_TEST_THEME`, checks Stripe and
reCAPTCHA markup, and renders frontpage, sign-in and `/body`.

Overlay contracts also run without Rails:

        ruby script/check-overlay-contracts.rb

Copyright (c) 2011 mySociety, released under the MIT license
